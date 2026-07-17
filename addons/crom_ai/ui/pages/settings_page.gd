class_name SettingsPage
extends Control

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const DashboardCard = preload("res://addons/crom_ai/ui/components/dashboard_card.gd")
const StatBadge = preload("res://addons/crom_ai/ui/components/stat_badge.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Settings Page — Configuração do Motor IA, API Key, WebSocket
# ==============================================================================

signal log_requested(msg: String)
signal test_connectivity_requested()

var _input_model: LineEdit
var _input_api_key: LineEdit

func _ready() -> void:
	_build_layout()

func _build_layout() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var main_box := VBoxContainer.new()
	main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.add_theme_constant_override("separation", ThemeConstants.SPACING_XL)
	scroll.add_child(main_box)
	
	# Card: Configuração do Agente IA
	var card_ia := DashboardCard.new(
		"Configuração do Agente IA",
		"Ajuste o provedor, modelo e chave de API do motor ReAct.",
		ThemeConstants.ACCENT_PURPLE
	)
	card_ia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.add_child(card_ia)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ThemeConstants.SPACING_LG)
	grid.add_theme_constant_override("v_separation", ThemeConstants.SPACING_SM)
	card_ia.add_content_node(grid)
	
	_add_config_row(grid, "Provedor e Modelo:", "openrouter : google/gemini-2.5-flash", false)
	_add_config_row(grid, "Chave de API:", "Configurada no painel do Crom Agente (user://)", true)
	
	var lbl_ws := Label.new()
	lbl_ws.text = "Porta WebSocket MCP:"
	lbl_ws.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	grid.add_child(lbl_ws)
	
	var ws_val := Label.new()
	ws_val.text = "8080 (Ativo e aguardando conexões)"
	ws_val.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	ws_val.add_theme_color_override("font_color", ThemeConstants.ACCENT_GREEN)
	grid.add_child(ws_val)
	
	# Botão de teste
	var btn_test := Button.new()
	btn_test.text = " Testar Conectividade com Motor ReAct"
	btn_test.icon = IconProvider.get_icon("refresh", 14, ThemeConstants.TEXT_PRIMARY)
	btn_test.custom_minimum_size = Vector2(0, 38)
	btn_test.pressed.connect(func(): test_connectivity_requested.emit())
	card_ia.add_content_node(btn_test)
	
	# Card: Informações do Sistema
	var card_sys := DashboardCard.new(
		"Informações do Sistema",
		"Dados do ambiente de execução atual.",
		ThemeConstants.ACCENT_BLUE
	)
	card_sys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.add_child(card_sys)
	
	card_sys.add_content_label("Godot Engine: %s" % Engine.get_version_info().get("string", "4.6"), ThemeConstants.TEXT_PRIMARY)
	card_sys.add_content_label("Renderer: Forward+", ThemeConstants.TEXT_SECONDARY)
	card_sys.add_content_label("OS: %s" % OS.get_name(), ThemeConstants.TEXT_SECONDARY)
	card_sys.add_content_label("Tema: VS Code Dark+ Minimalista", ThemeConstants.TEXT_MUTED)

func _add_config_row(grid: GridContainer, label_text: String, default_value: String, is_secret: bool) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	grid.add_child(lbl)
	
	var input := LineEdit.new()
	input.text = default_value
	input.secret = is_secret
	input.custom_minimum_size = Vector2(350, 32)
	grid.add_child(input)
	
	if is_secret:
		_input_api_key = input
	else:
		_input_model = input

