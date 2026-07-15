@tool
extends Control

# ==============================================================================
# CromAIChatDock (@tool): Painel Lateral Integrado à IDE Godot e ao App
# Permite ao desenvolvedor/jogador conversar com o Agente, configurar Ollama/OpenRouter/API Key,
# e monitorar o Loop ReAct visualmente direto na barra lateral.
# ==============================================================================

var react_engine: Node = null

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
	
	build_mode_btn.pressed.connect(func(): _send_direct_tool("switch_mode", {"mode": "build"}))
	play_mode_btn.pressed.connect(func(): _send_direct_tool("switch_mode", {"mode": "play"}))
	clear_btn.pressed.connect(func():
		chat_log.clear()
		if react_engine and react_engine.has_method("_reset_messages"):
			react_engine._reset_messages()
		_append_to_log("[color=#89b4fa]🧹 Histórico do chat limpo.[/color]")
	)
	
	_append_to_log("[color=#a6e3a1][b]🌌 CromAI Godot Agent — Chat Lateral Inicializado![/b][/color]")
	_append_to_log("[color=#cdd6f4]Pronto para receber instruções de criação (Build) e exploração (Play).[/color]")

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
			api_key_input.text = str(cfg.get_value("ai", "api_key", ""))
			return
			
	# Padrão inicial conforme solicitado: google/gemini-2.5-flash ou ollama
	provider_option.select(0)
	model_input.text = "google/gemini-2.5-flash"

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
	var prompt = prompt_input.text.strip_edges()
	if prompt == "":
		return
		
	prompt_input.text = ""
	send_btn.disabled = true
	prompt_input.editable = false
	
	if react_engine and react_engine.has_method("send_user_prompt"):
		react_engine.send_user_prompt(prompt)
	else:
		_append_to_log("[color=#f38ba8][Erro] Motor ReAct nativo não inicializado.[/color]")
		_enable_input()

func _enable_input() -> void:
	send_btn.disabled = false
	prompt_input.editable = true
	prompt_input.grab_focus()

func _on_agent_message_added(role: String, text: String) -> void:
	match role:
		"user":
			_append_to_log("\n[color=#89dceb][b]🧑 Você:[/b][/color] " + text)
		"assistant":
			_append_to_log("\n[color=#cba6f7][b]🤖 CromAgente:[/b][/color] " + text)
		"system":
			_append_to_log("[color=#7f849c][i]" + text + "[/i][/color]")
		"tool_call":
			_append_to_log("[color=#f9e2af]" + text + "[/color]")
		"tool_res":
			_append_to_log("[color=#a6e3a1]" + text + "[/color]")

func _on_tool_executing(tool_name: String, _args: Dictionary) -> void:
	pass # O log detalhado já é disparado como tool_call e tool_res

func _on_react_finished(_final_answer: String) -> void:
	_enable_input()

func _on_error_occurred(err_msg: String) -> void:
	_append_to_log("\n[color=#f38ba8][b]❌ Erro:[/b] " + err_msg + "[/color]")
	_enable_input()

func _append_to_log(bbcode: String) -> void:
	if chat_log:
		chat_log.append_text(bbcode + "\n")

func _send_direct_tool(tool_name: String, args: Dictionary) -> void:
	_append_to_log("\n[color=#f9e2af]⚙️ Ação Rápida: %s(%s)[/color]" % [tool_name, JSON.stringify(args)])
	var proc = _find_command_processor()
	if proc and proc.has_method("process_command"):
		var res = proc.process_command(JSON.stringify({"action": tool_name, "params": args}))
		_append_to_log("[color=#a6e3a1]✅ Resultado: %s[/color]" % JSON.stringify(res))
	else:
		_append_to_log("[color=#f38ba8][Erro] CommandProcessor não encontrado para ação direta.[/color]")

func _find_command_processor() -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var root = tree.root
	if root and root.has_node("CommandProcessor"):
		return root.get_node("CommandProcessor")
	# Ou busca pelo plugin de editor
	var proc_class = load("res://addons/crom_ai/command_processor.gd")
	if proc_class:
		return proc_class.new(null)
	return null
