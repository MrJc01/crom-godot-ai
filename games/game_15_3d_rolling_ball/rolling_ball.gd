extends Node3D

var ball_body: RigidBody3D

func _ready() -> void:
	var env = WorldEnvironment.new()
	var environ = Environment.new()
	environ.background_mode = Environment.BG_COLOR
	environ.background_color = Color(0.1, 0.2, 0.3)
	env.environment = environ
	add_child(env)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)
	
	var cam = Camera3D.new()
	cam.position = Vector3(0, 8, 12)
	add_child(cam)
	cam.look_at_from_position(cam.position, Vector3.ZERO, Vector3.UP)
	
	var floor_body = StaticBody3D.new()
	var floor_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(20, 0.5, 20)
	floor_mesh.mesh = box
	floor_body.add_child(floor_mesh)
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(20, 0.5, 20)
	col.shape = box_shape
	floor_body.add_child(col)
	add_child(floor_body)
	
	ball_body = RigidBody3D.new()
	ball_body.position = Vector3(0, 3, 0)
	var ball_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	ball_mesh.mesh = sphere
	ball_body.add_child(ball_mesh)
	var b_col = CollisionShape3D.new()
	var s_shape = SphereShape3D.new()
	b_col.shape = s_shape
	ball_body.add_child(b_col)
	add_child(ball_body)

func _process(delta: float) -> void:
	if ball_body:
		if Input.is_action_pressed("ui_up"): ball_body.apply_central_force(Vector3(0, 0, -15))
		if Input.is_action_pressed("ui_down"): ball_body.apply_central_force(Vector3(0, 0, 15))
		if Input.is_action_pressed("ui_left"): ball_body.apply_central_force(Vector3(-15, 0, 0))
		if Input.is_action_pressed("ui_right"): ball_body.apply_central_force(Vector3(15, 0, 0))
