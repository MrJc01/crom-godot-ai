@tool
extends Node

# ==============================================================================
# CromAgentClient: integração NATIVA com o daemon do crom-agente.
#
# Fala o protocolo WebSocket do daemon (ws://127.0.0.1:9090/ws):
#   -> {"type":"subscribe","workspace":...}
#   -> {"type":"run","workspace":...,"task":...,"session":...,"provider":...,"model":...}
#   -> {"type":"permission_response","workspace":...,"payload":{"approved":..,"remember":..}}
#   -> {"type":"stop","workspace":...}
#   <- {"success","stream","error","data":{...}} com data.type em
#      {status, started, stream_chunk, message, ask_permission, message_injected, error}
#      ou eventos do loop ReAct {"event":"thinking|tool_call|tool_result|...", "data":{...}}
#
# Também cuida do ciclo de vida: autostart do daemon via binário embutido,
# escrita do .crom/config.json do workspace e registro do servidor MCP
# godot-editor no ~/.crom/global.json (ferramentas do Editor para o agente).
# ==============================================================================

signal connection_changed(connected: bool)
signal agent_status_changed(status: String)
signal stream_chunk(text: String)
signal agent_message(role: String, text: String)
signal agent_event(event: Dictionary)
signal permission_requested(action: String, target: String)
signal run_started()
signal error_occurred(msg: String)

const DAEMON_WS_URL := "ws://127.0.0.1:9090/ws"
const GODOT_MCP_PORT := 8080
const RETRY_INTERVAL_SEC := 3.0
const MAX_CONNECT_ATTEMPTS := 5

var provider: String = "openrouter"
var model: String = "google/gemini-2.5-flash"
var api_key: String = ""
var permission_mode: String = "ask_every_time"
var auto_approve: bool = false
var session_id: String = "godot-editor"

var is_connected_to_daemon: bool = false
var is_busy: bool = false
var last_status: String = "idle"

var _ws: WebSocketPeer = null
var _was_open: bool = false
var _connect_attempts: int = 0
var _retry_timer: float = 0.0
var _daemon_spawned: bool = false
var _pending_tasks: Array[String] = []
var _workspace: String = ""

func _ready() -> void:
	_workspace = ProjectSettings.globalize_path("res://").rstrip("/")
	set_process(true)
	_write_workspace_config()
	_register_godot_mcp_server()
	_open_socket()

# --- API pública -------------------------------------------------------------

func set_config(p_provider: String, p_model: String, p_api_key: String, p_permission_mode: String = "") -> void:
	provider = p_provider
	model = p_model
	api_key = p_api_key
	if p_permission_mode != "":
		permission_mode = p_permission_mode
	_write_workspace_config()

func new_session() -> void:
	var dt := Time.get_datetime_dict_from_system()
	session_id = "godot-%04d%02d%02d-%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

func send_user_prompt(task: String) -> void:
	if task.strip_edges() == "":
		return
	_write_workspace_config()
	if _is_open():
		_send_run(task)
	else:
		_pending_tasks.append(task)
		_connect_attempts = 0
		_open_socket()

func respond_permission(approved: bool, remember: bool = false) -> void:
	_send_json({
		"type": "permission_response",
		"workspace": _workspace,
		"payload": { "approved": approved, "remember": remember },
	})

func set_auto_approve(enabled: bool) -> void:
	auto_approve = enabled
	if _is_open():
		_send_json({ "type": "set_auto_approve", "workspace": _workspace, "auto_approve": enabled })

func interrupt() -> void:
	_send_json({ "type": "stop", "workspace": _workspace })

func restart_daemon() -> void:
	var bin := _get_agent_binary_path()
	if bin != "":
		OS.create_process(bin, ["daemon", "restart"])
		_daemon_spawned = true
		_connect_attempts = 0
		_retry_timer = RETRY_INTERVAL_SEC

# --- Loop de rede ------------------------------------------------------------

func _process(delta: float) -> void:
	if _ws == null:
		if _retry_timer > 0.0:
			_retry_timer -= delta
			if _retry_timer <= 0.0 and _connect_attempts < MAX_CONNECT_ATTEMPTS:
				_open_socket()
		return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				is_connected_to_daemon = true
				_connect_attempts = 0
				connection_changed.emit(true)
				_send_json({ "type": "subscribe", "workspace": _workspace })
				for task in _pending_tasks:
					_send_run(task)
				_pending_tasks.clear()
			while _ws.get_available_packet_count() > 0:
				var pkt := _ws.get_packet().get_string_from_utf8()
				_handle_packet(pkt)
		WebSocketPeer.STATE_CLOSED:
			var had_conn := _was_open
			_ws = null
			_was_open = false
			if had_conn:
				is_connected_to_daemon = false
				connection_changed.emit(false)
				_retry_timer = RETRY_INTERVAL_SEC
			else:
				_connect_attempts += 1
				if not _daemon_spawned:
					_spawn_daemon()
				if _connect_attempts < MAX_CONNECT_ATTEMPTS:
					_retry_timer = RETRY_INTERVAL_SEC
				elif not _pending_tasks.is_empty():
					_pending_tasks.clear()
					error_occurred.emit("Não foi possível conectar ao daemon do crom-agente (porta 9090). Verifique a instalação do binário em addons/crom_ai/bin/.")

func _open_socket() -> void:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(DAEMON_WS_URL)
	if err != OK:
		_ws = null
		_retry_timer = RETRY_INTERVAL_SEC

func _is_open() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN

func _send_json(data: Dictionary) -> void:
	if _is_open():
		_ws.send_text(JSON.stringify(data))

func _send_run(task: String) -> void:
	is_busy = true
	run_started.emit()
	_send_json({
		"type": "run",
		"workspace": _workspace,
		"task": task,
		"session": session_id,
		"provider": provider,
		"model": model,
		"auto_approve": auto_approve,
	})

# --- Tratamento de eventos do daemon ------------------------------------------

func _handle_packet(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var resp: Dictionary = parsed

	if resp.get("error", "") != "" and not resp.get("success", true):
		is_busy = false
		error_occurred.emit(str(resp["error"]))

	var data = resp.get("data")
	if data is String:
		data = JSON.parse_string(data)
	if not (data is Dictionary):
		return
	var payload: Dictionary = data

	# Eventos do loop ReAct (thinking, tool_call, tool_result, ...)
	if payload.has("event"):
		agent_event.emit(payload)
		return

	match str(payload.get("type", "")):
		"status":
			var status := str(payload.get("status", "idle"))
			last_status = status
			is_busy = not (status in ["finished", "idle", "waiting_user_input"] or status.begins_with("error:"))
			agent_status_changed.emit(status)
			if status.begins_with("error:"):
				error_occurred.emit(status.trim_prefix("error:").strip_edges())
		"started":
			is_busy = true
		"stream_chunk":
			stream_chunk.emit(str(payload.get("content", "")))
		"message":
			agent_message.emit(str(payload.get("role", "assistant")), str(payload.get("content", "")))
		"ask_permission":
			permission_requested.emit(str(payload.get("action", "")), str(payload.get("target", "")))
		"message_injected":
			pass
		"error":
			is_busy = false
			error_occurred.emit(str(payload.get("error", "Erro desconhecido no daemon.")))

# --- Ciclo de vida do daemon ---------------------------------------------------

func _spawn_daemon() -> void:
	_daemon_spawned = true
	var bin := _get_agent_binary_path()
	if bin == "":
		error_occurred.emit("Binário do crom-agente não encontrado em addons/crom_ai/bin/. Baixe a release ou compile o daemon.")
		return
	OS.create_process(bin, ["daemon", "start"])
	print("[CromAgentClient] Daemon do crom-agente iniciado em segundo plano (%s)." % bin)

func _platform_suffix() -> String:
	var arch := "amd64"
	if Engine.get_architecture_name().contains("arm"):
		arch = "arm64"
	match OS.get_name():
		"Windows":
			return "windows-%s.exe" % arch
		"macOS":
			return "darwin-%s" % arch
		_:
			return "linux-%s" % arch

func _get_agent_binary_path() -> String:
	var base := ProjectSettings.globalize_path("res://addons/crom_ai/bin/")
	for candidate in ["crom-agente-" + _platform_suffix(), "crom-agente"]:
		var path := base.path_join(candidate)
		if FileAccess.file_exists(path):
			return path
	return ""

func _get_mcp_binary_path() -> String:
	var base := ProjectSettings.globalize_path("res://addons/crom_ai/bin/")
	var path := base.path_join("godot-mcp-" + _platform_suffix())
	if FileAccess.file_exists(path):
		return path
	return ""

# --- Configuração (workspace e global) ----------------------------------------

func _write_workspace_config() -> void:
	if not DirAccess.dir_exists_absolute("res://.crom"):
		DirAccess.make_dir_recursive_absolute("res://.crom")

	var config_data := {
		"workspace_name": ProjectSettings.get_setting("application/config/name", "GodotProject"),
		"provider": provider,
		"model": model,
		"permission_mode": permission_mode,
		"workspace_jail": true,
		"auto_verify": true,
	}
	var f := FileAccess.open("res://.crom/config.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(config_data, "\t"))
		f.close()

	var env_lines: Array[String] = []
	match provider:
		"openrouter":
			if api_key != "": env_lines.append("OPENROUTER_API_KEY=" + api_key)
		"ollama":
			env_lines.append("OLLAMA_HOST=http://localhost:11434")
		"cromia":
			if api_key != "": env_lines.append("CROMIA_API_KEY=" + api_key)
		"openai":
			if api_key != "": env_lines.append("OPENAI_API_KEY=" + api_key)
		"anthropic":
			if api_key != "": env_lines.append("ANTHROPIC_API_KEY=" + api_key)
		"gemini":
			if api_key != "": env_lines.append("GEMINI_API_KEY=" + api_key)
	var f_env := FileAccess.open("res://.crom/.env", FileAccess.WRITE)
	if f_env:
		f_env.store_string("\n".join(env_lines))
		f_env.close()

# Registra (ou atualiza) o servidor MCP godot-editor no ~/.crom/global.json.
# Se a entrada mudou e o daemon já roda, reinicia-o para recarregar as tools.
func _register_godot_mcp_server() -> void:
	var mcp_bin := _get_mcp_binary_path()
	if mcp_bin == "":
		push_warning("[CromAgentClient] Binário godot-mcp não encontrado; ferramentas de editor não serão registradas no agente.")
		return

	var home := OS.get_environment("USERPROFILE") if OS.get_name() == "Windows" else OS.get_environment("HOME")
	if home == "":
		return
	var global_path := home.path_join(".crom").path_join("global.json")

	var global_cfg: Dictionary = {}
	if FileAccess.file_exists(global_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(global_path))
		if parsed is Dictionary:
			global_cfg = parsed
		else:
			push_warning("[CromAgentClient] ~/.crom/global.json inválido; não será alterado para não corromper a config do daemon.")
			return

	var entry := {
		"name": "godot-editor",
		"command": mcp_bin,
		"args": ["--mcp-stdio", "--port", str(GODOT_MCP_PORT)],
		"env": ["GODOT_PROJECT_DIR=" + _workspace],
	}

	var servers: Array = global_cfg.get("mcp_servers", []) if global_cfg.get("mcp_servers") is Array else []
	var changed := true
	var replaced := false
	for i in range(servers.size()):
		if servers[i] is Dictionary and str(servers[i].get("name", "")) == "godot-editor":
			changed = not _mcp_entry_matches(servers[i], entry)
			servers[i] = entry
			replaced = true
			break
	if not replaced:
		servers.append(entry)
	if not changed:
		return

	global_cfg["mcp_servers"] = servers
	DirAccess.make_dir_recursive_absolute(home.path_join(".crom"))
	var f := FileAccess.open(global_path, FileAccess.WRITE)
	if f:
		# O parser JSON do GDScript transforma todo número em float (3 -> 3.0), o que
		# quebra o unmarshal do daemon Go (campos int). Reverte floats inteiros para int.
		f.store_string(JSON.stringify(_coerce_whole_floats(global_cfg), "  "))
		f.close()
		print("[CromAgentClient] Servidor MCP godot-editor registrado em %s" % global_path)
		# O daemon lê o global.json no boot; reinicia para carregar as novas ferramentas.
		var bin := _get_agent_binary_path()
		if bin != "":
			OS.create_process(bin, ["daemon", "restart"])
			_daemon_spawned = true

# Converte recursivamente floats com valor inteiro (3.0) de volta para int (3),
# preservando o formato que o daemon Go espera no global.json.
func _coerce_whole_floats(value: Variant) -> Variant:
	if value is float:
		if is_equal_approx(value, floor(value)) and abs(value) < 1e15:
			return int(value)
		return value
	elif value is Dictionary:
		var out := {}
		for k in value:
			out[k] = _coerce_whole_floats(value[k])
		return out
	elif value is Array:
		var out := []
		for e in value:
			out.append(_coerce_whole_floats(e))
		return out
	return value

# Compara duas entradas de MCP server por campo (ordem-independente)
func _mcp_entry_matches(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("name", "")) != str(b.get("name", "")):
		return false
	if str(a.get("command", "")) != str(b.get("command", "")):
		return false
	if JSON.stringify(a.get("args", [])) != JSON.stringify(b.get("args", [])):
		return false
	if JSON.stringify(a.get("env", [])) != JSON.stringify(b.get("env", [])):
		return false
	return true
