class_name PlaytestReport
extends PanelContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const StatBadge = preload("res://addons/crom_ai/ui/components/stat_badge.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Playtest Report — Exibe o relatório da IA após jogar (screenshots + análise)
# ==============================================================================

var _vbox: VBoxContainer
var _analysis_label: RichTextLabel

func _init(report: Dictionary = {}) -> void:
	add_theme_stylebox_override("panel", StyleFactory.card_with_accent(ThemeConstants.ACCENT_TEAL))
	
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	add_child(_vbox)
	
	if not report.is_empty():
		populate(report)

func populate(report: Dictionary) -> void:
	# Limpar conteúdo anterior
	for c in _vbox.get_children():
		c.queue_free()
	
	# Header
	var header := HBoxContainer.new()
	_vbox.add_child(header)
	
	var title_box := HBoxContainer.new()
	title_box.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	title_box.add_child(IconProvider.icon_rect("gamepad", 20, ThemeConstants.ACCENT_TEAL))
	
	var title := Label.new()
	title.text = "Relatório de Playtest: %s" % report.get("game_name", "Jogo")
	title.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H3)
	title.add_theme_color_override("font_color", ThemeConstants.ACCENT_TEAL)
	title_box.add_child(title)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	
	var badge := StatBadge.new(report.get("game_type", "2D"), ThemeConstants.BADGE_INFO_BG, ThemeConstants.BADGE_INFO_FG)
	header.add_child(badge)
	
	# Timestamps
	var time_lbl := Label.new()
	time_lbl.text = "Iniciado: %s" % report.get("started_at", "--")
	time_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_TINY)
	time_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	_vbox.add_child(time_lbl)
	
	_vbox.add_child(HSeparator.new())
	
	# Screenshots count
	var screenshots: Array = report.get("screenshots", [])
	var ss_row := HBoxContainer.new()
	ss_row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	ss_row.add_child(IconProvider.icon_rect("camera", 16, ThemeConstants.TEXT_SECONDARY))
	
	var ss_lbl := Label.new()
	ss_lbl.text = "%d screenshots capturados" % screenshots.size()
	ss_lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	ss_lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	ss_row.add_child(ss_lbl)
	_vbox.add_child(ss_row)
	
	# Análise do Agente
	var analysis_text: String = report.get("agent_analysis", "Aguardando análise do agente...")
	_analysis_label = RichTextLabel.new()
	_analysis_label.custom_minimum_size = Vector2(0, 80)
	_analysis_label.add_theme_font_size_override("normal_font_size", ThemeConstants.FONT_SIZE_BODY)
	_analysis_label.append_text(analysis_text)
	_analysis_label.scroll_following = true
	_vbox.add_child(_analysis_label)

func update_analysis(text: String) -> void:
	if _analysis_label:
		_analysis_label.clear()
		_analysis_label.append_text(text)

