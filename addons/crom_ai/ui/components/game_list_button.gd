class_name GameListButton
extends Button

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")


# ==============================================================================
# Game List Button — Botão estilizado para lista de minijogos na sidebar
# ==============================================================================

signal game_selected(game_info: Dictionary)

var _game_info: Dictionary

func _init(game_info: Dictionary) -> void:
	_game_info = game_info
	var exists := FileAccess.file_exists(game_info["tscn"])
	var icon_str := "🟢" if exists else "⏳"
	
	text = "%s %s" % [icon_str, game_info["name"]]
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0, 32)
	disabled = not exists
	add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	
	if exists:
		pressed.connect(func(): game_selected.emit(_game_info))
