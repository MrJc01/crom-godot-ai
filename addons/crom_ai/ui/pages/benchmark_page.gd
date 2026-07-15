class_name BenchmarkPage
extends Control

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const DashboardCard = preload("res://addons/crom_ai/ui/components/dashboard_card.gd")
const GameRegistry = preload("res://addons/crom_ai/core/game_registry.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Benchmark Page — Modo Stress Test: IA cria todos os jogos do zero em loop
# Esta página é SECUNDÁRIA. Só roda quando o usuário pede explicitamente.
# ==============================================================================

signal log_requested(msg: String)

var _status_label: Label
var _progress: ProgressBar

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
	
	# Card explicativo
	var card := DashboardCard.new(
		"Benchmark — Stress Test Automatizado",
		"Modo onde o Agente IA cria todos os 15 jogos do zero em um projeto limpo, testando a capacidade completa do sistema.",
		ThemeConstants.ACCENT_ORANGE
	)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.add_child(card)
	
	card.add_content_label("O que acontece:", ThemeConstants.TEXT_PRIMARY, ThemeConstants.FONT_SIZE_H3)
	card.add_content_label("1. Cria um projeto Godot limpo automaticamente", ThemeConstants.TEXT_SECONDARY)
	card.add_content_label("2. Roda o Agente em loop para cada um dos 15 jogos", ThemeConstants.TEXT_SECONDARY)
	card.add_content_label("3. Cada jogo é gerado do zero (código, cena, assets)", ThemeConstants.TEXT_SECONDARY)
	card.add_content_label("4. Após criação, faz playtest automático e registra prints", ThemeConstants.TEXT_SECONDARY)
	card.add_content_label("5. Gera relatório final de quantos funcionaram", ThemeConstants.TEXT_SECONDARY)
	
	# Progresso
	var progress_card := DashboardCard.new(
		"Progresso do Benchmark",
		"Clique em 'Iniciar' na sidebar para começar.",
		ThemeConstants.BORDER_DEFAULT
	)
	progress_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.add_child(progress_card)
	
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 24)
	_progress.min_value = 0
	_progress.max_value = GameRegistry.get_total_count()
	_progress.value = 0
	_progress.show_percentage = true
	progress_card.add_content_node(_progress)
	
	_status_label = Label.new()
	_status_label.text = "Aguardando início..."
	_status_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	_status_label.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	progress_card.add_content_node(_status_label)

func update_progress(completed: int, current_game: String) -> void:
	if _progress:
		_progress.value = completed
	if _status_label:
		_status_label.text = "Gerando: %s (%d/%d)" % [current_game, completed, GameRegistry.get_total_count()]
		_status_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_YELLOW)

func mark_finished(total_ok: int, total_fail: int) -> void:
	if _status_label:
		_status_label.text = "Completo: %d sucesso, %d falhas" % [total_ok, total_fail]
		_status_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GREEN)

