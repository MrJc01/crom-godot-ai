extends Node2D

var ball_pos: Vector2 = Vector2(576, 500)
var ball_vel: Vector2 = Vector2(350, -350)
var paddle_pos: Vector2 = Vector2(576, 600)
var paddle_size: Vector2 = Vector2(140, 20)
var score: int = 0
var bricks: Array[ColorRect] = []
var score_label: Label
var paddle_rect: ColorRect
var ball_rect: ColorRect

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.06, 0.06, 0.1)
	add_child(bg)
	
	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.text = "Pontuação: 0"
	add_child(score_label)
	
	paddle_rect = ColorRect.new()
	paddle_rect.size = paddle_size
	paddle_rect.color = Color(0.2, 0.8, 1.0)
	add_child(paddle_rect)
	
	ball_rect = ColorRect.new()
	ball_rect.size = Vector2(16, 16)
	ball_rect.color = Color(1.0, 1.0, 0.2)
	add_child(ball_rect)
	
	_spawn_bricks()

func _spawn_bricks() -> void:
	for c in bricks:
		if is_instance_valid(c): c.queue_free()
	bricks.clear()
	for row in range(5):
		for col in range(10):
			var b = ColorRect.new()
			b.size = Vector2(90, 25)
			b.position = Vector2(100 + col * 96, 80 + row * 35)
			b.color = Color(0.9 - row*0.15, 0.3 + row*0.1, 0.8 - row*0.1)
			add_child(b)
			bricks.append(b)

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		paddle_pos.x -= 550 * delta
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		paddle_pos.x += 550 * delta
	paddle_pos.x = clamp(paddle_pos.x, paddle_size.x/2, 1152 - paddle_size.x/2)
	paddle_rect.position = paddle_pos - paddle_size/2
	
	ball_pos += ball_vel * delta
	if ball_pos.x <= 0 or ball_pos.x >= 1152 - 16:
		ball_vel.x *= -1
		ball_pos.x = clamp(ball_pos.x, 1, 1135)
	if ball_pos.y <= 0:
		ball_vel.y *= -1
	if ball_pos.y >= 648:
		ball_pos = Vector2(576, 500)
		ball_vel = Vector2(350, -350)
		score = max(0, score - 50)
		score_label.text = "Pontuação: %d" % score
		
	var b_rect = Rect2(ball_pos, Vector2(16, 16))
	var p_rect = Rect2(paddle_pos - paddle_size/2, paddle_size)
	if b_rect.intersects(p_rect) and ball_vel.y > 0:
		ball_vel.y *= -1.03
		var offset = (ball_pos.x - paddle_pos.x) / (paddle_size.x / 2)
		ball_vel.x = offset * 450.0
		
	for i in range(bricks.size() - 1, -1, -1):
		var b = bricks[i]
		if is_instance_valid(b) and b_rect.intersects(Rect2(b.position, b.size)):
			b.queue_free()
			bricks.remove_at(i)
			ball_vel.y *= -1
			score += 20
			score_label.text = "Pontuação: %d" % score
			if bricks.size() == 0:
				_spawn_bricks()
			break
	ball_rect.position = ball_pos
