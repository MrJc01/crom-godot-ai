class_name HomePage
extends Control

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")
const ProjectService = preload("res://addons/crom_ai/core/project_service.gd")
const GameRegistry = preload("res://addons/crom_ai/core/game_registry.gd")
const DashboardCard = preload("res://addons/crom_ai/ui/components/dashboard_card.gd")
const StatBadge = preload("res://addons/crom_ai/ui/components/stat_badge.gd")


# ==============================================================================
# Home Page — Dashboard com 4 Cards focados nos dados do usuário
# Usa ícones SVG do IconProvider ao invés de emojis
# ==============================================================================

func _ready() -> void:
	_build_dashboard()

func _build_dashboard() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", ThemeConstants.SPACING_XL)
	scroll.add_child(main_vbox)
	
	# Cabeçalho com ícone SVG
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	main_vbox.add_child(header_box)
	
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	header_box.add_child(title_row)
	
	title_row.add_child(IconProvider.icon_rect("zap", 28, ThemeConstants.ACCENT_BLUE))
	
	var title := Label.new()
	title.text = "Bem-vindo ao CromAI Godot Bridge & Agente ReAct"
	title.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H1)
	title.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	title_row.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "Uma arquitetura limpa e organizada para unificar inteligência artificial multimodal dentro do Godot com zero burocracia manual. Inspirado no VS Code, mas reimaginado como um hub de designer."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	subtitle.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	header_box.add_child(subtitle)
	
	# Grid 2x2 de Dashboard Cards
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ThemeConstants.SPACING_LG)
	grid.add_theme_constant_override("v_separation", ThemeConstants.SPACING_LG)
	main_vbox.add_child(grid)
	
	# Card 1: Meus Projetos
	var projects := ProjectService.list_projects()
	var card_projects := DashboardCard.new(
		"Meus Projetos",
		"Gerencie e acesse seus projetos Godot.",
		ThemeConstants.ACCENT_BLUE
	)
	card_projects.add_badge(StatBadge.info("%d projetos" % projects.size()))
	card_projects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var total_scenes := 0
	var total_scripts := 0
	for p in projects:
		total_scenes += p.get("scenes", 0)
		total_scripts += p.get("scripts", 0)
	
	var proj_row_1 := _icon_label_row("folder", "%d projetos instalados" % projects.size(), ThemeConstants.TEXT_PRIMARY)
	card_projects.add_content_node(proj_row_1)
	var proj_row_2 := _icon_label_row("monitor", "%d cenas  ·  %d scripts" % [total_scenes, total_scripts], ThemeConstants.TEXT_SECONDARY)
	card_projects.add_content_node(proj_row_2)
	if projects.size() > 0:
		card_projects.add_content_label("Último: %s" % projects[0].get("display_name", "--"), ThemeConstants.TEXT_MUTED)
	grid.add_child(card_projects)
	
	# Card 2: Agente ReAct
	var card_agent := DashboardCard.new(
		"Agente ReAct",
		"Motor ReAct: em res://addons/crom_ai",
		ThemeConstants.ACCENT_TEAL
	)
	card_agent.add_badge(StatBadge.active("ATIVO"))
	card_agent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_agent.add_content_node(_icon_label_row("bot", "google/gemini-2.5-flash", ThemeConstants.TEXT_PRIMARY))
	card_agent.add_content_node(_icon_label_row("wifi", "OpenRouter API", ThemeConstants.TEXT_SECONDARY))
	card_agent.add_content_label("Ativado na IDE (Aba lateral 'CromAI Chat')", ThemeConstants.TEXT_MUTED)
	grid.add_child(card_agent)
	
	# Card 3: Jogos Criados
	var available := GameRegistry.get_available_count()
	var total := GameRegistry.get_total_count()
	var card_games := DashboardCard.new(
		"Jogos Criados",
		"%d/%d minijogos gerados pela IA" % [available, total],
		ThemeConstants.ACCENT_GREEN
	)
	card_games.add_badge(StatBadge.new("%d/%d" % [available, total], ThemeConstants.BADGE_ACTIVE_BG, ThemeConstants.ACCENT_GREEN))
	card_games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 16)
	progress_bar.min_value = 0
	progress_bar.max_value = total
	progress_bar.value = available
	progress_bar.show_percentage = false
	card_games.add_content_node(progress_bar)
	
	var types_2d := 0
	var types_3d := 0
	var types_ui := 0
	for g in GameRegistry.get_all():
		match g["type"]:
			"3D": types_3d += 1
			"UI": types_ui += 1
			_: types_2d += 1
	card_games.add_content_node(_icon_label_row("gamepad", "2D: %d  ·  3D: %d  ·  UI: %d" % [types_2d, types_3d, types_ui], ThemeConstants.TEXT_SECONDARY))
	grid.add_child(card_games)
	
	# Card 4: Visão Geral do Sistema
	var card_system := DashboardCard.new(
		"Visão Geral do Sistema",
		"Godot 4.6 | Forward+ | VS Code Dark+",
		ThemeConstants.ACCENT_PURPLE
	)
	card_system.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_system.add_content_node(_icon_label_row("cpu", "Godot %s" % Engine.get_version_info().get("string", "4.6"), ThemeConstants.TEXT_PRIMARY))
	card_system.add_content_node(_icon_label_row("layout", "Renderer: Forward+", ThemeConstants.TEXT_SECONDARY))
	card_system.add_content_node(_icon_label_row("check_circle", "Plugins: CromAI Bridge Ativo", ThemeConstants.ACCENT_GREEN))
	card_system.add_content_node(_icon_label_row("wifi", "WebSocket: Porta 8080", ThemeConstants.TEXT_MUTED))
	grid.add_child(card_system)
	
	# Comandos Rápidos
	main_vbox.add_child(HSeparator.new())
	
	var cmd_row := HBoxContainer.new()
	cmd_row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	main_vbox.add_child(cmd_row)
	cmd_row.add_child(IconProvider.icon_rect("terminal", 16, ThemeConstants.ACCENT_YELLOW))
	var cmd_title := Label.new()
	cmd_title.text = "Comandos Rápidos do Chat Lateral"
	cmd_title.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H3)
	cmd_title.add_theme_color_override("font_color", ThemeConstants.ACCENT_YELLOW)
	cmd_row.add_child(cmd_title)
	
	var cmd_info := Label.new()
	cmd_info.text = " · /clean — Zera e limpa o diretório de jogos gerados\n · /benchmark — Dispara IA para construir, checar código e gerar relatórios\n · F5 / Play — Abre este Hub e reproduz jogos em 60 FPS e 16:9"
	cmd_info.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	cmd_info.add_theme_color_override("font_color", ThemeConstants.TEXT_SECONDARY)
	main_vbox.add_child(cmd_info)

# Helper: cria uma linha HBox com ícone SVG + texto
func _icon_label_row(icon_name: String, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	row.add_child(IconProvider.icon_rect(icon_name, 16, color))
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)
	return row
