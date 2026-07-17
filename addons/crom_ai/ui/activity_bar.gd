class_name ActivityBar
extends PanelContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")


# ==============================================================================
# Activity Bar — Barra lateral esquerda com ícones SVG de navegação (52px)
# Emite signal quando o usuário seleciona uma página.
# ==============================================================================

signal page_selected(page_id: String)

var _vbox: VBoxContainer
var _buttons: Dictionary = {}  # page_id -> Button
var _current_page: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(ThemeConstants.ACTIVITY_BAR_WIDTH, 0)
	add_theme_stylebox_override("panel", StyleFactory.zone_activity_bar())

func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_vbox.add_theme_constant_override("separation", ThemeConstants.SPACING_LG)
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.offset_left = 6
	_vbox.offset_top = 16
	_vbox.offset_right = -6
	add_child(_vbox)
	
	# Ícones de navegação principal (topo)
	_add_nav_button("home",      "home",     "Início (Dashboard)")
	_add_nav_button("projects",  "folder",   "Projetos")
	_add_nav_button("playtest",  "gamepad",  "Playtest (IA Joga)")
	_add_nav_button("settings",  "settings", "Configurações")
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(spacer)
	
	# Ícone secundário (fundo)
	_add_nav_button("benchmark", "wrench",   "Benchmark (Stress Test)")
	
	set_active_page("home")

func set_active_page(page_id: String) -> void:
	_current_page = page_id
	for id in _buttons:
		var btn: Button = _buttons[id]
		if id == page_id:
			btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(0.45, 0.45, 0.50)

func _add_nav_button(page_id: String, icon_name: String, tooltip: String) -> void:
	var btn := IconProvider.icon_button(icon_name, tooltip, 20, ThemeConstants.TEXT_PRIMARY)
	btn.custom_minimum_size = Vector2(40, 40)
	btn.pressed.connect(func():
		set_active_page(page_id)
		page_selected.emit(page_id)
	)
	_vbox.add_child(btn)
	_buttons[page_id] = btn
