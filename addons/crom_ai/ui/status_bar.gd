class_name StatusBar
extends PanelContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Status Bar — Rodapé fixo com FPS, RAM, provedor IA e status
# ==============================================================================

var _lbl_left: Label
var _lbl_right: Label

func _init() -> void:
	custom_minimum_size = Vector2(0, ThemeConstants.STATUS_BAR_HEIGHT)
	add_theme_stylebox_override("panel", StyleFactory.zone_status_bar())

func _ready() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 6
	hbox.offset_right = -6
	hbox.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	add_child(hbox)
	
	hbox.add_child(IconProvider.icon_rect("zap", 14, ThemeConstants.TEXT_WHITE))
	
	_lbl_left = Label.new()
	_lbl_left.text = "CromAI Hub | OpenRouter: google/gemini-2.5-flash | WS: 8080"
	_lbl_left.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_STATUS)
	_lbl_left.add_theme_color_override("font_color", ThemeConstants.TEXT_WHITE)
	_lbl_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_lbl_left)
	
	_lbl_right = Label.new()
	_lbl_right.text = "FPS: 60 | Mem: -- MB"
	_lbl_right.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_STATUS)
	_lbl_right.add_theme_color_override("font_color", ThemeConstants.TEXT_WHITE)
	hbox.add_child(_lbl_right)

func _process(_delta: float) -> void:
	if _lbl_right and is_inside_tree():
		var fps := Engine.get_frames_per_second()
		var mem := OS.get_static_memory_usage() / 1048576.0
		var nodes := get_tree().get_node_count()
		_lbl_right.text = "FPS: %d | Mem: %.1f MB | Nós: %d " % [fps, mem, nodes]

