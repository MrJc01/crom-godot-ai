class_name SidebarPanel
extends PanelContainer

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const GameRegistry = preload("res://addons/crom_ai/core/game_registry.gd")
const GameListButton = preload("res://addons/crom_ai/ui/components/game_list_button.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Sidebar Panel — Barra lateral contextual (250px)
# Muda o conteúdo baseado na página ativa.
# ==============================================================================

signal sidebar_action(action: String, data: Variant)

var _title_label: Label
var _scroll: ScrollContainer
var _content_box: VBoxContainer

func _init() -> void:
	custom_minimum_size = Vector2(ThemeConstants.SIDEBAR_WIDTH, 0)
	add_theme_stylebox_override("panel", StyleFactory.zone_sidebar())

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)
	
	# Cabeçalho
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0, ThemeConstants.TAB_BAR_HEIGHT)
	StyleFactory.apply_to(header, StyleFactory.panel(ThemeConstants.BG_SIDEBAR))
	vbox.add_child(header)
	
	_title_label = Label.new()
	_title_label.text = "EXPLORER"
	_title_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	_title_label.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	_title_label.position = Vector2(ThemeConstants.SPACING_MD, 10)
	header.add_child(_title_label)
	
	# Área com scroll
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)
	
	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	_scroll.add_child(_content_box)

func set_page(page_id: String) -> void:
	_clear_content()
	
	match page_id:
		"home":
			_title_label.text = "EXPLORER: INÍCIO"
			_build_home_sidebar()
		"projects":
			_title_label.text = "EXPLORER: PROJETOS"
			_build_projects_sidebar()
		"playtest":
			_title_label.text = "COMPONENTS: JOGOS"
			_build_playtest_sidebar()
		"settings":
			_title_label.text = "CONFIG: AGENTE & MCP"
			_build_settings_sidebar()
		"benchmark":
			_title_label.text = "BENCHMARK: STRESS TEST"
			_build_benchmark_sidebar()

func _clear_content() -> void:
	for c in _content_box.get_children():
		c.queue_free()

func _build_home_sidebar() -> void:
	_add_info_card("Resumo", "Gerencie seus projetos, teste com IA e crie jogos do zero.", "lightbulb")
	_add_info_card("Atalhos", " · F5: Executar projeto\n · godot -e: Abre IDE\n · /clean: Zera jogos\n · /benchmark: Audit", "terminal")
	_add_info_card("Sistema", "Godot 4.6 Forward+\nPlugins: 100% Ativados", "cpu")

func _build_projects_sidebar() -> void:
	var btn_new := Button.new()
	btn_new.text = " Criar Novo Projeto"
	btn_new.icon = IconProvider.get_icon("plus", 14, ThemeConstants.TEXT_PRIMARY)
	btn_new.custom_minimum_size = Vector2(0, 36)
	btn_new.pressed.connect(func(): sidebar_action.emit("create_project", null))
	_content_box.add_child(btn_new)
	
	_add_info_card("Dica", "Novos projetos já vêm com o Agente IA e Chat lateral 100% configurados.", "zap")

func _build_playtest_sidebar() -> void:
	for g in GameRegistry.get_all():
		var btn := GameListButton.new(g)
		btn.game_selected.connect(func(info): sidebar_action.emit("load_game", info))
		_content_box.add_child(btn)

func _build_settings_sidebar() -> void:
	_add_info_card("Segurança", "Chaves armazenadas localmente no projeto.", "shield_check")
	_add_info_card("WebSocket", "Porta 8080 para agentes externos.", "wifi")

func _build_benchmark_sidebar() -> void:
	_add_info_card("Modo Stress Test", "Cria um projeto limpo e roda o Agente em loop gerando todos os 15 jogos do zero.", "wrench")
	var btn_run := Button.new()
	btn_run.text = " Iniciar Benchmark"
	btn_run.icon = IconProvider.get_icon("rocket", 14, ThemeConstants.TEXT_PRIMARY)
	btn_run.custom_minimum_size = Vector2(0, 40)
	btn_run.pressed.connect(func(): sidebar_action.emit("run_benchmark", null))
	_content_box.add_child(btn_run)

func _add_info_card(title: String, description: String, icon_name: String = "") -> void:
	var card := PanelContainer.new()
	StyleFactory.apply_to(card, StyleFactory.card())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ThemeConstants.SPACING_XS)
	card.add_child(box)
	
	var title_box := HBoxContainer.new()
	title_box.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	if not icon_name.is_empty():
		title_box.add_child(IconProvider.icon_rect(icon_name, 14, ThemeConstants.TEXT_PRIMARY))
	
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	t.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	title_box.add_child(t)
	box.add_child(title_box)
	
	var d := Label.new()
	d.text = description
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_TINY)
	d.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	box.add_child(d)
	
	_content_box.add_child(card)

