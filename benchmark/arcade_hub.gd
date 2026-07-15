extends Control

# ==============================================================================
# CromAI Master Hub & App Designer (VS Code Minimalist Dark Mode Theme)
# 4 Páginas Separadas e Organizadas no Menu Lateral:
# 1. 🏠 Página Inicial (Informações Relevantes, Arquitetura e Telemetria Geral)
# 2. 📁 Página de Projetos (Gerenciador Completo & Criar Novo Projeto com IA)
# 3. 🎮 Página de Minijogos (Suíte 15 Jogos ReAct e Teste no Canvas 16:9)
# 4. ⚙️ Página de Configurações (Ajustes do Motor IA, MCP, Chaves e WebSockets)
# ==============================================================================

# Paleta de Cores Minimalista VS Code Dark+
const COLOR_BG_ACTIVITY = Color(0.11, 0.11, 0.11)       # #1c1c1c (Activity Bar)
const COLOR_BG_SIDEBAR  = Color(0.145, 0.145, 0.149)    # #252526 (Primary Side Bar)
const COLOR_BG_EDITOR   = Color(0.118, 0.118, 0.118)    # #1e1e1e (Canvas / Editor)
const COLOR_BG_PANEL    = Color(0.10, 0.10, 0.10)       # #1a1a1a (Terminal / Panel)
const COLOR_BORDER      = Color(0.18, 0.18, 0.19)       # #2d2d30 (Borders)
const COLOR_STATUS_BAR  = Color(0.0, 0.48, 0.80)        # #007acc (Rodapé VS Code Blue)
const COLOR_TEXT_MAIN   = Color(0.88, 0.88, 0.88)
const COLOR_TEXT_MUTED  = Color(0.55, 0.55, 0.55)
const COLOR_ACCENT      = Color(0.2, 0.6, 1.0)
const COLOR_GREEN       = Color(0.3, 0.85, 0.45)

# Zonas Principais do Layout
var activity_vbox: VBoxContainer
var sidebar_title_label: Label
var sidebar_content_box: VBoxContainer
var editor_tab_label: Label
var editor_canvas_box: Control
var log_box: RichTextLabel
var status_lbl_left: Label
var status_lbl_right: Label

# Containers das 4 Páginas no Canvas
var page_home: Control
var page_projects: Control
var page_games: Control
var page_settings: Control

# Componentes Específicos do Canvas de Jogos
var viewport_sub: SubViewport
var game_display: TextureRect
var active_game_node: Node
var active_game_info: Dictionary = {}

# Componentes Específicos de Criação de Projetos e Config
var input_project_name: LineEdit
var input_api_key: LineEdit
var input_model_name: LineEdit

var is_master := (ProjectSettings.globalize_path("res://").simplify_path() == "/home/j/Documentos/GitHub/crom-godot-ai")

# Estado e Motores ReAct / Telemetria
var current_view: String = "home"
var monitor: Node
var engine: Node

# Suíte dos 15 Minijogos Procedurais
var game_list: Array[Dictionary] = [
	{"id": "pong", "name": "1. Crom Pong ReAct", "type": "2D", "tscn": "res://games/pong/pong.tscn"},
	{"id": "flappy", "name": "2. Flappy AI Bird", "type": "2D", "tscn": "res://games/flappy/flappy.tscn"},
	{"id": "snake", "name": "3. Snake Cyber Grid", "type": "2D", "tscn": "res://games/snake/snake.tscn"},
	{"id": "breakout", "name": "4. Neon Breakout", "type": "2D", "tscn": "res://games/breakout/breakout.tscn"},
	{"id": "space_invaders", "name": "5. Space AI Invaders", "type": "2D", "tscn": "res://games/space_invaders/space_invaders.tscn"},
	{"id": "tetris", "name": "6. Block Matrix", "type": "2D", "tscn": "res://games/tetris/tetris.tscn"},
	{"id": "platformer", "name": "7. Cyber Runner 2D", "type": "2D", "tscn": "res://games/platformer/platformer.tscn"},
	{"id": "racing_topdown", "name": "8. Turbo Drift 2D", "type": "2D", "tscn": "res://games/racing_topdown/racing_topdown.tscn"},
	{"id": "tower_defense", "name": "9. AI Turret Defense", "type": "2D", "tscn": "res://games/tower_defense/tower_defense.tscn"},
	{"id": "asteroid_shooter", "name": "10. Asteroid Blaster", "type": "2D", "tscn": "res://games/asteroid_shooter/asteroid_shooter.tscn"},
	{"id": "memory_puzzle", "name": "11. ReAct Memory Grid", "type": "UI", "tscn": "res://games/memory_puzzle/memory_puzzle.tscn"},
	{"id": "flappy_3d", "name": "12. Flappy Cyber 3D", "type": "3D", "tscn": "res://games/flappy_3d/flappy_3d.tscn"},
	{"id": "rolling_ball_3d", "name": "13. Rolling Sphere 3D", "type": "3D", "tscn": "res://games/rolling_ball_3d/rolling_ball_3d.tscn"},
	{"id": "isometric_shooter", "name": "14. Iso Mech Arena", "type": "3D", "tscn": "res://games/isometric_shooter/isometric_shooter.tscn"},
	{"id": "raycaster_3d", "name": "15. Retro Raycaster 3D", "type": "3D", "tscn": "res://games/raycaster_3d/raycaster_3d.tscn"}
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_vs_code_layout()
	_init_agent_and_monitor()
	
	# Inicia na Página Inicial se for master, senão abre direto os jogos
	if is_master:
		_set_view("home")
	else:
		_set_view("games")

# ==============================================================================
# CONSTRUÇÃO DO LAYOUT 5 ZONAS (ACTIVITY BAR + SIDEBAR + CANVAS + PANEL + RODAPÉ)
# ==============================================================================
func _build_vs_code_layout() -> void:
	var bg_main = ColorRect.new()
	bg_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_main.color = COLOR_BG_EDITOR
	add_child(bg_main)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_bottom = -24 # Abre 24px para a Status Bar
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)
	
	# ZONA 1: ACTIVITY BAR (Menu Lateral Esquerdo - 52px)
	var activity_panel = PanelContainer.new()
	activity_panel.custom_minimum_size = Vector2(52, 0)
	_apply_flat_style(activity_panel, COLOR_BG_ACTIVITY, COLOR_BORDER, false, true)
	main_hbox.add_child(activity_panel)
	
	activity_vbox = VBoxContainer.new()
	activity_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	activity_vbox.add_theme_constant_override("separation", 16)
	activity_vbox.position = Vector2(6, 16)
	activity_panel.add_child(activity_vbox)
	
	_add_activity_btn("🏠", "Página Inicial (Informações Relevantes)", func(): _set_view("home"))
	if is_master:
		_add_activity_btn("📁", "Projetos (Lista & Criar Novo)", func(): _set_view("projects"))
	_add_activity_btn("🎮", "Suíte de 15 Minijogos", func(): _set_view("games"))
	_add_activity_btn("⚙️", "Configurações IA e MCP", func(): _set_view("settings"))
	
	# ZONA 2: PRIMARY SIDE BAR (250px)
	var sidebar_panel = PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(250, 0)
	_apply_flat_style(sidebar_panel, COLOR_BG_SIDEBAR, COLOR_BORDER, false, true)
	main_hbox.add_child(sidebar_panel)
	
	var sidebar_vbox = VBoxContainer.new()
	sidebar_vbox.add_theme_constant_override("separation", 8)
	sidebar_panel.add_child(sidebar_vbox)
	
	var sidebar_header = PanelContainer.new()
	sidebar_header.custom_minimum_size = Vector2(0, 38)
	_apply_flat_style(sidebar_header, COLOR_BG_SIDEBAR, COLOR_BORDER, false, false)
	sidebar_vbox.add_child(sidebar_header)
	
	sidebar_title_label = Label.new()
	sidebar_title_label.text = "EXPLORER: INÍCIO"
	sidebar_title_label.add_theme_font_size_override("font_size", 12)
	sidebar_title_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	sidebar_title_label.position = Vector2(12, 10)
	sidebar_header.add_child(sidebar_title_label)
	
	var sidebar_scroll = ScrollContainer.new()
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_vbox.add_child(sidebar_scroll)
	
	sidebar_content_box = VBoxContainer.new()
	sidebar_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_content_box.add_theme_constant_override("separation", 6)
	sidebar_scroll.add_child(sidebar_content_box)
	
	# ZONAS 3 E 4: EDITOR GROUP (Centro) + TERMINAL PANEL (Baixo)
	var right_vsplit = VSplitContainer.new()
	right_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vsplit.split_offset = 360
	main_hbox.add_child(right_vsplit)
	
	var editor_group = VBoxContainer.new()
	editor_group.add_theme_constant_override("separation", 0)
	right_vsplit.add_child(editor_group)
	
	# Top Tabs Bar
	var tabs_bar = PanelContainer.new()
	tabs_bar.custom_minimum_size = Vector2(0, 38)
	_apply_flat_style(tabs_bar, COLOR_BG_ACTIVITY, COLOR_BORDER, false, false)
	editor_group.add_child(tabs_bar)
	
	var active_tab = PanelContainer.new()
	active_tab.custom_minimum_size = Vector2(220, 38)
	_apply_flat_style(active_tab, COLOR_BG_EDITOR, COLOR_ACCENT, false, false, true) # Top border azul
	tabs_bar.add_child(active_tab)
	
	editor_tab_label = Label.new()
	editor_tab_label.text = "🏠 Welcome_Information.gd"
	editor_tab_label.add_theme_font_size_override("font_size", 13)
	editor_tab_label.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
	editor_tab_label.position = Vector2(14, 10)
	active_tab.add_child(editor_tab_label)
	
	# Editor Canvas Box
	editor_canvas_box = Control.new()
	editor_canvas_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_canvas_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_group.add_child(editor_canvas_box)
	
	# Constrói as 4 Páginas e as adiciona ao Canvas
	page_home = _create_page_home()
	page_projects = _create_page_projects()
	page_games = _create_page_games()
	page_settings = _create_page_settings()
	
	for p in [page_home, page_projects, page_games, page_settings]:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		editor_canvas_box.add_child(p)
		
	# ZONA 4: PANEL (Terminal Integrado & Telemetria)
	var bottom_panel = VBoxContainer.new()
	bottom_panel.custom_minimum_size = Vector2(0, 160)
	bottom_panel.add_theme_constant_override("separation", 0)
	right_vsplit.add_child(bottom_panel)
	
	var panel_tabs = PanelContainer.new()
	panel_tabs.custom_minimum_size = Vector2(0, 32)
	_apply_flat_style(panel_tabs, COLOR_BG_SIDEBAR, COLOR_BORDER, true, false)
	bottom_panel.add_child(panel_tabs)
	
	var panel_header_hbox = HBoxContainer.new()
	panel_header_hbox.position = Vector2(12, 5)
	panel_header_hbox.add_theme_constant_override("separation", 20)
	panel_tabs.add_child(panel_header_hbox)
	
	var p_title = Label.new()
	p_title.text = "TERMINAL & TELEMETRIA REACT"
	p_title.add_theme_font_size_override("font_size", 11)
	p_title.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
	panel_header_hbox.add_child(p_title)
	
	var btn_quick_inspect = Button.new()
	btn_quick_inspect.text = "🔍 IA: Inspecionar Jogo Atual"
	btn_quick_inspect.add_theme_font_size_override("font_size", 11)
	btn_quick_inspect.pressed.connect(_on_btn_agent_inspect)
	panel_header_hbox.add_child(btn_quick_inspect)
	
	var btn_quick_refactor = Button.new()
	btn_quick_refactor.text = "🛠️ IA: Refatorar Código"
	btn_quick_refactor.add_theme_font_size_override("font_size", 11)
	btn_quick_refactor.pressed.connect(_on_btn_agent_refactor)
	panel_header_hbox.add_child(btn_quick_refactor)
	
	var btn_quick_bench = Button.new()
	btn_quick_bench.text = "⏱️ Rodar Benchmark (3.0s)"
	btn_quick_bench.add_theme_font_size_override("font_size", 11)
	btn_quick_bench.pressed.connect(_on_btn_benchmark)
	panel_header_hbox.add_child(btn_quick_bench)
	
	var panel_body = PanelContainer.new()
	panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_flat_style(panel_body, COLOR_BG_PANEL, COLOR_BORDER, false, false)
	bottom_panel.add_child(panel_body)
	
	log_box = RichTextLabel.new()
	log_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_box.position = Vector2(12, 8)
	log_box.size = Vector2(1100, 140)
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_box.append_text("[color=#89b4fa]✨ CromAI Minimalist Hub Inicializado.[/color]\n[color=#a6e3a1]✓ 4 Páginas Semânticas separadas (Início, Projetos, Minijogos, Configurações).[/color]\n")
	panel_body.add_child(log_box)
	
	# ZONA 5: STATUS BAR (Rodapé - 24px)
	var status_bar = PanelContainer.new()
	status_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_bar.custom_minimum_size = Vector2(0, 24)
	_apply_flat_style(status_bar, COLOR_STATUS_BAR, COLOR_STATUS_BAR, false, false)
	add_child(status_bar)
	
	status_lbl_left = Label.new()
	status_lbl_left.text = " ⚡ CromAI Godot App Designer | Provedor: OpenRouter (google/gemini-2.5-flash) | WS: 8080"
	status_lbl_left.add_theme_font_size_override("font_size", 11)
	status_lbl_left.add_theme_color_override("font_color", Color.WHITE)
	status_lbl_left.position = Vector2(8, 3)
	status_bar.add_child(status_lbl_left)
	
	status_lbl_right = Label.new()
	status_lbl_right.text = "FPS: 60 | Mem: -- MB | Tema: VS Code Clean "
	status_lbl_right.add_theme_font_size_override("font_size", 11)
	status_lbl_right.add_theme_color_override("font_color", Color.WHITE)
	status_lbl_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_lbl_right.position = Vector2(-240, 3)
	status_bar.add_child(status_lbl_right)

# ==============================================================================
# SELETOR DAS 4 PÁGINAS (HOME / PROJECTS / GAMES / SETTINGS)
# ==============================================================================
func _set_view(view_id: String) -> void:
	current_view = view_id
	page_home.visible = (view_id == "home")
	page_projects.visible = (view_id == "projects")
	page_games.visible = (view_id == "games")
	page_settings.visible = (view_id == "settings")
	
	for c in sidebar_content_box.get_children(): c.queue_free()
	
	if view_id == "home":
		sidebar_title_label.text = "EXPLORER: INÍCIO"
		editor_tab_label.text = "🏠 Welcome_Information.gd"
		_populate_sidebar_home()
	elif view_id == "projects":
		sidebar_title_label.text = "EXPLORER: MEUS PROJETOS"
		editor_tab_label.text = "📁 Projects_Manager.ts"
		_populate_sidebar_projects()
	elif view_id == "games":
		sidebar_title_label.text = "COMPONENTS: SUÍTE 15 JOGOS"
		editor_tab_label.text = "🎮 Minigames_Viewport.tscn"
		_populate_sidebar_games()
	elif view_id == "settings":
		sidebar_title_label.text = "CONFIG: AGENTE & MCP"
		editor_tab_label.text = "⚙️ ReAct_Engine_Config.json"
		_populate_sidebar_settings()

# ==============================================================================
# CONSTRUÇÃO DAS 4 PÁGINAS DO CANVAS
# ==============================================================================

# PÁGINA 1: HOME (Informações Relevantes e Arquitetura)
func _create_page_home() -> Control:
	var ctrl = Control.new()
	var card = PanelContainer.new()
	card.position = Vector2(24, 24)
	card.size = Vector2(780, 320)
	_apply_flat_style(card, Color(0.14, 0.14, 0.15), COLOR_BORDER, false, false)
	ctrl.add_child(card)
	
	var box = VBoxContainer.new()
	box.position = Vector2(24, 24)
	box.size = Vector2(732, 280)
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	
	var t = Label.new()
	t.text = "⚡ Bem-vindo ao CromAI Godot Bridge & Agente ReAct"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	box.add_child(t)
	
	var d = Label.new()
	d.text = "Arquitetura limpa e organizada inspirada no VS Code Dark Mode minimalista. O sistema une o motor ReAct nativo (GDScript 4) na barra lateral da sua IDE Godot com a capacidade de criar jogos, editar scripts e checar visualmente telas (Multimodal) via Base64."
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
	box.add_child(d)
	
	box.add_child(HSeparator.new())
	
	var info_lbl = Label.new()
	info_lbl.text = "📌 Informações Relevantes do Seu Ambiente Atual:"
	info_lbl.add_theme_font_size_override("font_size", 14)
	info_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	box.add_child(info_lbl)
	
	var details = Label.new()
	details.text = " • Motor ReAct na IDE: Ativado em res://addons/crom_ai (Aba lateral 'CromAI Chat').\n • Modelo Inteligente: google/gemini-2.5-flash (OpenRouter API).\n • Suíte de Testes: 15 Minijogos procedurais integrados (Pong, Snake, Flappy, 3D Raycaster, etc.).\n • Comandos de Chat: Digite /clean para limpar pasta ou /benchmark para rodar teste de IA com confirmação."
	details.add_theme_font_size_override("font_size", 13)
	details.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	box.add_child(details)
	return ctrl

# PÁGINA 2: PROJETOS (Criar Novo Projeto com IA e Lista de Projetos no PC)
func _create_page_projects() -> Control:
	var ctrl = Control.new()
	
	# Coluna Esquerda: Criar Novo Projeto com Agente IA
	var create_panel = PanelContainer.new()
	create_panel.position = Vector2(16, 16)
	create_panel.size = Vector2(340, 336)
	_apply_flat_style(create_panel, Color(0.14, 0.14, 0.15), COLOR_BORDER, false, false)
	ctrl.add_child(create_panel)
	
	var c_box = VBoxContainer.new()
	c_box.position = Vector2(16, 16)
	c_box.size = Vector2(308, 304)
	c_box.add_theme_constant_override("separation", 10)
	create_panel.add_child(c_box)
	
	var ct = Label.new()
	ct.text = "🚀 Criar Novo Projeto Godot"
	ct.add_theme_font_size_override("font_size", 18)
	ct.add_theme_color_override("font_color", COLOR_GREEN)
	c_box.add_child(ct)
	
	var cd = Label.new()
	cd.text = "Cria uma pasta em ~/Documentos/Godot/ com o Agente ReAct (CromAI Chat) 100% ativado por padrão na IDE."
	cd.autowrap_mode = TextServer.AUTOWRAP_WORD
	cd.add_theme_font_size_override("font_size", 12)
	cd.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	c_box.add_child(cd)
	
	input_project_name = LineEdit.new()
	input_project_name.placeholder_text = "Nome (ex: crom-rpg-3d)"
	input_project_name.custom_minimum_size = Vector2(0, 36)
	c_box.add_child(input_project_name)
	
	var btn_create = Button.new()
	btn_create.text = "➕ Criar & Abrir no Editor Godot"
	btn_create.custom_minimum_size = Vector2(0, 42)
	btn_create.pressed.connect(_on_create_new_project_pressed)
	c_box.add_child(btn_create)
	
	# Coluna Direita: Lista Completa de Projetos
	var list_panel = PanelContainer.new()
	list_panel.position = Vector2(372, 16)
	list_panel.size = Vector2(440, 336)
	_apply_flat_style(list_panel, Color(0.14, 0.14, 0.15), COLOR_BORDER, false, false)
	ctrl.add_child(list_panel)
	
	var l_box = VBoxContainer.new()
	l_box.position = Vector2(16, 16)
	l_box.size = Vector2(408, 304)
	l_box.add_theme_constant_override("separation", 10)
	list_panel.add_child(l_box)
	
	var lt = Label.new()
	lt.text = "📁 Meus Projetos Instalados no Computador"
	lt.add_theme_font_size_override("font_size", 18)
	lt.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	l_box.add_child(lt)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l_box.add_child(scroll)
	
	var p_box = VBoxContainer.new()
	p_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_box.add_theme_constant_override("separation", 6)
	scroll.add_child(p_box)
	
	_populate_projects_list_ui(p_box)
	return ctrl

# PÁGINA 3: JOGOS (SubViewport 16:9 + TextureRect)
func _create_page_games() -> Control:
	var ctrl = Control.new()
	viewport_sub = SubViewport.new()
	viewport_sub.size = Vector2i(1152, 648)
	viewport_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_sub.handle_input_locally = false
	add_child(viewport_sub)
	
	game_display = TextureRect.new()
	game_display.texture = viewport_sub.get_texture()
	game_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(game_display)
	return ctrl

# PÁGINA 4: SETTINGS (Configuração Clara e Organizada)
func _create_page_settings() -> Control:
	var ctrl = Control.new()
	var card = PanelContainer.new()
	card.position = Vector2(24, 24)
	card.size = Vector2(780, 320)
	_apply_flat_style(card, Color(0.14, 0.14, 0.15), COLOR_BORDER, false, false)
	ctrl.add_child(card)
	
	var box = VBoxContainer.new()
	box.position = Vector2(24, 24)
	box.size = Vector2(732, 280)
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	
	var st = Label.new()
	st.text = "⚙️ Configuração Geral do Agente e Conectores"
	st.add_theme_font_size_override("font_size", 20)
	st.add_theme_color_override("font_color", Color(0.9, 0.6, 1.0))
	box.add_child(st)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	
	var l1 = Label.new(); l1.text = "Provedor e Modelo IA:"; grid.add_child(l1)
	input_model_name = LineEdit.new(); input_model_name.text = "openrouter : google/gemini-2.5-flash"; input_model_name.custom_minimum_size = Vector2(350, 32); grid.add_child(input_model_name)
	
	var l2 = Label.new(); l2.text = "Chave de API (OpenRouter):"; grid.add_child(l2)
	input_api_key = LineEdit.new(); input_api_key.text = "sk-or-v1-04914... (Configurado)"; input_api_key.secret = true; input_api_key.custom_minimum_size = Vector2(350, 32); grid.add_child(input_api_key)
	
	var l3 = Label.new(); l3.text = "Porta do WebSocket MCP:"; grid.add_child(l3)
	var p_lbl = Label.new(); p_lbl.text = "8080 (Ativo e aguardando conexões de agentes externos)"; p_lbl.add_theme_color_override("font_color", COLOR_GREEN); grid.add_child(p_lbl)
	
	box.add_child(HSeparator.new())
	
	var btn_test = Button.new()
	btn_test.text = "🔄 Testar Conectividade com Motor ReAct"
	btn_test.custom_minimum_size = Vector2(0, 38)
	btn_test.pressed.connect(func():
		_log("[color=#f9e231]⚙️ Testando ping para OpenRouter Gemini 2.5 Flash...[/color]")
		if engine: engine.send_user_prompt("Responda em 1 frase confirmando que você está ativo e pronto para ajudar o usuário no Godot.")
	)
	box.add_child(btn_test)
	return ctrl

# ==============================================================================
# CONSTRUÇÃO DO CONTEÚDO DA SIDEBAR PARA CADA UMA DAS 4 PÁGINAS
# ==============================================================================
func _populate_sidebar_home() -> void:
	_add_sidebar_card("📌 Resumo Geral", "O CromAI unifica inteligência artificial multimodal dentro do Godot com zero burocracia manual.")
	_add_sidebar_card("⌨️ Atalhos Rápidos", " • F5: Abre este Hub\n • godot -e: Abre a IDE direto\n • /clean: Zera pasta de jogos\n • /benchmark: Audit ao vivo")
	_add_sidebar_card("🛠️ Status do Sistema", "Godot 4.6 Forward+\nTema: VS Code Dark+\nPlugins: 100% Ativados")

func _populate_sidebar_projects() -> void:
	var btn_new = Button.new()
	btn_new.text = "➕ Criar Novo Projeto"
	btn_new.custom_minimum_size = Vector2(0, 34)
	btn_new.pressed.connect(func(): _set_view("projects"))
	sidebar_content_box.add_child(btn_new)
	
	_add_sidebar_card("💡 Gerenciamento", "Selecione qualquer projeto na lista central para abri-lo diretamente no Editor com o Agente IA ou executá-lo.")

func _populate_sidebar_games() -> void:
	for g in game_list:
		var exists = FileAccess.file_exists(g["tscn"])
		var icon_str = "🟢" if exists else "⏳"
		var btn = Button.new()
		btn.text = "%s %s" % [icon_str, g["name"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.disabled = not exists
		if exists:
			btn.pressed.connect(func(): _load_game(g))
		sidebar_content_box.add_child(btn)

func _populate_sidebar_settings() -> void:
	_add_sidebar_card("🔐 Segurança", "Suas chaves e configurações ficam armazenadas localmente no projeto para comunicação segura via HTTPS com OpenRouter.")
	_add_sidebar_card("📡 Servidor WebSocket", "A porta 8080 permite que agentes em Python, Go ou Node conectem e comandem seu mundo em tempo real.")

func _populate_projects_list_ui(parent: VBoxContainer) -> void:
	var projects_found: Array[String] = []
	var cfg_path = OS.get_environment("HOME") + "/.local/share/godot/projects.cfg"
	if FileAccess.file_exists(cfg_path):
		var file = FileAccess.open(cfg_path, FileAccess.READ)
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			if line.begins_with("[") and line.ends_with("]"):
				var p = line.substr(1, line.length() - 2)
				if not projects_found.has(p) and DirAccess.dir_exists_absolute(p): projects_found.append(p)
		file.close()
		
	for p in ["/home/j/Documentos/GitHub/crom-godot-ai", "/home/j/novo-projeto-de-jogo", "/home/j/crom-game-1"]:
		if not projects_found.has(p) and DirAccess.dir_exists_absolute(p): projects_found.append(p)
		
	for p_path in projects_found:
		var card = PanelContainer.new()
		_apply_flat_style(card, Color(0.16, 0.16, 0.17), COLOR_BORDER, false, false)
		var box = VBoxContainer.new()
		card.add_child(box)
		
		var s_name = p_path.get_file(); if s_name.is_empty(): s_name = p_path
		var lbl = Label.new(); lbl.text = "⭐ " + s_name + " — [color=#a6e3a1]" + p_path + "[/color]"; box.add_child(lbl)
		
		var hbox = HBoxContainer.new(); box.add_child(hbox)
		var btn_edit = Button.new(); btn_edit.text = "🛠️ Abrir na IDE (com Agente IA)"; btn_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_edit.pressed.connect(func(): _log("Abrindo IDE em: " + p_path); OS.create_process("godot", ["-e", "--path", p_path]))
		hbox.add_child(btn_edit)
		
		var btn_play = Button.new(); btn_play.text = "▶️ F5 Play"; btn_play.custom_minimum_size = Vector2(120, 32)
		btn_play.pressed.connect(func(): _log("Executando em: " + p_path); OS.create_process("godot", ["--path", p_path]))
		hbox.add_child(btn_play)
		parent.add_child(card)

# ==============================================================================
# FUNÇÕES DE SUPORTE, ESTILIZAÇÃO E EVENTOS
# ==============================================================================
func _on_create_new_project_pressed() -> void:
	if not input_project_name: return
	var p_name = input_project_name.text.strip_edges()
	if p_name.is_empty(): p_name = "novo-rpg-ia-" + str(randi() % 900 + 100)
	var dest = "/home/j/Documentos/Godot/" + p_name
	_log("[color=#a6e3a1]🚀 Criando novo projeto modular em:[/color] " + dest)
	
	DirAccess.make_dir_recursive_absolute(dest + "/addons"); DirAccess.make_dir_recursive_absolute(dest + "/benchmark")
	var m_add = "/home/j/Documentos/GitHub/crom-godot-ai/addons/crom_ai"
	var m_ben = "/home/j/Documentos/GitHub/crom-godot-ai/benchmark"
	if DirAccess.dir_exists_absolute(m_add): OS.execute("cp", ["-rf", m_add, dest + "/addons/"])
	if DirAccess.dir_exists_absolute(m_ben): OS.execute("cp", ["-rf", m_ben + "/.", dest + "/benchmark/"])
	if FileAccess.file_exists("/home/j/Documentos/GitHub/crom-godot-ai/icon.svg"):
		OS.execute("cp", ["-f", "/home/j/Documentos/GitHub/crom-godot-ai/icon.svg", dest + "/icon.svg"])
		
	var cfg = """; Engine configuration file.
config_version=5
[application]
config/name="%s"
run/main_scene="res://benchmark/arcade_hub.tscn"
config/features=PackedStringArray("4.6", "Forward Plus")
config/icon="res://icon.svg"
[autoload]
CromWorldManager="*res://addons/crom_ai/world_state_manager.gd"
[editor_plugins]
enabled=PackedStringArray("res://addons/crom_ai/plugin.cfg")
[display]
window/size/viewport_width=1152
window/size/viewport_height=648
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
""" % p_name
	var f = FileAccess.open(dest + "/project.godot", FileAccess.WRITE)
	if f: f.store_string(cfg); f.close()
	
	var cfg_path = OS.get_environment("HOME") + "/.local/share/godot/projects.cfg"
	if FileAccess.file_exists(cfg_path):
		var old = FileAccess.get_file_as_string(cfg_path)
		var f_c = FileAccess.open(cfg_path, FileAccess.WRITE)
		f_c.store_string("[%s]\n\nfavorite=true\n\n%s" % [dest, old]); f_c.close()
		
	input_project_name.text = ""
	_set_view("projects")
	_log("[color=#f9e231]🛠️ Abrindo a IDE do Godot no novo projeto...[/color]")
	OS.create_process("godot", ["-e", "--path", dest])

func _init_agent_and_monitor() -> void:
	var MonClass = load("res://benchmark/benchmark_monitor.gd")
	if MonClass:
		monitor = MonClass.new(); add_child(monitor)
		monitor.benchmark_finished.connect(func(g_id, rep):
			_log("[color=#a6e3a1]✅ Telemetria de %s: %.1f FPS (Peak RAM: %.1f MB)[/color]" % [g_id, rep["fps"]["average"], rep["memory_mb"]["peak"]])
		)
	var ProcClass = load("res://addons/crom_ai/command_processor.gd")
	var proc = ProcClass.new(null); add_child(proc)
	var EngineClass = load("res://addons/crom_ai/native_react_engine.gd")
	if EngineClass:
		engine = EngineClass.new(proc); add_child(engine)
		engine.set_config("openrouter", "google/gemini-2.5-flash", "sk-or-v1-key-removed-by-antigravity")
		engine.message_added.connect(func(role, text): if role == "tool_call": _log("[color=#fab387]🤖 Ferramenta Acionada:[/color] " + text.substr(0, 100)))
		engine.react_finished.connect(func(ans): _log("[color=#cba6f7]🤖 Resposta do Agente:[/color]\n" + ans))

func _load_game(info: Dictionary) -> void:
	active_game_info = info
	if active_game_node: active_game_node.queue_free(); active_game_node = null
	_log("[color=#89b4fa]Carregando minijogo no Canvas:[/color] [b]%s[/b]" % info["name"])
	var res = load(info["tscn"]) as PackedScene
	if res:
		active_game_node = res.instantiate(); viewport_sub.add_child(active_game_node)
	else: _log("[color=#f38ba8]Erro ao carregar minijogo:[/color] %s" % info["tscn"])

func _input(event: InputEvent) -> void:
	if current_view == "games" and game_display and game_display.visible and viewport_sub and is_instance_valid(viewport_sub):
		if event is InputEventKey: viewport_sub.push_input(event)
		elif (event is InputEventMouseButton or event is InputEventMouseMotion): viewport_sub.push_input(event)

func _process(_delta: float) -> void:
	if status_lbl_right and is_inside_tree():
		status_lbl_right.text = "FPS: %d | Mem: %.1f MB | Nós: %d | Tema: VS Code Clean " % [Engine.get_frames_per_second(), OS.get_static_memory_usage() / 1048576.0, get_tree().get_node_count()]

func _on_btn_agent_inspect() -> void:
	if not engine or active_game_info.is_empty(): return
	_log("[color=#f9e231]🤖 Agente tirando print de %s para inspeção visual...[/color]" % active_game_info["name"])
	engine.send_user_prompt("Chame capture_screenshot agora e analise a responsividade e o código do jogo '%s'." % active_game_info["name"])

func _on_btn_agent_refactor() -> void:
	if not engine or active_game_info.is_empty(): return
	_log("[color=#f9e231]🤖 Refatorando código de %s...[/color]" % active_game_info["name"])
	engine.send_user_prompt("Otimize o script do jogo '%s' usando modify_project_file." % active_game_info["name"])

func _on_btn_benchmark() -> void:
	if not monitor or active_game_info.is_empty(): return
	_log("[color=#a6e3a1]⏱️ Disparando teste de telemetria (3.0s)...[/color]")
	monitor.start_benchmark(active_game_info["id"], 3.0)

func _log(msg: String) -> void:
	if log_box: log_box.append_text(msg + "\n")

func _apply_flat_style(panel: Control, bg_color: Color, border_color: Color, border_top: bool = false, border_right: bool = false, border_top_accent: bool = false) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color; sb.border_color = border_color
	if border_top: sb.border_width_top = 1
	if border_right: sb.border_width_right = 1
	if border_top_accent: sb.border_color = COLOR_ACCENT; sb.border_width_top = 2
	panel.add_theme_stylebox_override("panel", sb)

func _add_activity_btn(icon_text: String, tooltip: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = icon_text; btn.tooltip_text = tooltip; btn.custom_minimum_size = Vector2(40, 40); btn.flat = true
	btn.add_theme_font_size_override("font_size", 18); btn.pressed.connect(callback)
	activity_vbox.add_child(btn)

func _add_sidebar_card(title_str: String, desc_str: String) -> void:
	var card = PanelContainer.new(); _apply_flat_style(card, Color(0.16, 0.16, 0.17), COLOR_BORDER, false, false)
	var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 3); card.add_child(box)
	var t = Label.new(); t.text = title_str; t.add_theme_font_size_override("font_size", 13); t.add_theme_color_override("font_color", COLOR_TEXT_MAIN); box.add_child(t)
	var d = Label.new(); d.text = desc_str; d.autowrap_mode = TextServer.AUTOWRAP_WORD; d.add_theme_font_size_override("font_size", 11); d.add_theme_color_override("font_color", COLOR_TEXT_MUTED); box.add_child(d)
	sidebar_content_box.add_child(card)
