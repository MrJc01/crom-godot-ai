class_name HomePage
extends Control

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")
const ProjectService = preload("res://addons/crom_ai/core/project_service.gd")
const GameRegistry = preload("res://addons/crom_ai/core/game_registry.gd")
const StatBadge = preload("res://addons/crom_ai/ui/components/stat_badge.gd")

# ==============================================================================
# Home Page — Dashboard minimalista, dev-first.
# Saudação + projetos recentes + status do agente + ações rápidas.
# ==============================================================================

signal navigate_requested(page_id: String)
signal open_project_requested(path: String)

func _ready() -> void:
	_build()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, ThemeConstants.SPACING_XL)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", ThemeConstants.SPACING_XL)
	scroll.add_child(root)

	_build_header(root)

	# Duas colunas: recentes (larga) + lateral (agente + ações)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", ThemeConstants.SPACING_LG)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_theme_constant_override("separation", ThemeConstants.SPACING_MD)
	columns.add_child(left)
	_build_recent_projects(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", ThemeConstants.SPACING_MD)
	columns.add_child(right)
	_build_agent_card(right)
	_build_quick_actions(right)

func _build_header(root: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ThemeConstants.SPACING_XS)
	root.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	box.add_child(title_row)
	title_row.add_child(IconProvider.icon_rect("zap", 26, ThemeConstants.ACCENT_BLUE))

	var title := Label.new()
	title.text = "Crom Hub"
	title.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H1)
	title.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	title_row.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Um ambiente de desenvolvimento Godot com o Crom Agente acoplado. Crie um projeto e converse com o agente na aba lateral da IDE para construir, mover e configurar tudo."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	subtitle.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	box.add_child(subtitle)

func _build_recent_projects(col: VBoxContainer) -> void:
	col.add_child(_section_title("folder", "Projetos recentes", ThemeConstants.ACCENT_BLUE))

	var projects := ProjectService.list_projects()
	if projects.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum projeto ainda. Vá em Projetos para criar o primeiro."
		empty.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
		empty.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
		col.add_child(empty)
	else:
		var shown := 0
		for p in projects:
			if shown >= 5:
				break
			col.add_child(_recent_row(p))
			shown += 1

	var see_all := Button.new()
	see_all.text = "Ver todos os projetos"
	see_all.flat = true
	see_all.add_theme_color_override("font_color", ThemeConstants.ACCENT_BLUE)
	see_all.pressed.connect(func(): navigate_requested.emit("projects"))
	col.add_child(see_all)

func _recent_row(p: Dictionary) -> Control:
	var card := PanelContainer.new()
	StyleFactory.apply_to(card, StyleFactory.card())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ThemeConstants.SPACING_MD)
	card.add_child(row)

	var is_fav: bool = p.get("favorite", false)
	row.add_child(IconProvider.icon_rect("star" if is_fav else "folder", 18,
		ThemeConstants.ACCENT_YELLOW if is_fav else ThemeConstants.TEXT_SECONDARY))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = p.get("display_name", "Projeto")
	name_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	name_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	info.add_child(name_lbl)

	var path_lbl := Label.new()
	path_lbl.text = "%s  ·  %d cenas · %d scripts" % [p.get("path", ""), p.get("scenes", 0), p.get("scripts", 0)]
	path_lbl.clip_text = true
	path_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_TINY)
	path_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	info.add_child(path_lbl)

	var open_btn := Button.new()
	open_btn.text = "Abrir"
	open_btn.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	open_btn.pressed.connect(func(): open_project_requested.emit(p.get("path", "")))
	row.add_child(open_btn)
	return card

func _build_agent_card(col: VBoxContainer) -> void:
	col.add_child(_section_title("bot", "Crom Agente", ThemeConstants.ACCENT_TEAL))

	var card := PanelContainer.new()
	StyleFactory.apply_to(card, StyleFactory.card_with_accent(ThemeConstants.ACCENT_TEAL))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	card.add_child(box)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	box.add_child(status_row)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = ThemeConstants.ACCENT_GREEN
	status_row.add_child(dot)
	var status_lbl := Label.new()
	status_lbl.text = "Acoplado ao projeto aberto"
	status_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	status_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	status_row.add_child(status_lbl)

	box.add_child(_bullet("Chat na aba lateral da IDE (Crom Agente)"))
	box.add_child(_bullet("Lê e edita scripts, cenas e nós"))
	box.add_child(_bullet("Move objetos e configura o projeto"))
	col.add_child(card)

func _build_quick_actions(col: VBoxContainer) -> void:
	col.add_child(_section_title("zap", "Ações rápidas", ThemeConstants.ACCENT_YELLOW))

	col.add_child(_action_button("plus", "Criar novo projeto", func(): navigate_requested.emit("projects")))
	col.add_child(_action_button("gamepad", "Playtest com IA", func(): navigate_requested.emit("playtest")))
	col.add_child(_action_button("settings", "Configurar agente & MCP", func(): navigate_requested.emit("settings")))

func _action_button(icon: String, text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = "  " + text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.icon = IconProvider.get_icon(icon, 15, ThemeConstants.TEXT_PRIMARY)
	btn.custom_minimum_size = Vector2(0, 38)
	btn.pressed.connect(cb)
	return btn

func _section_title(icon: String, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	row.add_child(IconProvider.icon_rect(icon, 16, color))
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H3)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)
	return row

func _bullet(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "· " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	return lbl
