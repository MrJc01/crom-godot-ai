extends Node2D

var hero_pos: Vector2 = Vector2(576, 324)
var coins: Array[Dictionary] = []
var score: int = 0
var score_label: Label
var hero_sprite: Sprite2D

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.15, 0.12, 0.1)
	add_child(bg)
	
	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.text = "Ouro: 0"
	add_child(score_label)
	
	var hero_tex = load("res://assets/sprites/hero.svg")
	hero_sprite = Sprite2D.new()
	if hero_tex: hero_sprite.texture = hero_tex
	add_child(hero_sprite)
	
	var coin_tex = load("res://assets/sprites/coin.svg")
	for i in range(8):
		var s = Sprite2D.new()
		if coin_tex: s.texture = coin_tex
		add_child(s)
		coins.append({"pos": Vector2(randf_range(100, 1050), randf_range(100, 550)), "node": s})

func _process(delta: float) -> void:
	var move = Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W): move.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S): move.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A): move.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D): move.x += 1
	
	hero_pos += move.normalized() * 320 * delta
	hero_sprite.position = hero_pos
	
	var h_rect = Rect2(hero_pos - Vector2(24, 24), Vector2(48, 48))
	for i in range(coins.size() - 1, -1, -1):
		var c = coins[i]
		if is_instance_valid(c.node): c.node.position = c.pos
		if h_rect.intersects(Rect2(c.pos - Vector2(24, 24), Vector2(48, 48))):
			if is_instance_valid(c.node): c.node.queue_free()
			coins.remove_at(i)
			score += 10
			score_label.text = "Ouro: %d" % score
