extends Node2D

# ==============================================================================
# Game 02: Snake Grid (100% Procedural / Código Puro)
# ==============================================================================

const GRID_W = 36
const GRID_H = 20
const CELL_SIZE = 32

var snake: Array[Vector2i] = [Vector2i(18, 10), Vector2i(17, 10), Vector2i(16, 10)]
var direction: Vector2i = Vector2i(1, 0)
var next_direction: Vector2i = Vector2i(1, 0)
var apple: Vector2i = Vector2i(25, 10)
var score: int = 0

var move_timer: float = 0.0
var move_interval: float = 0.12 # Velocidade inicial

var score_label: Label
var cells_container: Node2D

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(GRID_W * CELL_SIZE, GRID_H * CELL_SIZE)
	bg.color = Color(0.06, 0.08, 0.06)
	add_child(bg)
	
	cells_container = Node2D.new()
	add_child(cells_container)
	
	score_label = Label.new()
	score_label.position = Vector2(20, 10)
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.text = "Pontuação: 0"
	add_child(score_label)
	
	_spawn_apple()
	_redraw_grid()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_up") and direction != Vector2i(0, 1):
		next_direction = Vector2i(0, -1)
	elif Input.is_action_just_pressed("ui_down") and direction != Vector2i(0, -1):
		next_direction = Vector2i(0, 1)
	elif Input.is_action_just_pressed("ui_left") and direction != Vector2i(1, 0):
		next_direction = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("ui_right") and direction != Vector2i(-1, 0):
		next_direction = Vector2i(1, 0)
		
	move_timer += delta
	if move_timer >= move_interval:
		move_timer = 0.0
		_step_snake()

func _step_snake() -> void:
	direction = next_direction
	var head = snake[0] + direction
	
	# Wrap de bordas
	if head.x < 0: head.x = GRID_W - 1
	elif head.x >= GRID_W: head.x = 0
	if head.y < 0: head.y = GRID_H - 1
	elif head.y >= GRID_H: head.y = 0
	
	# Colisão com o próprio corpo
	if head in snake:
		_game_over()
		return
		
	snake.insert(0, head)
	
	if head == apple:
		score += 10
		score_label.text = "Pontuação: %d" % score
		move_interval = max(0.05, move_interval - 0.003) # Acelera
		_spawn_apple()
	else:
		snake.pop_back()
		
	_redraw_grid()

func _spawn_apple() -> void:
	apple = Vector2i(randi_range(0, GRID_W - 1), randi_range(0, GRID_H - 1))
	while apple in snake:
		apple = Vector2i(randi_range(0, GRID_W - 1), randi_range(0, GRID_H - 1))

func _game_over() -> void:
	score = 0
	move_interval = 0.12
	snake = [Vector2i(18, 10), Vector2i(17, 10), Vector2i(16, 10)]
	direction = Vector2i(1, 0)
	next_direction = Vector2i(1, 0)
	score_label.text = "Pontuação: 0 (Game Over)"
	_spawn_apple()

func _redraw_grid() -> void:
	for c in cells_container.get_children():
		c.queue_free()
		
	# Desenha maçã
	var apple_rect = ColorRect.new()
	apple_rect.position = Vector2(apple.x * CELL_SIZE + 2, apple.y * CELL_SIZE + 2)
	apple_rect.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
	apple_rect.color = Color(1.0, 0.2, 0.3)
	cells_container.add_child(apple_rect)
	
	# Desenha cobra
	for i in range(snake.size()):
		var pt = snake[i]
		var part = ColorRect.new()
		part.position = Vector2(pt.x * CELL_SIZE + 1, pt.y * CELL_SIZE + 1)
		part.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
		part.color = Color(0.2, 0.9, 0.4) if i == 0 else Color(0.1, 0.6, 0.2)
		cells_container.add_child(part)
