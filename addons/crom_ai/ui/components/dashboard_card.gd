class_name DashboardCard
extends PanelContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const StatBadge = preload("res://addons/crom_ai/ui/components/stat_badge.gd")


# ==============================================================================
# Dashboard Card — Card genérico do Dashboard com título, badge e conteúdo slot
# Layout:
#   ┌─────────────────────────────────┐
#   │  Título               [BADGE]  │  ← Header com StatBadge opcional
#   │  Subtítulo                      │  ← Texto secundário
#   │  ─────────────────────────────  │  ← Separador
#   │  [Conteúdo Customizado]         │  ← Slot (gráfico, texto, ícones)
#   └─────────────────────────────────┘
# ==============================================================================

var _vbox: VBoxContainer
var _header: HBoxContainer
var _title_label: Label
var _subtitle_label: Label
var _content_container: VBoxContainer

func _init(title: String = "", subtitle: String = "", accent_color: Color = ThemeConstants.BORDER_DEFAULT) -> void:
	custom_minimum_size = Vector2(340, 140)
	add_theme_stylebox_override("panel", StyleFactory.card_with_accent(accent_color))
	
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	add_child(_vbox)
	
	# Header: Título + Badge (lado a lado)
	_header = HBoxContainer.new()
	_vbox.add_child(_header)
	
	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H2)
	_title_label.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title_label)
	
	# Subtítulo
	if not subtitle.is_empty():
		_subtitle_label = Label.new()
		_subtitle_label.text = subtitle
		_subtitle_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
		_subtitle_label.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
		_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_vbox.add_child(_subtitle_label)
	
	# Separador sutil
	var sep := HSeparator.new()
	_vbox.add_child(sep)
	
	# Container para conteúdo customizado (slot)
	_content_container = VBoxContainer.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("separation", ThemeConstants.SPACING_XS)
	_vbox.add_child(_content_container)

func add_badge(badge: StatBadge) -> void:
	_header.add_child(badge)

func get_content_container() -> VBoxContainer:
	return _content_container

func set_title(text: String) -> void:
	_title_label.text = text

func add_content_label(text: String, color: Color = ThemeConstants.TEXT_SECONDARY, font_size: int = ThemeConstants.FONT_SIZE_BODY) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content_container.add_child(lbl)
	return lbl

func add_content_node(node: Control) -> void:
	_content_container.add_child(node)
