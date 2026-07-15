extends Node2D

var enemies: Array[Dictionary] = []
var towers: Array[Vector2] = [Vector2(350, 250), Vector2(750, 350)]
var gold: int = 100
var score_label: Label
var path_points: Array[Vector2] = [Vector2(0, 300), Vector2(400, 300), Vector2(400, 450), Vector2(800, 450), Vector2(800, 200), Vector2(1152, 200)]

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.2, 0.35, 0.2)
	add_child(bg)
	
	for i in range(path_points.size() - 1):
		var line = Line2D.new()
		line.add_point(path_points[i])
		line.add_point(path_points[i+1])
		line.width = 40.0
		line.default_color = Color(0.6, 0.5, 0.3)
		add_child(line)
		
	for t in towers:
		var r = ColorRect.new()
		r.size = Vector2(36, 36)
		r.position = t - Vector2(18, 18)
		r.color = Color(0.2, 0.4, 0.9)
		add_child(r)
		
	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.text = "Ouro: %d" % gold
	add_child(score_label)
