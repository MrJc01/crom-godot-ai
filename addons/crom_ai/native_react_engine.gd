@tool
extends Node

signal message_added(role: String, text: String)
signal react_finished(answer: String)

var is_busy: bool = false
var _go_pid: int = 0
var _go_pipe: Variant = null
var _provider: String = "openrouter"
var _model: String = "google/gemini-2.5-flash"
var _api_key: String = ""

func set_config(provider: String, model: String, api_key: String) -> void:
	_provider = provider
	_model = model
	_api_key = api_key
	_write_go_workspace_config()

func send_user_prompt(prompt: String) -> void:
	if is_busy:
		return
	is_busy = true
	
	_write_go_workspace_config()
	
	var binary_path: String = _get_binary_path()
	if binary_path == "" or not FileAccess.file_exists(binary_path):
		emit_signal("message_added", "system", "Erro: Binário 'crom-agente' não encontrado no plugin.")
		is_busy = false
		emit_signal("react_finished", "Erro: Executável ausente.")
		return
		
	emit_signal("message_added", "system", "Iniciando motor Go (crom-agente)...")
	
	var arguments: PackedStringArray = ["run", prompt]
	var res: Dictionary = OS.execute_with_pipe(binary_path, arguments)
	if res.has("pid") and res.get("pid") > 0:
		_go_pid = res["pid"]
		_go_pipe = res["stdio"]
		set_process(true)
	else:
		emit_signal("message_added", "system", "Erro ao iniciar o processo do crom-agente Go.")
		is_busy = false
		emit_signal("react_finished", "Erro na execução.")

func _get_binary_path() -> String:
	var base_path: String = ProjectSettings.globalize_path("res://addons/crom_ai/bin/")
	var os_name: String = OS.get_name()
	var bin_name: String = ""
	
	match os_name:
		"Windows":
			bin_name = "crom-agente-windows-amd64.exe"
		"macOS":
			bin_name = "crom-agente-darwin-amd64"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD":
			bin_name = "crom-agente-linux-amd64"
		_:
			bin_name = "crom-agente"
			
	var full_path: String = base_path.path_join(bin_name)
	if FileAccess.file_exists(full_path):
		return full_path
		
	# Fallbacks
	var local_fallback: String = base_path.path_join("crom-agente")
	if FileAccess.file_exists(local_fallback):
		return local_fallback
		
	var dev_fallback: String = "/home/j/Documentos/GitHub/crom-agente/bin/crom-agente"
	if FileAccess.file_exists(dev_fallback):
		return dev_fallback
		
	return ""

func interrupt() -> void:
	if _go_pid > 0:
		OS.kill(_go_pid)
		_go_pid = 0
		_go_pipe = null
		is_busy = false
		emit_signal("message_added", "system", "Execução do crom-agente interrompida pelo usuário.")
		emit_signal("react_finished", "Interrompido.")

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if _go_pipe and _go_pipe is FileAccess and _go_pipe.is_open():
		var avail: int = _go_pipe.get_length()
		if avail > 0:
			var buffer: PackedByteArray = _go_pipe.get_buffer(avail)
			var chunk: String = buffer.get_string_from_utf8()
			if chunk != "":
				var clean_chunk: String = _clean_ansi_escape_codes(chunk)
				emit_signal("message_added", "assistant", clean_chunk)
				
		if not OS.is_process_running(_go_pid):
			_go_pipe.close()
			_go_pipe = null
			_go_pid = 0
			is_busy = false
			set_process(false)
			emit_signal("message_added", "system", "Execução concluída.")
			emit_signal("react_finished", "Processo Go concluído.")

func _clean_ansi_escape_codes(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\\\x1B\\\\[[0-9;]*[a-zA-Z]")
	var res: String = regex.sub(text, "", true)
	res = res.replace("\u001b", "")
	return res

func _write_go_workspace_config() -> void:
	var dir_path: String = "res://.crom"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var config_data: Dictionary = {
		"workspace_name": "GodotProjectWorkspace",
		"provider": _provider,
		"model": _model,
		"permission_mode": "total_access",
		"workspace_jail": false,
		"auto_verify": true
	}
	
	var f: FileAccess = FileAccess.open("res://.crom/config.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(config_data, "\t"))
		f.close()
		
	var env_content: String = ""
	match _provider:
		"openrouter": env_content = "OPENROUTER_API_KEY=" + _api_key
		"ollama": env_content = "OLLAMA_HOST=http://localhost:11434"
		"cromia": env_content = "CROMIA_API_KEY=" + _api_key
		"openai": env_content = "OPENAI_API_KEY=" + _api_key
		
	var f_env: FileAccess = FileAccess.open("res://.crom/.env", FileAccess.WRITE)
	if f_env:
		f_env.store_string(env_content)
		f_env.close()
