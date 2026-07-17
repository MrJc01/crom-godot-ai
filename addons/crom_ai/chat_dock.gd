@tool
extends Control

# ==============================================================================
# Crom Agente — Painel lateral nativo da IDE Godot (estilo Antigravity/VS Code).
#
# O chat É o crom-agente acoplado ao projeto aberto: conversa via daemon
# (CromAgentClient), com streaming em tempo real, aprovação de ferramentas
# (HITL), histórico de sessões e detecção de erros de script do Godot.
# Toda a UI é construída em código usando ThemeConstants/StyleFactory.
# ==============================================================================

const ThemeC = preload("res://addons/crom_ai/core/theme_constants.gd")
const Styles = preload("res://addons/crom_ai/core/style_factory.gd")
const AgentClient = preload("res://addons/crom_ai/crom_agent_client.gd")

const HISTORY_DIR := "user://crom_chat_history"

const PROVIDERS := [
	{ "id": "openrouter", "label": "OpenRouter", "model": "google/gemini-2.5-flash", "key_hint": "sk-or-v1-..." },
	{ "id": "ollama", "label": "Ollama (local)", "model": "llama3", "key_hint": "Não necessário" },
	{ "id": "openai", "label": "OpenAI", "model": "gpt-4o", "key_hint": "sk-..." },
	{ "id": "anthropic", "label": "Anthropic", "model": "claude-sonnet-4-5", "key_hint": "sk-ant-..." },
	{ "id": "gemini", "label": "Google Gemini", "model": "gemini-2.5-flash", "key_hint": "AIza..." },
	{ "id": "cromia", "label": "CromIA Cloud", "model": "google/gemini-2.5-flash", "key_hint": "Chave CromIA" },
]

# Slash commands. kind: "agent" (vira task), "scene" (pede uma cena), "local" (ação da UI).
const SLASH_COMMANDS := [
	{ "cmd": "/jogar", "desc": "Executar a cena atual", "kind": "agent",
	  "task": "Rode a cena atualmente aberta no editor usando play_scene e confirme se abriu corretamente." },
	{ "cmd": "/jogar-cena", "desc": "Executar uma cena específica…", "kind": "scene" },
	{ "cmd": "/parar", "desc": "Parar a execução em teste", "kind": "agent",
	  "task": "Pare a execução da cena em teste usando stop_scene." },
	{ "cmd": "/inspecionar", "desc": "Screenshot + análise visual", "kind": "agent",
	  "task": "Capture um screenshot do jogo/editor com capture_screenshot e analise o layout, o enquadramento e a responsividade." },
	{ "cmd": "/arvore", "desc": "Ler a árvore de nós da cena", "kind": "agent",
	  "task": "Leia a árvore de nós da cena aberta com get_scene_tree e resuma a estrutura para mim." },
	{ "cmd": "/corrigir", "desc": "Corrigir o último erro detectado", "kind": "agent",
	  "task": "Analise o último erro de script reportado no projeto, encontre a causa e corrija-o." },
	{ "cmd": "/nova", "desc": "Iniciar uma nova conversa", "kind": "local", "action": "new" },
	{ "cmd": "/limpar", "desc": "Limpar o chat atual", "kind": "local", "action": "clear" },
]

# var (não const): valores referenciam constantes de outro script, resolvidas em runtime.
var CHIP_META := {
	"file":      { "icon": "code",         "color": ThemeC.ACCENT_BLUE },
	"scene":     { "icon": "layout",       "color": ThemeC.ACCENT_PURPLE },
	"node":      { "icon": "gamepad",      "color": ThemeC.ACCENT_TEAL },
	"error":     { "icon": "alert_circle", "color": ThemeC.ACCENT_RED },
	"selection": { "icon": "terminal",     "color": ThemeC.ACCENT_YELLOW },
}

var agent: Node = null

var _chat_history: Array[Dictionary] = []
var _session_id: String = ""
var _streaming_buffer: String = ""
var _error_lut: Array[String] = []
var _last_log_size: int = 0
var _log_timer: Timer = null
var _error_popup: ConfirmationDialog = null
var _last_error_context: String = ""

# UI refs
var _status_dot: ColorRect
var _status_label: Label
var _chat_log: RichTextLabel
var _prompt_input: LineEdit
var _send_btn: Button
var _config_panel: PanelContainer
var _provider_option: OptionButton
var _model_input: LineEdit
var _api_key_input: LineEdit
var _perm_option: OptionButton
var _auto_approve_check: CheckBox
var _permission_bar: PanelContainer
var _permission_label: Label
var _history_panel: VBoxContainer
var _history_list: VBoxContainer
var _chat_area: VBoxContainer
var _context_bar: HFlowContainer
var _slash_menu: PanelContainer
var _slash_list: VBoxContainer

const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")
var _context_chips: Array[Dictionary] = []
var _slash_items: Array[Dictionary] = []

func _ready() -> void:
	_build_ui()
	_load_saved_config()

	agent = AgentClient.new()
	agent.name = "CromAgentClient"
	add_child(agent)
	agent.connection_changed.connect(_on_connection_changed)
	agent.agent_status_changed.connect(_on_agent_status)
	agent.stream_chunk.connect(_on_stream_chunk)
	agent.agent_message.connect(_on_agent_message)
	agent.agent_event.connect(_on_agent_event)
	agent.permission_requested.connect(_on_permission_requested)
	agent.error_occurred.connect(_on_error_occurred)
	_apply_config_to_agent()

	_append_entry("system", "Crom Agente pronto. Conectando ao daemon...")
	_start_log_monitoring()

# ==============================================================================
# Construção da UI
# ==============================================================================

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	add_child(root)

	# --- Header: status + ações ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	root.add_child(header)

	_status_dot = ColorRect.new()
	_status_dot.custom_minimum_size = Vector2(8, 8)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_dot.color = ThemeC.TEXT_MUTED
	header.add_child(_status_dot)

	var title := Label.new()
	title.text = "CROM AGENTE"
	title.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_SMALL)
	title.add_theme_color_override("font_color", ThemeC.TEXT_PRIMARY)
	header.add_child(title)

	_status_label = Label.new()
	_status_label.text = "desconectado"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_TINY)
	_status_label.add_theme_color_override("font_color", ThemeC.TEXT_MUTED)
	header.add_child(_status_label)

	var new_btn := Button.new()
	new_btn.text = "+"
	new_btn.tooltip_text = "Nova conversa"
	new_btn.flat = true
	new_btn.pressed.connect(_on_new_session)
	header.add_child(new_btn)

	var hist_btn := Button.new()
	hist_btn.text = "⋯"
	hist_btn.tooltip_text = "Histórico de conversas"
	hist_btn.flat = true
	hist_btn.pressed.connect(_toggle_history)
	header.add_child(hist_btn)

	var cfg_btn := Button.new()
	cfg_btn.text = "⚙"
	cfg_btn.tooltip_text = "Configurações do agente"
	cfg_btn.flat = true
	cfg_btn.pressed.connect(func(): _config_panel.visible = not _config_panel.visible)
	header.add_child(cfg_btn)

	# --- Painel de configuração (recolhível) ---
	_config_panel = PanelContainer.new()
	_config_panel.visible = false
	Styles.apply_to(_config_panel, Styles.card())
	root.add_child(_config_panel)
	_build_config_panel()

	# --- Área do chat ---
	_chat_area = VBoxContainer.new()
	_chat_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_area.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	root.add_child(_chat_area)

	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.selection_enabled = true
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.meta_clicked.connect(_on_chat_log_meta_clicked)
	_chat_area.add_child(_chat_log)

	# --- Barra de permissão (HITL) ---
	_permission_bar = PanelContainer.new()
	_permission_bar.visible = false
	Styles.apply_to(_permission_bar, Styles.card_with_accent(ThemeC.ACCENT_ORANGE))
	_chat_area.add_child(_permission_bar)

	var perm_box := VBoxContainer.new()
	perm_box.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	_permission_bar.add_child(perm_box)

	_permission_label = Label.new()
	_permission_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_permission_label.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_SMALL)
	_permission_label.add_theme_color_override("font_color", ThemeC.TEXT_PRIMARY)
	perm_box.add_child(_permission_label)

	var perm_btns := HBoxContainer.new()
	perm_btns.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	perm_box.add_child(perm_btns)

	var allow_btn := Button.new()
	allow_btn.text = "Permitir"
	allow_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	allow_btn.pressed.connect(func(): _resolve_permission(true, false))
	perm_btns.add_child(allow_btn)

	var always_btn := Button.new()
	always_btn.text = "Sempre permitir"
	always_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	always_btn.pressed.connect(func(): _resolve_permission(true, true))
	perm_btns.add_child(always_btn)

	var deny_btn := Button.new()
	deny_btn.text = "Negar"
	deny_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deny_btn.pressed.connect(func(): _resolve_permission(false, false))
	perm_btns.add_child(deny_btn)

	# --- Barra de context chips (badges de contexto) ---
	_context_bar = HFlowContainer.new()
	_context_bar.visible = false
	_context_bar.add_theme_constant_override("h_separation", ThemeC.SPACING_XS)
	_context_bar.add_theme_constant_override("v_separation", ThemeC.SPACING_XS)
	_chat_area.add_child(_context_bar)

	# --- Menu de slash commands (autocomplete in-flow, não rouba foco) ---
	_slash_menu = PanelContainer.new()
	_slash_menu.visible = false
	Styles.apply_to(_slash_menu, Styles.card())
	_chat_area.add_child(_slash_menu)
	_slash_list = VBoxContainer.new()
	_slash_list.add_theme_constant_override("separation", 2)
	_slash_menu.add_child(_slash_list)

	# --- Input ---
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	_chat_area.add_child(input_row)

	var attach_btn := Button.new()
	attach_btn.text = "+"
	attach_btn.tooltip_text = "Anexar contexto (arquivo, cena, seleção)"
	attach_btn.flat = true
	attach_btn.pressed.connect(_on_attach_pressed)
	input_row.add_child(attach_btn)

	_prompt_input = LineEdit.new()
	_prompt_input.placeholder_text = "Peça ao agente para criar, mover, corrigir...  (digite / para comandos)"
	_prompt_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_input.text_submitted.connect(func(_t): _on_send_pressed())
	_prompt_input.text_changed.connect(_on_prompt_text_changed)
	_prompt_input.gui_input.connect(_on_prompt_gui_input)
	input_row.add_child(_prompt_input)

	_send_btn = Button.new()
	_send_btn.text = "Enviar"
	_send_btn.pressed.connect(_on_send_pressed)
	input_row.add_child(_send_btn)

	# --- Painel de histórico (sobreposto ao chat) ---
	_history_panel = VBoxContainer.new()
	_history_panel.visible = false
	_history_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_panel.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	root.add_child(_history_panel)

	var hist_title := Label.new()
	hist_title.text = "CONVERSAS ANTERIORES"
	hist_title.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_TINY)
	hist_title.add_theme_color_override("font_color", ThemeC.TEXT_MUTED)
	_history_panel.add_child(hist_title)

	var hist_scroll := ScrollContainer.new()
	hist_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hist_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_history_panel.add_child(hist_scroll)

	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", ThemeC.SPACING_XS)
	hist_scroll.add_child(_history_list)

	var back_btn := Button.new()
	back_btn.text = "Voltar ao chat"
	back_btn.pressed.connect(_toggle_history)
	_history_panel.add_child(back_btn)

func _build_config_panel() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	_config_panel.add_child(box)

	box.add_child(_config_row_label("Provedor"))
	_provider_option = OptionButton.new()
	for p in PROVIDERS:
		_provider_option.add_item(p["label"])
	_provider_option.item_selected.connect(_on_provider_selected)
	box.add_child(_provider_option)

	box.add_child(_config_row_label("Modelo"))
	_model_input = LineEdit.new()
	_model_input.placeholder_text = "ex: google/gemini-2.5-flash"
	box.add_child(_model_input)

	box.add_child(_config_row_label("API Key"))
	_api_key_input = LineEdit.new()
	_api_key_input.secret = true
	_api_key_input.placeholder_text = "Armazenada localmente (user://)"
	box.add_child(_api_key_input)

	box.add_child(_config_row_label("Permissões"))
	_perm_option = OptionButton.new()
	_perm_option.add_item("Perguntar antes de agir (recomendado)")
	_perm_option.add_item("Acesso total ao projeto")
	box.add_child(_perm_option)

	_auto_approve_check = CheckBox.new()
	_auto_approve_check.text = "Aprovar ferramentas automaticamente"
	_auto_approve_check.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_SMALL)
	box.add_child(_auto_approve_check)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", ThemeC.SPACING_SM)
	box.add_child(actions)

	var save_btn := Button.new()
	save_btn.text = "Salvar"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_and_apply_config)
	actions.add_child(save_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Reiniciar daemon"
	restart_btn.pressed.connect(func():
		if agent:
			agent.restart_daemon()
			_append_entry("system", "Daemon do crom-agente reiniciando...")
	)
	actions.add_child(restart_btn)

func _config_row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_TINY)
	lbl.add_theme_color_override("font_color", ThemeC.TEXT_MUTED)
	return lbl

# ==============================================================================
# Configuração
# ==============================================================================

func _get_config_path() -> String:
	var home := OS.get_environment("USERPROFILE") if OS.get_name() == "Windows" else OS.get_environment("HOME")
	if home == "":
		return "user://crom_ai_config.cfg"
	var global_dir := home.path_join(".crom")
	if not DirAccess.dir_exists_absolute(global_dir):
		DirAccess.make_dir_recursive_absolute(global_dir)
	var global_path := global_dir.path_join("crom_ai_config.cfg")
	# Migrate from project-specific user:// config if it exists and global doesn't
	if not FileAccess.file_exists(global_path) and FileAccess.file_exists("user://crom_ai_config.cfg"):
		var dir := DirAccess.open("user://")
		if dir:
			dir.copy("user://crom_ai_config.cfg", global_path)
	return global_path

func _on_provider_selected(index: int) -> void:
	var p: Dictionary = PROVIDERS[index]
	_model_input.text = p["model"]
	_api_key_input.placeholder_text = p["key_hint"]

func _load_saved_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_get_config_path()) == OK:
		var prov_id := str(cfg.get_value("ai", "provider", "openrouter"))
		for i in range(PROVIDERS.size()):
			if PROVIDERS[i]["id"] == prov_id:
				_provider_option.select(i)
				break
		_model_input.text = str(cfg.get_value("ai", "model", PROVIDERS[_provider_option.selected]["model"]))
		_api_key_input.text = str(cfg.get_value("ai", "api_key", ""))
		_perm_option.select(int(cfg.get_value("ai", "permission_index", 0)))
		_auto_approve_check.button_pressed = bool(cfg.get_value("ai", "auto_approve", false))
	else:
		_provider_option.select(0)
		_model_input.text = PROVIDERS[0]["model"]
		_config_panel.visible = true
		_append_entry_deferred("system", "Configure o provedor e a API key para começar (botão ⚙).")

func _save_and_apply_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ai", "provider", PROVIDERS[_provider_option.selected]["id"])
	cfg.set_value("ai", "model", _model_input.text.strip_edges())
	cfg.set_value("ai", "api_key", _api_key_input.text.strip_edges())
	cfg.set_value("ai", "permission_index", _perm_option.selected)
	cfg.set_value("ai", "auto_approve", _auto_approve_check.button_pressed)
	cfg.save(_get_config_path())
	_apply_config_to_agent()
	_config_panel.visible = false
	_append_entry("system", "Configuração salva: %s · %s" % [PROVIDERS[_provider_option.selected]["label"], _model_input.text])

func _apply_config_to_agent() -> void:
	if not agent:
		return
	var perm_mode := "ask_every_time" if _perm_option.selected == 0 else "total_access"
	agent.set_config(
		PROVIDERS[_provider_option.selected]["id"],
		_model_input.text.strip_edges(),
		_api_key_input.text.strip_edges(),
		perm_mode
	)
	agent.set_auto_approve(_auto_approve_check.button_pressed)

# ==============================================================================
# Envio e fluxo do agente
# ==============================================================================

func _on_send_pressed() -> void:
	# Enter com o menu de slash aberto seleciona a primeira sugestão
	if _slash_menu.visible and not _slash_items.is_empty():
		_execute_slash(_slash_items[0])
		return

	if agent and agent.is_busy:
		agent.interrupt()
		_append_entry("system", "Interrompendo o agente...")
		return

	var prompt := _prompt_input.text.strip_edges()
	if prompt == "" and _context_chips.is_empty():
		return

	# Comando de slash local digitado por extenso
	if prompt.begins_with("/"):
		for cmd in SLASH_COMMANDS:
			if prompt == cmd["cmd"] and cmd["kind"] == "local":
				_prompt_input.text = ""
				_hide_slash_menu()
				_run_local_command(cmd["action"])
				return

	_prompt_input.text = ""
	_hide_slash_menu()
	_dispatch_user_task(prompt)

# Envia uma tarefa ao agente, anexando os chips de contexto como preâmbulo.
func _dispatch_user_task(prompt: String) -> void:
	var preamble := _build_context_preamble()
	var display := prompt
	if not _context_chips.is_empty():
		var tags: Array[String] = []
		for chip in _context_chips:
			tags.append(chip["label"])
		display = ("[Contexto: %s]\n" % ", ".join(tags)) + prompt
	_append_entry("user", display)
	_save_session()

	if agent:
		agent.send_user_prompt(preamble + prompt)
		_set_busy_ui(true)
	else:
		_append_entry("system", "Erro: cliente do agente não inicializado.")

	_context_chips.clear()
	_rebuild_context_bar()

func _run_local_command(action: String) -> void:
	match action:
		"clear":
			_chat_history.clear()
			_streaming_buffer = ""
			_render_chat_log()
			_append_entry("system", "Chat limpo.")
		"new":
			_on_new_session()

# ==============================================================================
# Context chips (badges de contexto acima do input)
# ==============================================================================

# API pública — usada por drag&drop, menu de contexto do editor e detecção de erro.
func add_context_chip(type: String, label: String, payload: String) -> void:
	for chip in _context_chips:
		if chip["type"] == type and chip["payload"] == payload:
			return # evita duplicatas
	_context_chips.append({ "type": type, "label": label, "payload": payload })
	_rebuild_context_bar()

func add_paths_as_context(paths) -> void:
	for p in paths:
		var s := str(p)
		add_context_chip("scene" if s.ends_with(".tscn") else "file", s.get_file(), s)
	_append_entry("system", "Contexto anexado. Escreva sua instrução e envie.")

func add_nodes_as_context(nodes) -> void:
	for n in nodes:
		if n is Node:
			add_context_chip("node", str(n.name), "%s (%s) em %s" % [n.name, n.get_class(), n.get_path()])
	_append_entry("system", "Nó(s) anexado(s) ao contexto.")

func _rebuild_context_bar() -> void:
	for c in _context_bar.get_children():
		c.queue_free()
	_context_bar.visible = not _context_chips.is_empty()
	for i in range(_context_chips.size()):
		_context_bar.add_child(_make_chip(i, _context_chips[i]))

func _make_chip(index: int, chip: Dictionary) -> Control:
	var meta: Dictionary = CHIP_META.get(chip["type"], { "icon": "code", "color": ThemeC.TEXT_SECONDARY })
	var panel := PanelContainer.new()
	Styles.apply_to(panel, Styles.badge(ThemeC.BG_INPUT, meta["color"]))
	panel.tooltip_text = str(chip["payload"])

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", ThemeC.SPACING_XS)
	panel.add_child(box)

	box.add_child(IconProvider.icon_rect(meta["icon"], 12, meta["color"]))
	var lbl := Label.new()
	lbl.text = str(chip["label"]).left(28)
	lbl.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_TINY)
	lbl.add_theme_color_override("font_color", ThemeC.TEXT_PRIMARY)
	box.add_child(lbl)

	var x_btn := Button.new()
	x_btn.text = "×"
	x_btn.flat = true
	x_btn.tooltip_text = "Remover do contexto"
	x_btn.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_SMALL)
	x_btn.pressed.connect(func(): _remove_chip(index))
	box.add_child(x_btn)
	return panel

func _remove_chip(index: int) -> void:
	if index >= 0 and index < _context_chips.size():
		_context_chips.remove_at(index)
		_rebuild_context_bar()

func _build_context_preamble() -> String:
	if _context_chips.is_empty():
		return ""
	var lines: Array[String] = ["--- Contexto anexado pelo usuário ---"]
	for chip in _context_chips:
		match chip["type"]:
			"file": lines.append("Arquivo do projeto: " + str(chip["payload"]))
			"scene": lines.append("Cena do projeto: " + str(chip["payload"]))
			"node": lines.append("Nó da cena aberta: " + str(chip["payload"]))
			"error": lines.append("Erro do console do Godot:\n" + str(chip["payload"]))
			"selection": lines.append("Trecho de código selecionado:\n" + str(chip["payload"]))
			_: lines.append(str(chip["payload"]))
	lines.append("--- Fim do contexto ---\n")
	return "\n".join(lines) + "\n"

# Botão "+" ao lado do input: anexa contexto do estado atual do editor
func _on_attach_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var popup := PopupMenu.new()
	var opts: Array[Dictionary] = []

	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root and scene_root.scene_file_path != "":
		opts.append({ "label": "Cena aberta: " + scene_root.scene_file_path.get_file(),
			"cb": func(): add_context_chip("scene", scene_root.scene_file_path.get_file(), scene_root.scene_file_path) })

	var se := EditorInterface.get_script_editor()
	if se and se.get_current_script():
		var sp: String = se.get_current_script().resource_path
		opts.append({ "label": "Script aberto: " + sp.get_file(),
			"cb": func(): add_context_chip("file", sp.get_file(), sp) })
		var code_edit = se.get_current_editor()
		if code_edit and code_edit.get_base_editor() and code_edit.get_base_editor().has_method("get_selected_text"):
			var sel: String = code_edit.get_base_editor().get_selected_text()
			if sel.strip_edges() != "":
				opts.append({ "label": "Seleção de código (%d chars)" % sel.length(),
					"cb": func(): add_context_chip("selection", "Trecho de %s" % sp.get_file(), sel) })

	var selected_nodes := EditorInterface.get_selection().get_selected_nodes() if EditorInterface.get_selection() else []
	if not selected_nodes.is_empty():
		opts.append({ "label": "Nós selecionados (%d)" % selected_nodes.size(),
			"cb": func(): add_nodes_as_context(selected_nodes) })

	if opts.is_empty():
		_append_entry("system", "Nada para anexar: abra uma cena/script ou selecione um nó no editor.")
		return

	for i in range(opts.size()):
		popup.add_item(opts[i]["label"], i)
	popup.id_pressed.connect(func(id): opts[id]["cb"].call())
	add_child(popup)
	popup.popup_hide.connect(func(): popup.queue_free())
	popup.position = Vector2i(get_screen_position()) + Vector2i(0, 40)
	popup.popup()

# ==============================================================================
# Slash commands (autocomplete)
# ==============================================================================

func _on_prompt_text_changed(text: String) -> void:
	if not text.begins_with("/"):
		_hide_slash_menu()
		return
	_rebuild_slash_menu(text)

func _on_prompt_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _slash_menu.visible:
		_hide_slash_menu()

func _rebuild_slash_menu(text: String) -> void:
	_slash_items.clear()
	for c in _slash_list.get_children():
		c.queue_free()

	if text.begins_with("/jogar-cena"):
		var remainder := text.substr("/jogar-cena".length()).strip_edges().to_lower()
		for scene in _list_scenes():
			if remainder == "" or scene.to_lower().contains(remainder):
				_slash_items.append({ "kind": "scene_pick", "label": scene.get_file(), "desc": scene, "scene": scene })
	else:
		var needle := text.substr(1).to_lower()
		for cmd in SLASH_COMMANDS:
			if needle == "" or str(cmd["cmd"]).substr(1).to_lower().begins_with(needle):
				_slash_items.append({ "kind": cmd["kind"], "label": cmd["cmd"], "desc": cmd["desc"], "cmd": cmd })

	if _slash_items.is_empty():
		_hide_slash_menu()
		return

	var shown := 0
	for item in _slash_items:
		if shown >= 8:
			break
		var btn := Button.new()
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", ThemeC.FONT_SIZE_SMALL)
		btn.text = "%s   —   %s" % [item["label"], item["desc"]]
		var captured := item
		btn.pressed.connect(func(): _execute_slash(captured))
		_slash_list.add_child(btn)
		shown += 1
	_slash_menu.visible = true

func _hide_slash_menu() -> void:
	_slash_menu.visible = false
	_slash_items.clear()

func _execute_slash(item: Dictionary) -> void:
	match item["kind"]:
		"scene":
			# Entra no modo de escolha de cena
			_prompt_input.text = "/jogar-cena "
			_prompt_input.caret_column = _prompt_input.text.length()
			_prompt_input.grab_focus()
			_rebuild_slash_menu(_prompt_input.text)
		"scene_pick":
			_prompt_input.text = ""
			_hide_slash_menu()
			_dispatch_user_task("Rode a cena %s usando play_scene com esse caminho e confirme se executou corretamente." % item["scene"])
		"agent":
			_prompt_input.text = ""
			_hide_slash_menu()
			_dispatch_user_task(item["cmd"]["task"])
		"local":
			_prompt_input.text = ""
			_hide_slash_menu()
			_run_local_command(item["cmd"]["action"])

func _list_scenes() -> Array[String]:
	var scenes: Array[String] = []
	_scan_scenes("res://", scenes)
	return scenes

func _scan_scenes(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and entry != "addons":
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_scan_scenes(full, out)
			elif entry.ends_with(".tscn"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _on_new_session() -> void:
	_chat_history.clear()
	_streaming_buffer = ""
	_session_id = ""
	if agent:
		agent.new_session()
	_append_entry("system", "Nova conversa iniciada.")

func _set_busy_ui(busy: bool) -> void:
	_send_btn.text = "Parar" if busy else "Enviar"
	_prompt_input.editable = not busy
	if not busy:
		_prompt_input.grab_focus()

func _on_connection_changed(connected: bool) -> void:
	_status_dot.color = ThemeC.ACCENT_GREEN if connected else ThemeC.ACCENT_RED
	_status_label.text = "daemon conectado" if connected else "daemon offline"
	if connected:
		_append_entry("system", "Conectado ao daemon do crom-agente. O agente enxerga e edita este projeto.")

func _on_agent_status(status: String) -> void:
	match status:
		"finished", "idle":
			_status_label.text = "pronto"
			_finalize_stream()
			_collapse_tools()
			_set_busy_ui(false)
			_permission_bar.visible = false
		"waiting_user_input":
			_status_label.text = "aguardando você"
			_finalize_stream()
			_set_busy_ui(false)
		_:
			if status.begins_with("error:"):
				_status_label.text = "erro"
				_set_busy_ui(false)
			else:
				_status_label.text = status
				_set_busy_ui(true)

func _on_stream_chunk(text: String) -> void:
	_streaming_buffer += text
	if not _chat_history.is_empty() and _chat_history[-1].get("role") == "streaming":
		_chat_history[-1]["text"] = _streaming_buffer
	else:
		_chat_history.append({ "role": "streaming", "text": _streaming_buffer, "expanded": true })
	_render_chat_log()

func _finalize_stream() -> void:
	if not _chat_history.is_empty() and _chat_history[-1].get("role") == "streaming":
		if _streaming_buffer.strip_edges() != "":
			_chat_history[-1] = { "role": "assistant", "text": _streaming_buffer, "expanded": true }
		else:
			_chat_history.remove_at(_chat_history.size() - 1)
		_render_chat_log()
		_save_session()
	_streaming_buffer = ""

func _on_agent_message(role: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	# Mensagem final substitui o buffer de streaming correspondente
	if not _chat_history.is_empty() and _chat_history[-1].get("role") == "streaming":
		_chat_history.remove_at(_chat_history.size() - 1)
		_streaming_buffer = ""
	_append_entry(role if role in ["user", "assistant", "system"] else "assistant", text)
	_save_session()

func _on_agent_event(event: Dictionary) -> void:
	var kind := str(event.get("event", ""))
	var data: Dictionary = event.get("data", {}) if event.get("data") is Dictionary else {}
	match kind:
		"tool_call":
			var tool_name := str(data.get("tool", data.get("name", "ferramenta")))
			var args := JSON.stringify(data.get("args", data.get("arguments", {})))
			_append_entry("tool_call", "Ferramenta: %s %s" % [tool_name, args.left(400)], true)
		"tool_result":
			var res_txt := str(data.get("result", data.get("output", JSON.stringify(data))))
			_append_entry("tool_res", res_txt.left(800), false)
		"thinking":
			_status_label.text = "pensando..."
		"error":
			_append_entry("system", "Erro: " + str(data.get("message", JSON.stringify(data))))
		"message", "finished":
			pass

func _on_permission_requested(action: String, target: String) -> void:
	_permission_label.text = "O agente quer executar: %s\n%s" % [action, target]
	_permission_bar.visible = true

func _resolve_permission(approved: bool, remember: bool) -> void:
	if agent:
		agent.respond_permission(approved, remember)
	_permission_bar.visible = false
	var verdict := "aprovada" if approved else "negada"
	if remember:
		verdict += " (sempre)"
	_append_entry("system", "Permissão %s." % verdict)

func _on_error_occurred(err_msg: String) -> void:
	_finalize_stream()
	_collapse_tools()
	_append_entry("system", "Erro: " + err_msg)
	_set_busy_ui(false)
	_save_session()

# ==============================================================================
# Renderização do histórico (RichTextLabel + BBCode)
# ==============================================================================

func _append_entry(role: String, text: String, expanded: bool = false) -> void:
	_chat_history.append({ "role": role, "text": text, "expanded": expanded })
	_render_chat_log()

func _append_entry_deferred(role: String, text: String) -> void:
	call_deferred("_append_entry", role, text)

func _collapse_tools() -> void:
	for entry in _chat_history:
		if entry["role"] in ["tool_call", "tool_res"]:
			entry["expanded"] = false
	_render_chat_log()

func _render_chat_log() -> void:
	if not _chat_log:
		return
	_chat_log.clear()
	_error_lut.clear()

	for i in range(_chat_history.size()):
		var entry: Dictionary = _chat_history[i]
		var role := str(entry["role"])
		var text := str(entry["text"])
		var expanded: bool = entry.get("expanded", false)

		var clean_text := text
		if role in ["user", "assistant", "streaming"]:
			clean_text = _format_badges(clean_text)

		var is_error := role == "system" and (clean_text.to_lower().contains("erro") or clean_text.to_lower().contains("failed"))
		if is_error:
			var err_idx := _error_lut.size()
			_error_lut.append(clean_text)
			clean_text += " [url=copy_to_input_%d][color=#f38ba8][Corrigir][/color][/url]" % err_idx

		match role:
			"user":
				_chat_log.append_text("\n[color=#56b6c2][b]Você[/b][/color]\n" + clean_text + "\n")
			"assistant":
				_chat_log.append_text("\n[color=#c678dd][b]Crom Agente[/b][/color]\n" + clean_text + "\n")
			"streaming":
				_chat_log.append_text("\n[color=#c678dd][b]Crom Agente[/b][/color] [color=#5c6370]…[/color]\n" + clean_text + "\n")
			"system":
				_chat_log.append_text("[color=#5c6370][i]" + clean_text + "[/i][/color]\n")
			"tool_call":
				var tool_label := _extract_tool_name(clean_text)
				var arrow := "▼" if expanded else "▶"
				var color := "#e5c07b" if expanded else "#98c379"
				_chat_log.append_text("[url=toggle_%d][bgcolor=#282c34]  [color=%s]%s %s[/color]  [/bgcolor][/url]\n" % [i, color, arrow, tool_label])
			"tool_res":
				if expanded:
					_chat_log.append_text("[bgcolor=#1e1e2e][color=#abb2bf]  " + clean_text + "[/color][/bgcolor]\n")

func _format_badges(s: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?<!\\w)res:\\/\\/[a-zA-Z0-9_\\/.-]+")
	var result := s
	var matches := regex.search_all(s)
	for j in range(matches.size() - 1, -1, -1):
		var m := matches[j]
		var path := m.get_string()
		var file_name := path.get_file()
		if file_name == "":
			file_name = path.get_base_dir().get_file() + "/"
		var badge := "[bgcolor=#282c34][color=#61afef][url=%s] %s [/url][/color][/bgcolor]" % [path, file_name]
		result = result.substr(0, m.get_start()) + badge + result.substr(m.get_end())
	return result

func _extract_tool_name(s: String) -> String:
	var regex := RegEx.new()
	regex.compile("Ferramenta:\\s*([a-zA-Z0-9_]+)")
	var res := regex.search(s)
	if res:
		return "Usou %s" % res.get_string(1)
	return s.strip_edges().left(60)

func _on_chat_log_meta_clicked(meta: Variant) -> void:
	var m_str := str(meta)
	if m_str.begins_with("toggle_"):
		var idx := int(m_str.trim_prefix("toggle_"))
		if idx >= 0 and idx < _chat_history.size():
			var is_exp: bool = _chat_history[idx].get("expanded", false)
			_chat_history[idx]["expanded"] = not is_exp
			if idx + 1 < _chat_history.size() and _chat_history[idx + 1]["role"] == "tool_res":
				_chat_history[idx + 1]["expanded"] = not is_exp
			_render_chat_log()
	elif m_str.begins_with("copy_to_input_"):
		var idx := int(m_str.trim_prefix("copy_to_input_"))
		if idx >= 0 and idx < _error_lut.size():
			_prompt_input.text = "Ocorreu o seguinte erro: " + _error_lut[idx] + ". Localize e corrija."
			_prompt_input.grab_focus()
	elif m_str.begins_with("res://"):
		if Engine.is_editor_hint():
			if m_str.ends_with(".gd"):
				var res = load(m_str)
				if res:
					EditorInterface.edit_resource(res)
			elif m_str.ends_with(".tscn"):
				EditorInterface.open_scene_from_path(m_str)
			else:
				EditorInterface.select_file(m_str)

# ==============================================================================
# Histórico de sessões (user://crom_chat_history)
# ==============================================================================

func _toggle_history() -> void:
	var show := not _history_panel.visible
	_history_panel.visible = show
	_chat_area.visible = not show
	if show:
		_load_sessions_list()

func _load_sessions_list() -> void:
	for child in _history_list.get_children():
		child.queue_free()

	if not DirAccess.dir_exists_absolute(HISTORY_DIR):
		var label := Label.new()
		label.text = "Nenhuma conversa salva."
		label.add_theme_color_override("font_color", ThemeC.TEXT_MUTED)
		_history_list.add_child(label)
		return

	var sessions: Array[String] = []
	var dir := DirAccess.open(HISTORY_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				sessions.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	sessions.sort()
	sessions.reverse()

	if sessions.is_empty():
		var label := Label.new()
		label.text = "Nenhuma conversa salva."
		label.add_theme_color_override("font_color", ThemeC.TEXT_MUTED)
		_history_list.add_child(label)
		return

	for s_file in sessions:
		var data = JSON.parse_string(FileAccess.get_file_as_string(HISTORY_DIR + "/" + s_file))
		if data is Dictionary and data.has("history"):
			var first_prompt := "Conversa vazia"
			for entry in data["history"]:
				if entry["role"] == "user":
					first_prompt = str(entry["text"]).left(40)
					break
			var btn := Button.new()
			btn.text = "%s · %s" % [s_file.trim_prefix("session_").trim_suffix(".json").left(16), first_prompt]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(func(): _load_session_by_file(s_file))
			_history_list.add_child(btn)

func _load_session_by_file(file_name: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(HISTORY_DIR + "/" + file_name))
	if data is Dictionary:
		_session_id = str(data.get("session_id", ""))
		_chat_history.clear()
		for entry in data.get("history", []):
			if entry is Dictionary:
				_chat_history.append({
					"role": str(entry.get("role", "system")),
					"text": str(entry.get("text", "")),
					"expanded": false,
				})
		if agent:
			agent.session_id = "godot-" + _session_id if _session_id != "" else "godot-editor"
		_render_chat_log()
		_toggle_history()

func _save_session() -> void:
	if _chat_history.is_empty():
		return
	if _session_id.is_empty():
		var dt := Time.get_datetime_dict_from_system()
		_session_id = "%04d-%02d-%02d_%02d-%02d-%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
		if agent:
			agent.session_id = "godot-" + _session_id

	if not DirAccess.dir_exists_absolute(HISTORY_DIR):
		DirAccess.make_dir_recursive_absolute(HISTORY_DIR)

	var persistable: Array = []
	for entry in _chat_history:
		if entry["role"] != "streaming":
			persistable.append(entry)

	var file := FileAccess.open(HISTORY_DIR + "/session_" + _session_id + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({ "session_id": _session_id, "history": persistable }, "\t"))
		file.close()

# ==============================================================================
# Monitoramento de erros do Godot (log watcher) — envia erros para o agente
# ==============================================================================

func _start_log_monitoring() -> void:
	_log_timer = Timer.new()
	_log_timer.wait_time = 1.0
	_log_timer.autostart = true
	_log_timer.timeout.connect(_check_godot_log)
	add_child(_log_timer)

	var log_path := "user://logs/godot.log"
	if FileAccess.file_exists(log_path):
		var f := FileAccess.open(log_path, FileAccess.READ)
		if f:
			_last_log_size = f.get_length()
			f.close()

func _check_godot_log() -> void:
	var log_path := "user://logs/godot.log"
	if not FileAccess.file_exists(log_path):
		return
	var f := FileAccess.open(log_path, FileAccess.READ)
	if not f:
		return
	var current_size := f.get_length()
	if current_size > _last_log_size:
		f.seek(_last_log_size)
		var new_content := f.get_buffer(current_size - _last_log_size).get_string_from_utf8()
		_last_log_size = current_size
		f.close()

		if new_content.contains("SCRIPT ERROR:") or new_content.contains("Parse Error:"):
			var err_lines: Array[String] = []
			var capturing := false
			for line in new_content.split("\n"):
				var l := line.strip_edges()
				if l.contains("SCRIPT ERROR:") or l.contains("Parse Error:") or l.contains("GDScript backtrace"):
					capturing = true
				if capturing:
					err_lines.append(l)
					if err_lines.size() >= 5:
						break
			if not err_lines.is_empty():
				_show_error_popup("\n".join(err_lines))
	else:
		_last_log_size = current_size
		f.close()

func _show_error_popup(err_msg: String) -> void:
	if not _error_popup:
		_error_popup = ConfirmationDialog.new()
		_error_popup.title = "Crom Agente — Erro Detectado"
		_error_popup.get_ok_button().text = "Corrigir agora"
		_error_popup.get_cancel_button().text = "Ignorar"
		_error_popup.add_button("Anexar ao chat", true, "attach")
		add_child(_error_popup)
		_error_popup.confirmed.connect(func():
			add_context_chip("error", "Erro de script", _last_error_context)
			_dispatch_user_task("Corrija o erro de script que anexei no contexto.")
		)
		_error_popup.custom_action.connect(func(action):
			if action == "attach":
				add_context_chip("error", "Erro de script", _last_error_context)
				_append_entry("system", "Erro anexado ao chat como contexto. Escreva o que fazer e envie.")
				_error_popup.hide()
		)
	_last_error_context = err_msg
	_error_popup.dialog_text = "O Godot reportou um erro de script:\n\n%s\n\nO que deseja fazer?" % err_msg
	_error_popup.popup_centered()

# ==============================================================================
# Drag & Drop de contexto (arquivos e nós)
# ==============================================================================

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") in ["files", "nodes", "node_paths"]

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	if data.has("files"):
		add_paths_as_context(data["files"])
	elif data.has("nodes"):
		add_nodes_as_context(data["nodes"])
	elif data.has("paths"):
		for p in data["paths"]:
			add_context_chip("node", str(p).get_file(), str(p))
		_append_entry("system", "Nó(s) anexado(s) ao contexto.")
