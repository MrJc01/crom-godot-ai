extends Control

var player_pos: Vector2 = Vector2(3.5, 3.5)
var player_angle: float = 0.0
var world_map: Array = [
	[1,1,1,1,1,1,1,1],
	[1,0,0,0,0,0,0,1],
	[1,0,1,0,0,1,0,1],
	[1,0,0,0,0,0,0,1],
	[1,0,0,1,1,0,0,1],
	[1,0,0,0,0,0,0,1],
	[1,1,1,1,1,1,1,1]
]
var slices: Array[ColorRect] = []

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.15, 0.15, 0.15)
	add_child(bg)
	for i in range(144):
		var r = ColorRect.new()
		r.position = Vector2(i * 8, 324)
		r.size = Vector2(8, 100)
		add_child(r)
		slices.append(r)

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"): player_angle -= 3.0 * delta
	if Input.is_action_pressed("ui_right"): player_angle += 3.0 * delta
	if Input.is_action_pressed("ui_up"):
		player_pos += Vector2(cos(player_angle), sin(player_angle)) * 2.0 * delta
	for i in range(slices.size()):
		var ray_angle = player_angle + (float(i) / 144.0 - 0.5) * 1.04 # 60 graus FOV
		var dist = 0.1
		var ray_dir = Vector2(cos(ray_angle), sin(ray_angle))
		while dist < 12.0:
			var test_p = player_pos + ray_dir * dist
			var tx = int(test_p.x)
			var ty = int(test_p.y)
			if tx < 0 or tx >= 8 or ty < 0 or ty >= 7 or world_map[ty][tx] > 0:
				break
			dist += 0.1
		var wall_h = clamp(400.0 / dist, 10.0, 640.0)
		slices[i].position.y = 324 - wall_h / 2.0
		slices[i].size.y = wall_h
		var shade = clamp(1.0 - dist / 10.0, 0.1, 1.0)
		slices[i].color = Color(shade, shade * 0.8, shade * 0.6)
