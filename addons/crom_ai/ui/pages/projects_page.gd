class_name ProjectsPage
extends Control

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const ProjectService = preload("res://addons/crom_ai/core/project_service.gd")
const ProjectCard = preload("res://addons/crom_ai/ui/components/project_card.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Projects Page — Criar + Listar projetos com dados e estatísticas
# ==============================================================================

signal log_requested(msg: String)

var _projects_list_box: VBoxContainer
var _input_name: LineEdit

func _ready() -> void:
	_build_layout()

func _build_layout() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", ThemeConstants.SPACING_LG)
	add_child(hbox)
	
	# Coluna Esquerda: Criar Novo Projeto
	var create_panel := PanelContainer.new()
	create_panel.custom_minimum_size = Vector2(320, 0)
	StyleFactory.apply_to(create_panel, StyleFactory.card_with_accent(ThemeConstants.ACCENT_GREEN))
	hbox.add_child(create_panel)
	
	var create_box := VBoxContainer.new()
	create_box.add_theme_constant_override("separation", ThemeConstants.SPACING_MD)
	create_panel.add_child(create_box)
	
	# Cabeçalho Criar
	var header_create := HBoxContainer.new()
	header_create.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	create_box.add_child(header_create)
	header_create.add_child(IconProvider.icon_rect("plus_circle", 20, ThemeConstants.ACCENT_GREEN))
	
	var ct := Label.new()
	ct.text = "Criar Novo Projeto"
	ct.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H2)
	ct.add_theme_color_override("font_color", ThemeConstants.ACCENT_GREEN)
	header_create.add_child(ct)
	
	var cd := Label.new()
	cd.text = "Gera uma pasta em ~/Documentos/Godot/ com o Agente ReAct (CromAI Chat) 100% ativado e pronto para uso na IDE."
	cd.autowrap_mode = TextServer.AUTOWRAP_WORD
	cd.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	cd.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	create_box.add_child(cd)
	
	create_box.add_child(HSeparator.new())
	
	var lbl_input := Label.new()
	lbl_input.text = "Nome do Projeto:"
	lbl_input.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	lbl_input.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	create_box.add_child(lbl_input)
	
	_input_name = LineEdit.new()
	_input_name.placeholder_text = "ex: crom-rpg-3d"
	_input_name.custom_minimum_size = Vector2(0, 36)
	create_box.add_child(_input_name)
	
	var btn_create := Button.new()
	btn_create.text = " Criar & Abrir no Editor"
	btn_create.icon = IconProvider.get_icon("plus", 14, ThemeConstants.TEXT_PRIMARY)
	btn_create.custom_minimum_size = Vector2(0, 42)
	btn_create.pressed.connect(_on_create_pressed)
	create_box.add_child(btn_create)
	
	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	create_box.add_child(tip_row)
	tip_row.add_child(IconProvider.icon_rect("lightbulb", 14, ThemeConstants.TEXT_MUTED))
	
	var tip := Label.new()
	tip.text = "O Editor abrirá automaticamente."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_TINY)
	tip.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	tip_row.add_child(tip)
	
	# Coluna Direita: Lista de Projetos
	var list_panel := PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StyleFactory.apply_to(list_panel, StyleFactory.card())
	hbox.add_child(list_panel)
	
	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", ThemeConstants.SPACING_MD)
	list_panel.add_child(list_vbox)
	
	# Cabeçalho Lista
	var header_list := HBoxContainer.new()
	header_list.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	list_vbox.add_child(header_list)
	header_list.add_child(IconProvider.icon_rect("folder", 20, ThemeConstants.ACCENT_YELLOW))
	
	var lt := Label.new()
	lt.text = "Meus Projetos Instalados"
	lt.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H2)
	lt.add_theme_color_override("font_color", ThemeConstants.ACCENT_YELLOW)
	header_list.add_child(lt)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_vbox.add_child(scroll)
	
	_projects_list_box = VBoxContainer.new()
	_projects_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_projects_list_box.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	scroll.add_child(_projects_list_box)
	
	_refresh_projects_list()

func _refresh_projects_list() -> void:
	for c in _projects_list_box.get_children():
		c.queue_free()
	
	var projects := ProjectService.list_projects()
	for p in projects:
		var card := ProjectCard.new(p)
		card.open_editor_requested.connect(func(path):
			log_requested.emit("Abrindo Editor IDE em: " + path)
			ProjectService.open_in_editor(path)
		)
		card.run_project_requested.connect(func(path):
			log_requested.emit("Executando projeto: " + path)
			ProjectService.run_project(path)
		)
		_projects_list_box.add_child(card)

func _on_create_pressed() -> void:
	var p_name := _input_name.text.strip_edges() if _input_name else ""
	log_requested.emit("Criando projeto: " + p_name)
	var dest := ProjectService.create_project(p_name)
	if _input_name:
		_input_name.text = ""
	_refresh_projects_list()
	log_requested.emit("Abrindo IDE no novo projeto...")
	ProjectService.open_in_editor(dest)

