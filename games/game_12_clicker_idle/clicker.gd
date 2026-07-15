extends Node2D

var coins: float = 0.0
var cps: float = 1.0
var coin_label: Label
var cps_label: Label

func _ready() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.1, 0.1, 0.15)
	add_child(bg)
	
	coin_label = Label.new()
	coin_label.position = Vector2(300, 150)
	coin_label.size = Vector2(552, 80)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_label.add_theme_font_size_override("font_size", 56)
	coin_label.text = "$ 0"
	add_child(coin_label)
	
	cps_label = Label.new()
	cps_label.position = Vector2(300, 240)
	cps_label.size = Vector2(552, 40)
	cps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cps_label.add_theme_font_size_override("font_size", 28)
	cps_label.text = "+ 1.0 por segundo"
	add_child(cps_label)
	
	var btn = Button.new()
	btn.position = Vector2(450, 330)
	btn.size = Vector2(252, 120)
	btn.text = "CLIQUE PARA GERAR ($)"
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func():
		coins += 10
		coin_label.text = "$ %d" % int(coins)
	)
	add_child(btn)

func _process(delta: float) -> void:
	coins += cps * delta
	coin_label.text = "$ %d" % int(coins)
