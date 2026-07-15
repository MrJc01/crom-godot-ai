extends Node2D

# ==============================================================================
# Game 03: Flappy Bird Clone (Com Assets SVG)
# ==============================================================================

var bird_pos: Vector2 = Vector2(200, 324)
var bird_vel_y: float = 0.0
const GRAVITY = 1400.0
const JUMP_FORCE = -480.0

var pipes: Array[Dictionary] = [] # { "x": float, "gap_y": float }
var pipe_speed: float = 240.0
var spawn_timer: float = 0.0
var score: int = 0

var bird_sprite: Sprite2D
var pipe_tex: Texture2D
var pipes_container: Node2D
var score_label: Label

func _ready() -> void:
	# Fundo Céu Paralaxe
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.4, 0.75, 0.95)
	add_child(bg)
	
	pipes_container = Node2D.new()
	add_child(pipes_container)
	
	# Carrega texturas
	var bird_tex = load("res://assets/sprites/flappy_bird.svg")
	pipe_tex = load("res://assets/sprites/pipe.svg")
	
	bird_sprite = Sprite2D.new()
	if bird_tex:
		bird_sprite.texture = bird_tex
	add_child(bird_sprite)
	
	score_label = Label.new()
	score_label.position = Vector2(520, 30)
	score_label.add_theme_font_size_override("font_size", 48)
	score_label.text = "0"
	add_child(score_label)
	
	_spawn_pipe()

func _process(delta: float) -> void:
	# Pulo
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		bird_vel_y = JUMP_FORCE
		
	# Gravidade
	bird_vel_y += GRAVITY * delta
	bird_pos.y += bird_vel_y * delta
	bird_sprite.position = bird_pos
	bird_sprite.rotation = clamp(bird_vel_y * 0.002, -0.6, 1.2)
	
	# Checa chão / teto
	if bird_pos.y > 640 or bird_pos.y < 0:
		_reset_game()
		return
		
	# Geração de canos
	spawn_timer += delta
	if spawn_timer >= 2.0:
		spawn_timer = 0.0
		_spawn_pipe()
		
	# Atualiza canos e colisão
	var bird_rect = Rect2(bird_pos - Vector2(22, 22), Vector2(44, 44))
	
	for i in range(pipes.size() - 1, -1, -1):
		pipes[i]["x"] -= pipe_speed * delta
		var px = pipes[i]["x"]
		var gap_y = pipes[i]["gap_y"]
		
		# Colisão cano superior (altura 400, gap 160)
		var top_rect = Rect2(Vector2(px, gap_y - 80 - 400), Vector2(80, 400))
		var bot_rect = Rect2(Vector2(px, gap_y + 80), Vector2(80, 400))
		
		if bird_rect.intersects(top_rect) or bird_rect.intersects(bot_rect):
			_reset_game()
			return
			
		if not pipes[i].get("scored", false) and px < bird_pos.x:
			pipes[i]["scored"] = true
			score += 1
			score_label.text = str(score)
			
		if px < -100:
			pipes.remove_at(i)
			
	_redraw_pipes()

func _spawn_pipe() -> void:
	pipes.append({
		"x": 1200.0,
		"gap_y": randf_range(180.0, 460.0),
		"scored": false
	})

func _redraw_pipes() -> void:
	for c in pipes_container.get_children():
		c.queue_free()
		
	for p in pipes:
		var px = p["x"]
		var gap_y = p["gap_y"]
		
		var top_s = Sprite2D.new()
		if pipe_tex: top_s.texture = pipe_tex
		top_s.position = Vector2(px + 40, gap_y - 80 - 200)
		top_s.flip_v = true
		pipes_container.add_child(top_s)
		
		var bot_s = Sprite2D.new()
		if pipe_tex: bot_s.texture = pipe_tex
		bot_s.position = Vector2(px + 40, gap_y + 80 + 200)
		pipes_container.add_child(bot_s)

func _reset_game() -> void:
	bird_pos = Vector2(200, 324)
	bird_vel_y = 0.0
	pipes.clear()
	score = 0
	score_label.text = "0"
	_spawn_pipe()
