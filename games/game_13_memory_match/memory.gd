extends Node2D

var cards: Array[Dictionary] = []
var flipped_idx: int = -1
var score: int = 0
var score_label: Label

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.12, 0.14, 0.2)
	add_child(bg)
	
	score_label = Label.new()
	score_label.position = Vector2(30, 30)
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.text = "Pares Encontrados: 0"
	add_child(score_label)
