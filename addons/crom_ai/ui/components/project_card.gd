class_name ProjectCard
extends PanelContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const StatBadge = preload("res://addons/crom_ai/ui/components/stat_badge.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Project Card — Linha de projeto minimalista com ações CRUD.
# Ícone · Nome + caminho · badges · [Abrir] [Play] [menu ⋯]
# ==============================================================================

signal open_editor_requested(path: String)
signal run_project_requested(path: String)
signal rename_requested(path: String, current_name: String)
signal remove_requested(path: String)
signal delete_requested(path: String)
signal favorite_toggled(path: String)

enum MenuAction { RENAME, REVEAL, FAVORITE, REMOVE, DELETE }

var _path: String
var _display_name: String

func _init(project_info: Dictionary) -> void:
	_path = project_info.get("path", "")
	_display_name = project_info.get("display_name", project_info.get("short_name", "Projeto"))
	add_theme_stylebox_override("panel", StyleFactory.card())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ThemeConstants.SPACING_MD)
	add_child(row)

	# Ícone do projeto
	var is_fav: bool = project_info.get("favorite", false)
	row.add_child(IconProvider.icon_rect(
		"star" if is_fav else "folder", 20,
		ThemeConstants.ACCENT_YELLOW if is_fav else ThemeConstants.ACCENT_BLUE))

	# Nome + caminho/stats
	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)
	row.add_child(info_box)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	info_box.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = _display_name
	name_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H3)
	name_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	name_row.add_child(name_lbl)

	if project_info.get("has_crom_ai", false):
		name_row.add_child(StatBadge.active("AGENTE"))

	var detail_lbl := Label.new()
	var scenes_count: int = project_info.get("scenes", 0)
	var scripts_count: int = project_info.get("scripts", 0)
	detail_lbl.text = "%s  ·  %d cenas  ·  %d scripts" % [_path, scenes_count, scripts_count]
	detail_lbl.clip_text = true
	detail_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_TINY)
	detail_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	info_box.add_child(detail_lbl)

	# Ações
	var btn_edit := Button.new()
	btn_edit.text = "Abrir"
	btn_edit.tooltip_text = "Abrir no Editor Godot com o Crom Agente"
	btn_edit.icon = IconProvider.get_icon("code", 13, ThemeConstants.TEXT_PRIMARY)
	btn_edit.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	btn_edit.pressed.connect(func(): open_editor_requested.emit(_path))
	row.add_child(btn_edit)

	var btn_play := Button.new()
	btn_play.tooltip_text = "Executar o projeto"
	btn_play.icon = IconProvider.get_icon("play", 13, ThemeConstants.ACCENT_GREEN)
	btn_play.flat = true
	btn_play.pressed.connect(func(): run_project_requested.emit(_path))
	row.add_child(btn_play)

	var menu := MenuButton.new()
	menu.text = "⋯"
	menu.tooltip_text = "Mais ações"
	menu.flat = true
	var popup := menu.get_popup()
	popup.add_item("Renomear", MenuAction.RENAME)
	popup.add_item("Mostrar na pasta", MenuAction.REVEAL)
	popup.add_item("Favoritar / Desfavoritar", MenuAction.FAVORITE)
	popup.add_separator()
	popup.add_item("Remover da lista", MenuAction.REMOVE)
	popup.add_item("Excluir do disco...", MenuAction.DELETE)
	popup.id_pressed.connect(_on_menu_action)
	row.add_child(menu)

func _on_menu_action(id: int) -> void:
	match id:
		MenuAction.RENAME:
			rename_requested.emit(_path, _display_name)
		MenuAction.REVEAL:
			OS.shell_show_in_file_manager(_path)
		MenuAction.FAVORITE:
			favorite_toggled.emit(_path)
		MenuAction.REMOVE:
			remove_requested.emit(_path)
		MenuAction.DELETE:
			delete_requested.emit(_path)
