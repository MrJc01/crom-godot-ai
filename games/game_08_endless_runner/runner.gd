extends Node2D

var dino_pos: Vector2 = Vector2(150, 500)
var dino_vel_y: float = 0.0
var is_grounded: bool = true
var obstacles: Array[Dictionary] = []
var obs_timer: float = 0.0
var score: float = 0.0
var score_label: Label
var dino_rect: ColorRect

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.9, 0.95, 1.0)
	add_child(bg)
	
	var ground = ColorRect.new()
	ground.position = Vector2(0, 540)
	ground.size = Vector2(1152, 108)
	ground.color = Color(0.4, 0.3, 0.2)
	add_child(ground)
	
	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	add_child(score_label)
	
	dino_rect = ColorRect.new()
	dino_rect.size = Vector2(40, 60)
	dino_rect.color = Color(0.2, 0.7, 0.3)
	add_child(dino_rect)

func _process(delta: float) -> void:
	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and is_grounded:
		dino_vel_y = -650.0
		is_grounded = false
	dino_vel_y += 1800.0 * delta
	dino_pos.y += dino_vel_y * delta
	if dino_pos.y >= 480:
		dino_pos.y = 480
		dino_vel_y = 0.0
		is_grounded = true
	dino_rect.position = dino_pos
	
	obs_timer += delta
	if obs_timer >= 1.5:
		obs_timer = 0.0
		var r = ColorRect.new()
		r.size = Vector2(30, 50)
		r.color = Color(0.8, 0.2, 0.2)
		add_child(r)
		obstacles.append({"pos": Vector2(1200, 490), "node": r})
		
	for i in range(obstacles.size() - 1, -1, -1):
		obstacles[i].pos.x -= 400 * delta
		if is_instance_valid(obstacles[i].node): obstacles[i].node.position = obstacles[i].pos
		if obstacles[i].pos.x < -100:
			if is_instance_valid(obstacles[i].node): obstacles[i].node.queue_free()
			obstacles.remove_at(i)
	score += delta * 15.0
	score_label.text = "Distância: %dm" % int(score)
