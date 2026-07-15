@tool
extends Control

# ==============================================================================
# CromAIChatDock (@tool): Painel Lateral Integrado à IDE Godot e ao App
# Permite ao desenvolvedor/jogador conversar com o Agente, configurar Ollama/OpenRouter/API Key,
# e monitorar o Loop ReAct visualmente direto na barra lateral.
# ==============================================================================

var react_engine: Node = null
var pending_benchmark_confirm: bool = false
var _chat_history: Array[Dictionary] = []
var _session_id: String = ""
var _error_lut: Array[String] = []
var _last_log_size: int = 0
var _log_timer: Timer = null
var _error_popup: ConfirmationDialog = null
var _last_error_context: String = ""

@onready var history_btn: Button = $MainVBox/HeaderHBox/HistoryBtn
@onready var history_panel: VBoxContainer = $MainVBox/HistoryPanel
@onready var history_list: VBoxContainer = $MainVBox/HistoryPanel/HistoryScroll/HistoryList
@onready var back_to_chat_btn: Button = $MainVBox/HistoryPanel/BackToChatBtn
@onready var quick_actions_hbox: HBoxContainer = $MainVBox/QuickActionsHBox
@onready var input_hbox: HBoxContainer = $MainVBox/InputHBox

@onready var config_panel: PanelContainer = $MainVBox/ConfigPanel
@onready var provider_option: OptionButton = $MainVBox/ConfigPanel/ConfigVBox/ProviderHBox/ProviderOption
@onready var model_input: LineEdit = $MainVBox/ConfigPanel/ConfigVBox/ModelHBox/ModelInput
@onready var api_key_input: LineEdit = $MainVBox/ConfigPanel/ConfigVBox/ApiKeyHBox/ApiKeyInput
@onready var save_config_btn: Button = $MainVBox/ConfigPanel/ConfigVBox/SaveConfigBtn
@onready var toggle_config_btn: Button = $MainVBox/HeaderHBox/ToggleConfigBtn

@onready var chat_log: RichTextLabel = $MainVBox/ChatLog
@onready var prompt_input: LineEdit = $MainVBox/InputHBox/PromptInput
@onready var send_btn: Button = $MainVBox/InputHBox/SendBtn

@onready var build_mode_btn: Button = $MainVBox/QuickActionsHBox/BuildModeBtn
@onready var play_mode_btn: Button = $MainVBox/QuickActionsHBox/PlayModeBtn
@onready var clear_btn: Button = $MainVBox/QuickActionsHBox/ClearBtn

func _ready() -> void:
	_init_provider_options()
	_load_saved_config()
	
	# Instancia ou conecta ao NativeReActEngine
	var EngineClass = load("res://addons/crom_ai/native_react_engine.gd")
	if EngineClass:
		# Busca pelo CommandProcessor local ou no tree
		var proc = _find_command_processor()
		react_engine = EngineClass.new(proc)
		react_engine.name = "NativeReActEngine"
		add_child(react_engine)
		
		# Conecta sinais do ReAct para atualizar a UI do Chat Lateral em tempo real
		react_engine.message_added.connect(_on_agent_message_added)
		react_engine.tool_executing.connect(_on_tool_executing)
		react_engine.react_finished.connect(_on_react_finished)
		react_engine.error_occurred.connect(_on_error_occurred)
		
		# Aplica configuração inicial no motor
		_apply_config_to_engine()
	
	# Conexões de botões da UI
	toggle_config_btn.pressed.connect(func(): config_panel.visible = not config_panel.visible)
	save_config_btn.pressed.connect(_save_and_apply_config)
	send_btn.pressed.connect(_on_send_pressed)
	prompt_input.text_submitted.connect(_on_send_pressed)
	chat_log.meta_clicked.connect(_on_chat_log_meta_clicked)
	history_btn.pressed.connect(_on_history_btn_pressed)
	back_to_chat_btn.pressed.connect(_on_back_to_chat_btn_pressed)
	
	build_mode_btn.pressed.connect(func(): _send_direct_tool("switch_mode", {"mode": "build"}))
	play_mode_btn.pressed.connect(func(): _send_direct_tool("switch_mode", {"mode": "play"}))
	clear_btn.pressed.connect(func():
		chat_log.clear()
		_chat_history.clear()
		_session_id = ""
		if react_engine and react_engine.has_method("_reset_messages"):
			react_engine._reset_messages()
		_chat_history.append({
			"role": "system",
			"text": "Histórico do chat limpo.",
			"expanded": false
		})
		_render_chat_log()
	)
	
	_chat_history.append({
		"role": "system",
		"text": "CromAI Godot Agent — Chat Lateral Inicializado!\nPronto para receber instruções de criação (Build) e exploração (Play).",
		"expanded": false
	})
	_render_chat_log()
	_start_log_monitoring()

func _init_provider_options() -> void:
	provider_option.clear()
	provider_option.add_item("OpenRouter (ex: google/gemini-2.5-flash)", 0)
	provider_option.add_item("Ollama Local (ex: llama3 / qwen)", 1)
	provider_option.add_item("CromIA Cloud", 2)
	provider_option.add_item("OpenAI Compatible", 3)
	provider_option.item_selected.connect(_on_provider_selected)

func _on_provider_selected(index: int) -> void:
	match index:
		0: # OpenRouter
			if model_input.text == "" or model_input.text == "llama3":
				model_input.text = "google/gemini-2.5-flash"
			api_key_input.placeholder_text = "sk-or-v1-..."
		1: # Ollama
			if model_input.text == "" or "gemini" in model_input.text:
				model_input.text = "llama3"
			api_key_input.placeholder_text = "Não necessário para Ollama local"
		2: # CromIA
			model_input.text = "google/gemini-2.5-flash"
			api_key_input.placeholder_text = "Chave da CromIA Cloud"
		3: # OpenAI
			model_input.text = "gpt-4o"
			api_key_input.placeholder_text = "sk-..."

func _load_saved_config() -> void:
	if FileAccess.file_exists("user://crom_ai_config.cfg"):
		var cfg = ConfigFile.new()
		var err = cfg.load("user://crom_ai_config.cfg")
		if err == OK:
			var prov_idx = int(cfg.get_value("ai", "provider_index", 0))
			provider_option.select(prov_idx)
			model_input.text = str(cfg.get_value("ai", "model", "google/gemini-2.5-flash"))
			var key = str(cfg.get_value("ai", "api_key", ""))
			if key.is_empty() or key == "null":
				key = "sk-or-v1-key-removed-by-antigravity"
			api_key_input.text = key
			return
			
	provider_option.select(0)
	model_input.text = "google/gemini-2.5-flash"
	api_key_input.text = "sk-or-v1-key-removed-by-antigravity"

func _save_and_apply_config() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("ai", "provider_index", provider_option.selected)
	cfg.set_value("ai", "model", model_input.text.strip_edges())
	cfg.set_value("ai", "api_key", api_key_input.text.strip_edges())
	cfg.save("user://crom_ai_config.cfg")
	
	_apply_config_to_engine()
	_append_to_log("[color=#f9e2af]💾 Configurações salvas: %s -> %s[/color]" % [provider_option.get_item_text(provider_option.selected), model_input.text])
	config_panel.visible = false

func _apply_config_to_engine() -> void:
	if not react_engine:
		return
	var prov_str = "openrouter"
	match provider_option.selected:
		0: prov_str = "openrouter"
		1: prov_str = "ollama"
		2: prov_str = "cromia"
		3: prov_str = "openai"
		
	if react_engine.has_method("set_config"):
		react_engine.set_config(prov_str, model_input.text.strip_edges(), api_key_input.text.strip_edges())

func _on_send_pressed(_text: String = "") -> void:
	if react_engine and react_engine.is_busy:
		react_engine.interrupt()
		return
		
	var prompt = prompt_input.text.strip_edges()
	if prompt == "":
		return
		
	prompt_input.text = ""
	_chat_history.append({
		"role": "user",
		"text": prompt,
		"expanded": false
	})
	_render_chat_log()
	_save_session()
	
	if prompt.to_lower().begins_with("/limpar") or prompt.to_lower().begins_with("/clean"):
		_chat_history.append({
			"role": "system",
			"text": "Limpando todos os jogos gerados da pasta res://games/...",
			"expanded": false
		})
		_clean_games_dir("res://games")
		_chat_history.append({
			"role": "system",
			"text": "Jogos limpos! Ambiente pronto para verificação funcional ou nova construção pelo Agente.",
			"expanded": false
		})
		_render_chat_log()
		_save_session()
		return
	
	if prompt.to_lower().begins_with("/benchmark"):
		pending_benchmark_confirm = true
		_chat_history.append({
			"role": "system",
			"text": "Comando /benchmark detectado! Deseja iniciar a verificação e construção funcional dos minijogos via Agente IA ReAct NATIVO? Digite 'confirmar' ou 'sim' para iniciar.",
			"expanded": false
		})
		_render_chat_log()
		_save_session()
		return
		
	if pending_benchmark_confirm and (prompt.to_lower() in ["sim", "confirmar", "yes", "ok", "s", "prosseguir"]):
		pending_benchmark_confirm = false
		_run_live_agent_benchmark()
		return
	elif pending_benchmark_confirm:
		pending_benchmark_confirm = false
		_chat_history.append({
			"role": "system",
			"text": "Comando /benchmark cancelado.",
			"expanded": false
		})
		_render_chat_log()
		_save_session()
		return
		
	_disable_input()
	
	if react_engine and react_engine.has_method("send_user_prompt"):
		react_engine.send_user_prompt(prompt)
	else:
		_chat_history.append({
			"role": "system",
			"text": "Erro: Motor ReAct nativo não inicializado.",
			"expanded": false
		})
		_render_chat_log()
		_save_session()
		_enable_input()

func _clean_games_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				if dir.current_is_dir():
					_clean_games_dir(path + "/" + file_name)
					dir.remove(file_name)
				else:
					dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func _run_live_agent_benchmark() -> void:
	_chat_history.append({
		"role": "system",
		"text": "Iniciando Verificação Funcional ao Vivo... A engine processará as cenas, injetando telemetria em tempo real.",
		"expanded": false
	})
	_disable_input()
	
	# Pre-criar diretórios vazios e README de base
	var game_registry = load("res://addons/crom_ai/core/game_registry.gd")
	if game_registry:
		game_registry.setup_benchmark_directories()
		_chat_history.append({
			"role": "system",
			"text": "Diretórios base e res://games/README.md criados com sucesso!",
			"expanded": false
		})
	_render_chat_log()
	
	if react_engine and react_engine.has_method("send_user_prompt"):
		var benchmark_prompt := """Você é o Agente ReAct Godot na IDE. O usuário iniciou o /benchmark.
Sua tarefa é CRIAR, IMPLEMENTAR COMPLETA E OBRIGATORIAMENTE todos os 15 jogos a seguir:

1. pong (Crom Pong ReAct):
   - Leia instruções em: res://games/pong/README.md
   - Script: res://games/pong/pong.gd e Cena: res://games/pong/pong.tscn
2. flappy (Flappy AI Bird):
   - Leia instruções em: res://games/flappy/README.md
   - Script: res://games/flappy/flappy.gd e Cena: res://games/flappy/flappy.tscn
3. snake (Snake Cyber Grid):
   - Leia instruções em: res://games/snake/README.md
   - Script: res://games/snake/snake.gd e Cena: res://games/snake/snake.tscn
4. breakout (Neon Breakout):
   - Leia instruções em: res://games/breakout/README.md
   - Script: res://games/breakout/breakout.gd e Cena: res://games/breakout/breakout.tscn
5. space_invaders (Space AI Invaders):
   - Leia instruções em: res://games/space_invaders/README.md
   - Script: res://games/space_invaders/space_invaders.gd e Cena: res://games/space_invaders/space_invaders.tscn
6. tetris (Block Matrix):
   - Leia instruções em: res://games/tetris/README.md
   - Script: res://games/tetris/tetris.gd e Cena: res://games/tetris/tetris.tscn
7. platformer (Cyber Runner 2D):
   - Leia instruções em: res://games/platformer/README.md
   - Script: res://games/platformer/platformer.gd e Cena: res://games/platformer/platformer.tscn
8. racing_topdown (Turbo Drift 2D):
   - Leia instruções em: res://games/racing_topdown/README.md
   - Script: res://games/racing_topdown/racing_topdown.gd e Cena: res://games/racing_topdown/racing_topdown.tscn
9. tower_defense (AI Turret Defense):
   - Leia instruções em: res://games/tower_defense/README.md
   - Script: res://games/tower_defense/tower_defense.gd e Cena: res://games/tower_defense/tower_defense.tscn
10. asteroid_shooter (Asteroid Blaster):
    - Leia instruções em: res://games/asteroid_shooter/README.md
    - Script: res://games/asteroid_shooter/asteroid_shooter.gd e Cena: res://games/asteroid_shooter/asteroid_shooter.tscn
11. memory_puzzle (ReAct Memory Grid):
    - Leia instruções em: res://games/memory_puzzle/README.md
    - Script: res://games/memory_puzzle/memory_puzzle.gd e Cena: res://games/memory_puzzle/memory_puzzle.tscn
12. flappy_3d (Flappy Cyber 3D):
    - Leia instruções em: res://games/flappy_3d/README.md
    - Script: res://games/flappy_3d/flappy_3d.gd e Cena: res://games/flappy_3d/flappy_3d.tscn
13. rolling_ball_3d (Rolling Sphere 3D):
    - Leia instruções em: res://games/rolling_ball_3d/README.md
    - Script: res://games/rolling_ball_3d/rolling_ball_3d.gd e Cena: res://games/rolling_ball_3d/rolling_ball_3d.tscn
14. isometric_shooter (Iso Mech Arena):
    - Leia instruções em: res://games/isometric_shooter/README.md
    - Script: res://games/isometric_shooter/isometric_shooter.gd e Cena: res://games/isometric_shooter/isometric_shooter.tscn
15. raycaster_3d (Retro Raycaster 3D):
    - Leia instruções em: res://games/raycaster_3d/README.md
    - Script: res://games/raycaster_3d/raycaster_3d.gd e Cena: res://games/raycaster_3d/raycaster_3d.tscn

REGRAS DE EXECUÇÃO OBRIGATÓRIAS E VERIFICADOR:
- Você deve ler o arquivo README.md de cada jogo ANTES de criá-los para seguir as especificações exatas.
- Você deve gerar arquivos GDScript completos e funcionais.
- Você deve gerar as cenas .tscn correspondentes para que os jogos apareçam no Arcade Hub.
- Você DEVE rodar e testar cada cena usando a ferramenta 'play_scene' para validar o funcionamento correto.
- Você DEVE realizar uma verificação final listando os diretórios para garantir que todos os 15 minijogos foram criados (com script .gd e cena .tscn correspondentes).
- NÃO finaliza a execução ReAct até ter criado, verificado e testado com sucesso TODOS os 15 jogos acima no projeto!
"""
		react_engine.send_user_prompt(benchmark_prompt)
	else:
		_chat_history.append({
			"role": "system",
			"text": "Erro: NativeReActEngine indisponível.",
			"expanded": false
		})
		_render_chat_log()
		_enable_input()

func _enable_input() -> void:
	send_btn.text = "Enviar"
	send_btn.disabled = false
	prompt_input.editable = true
	prompt_input.grab_focus()

func _disable_input() -> void:
	send_btn.text = "Interromper"
	send_btn.disabled = false
	prompt_input.editable = false

func _on_agent_message_added(role: String, text: String) -> void:
	_chat_history.append({
		"role": role,
		"text": text,
		"expanded": true
	})
	_render_chat_log()
	_save_session()

func _on_tool_executing(tool_name: String, _args: Dictionary) -> void:
	pass

func _on_react_finished(_final_answer: String) -> void:
	for entry in _chat_history:
		if entry["role"] in ["tool_call", "tool_res"]:
			entry["expanded"] = false
	_render_chat_log()
	_save_session()
	_enable_input()

func _on_error_occurred(err_msg: String) -> void:
	for entry in _chat_history:
		if entry["role"] in ["tool_call", "tool_res"]:
			entry["expanded"] = false
	_chat_history.append({
		"role": "system",
		"text": "Erro: " + err_msg,
		"expanded": false
	})
	_render_chat_log()
	_save_session()
	_enable_input()

func _append_to_log(bbcode: String) -> void:
	_chat_history.append({
		"role": "system",
		"text": bbcode,
		"expanded": false
	})
	_render_chat_log()

func _render_chat_log() -> void:
	if not chat_log:
		return
	chat_log.clear()
	_error_lut.clear()
	
	for i in range(_chat_history.size()):
		var entry = _chat_history[i]
		var role = entry["role"]
		var text = entry["text"]
		var expanded = entry.get("expanded", false)
		
		var clean_text = _remove_emojis(text)
		if role == "user" or role == "assistant":
			clean_text = _format_badges(clean_text)
			
		var is_error = clean_text.to_lower().contains("erro") or clean_text.to_lower().contains("error") or clean_text.to_lower().contains("failed")
		if is_error and role != "tool_call":
			var err_idx = _error_lut.size()
			_error_lut.append(clean_text)
			clean_text += " [url=copy_to_input_%d][bgcolor=#c0392b][color=#ffffff] 🛠️ Corrigir [/color][/bgcolor][/url]" % err_idx
			
		match role:
			"user":
				chat_log.append_text("\n[color=#56b6c2][b]Você[/b][/color] \n" + clean_text + "\n")
				chat_log.append_text("[color=#3e4452]────────────────────────────────────────────────[/color]\n")
			"assistant":
				chat_log.append_text("\n[color=#c678dd][b]CromAgente[/b][/color] \n" + clean_text + "\n")
				chat_log.append_text("[color=#3e4452]────────────────────────────────────────────────[/color]\n")
			"system":
				chat_log.append_text("[color=#5c6370][i]System: " + clean_text + "[/i][/color]\n")
			"tool_call":
				var tool_name = _extract_tool_name(clean_text)
				if expanded:
					chat_log.append_text("[url=toggle_%d][bgcolor=#282c34]  [color=#e5c07b]▼ %s[/color]  [/bgcolor][/url]\n" % [i, tool_name])
				else:
					chat_log.append_text("[url=toggle_%d][bgcolor=#282c34]  [color=#98c379]▶ %s[/color]  [/bgcolor][/url]\n" % [i, tool_name])
			"tool_res":
				if expanded:
					chat_log.append_text("[bgcolor=#1e1e2e][color=#abb2bf]  " + clean_text + "[/color][/bgcolor]\n")

func _remove_emojis(s: String) -> String:
	var emojis = ["🧑", "🤖", "✅", "❌", "🧹", "💾", "⚡", "👉", "🚀", "🏆", "⚠️", "💡", "🔐", "📡", "🌌", "⭐"]
	var res = s
	for e in emojis:
		res = res.replace(e, "")
	return res

func _format_badges(s: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?<!\\w)res:\\/\\/[a-zA-Z0-9_\\/.-]+")
	
	var result = s
	var matches = regex.search_all(s)
	for j in range(matches.size() - 1, -1, -1):
		var m = matches[j]
		var path = m.get_string()
		var file_name = path.get_file()
		if file_name == "":
			file_name = path.get_base_dir().get_file() + "/"
		var badge = "[bgcolor=#282c34][color=#61afef][url=%s] %s [/url][/color][/bgcolor]" % [path, file_name]
		result = result.substr(0, m.get_start()) + badge + result.substr(m.get_end())
	return result

func _extract_tool_name(s: String) -> String:
	var regex := RegEx.new()
	regex.compile("Ferramenta:\\s*([a-zA-Z0-9_]+)")
	var res = regex.search(s)
	if res:
		var name = res.get_string(1)
		var path_regex := RegEx.new()
		path_regex.compile("res:\\/\\/[a-zA-Z0-9_\\/.-]+")
		var path_res = path_regex.search(s)
		if path_res:
			return "Usou %s (%s)" % [name, path_res.get_string().get_file()]
		return "Usou %s" % name
	return s.strip_edges()

func _on_chat_log_meta_clicked(meta: Variant) -> void:
	var m_str = str(meta)
	if m_str.begins_with("toggle_"):
		var idx = int(m_str.trim_prefix("toggle_"))
		if idx >= 0 and idx < _chat_history.size():
			var is_exp = _chat_history[idx].get("expanded", false)
			_chat_history[idx]["expanded"] = not is_exp
			# Abre/fecha o resultado (tool_res) correspondente se estiver logo em seguida
			if idx + 1 < _chat_history.size() and _chat_history[idx + 1]["role"] == "tool_res":
				_chat_history[idx + 1]["expanded"] = not is_exp
			_render_chat_log()
	elif m_str.begins_with("copy_to_input_"):
		var idx = int(m_str.trim_prefix("copy_to_input_"))
		if idx >= 0 and idx < _error_lut.size():
			var err_txt = _error_lut[idx]
			if prompt_input:
				prompt_input.text = "Ocorreu o seguinte erro ao executar: " + err_txt + ". Por favor, localize e corrija este erro."
				prompt_input.grab_focus()
	elif m_str.begins_with("res://") or m_str.begins_with("/home/"):
		if Engine.is_editor_hint():
			var ei = EditorInterface
			if ei:
				if m_str.ends_with(".gd") or m_str.ends_with(".gdscript"):
					var res = load(m_str)
					if res:
						ei.edit_resource(res)
				elif m_str.ends_with(".tscn"):
					ei.open_scene_from_path(m_str)
				else:
					ei.select_file(m_str)

func _send_direct_tool(tool_name: String, args: Dictionary) -> void:
	_chat_history.append({
		"role": "system",
		"text": "Ação Rápida: %s(%s)" % [tool_name, JSON.stringify(args)],
		"expanded": false
	})
	_render_chat_log()
	var proc = _find_command_processor()
	if proc and proc.has_method("process_command"):
		var res = proc.process_command(JSON.stringify({"action": tool_name, "params": args}))
		_chat_history.append({
			"role": "system",
			"text": "Resultado: %s" % JSON.stringify(res),
			"expanded": false
		})
		_render_chat_log()
	else:
		_chat_history.append({
			"role": "system",
			"text": "Erro: CommandProcessor não encontrado para ação direta.",
			"expanded": false
		})
		_render_chat_log()

func _on_history_btn_pressed() -> void:
	var is_history_visible = history_panel.visible
	if not is_history_visible:
		config_panel.visible = false
		chat_log.visible = false
		quick_actions_hbox.visible = false
		input_hbox.visible = false
		history_panel.visible = true
		_load_sessions_list()
	else:
		_on_back_to_chat_btn_pressed()

func _on_back_to_chat_btn_pressed() -> void:
	history_panel.visible = false
	chat_log.visible = true
	quick_actions_hbox.visible = true
	input_hbox.visible = true

func _load_sessions_list() -> void:
	for child in history_list.get_children():
		child.queue_free()
		
	var dir_path = "res://addons/crom_ai/chat_history"
	if not DirAccess.dir_exists_absolute(dir_path):
		var label = Label.new()
		label.text = "Nenhum histórico encontrado."
		history_list.add_child(label)
		return
		
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var sessions: Array[String] = []
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				sessions.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		
		sessions.sort()
		sessions.reverse()
		
		if sessions.is_empty():
			var label = Label.new()
			label.text = "Nenhum histórico encontrado."
			history_list.add_child(label)
			return
			
		for s_file in sessions:
			var full_path = dir_path + "/" + s_file
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				var json_str = file.get_as_text()
				file.close()
				var data = JSON.parse_string(json_str)
				if data is Dictionary and data.has("history"):
					var history_arr = data["history"]
					var first_prompt = "Conversa sem mensagens"
					for entry in history_arr:
						if entry["role"] == "user":
							first_prompt = entry["text"]
							break
					
					var btn = Button.new()
					if first_prompt.length() > 30:
						first_prompt = first_prompt.left(27) + "..."
					btn.text = "%s - %s" % [s_file.trim_prefix("session_").trim_suffix(".json"), first_prompt]
					btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
					btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					btn.pressed.connect(func(): _load_session_by_file(s_file))
					history_list.add_child(btn)

func _load_session_by_file(file_name: String) -> void:
	var file_path = "res://addons/crom_ai/chat_history/" + file_name
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		file.close()
		var data = JSON.parse_string(json_str)
		if data is Dictionary:
			_session_id = data.get("session_id", "")
			_chat_history = data.get("history", [])
			if react_engine and react_engine.get("messages") is Array:
				react_engine.messages.clear()
				react_engine.messages.append({
					"role": "system",
					"content": "Você é o CromAgente..."
				})
				for entry in _chat_history:
					if entry["role"] in ["user", "assistant"]:
						react_engine.messages.append({
							"role": entry["role"],
							"content": entry["text"]
						})
			_render_chat_log()
			_on_back_to_chat_btn_pressed()

func _save_session() -> void:
	if _chat_history.is_empty():
		return
	if _session_id.is_empty():
		var dt = Time.get_datetime_dict_from_system()
		_session_id = "%04d-%02d-%02d_%02d-%02d-%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
		
	var dir_path = "res://addons/crom_ai/chat_history"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var file_path = dir_path + "/session_" + _session_id + ".json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var data = {
			"session_id": _session_id,
			"history": _chat_history
		}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

var _cached_proc: Node = null

func _find_command_processor() -> Node:
	if _cached_proc:
		return _cached_proc
	var tree = get_tree()
	if tree and tree.root and tree.root.has_node("CommandProcessor"):
		return tree.root.get_node("CommandProcessor")
	var proc_class = load("res://addons/crom_ai/command_processor.gd")
	if proc_class:
		_cached_proc = proc_class.new(null)
		_cached_proc.name = "CommandProcessor"
		add_child(_cached_proc)
		return _cached_proc
	return null

func _start_log_monitoring() -> void:
	_log_timer = Timer.new()
	_log_timer.wait_time = 1.0
	_log_timer.autostart = true
	_log_timer.timeout.connect(_check_godot_log)
	add_child(_log_timer)
	
	var log_path = "user://logs/godot.log"
	if FileAccess.file_exists(log_path):
		var f = FileAccess.open(log_path, FileAccess.READ)
		if f:
			_last_log_size = f.get_length()
			f.close()

func _check_godot_log() -> void:
	var log_path = "user://logs/godot.log"
	if not FileAccess.file_exists(log_path):
		return
		
	var f = FileAccess.open(log_path, FileAccess.READ)
	if not f:
		return
		
	var current_size = f.get_length()
	if current_size > _last_log_size:
		f.seek(_last_log_size)
		var new_bytes = f.get_buffer(current_size - _last_log_size)
		_last_log_size = current_size
		f.close()
		var new_content = new_bytes.get_string_from_utf8()
		
		if new_content.contains("SCRIPT ERROR:") or new_content.contains("GDScript backtrace") or new_content.contains("Parse Error:"):
			var lines = new_content.split("\n")
			var err_lines: Array[String] = []
			var capturing = false
			for line in lines:
				var l_strip = line.strip_edges()
				if l_strip.contains("SCRIPT ERROR:") or l_strip.contains("Parse Error:") or l_strip.contains("GDScript backtrace") or l_strip.contains("Redefined"):
					capturing = true
				if capturing:
					err_lines.append(l_strip)
					if err_lines.size() >= 5:
						break
			if not err_lines.is_empty():
				var full_err = "\n".join(err_lines)
				_show_error_popup(full_err)
	else:
		_last_log_size = current_size
		f.close()

func _show_error_popup(err_msg: String) -> void:
	if not _error_popup:
		_error_popup = ConfirmationDialog.new()
		_error_popup.title = "CromAI - Erro Detectado"
		_error_popup.get_ok_button().text = "Corrigir com CromAgente"
		_error_popup.get_cancel_button().text = "Ignorar"
		add_child(_error_popup)
		_error_popup.confirmed.connect(func():
			if prompt_input:
				prompt_input.text = "Ocorreu o seguinte erro de script no projeto: " + _last_error_context + ". Por favor, analise a cena e corrija o script."
				_on_send_pressed()
		)
	_last_error_context = err_msg
	_error_popup.dialog_text = "Ocorreu o seguinte erro de execução no Godot:\n\n%s\n\nDeseja enviar esta pilha de erro para o CromAgente corrigir?" % err_msg
	_error_popup.popup_centered()

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		var type = data.get("type", "")
		if type == "files" or type == "nodes" or type == "node_paths":
			return true
	return false

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if data is Dictionary:
		if data.has("files"):
			var files = data["files"]
			for f in files:
				if prompt_input:
					if prompt_input.text != "":
						prompt_input.text += " "
					prompt_input.text += str(f)
			_append_to_log("[color=#61afef]✓ Contexto adicionado (Arquivo): %s[/color]" % str(files))
		elif data.has("nodes"):
			var nodes = data["nodes"]
			for n in nodes:
				if n is Node and prompt_input:
					if prompt_input.text != "":
						prompt_input.text += " "
					prompt_input.text += n.name + " (" + n.get_class() + ")"
			_append_to_log("[color=#61afef]✓ Contexto adicionado (Nó): %s[/color]" % str(nodes))
		elif data.has("paths"):
			var paths = data["paths"]
			for p in paths:
				if prompt_input:
					if prompt_input.text != "":
						prompt_input.text += " "
					prompt_input.text += str(p)
			_append_to_log("[color=#61afef]✓ Contexto adicionado (Caminho do Nó): %s[/color]" % str(paths))
