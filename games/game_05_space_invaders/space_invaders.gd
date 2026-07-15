extends Node2D

var hero_pos: Vector2 = Vector2(576, 580)
var bullets: Array[Dictionary] = []
var invaders: Array[Dictionary] = []
var invader_dir: float = 1.0
var score: int = 0
var score_label: Label
var hero_sprite: Sprite2D
var invader_tex: Texture2D

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.05, 0.05, 0.08)
	add_child(bg)
	
	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.text = "Score: 0"
	add_child(score_label)
	
	invader_tex = load("res://assets/sprites/invader.svg")
	var hero_tex = load("res://assets/sprites/hero.svg")
	hero_sprite = Sprite2D.new()
	if hero_tex: hero_sprite.texture = hero_tex
	add_child(hero_sprite)
	_spawn_invaders()

func _spawn_invaders() -> void:
	for inv in invaders:
		if is_instance_valid(inv.sprite): inv.sprite.queue_free()
	invaders.clear()
	for row in range(4):
		for col in range(8):
			var s = Sprite2D.new()
			if invader_tex: s.texture = invader_tex
			add_child(s)
			invaders.append({"pos": Vector2(200 + col * 80, 100 + row * 60), "sprite": s})

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"): hero_pos.x -= 400 * delta
	if Input.is_action_pressed("ui_right"): hero_pos.x += 400 * delta
	hero_pos.x = clamp(hero_pos.x, 40, 1112)
	hero_sprite.position = hero_pos
	
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var b_rect = ColorRect.new()
		b_rect.size = Vector2(6, 16)
		b_rect.color = Color(1.0, 0.3, 0.3)
		add_child(b_rect)
		bullets.append({"pos": hero_pos - Vector2(3, 20), "node": b_rect})
		
	for i in range(bullets.size() - 1, -1, -1):
		bullets[i].pos.y -= 600 * delta
		if is_instance_valid(bullets[i].node):
			bullets[i].node.position = bullets[i].pos
		if bullets[i].pos.y < 0:
			if is_instance_valid(bullets[i].node): bullets[i].node.queue_free()
			bullets.remove_at(i)
			continue
			
		var b_box = Rect2(bullets[i].pos, Vector2(6, 16))
		for j in range(invaders.size() - 1, -1, -1):
			var inv = invaders[j]
			if b_box.intersects(Rect2(inv.pos - Vector2(24, 24), Vector2(48, 48))):
				if is_instance_valid(inv.sprite): inv.sprite.queue_free()
				invaders.remove_at(j)
				if is_instance_valid(bullets[i].node): bullets[i].node.queue_free()
				bullets.remove_at(i)
				score += 50
				score_label.text = "Score: %d" % score
				if invaders.size() == 0: _spawn_invaders()
				break
				
	var hit_edge = false
	for inv in invaders:
		inv.pos.x += 120 * invader_dir * delta
		if inv.pos.x > 1100 or inv.pos.x < 50: hit_edge = true
		if is_instance_valid(inv.sprite): inv.sprite.position = inv.pos
	if hit_edge:
		invader_dir *= -1.0
		for inv in invaders: inv.pos.y += 25
