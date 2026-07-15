class_name PlaytestPage
extends Control

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const PlaytestService = preload("res://addons/crom_ai/core/playtest_service.gd")
const PlaytestReport = preload("res://addons/crom_ai/ui/components/playtest_report.gd")

# ==============================================================================
# Playtest Page — Selecionar jogo, rodar no Canvas 16:9, IA joga e gera artefato
# ==============================================================================

signal log_requested(msg: String)

var viewport_sub: SubViewport
var game_display: TextureRect
var active_game_node: Node
var active_game_info: Dictionary = {}

var _playtest_svc: PlaytestService
var _report_container: VBoxContainer

func _ready() -> void:
	_build_layout()

func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	add_child(vbox)
	
	# SubViewport onde os jogos rodam (16:9)
	viewport_sub = SubViewport.new()
	viewport_sub.size = Vector2i(1152, 648)
	viewport_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_sub.handle_input_locally = false
	add_child(viewport_sub)
	
	game_display = TextureRect.new()
	game_display.texture = viewport_sub.get_texture()
	game_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(game_display)
	
	# Container para relatório do playtest
	_report_container = VBoxContainer.new()
	_report_container.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(_report_container)

func load_game(game_info: Dictionary) -> void:
	active_game_info = game_info
	if active_game_node:
		active_game_node.queue_free()
		active_game_node = null
	
	log_requested.emit("Carregando no Canvas: [b]%s[/b]" % game_info["name"])
	var res := load(game_info["tscn"]) as PackedScene
	if res:
		active_game_node = res.instantiate()
		viewport_sub.add_child(active_game_node)
	else:
		log_requested.emit("Erro ao carregar: %s" % game_info["tscn"])

func get_active_game_info() -> Dictionary:
	return active_game_info

func get_playtest_viewport() -> SubViewport:
	return viewport_sub

func show_playtest_report(report: Dictionary) -> void:
	for c in _report_container.get_children():
		c.queue_free()
	var report_widget := PlaytestReport.new(report)
	_report_container.add_child(report_widget)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if viewport_sub and is_instance_valid(viewport_sub):
		if event is InputEventKey:
			viewport_sub.push_input(event)
		elif event is InputEventMouseButton or event is InputEventMouseMotion:
			viewport_sub.push_input(event)

