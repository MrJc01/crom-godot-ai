class_name ProjectCard
extends PanelContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const StatBadge = preload("res://addons/crom_ai/ui/components/stat_badge.gd")


# ==============================================================================
# Project Card — Card de um projeto na lista com nome, stats e botões
# ==============================================================================

signal open_editor_requested(path: String)
signal run_project_requested(path: String)

var _path: String

func _init(project_info: Dictionary) -> void:
	_path = project_info.get("path", "")
	add_theme_stylebox_override("panel", StyleFactory.card())
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	add_child(vbox)
	
	# Linha 1: Nome do Projeto + Badge IA
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var name_lbl := Label.new()
	name_lbl.text = "📂 " + project_info.get("display_name", project_info.get("short_name", "Projeto"))
	name_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H3)
	name_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)
	
	if project_info.get("has_crom_ai", false):
		header.add_child(StatBadge.active("IA"))
	
	# Linha 2: Path + Stats
	var info_lbl := Label.new()
	var scenes_count: int = project_info.get("scenes", 0)
	var scripts_count: int = project_info.get("scripts", 0)
	info_lbl.text = "%s  ·  %d cenas  ·  %d scripts" % [_path, scenes_count, scripts_count]
	info_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	info_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	vbox.add_child(info_lbl)
	
	# Linha 3: Botões de Ação
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	vbox.add_child(hbox)
	
	var btn_edit := Button.new()
	btn_edit.text = "🛠️ Abrir na IDE (com Agente IA)"
	btn_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_edit.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	btn_edit.pressed.connect(func(): open_editor_requested.emit(_path))
	hbox.add_child(btn_edit)
	
	var btn_play := Button.new()
	btn_play.text = "▶️ Play"
	btn_play.custom_minimum_size = Vector2(100, 0)
	btn_play.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	btn_play.pressed.connect(func(): run_project_requested.emit(_path))
	hbox.add_child(btn_play)
