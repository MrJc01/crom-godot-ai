class_name TerminalPanel
extends VBoxContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Terminal Panel — Painel inferior com tabs, botões de ação IA e logs
# ==============================================================================

signal action_requested(action: String)

var _log_box: RichTextLabel

func _init() -> void:
	custom_minimum_size = Vector2(0, ThemeConstants.PANEL_MIN_HEIGHT)
	add_theme_constant_override("separation", 0)

func _ready() -> void:
	# Tab bar do painel
	var tab_bar := PanelContainer.new()
	tab_bar.custom_minimum_size = Vector2(0, ThemeConstants.PANEL_TAB_HEIGHT)
	StyleFactory.apply_to(tab_bar, StyleFactory.zone_panel())
	add_child(tab_bar)
	
	var header_hbox := HBoxContainer.new()
	header_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_hbox.offset_left = ThemeConstants.SPACING_MD
	header_hbox.offset_top = 5
	header_hbox.add_theme_constant_override("separation", ThemeConstants.SPACING_XL)
	tab_bar.add_child(header_hbox)
	
	var title := Label.new()
	title.text = "TERMINAL & LOGS"
	title.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_TINY)
	title.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	header_hbox.add_child(title)
	
	_add_action_button(header_hbox, " IA: Inspecionar Tela", "inspect", "search")
	_add_action_button(header_hbox, " IA: Refatorar", "refactor", "wrench")
	_add_action_button(header_hbox, " IA: Jogar", "playtest", "gamepad")
	_add_action_button(header_hbox, " Telemetria (3s)", "benchmark_quick", "clock")
	
	# Corpo do painel (logs)
	var body := PanelContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	StyleFactory.apply_to(body, StyleFactory.panel(ThemeConstants.BG_PANEL))
	add_child(body)
	
	_log_box = RichTextLabel.new()
	_log_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_box.offset_left = ThemeConstants.SPACING_MD
	_log_box.offset_top = ThemeConstants.SPACING_SM
	_log_box.offset_right = -ThemeConstants.SPACING_MD
	_log_box.offset_bottom = -ThemeConstants.SPACING_SM
	_log_box.scroll_following = true
	_log_box.add_theme_font_size_override("normal_font_size", ThemeConstants.FONT_SIZE_LOG)
	_log_box.append_text("[color=#89b4fa]CromAI Hub inicializado.[/color]\n")
	body.add_child(_log_box)

func log_message(msg: String) -> void:
	if _log_box:
		_log_box.append_text(msg + "\n")

func _add_action_button(parent: HBoxContainer, text: String, action_id: String, icon_name: String = "") -> void:
	var btn := Button.new()
	btn.text = text
	if not icon_name.is_empty():
		btn.icon = IconProvider.get_icon(icon_name, 12, ThemeConstants.TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_TINY)
	btn.pressed.connect(func(): action_requested.emit(action_id))
	parent.add_child(btn)

