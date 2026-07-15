extends Node2D

var hero_pos: Vector2 = Vector2(100, 400)
var vel_y: float = 0.0
var is_grounded: bool = false
var score: int = 0
var score_label: Label
var hero_sprite: Sprite2D
var platforms: Array[Rect2] = [Rect2(0, 560, 1152, 88), Rect2(300, 420, 200, 30), Rect2(650, 320, 250, 30)]

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.3, 0.6, 0.9)
	add_child(bg)
	
	for p in platforms:
		var r = ColorRect.new()
		r.position = p.position
		r.size = p.size
		r.color = Color(0.2, 0.5, 0.2)
		add_child(r)
		
	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.text = "Moedas: 0"
	add_child(score_label)
	
	var hero_tex = load("res://assets/sprites/hero.svg")
	hero_sprite = Sprite2D.new()
	if hero_tex: hero_sprite.texture = hero_tex
	add_child(hero_sprite)

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"): hero_pos.x -= 300 * delta
	if Input.is_action_pressed("ui_right"): hero_pos.x += 300 * delta
	if Input.is_action_just_pressed("ui_up") and is_grounded:
		vel_y = -680.0
		is_grounded = false
	vel_y += 1600.0 * delta
	hero_pos.y += vel_y * delta
	
	is_grounded = false
	var h_rect = Rect2(hero_pos - Vector2(16, 32), Vector2(32, 64))
	for p in platforms:
		if h_rect.intersects(p) and vel_y >= 0 and hero_pos.y < p.position.y + 20:
			hero_pos.y = p.position.y - 32
			vel_y = 0.0
			is_grounded = true
			break
	hero_sprite.position = hero_pos
