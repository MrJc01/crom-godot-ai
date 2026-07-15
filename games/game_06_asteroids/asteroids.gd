extends Node2D

var ship_pos: Vector2 = Vector2(576, 324)
var ship_vel: Vector2 = Vector2.ZERO
var ship_angle: float = 0.0
var score: int = 0
var score_label: Label
var ship_poly: Polygon2D
var asteroids: Array[Dictionary] = []

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.04, 0.04, 0.06)
	add_child(bg)
	
	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.text = "Asteroids: 0"
	add_child(score_label)
	
	ship_poly = Polygon2D.new()
	ship_poly.polygon = PackedVector2Array([Vector2(20, 0), Vector2(-15, -12), Vector2(-8, 0), Vector2(-15, 12)])
	ship_poly.color = Color(0.4, 0.9, 1.0)
	add_child(ship_poly)
	_spawn_asteroids(6)

func _spawn_asteroids(count: int) -> void:
	for i in range(count):
		var poly = Polygon2D.new()
		var pts: PackedVector2Array = []
		for a in range(8):
			var rad = float(a) / 8.0 * TAU
			var r = randf_range(20.0, 40.0)
			pts.append(Vector2(cos(rad)*r, sin(rad)*r))
		poly.polygon = pts
		poly.color = Color(0.6, 0.6, 0.65)
		add_child(poly)
		asteroids.append({"pos": Vector2(randf_range(50, 1100), randf_range(50, 600)), "vel": Vector2(randf_range(-100, 100), randf_range(-100, 100)), "node": poly})

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"): ship_angle -= 4.0 * delta
	if Input.is_action_pressed("ui_right"): ship_angle += 4.0 * delta
	if Input.is_action_pressed("ui_up"):
		ship_vel += Vector2(cos(ship_angle), sin(ship_angle)) * 300 * delta
	ship_pos += ship_vel * delta
	ship_vel *= 0.99
	
	if ship_pos.x < 0: ship_pos.x += 1152
	elif ship_pos.x >= 1152: ship_pos.x -= 1152
	if ship_pos.y < 0: ship_pos.y += 648
	elif ship_pos.y >= 648: ship_pos.y -= 648
	
	ship_poly.position = ship_pos
	ship_poly.rotation = ship_angle
	
	for ast in asteroids:
		ast.pos += ast.vel * delta
		if ast.pos.x < 0: ast.pos.x += 1152
		elif ast.pos.x >= 1152: ast.pos.x -= 1152
		if ast.pos.y < 0: ast.pos.y += 648
		elif ast.pos.y >= 648: ast.pos.y -= 648
		if is_instance_valid(ast.node): ast.node.position = ast.pos
