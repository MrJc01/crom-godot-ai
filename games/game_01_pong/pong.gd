extends Node2D

# ==============================================================================
# Game 01: Pong Clássico (100% Procedural / Primitivas de Código)
# ==============================================================================

var ball_pos: Vector2 = Vector2(576, 324)
var ball_vel: Vector2 = Vector2(400, 300)
var p1_pos: Vector2 = Vector2(50, 324)
var p2_pos: Vector2 = Vector2(1102, 324)

var paddle_size: Vector2 = Vector2(20, 120)
var ball_size: Vector2 = Vector2(16, 16)
var p1_score: int = 0
var p2_score: int = 0

var score_label: Label
var p1_rect: ColorRect
var p2_rect: ColorRect
var ball_rect: ColorRect

func _ready() -> void:
	# Fundo
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)
	
	# Linha central
	for y in range(0, 648, 40):
		var line = ColorRect.new()
		line.size = Vector2(4, 20)
		line.position = Vector2(574, y)
		line.color = Color(0.3, 0.3, 0.4, 0.5)
		add_child(line)
		
	# Raquete 1
	p1_rect = ColorRect.new()
	p1_rect.size = paddle_size
	p1_rect.color = Color(0.3, 0.8, 1.0)
	add_child(p1_rect)
	
	# Raquete 2
	p2_rect = ColorRect.new()
	p2_rect.size = paddle_size
	p2_rect.color = Color(1.0, 0.4, 0.4)
	add_child(p2_rect)
	
	# Bola
	ball_rect = ColorRect.new()
	ball_rect.size = ball_size
	ball_rect.color = Color(1.0, 1.0, 0.3)
	add_child(ball_rect)
	
	# Placar
	score_label = Label.new()
	score_label.position = Vector2(476, 20)
	score_label.size = Vector2(200, 60)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 42)
	add_child(score_label)
	_update_ui()

func _process(delta: float) -> void:
	# Controle do Jogador (P1)
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		p1_pos.y -= 450 * delta
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		p1_pos.y += 450 * delta
	p1_pos.y = clamp(p1_pos.y, paddle_size.y/2, 648 - paddle_size.y/2)
	
	# IA simples (P2)
	var p2_speed = 380.0
	if p2_pos.y < ball_pos.y - 15:
		p2_pos.y += p2_speed * delta
	elif p2_pos.y > ball_pos.y + 15:
		p2_pos.y -= p2_speed * delta
	p2_pos.y = clamp(p2_pos.y, paddle_size.y/2, 648 - paddle_size.y/2)
	
	# Movimento da bola
	ball_pos += ball_vel * delta
	
	# Rebote topo/fundo
	if ball_pos.y <= 0 or ball_pos.y >= 648 - ball_size.y:
		ball_vel.y *= -1
		ball_pos.y = clamp(ball_pos.y, 1, 647 - ball_size.y)
		
	# Colisão com raquetes
	var b_rect = Rect2(ball_pos, ball_size)
	var r1 = Rect2(p1_pos - paddle_size/2, paddle_size)
	var r2 = Rect2(p2_pos - paddle_size/2, paddle_size)
	
	if b_rect.intersects(r1) and ball_vel.x < 0:
		ball_vel.x *= -1.08 # Acelera ligeiramente
		var hit_offset = (ball_pos.y - p1_pos.y) / (paddle_size.y / 2)
		ball_vel.y = hit_offset * 350.0
		
	elif b_rect.intersects(r2) and ball_vel.x > 0:
		ball_vel.x *= -1.08
		var hit_offset = (ball_pos.y - p2_pos.y) / (paddle_size.y / 2)
		ball_vel.y = hit_offset * 350.0
		
	# Gols
	if ball_pos.x < -50:
		p2_score += 1
		_reset_ball()
	elif ball_pos.x > 1200:
		p1_score += 1
		_reset_ball()
		
	# Atualiza visuais
	p1_rect.position = p1_pos - paddle_size/2
	p2_rect.position = p2_pos - paddle_size/2
	ball_rect.position = ball_pos

func _reset_ball() -> void:
	ball_pos = Vector2(576, 324)
	ball_vel = Vector2(-400 if randf() > 0.5 else 400, randf_range(-200, 200))
	_update_ui()

func _update_ui() -> void:
	score_label.text = "%d   :   %d" % [p1_score, p2_score]
