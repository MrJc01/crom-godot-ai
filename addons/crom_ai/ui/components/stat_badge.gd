class_name StatBadge
extends PanelContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")


# ==============================================================================
# Stat Badge — Badge colorido reutilizável ("ATIVO", "15/15 ✅", "2D", etc.)
# Usado dentro de Dashboard Cards e listas de projetos.
# ==============================================================================

var _label: Label

func _init(text: String = "", bg_color: Color = ThemeConstants.BADGE_ACTIVE_BG, fg_color: Color = ThemeConstants.BADGE_ACTIVE_FG) -> void:
	custom_minimum_size = Vector2(0, 22)
	add_theme_stylebox_override("panel", StyleFactory.badge(bg_color, fg_color))
	
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BADGE)
	_label.add_theme_color_override("font_color", fg_color)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

func set_text(text: String) -> void:
	if _label:
		_label.text = text

static func active(text: String = "ATIVO") -> PanelContainer:
	var script := load("res://addons/crom_ai/ui/components/stat_badge.gd") as GDScript
	return script.new(text, ThemeConstants.BADGE_ACTIVE_BG, ThemeConstants.BADGE_ACTIVE_FG)

static func info(text: String = "INFO") -> PanelContainer:
	var script := load("res://addons/crom_ai/ui/components/stat_badge.gd") as GDScript
	return script.new(text, ThemeConstants.BADGE_INFO_BG, ThemeConstants.BADGE_INFO_FG)

static func warning(text: String = "AVISO") -> PanelContainer:
	var script := load("res://addons/crom_ai/ui/components/stat_badge.gd") as GDScript
	return script.new(text, ThemeConstants.BADGE_WARN_BG, ThemeConstants.BADGE_WARN_FG)

