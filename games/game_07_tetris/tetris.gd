extends Node2D

const GRID_W = 10
const GRID_H = 20
const CELL = 30
var grid: Array = []
var score: int = 0
var score_label: Label
var container: Node2D
var cur_piece: Array = [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]
var cur_pos: Vector2i = Vector2i(4, 0)
var cur_color: Color = Color(0.9, 0.8, 0.2)
var timer: float = 0.0

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	
	var grid_bg = ColorRect.new()
	grid_bg.position = Vector2(426, 24)
	grid_bg.size = Vector2(GRID_W * CELL, GRID_H * CELL)
	grid_bg.color = Color(0.03, 0.03, 0.05)
	add_child(grid_bg)
	
	container = Node2D.new()
	container.position = Vector2(426, 24)
	add_child(container)
	
	score_label = Label.new()
	score_label.position = Vector2(50, 50)
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.text = "Crom-Blocks: 0"
	add_child(score_label)
	
	for y in range(GRID_H):
		var row = []
		for x in range(GRID_W): row.append(null)
		grid.append(row)
	_spawn_piece()

func _spawn_piece() -> void:
	cur_pos = Vector2i(4, 0)
	var shapes = [
		[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
		[Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
		[Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(0,1)]
	]
	cur_piece = shapes[randi() % shapes.size()]
	cur_color = Color(randf(), randf(), randf())

func _process(delta: float) -> void:
	timer += delta
	if timer >= 0.5:
		timer = 0.0
		_move_piece(0, 1)

func _move_piece(dx: int, dy: int) -> void:
	cur_pos.x += dx
	cur_pos.y += dy
	_redraw()

func _redraw() -> void:
	for c in container.get_children(): c.queue_free()
	for pt in cur_piece:
		var r = ColorRect.new()
		r.position = Vector2((cur_pos.x + pt.x) * CELL + 1, (cur_pos.y + pt.y) * CELL + 1)
		r.size = Vector2(CELL - 2, CELL - 2)
		r.color = cur_color
		container.add_child(r)
