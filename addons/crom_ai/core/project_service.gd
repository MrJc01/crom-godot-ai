class_name ProjectService

# ==============================================================================
# Project Service — CRUD e estatísticas dos projetos Godot do usuário
# Responsabilidade: criar, listar, abrir projetos e coletar dados.
# Nenhuma lógica de UI aqui.
# ==============================================================================

const MASTER_PROJECT_PATH := "/home/j/Documentos/GitHub/crom-godot-ai"
const DEFAULT_PROJECT_DIR := "/home/j/Documentos/Godot"

# --- Listar todos os projetos do Godot no computador ---

static func list_projects() -> Array[Dictionary]:
	var projects: Array[Dictionary] = []
	var seen_paths: Array[String] = []
	
	# 1. Ler do projects.cfg oficial do Godot
	var cfg_path := OS.get_environment("HOME") + "/.local/share/godot/projects.cfg"
	if FileAccess.file_exists(cfg_path):
		var file := FileAccess.open(cfg_path, FileAccess.READ)
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.begins_with("[") and line.ends_with("]"):
				var p_path := line.substr(1, line.length() - 2)
				if not seen_paths.has(p_path) and DirAccess.dir_exists_absolute(p_path):
					seen_paths.append(p_path)
					projects.append(_build_project_info(p_path))
		file.close()
	
	# 2. Garantir que projetos conhecidos estejam na lista
	for known_path in [MASTER_PROJECT_PATH, "/home/j/novo-projeto-de-jogo", "/home/j/crom-game-1"]:
		if not seen_paths.has(known_path) and DirAccess.dir_exists_absolute(known_path):
			seen_paths.append(known_path)
			projects.append(_build_project_info(known_path))
	
	return projects

# --- Criar novo projeto com CromAI pré-configurado ---

static func create_project(project_name: String) -> String:
	if project_name.is_empty():
		project_name = "novo-projeto-" + str(randi() % 900 + 100)
	
	var dest := DEFAULT_PROJECT_DIR + "/" + project_name
	
	# Criar diretórios
	DirAccess.make_dir_recursive_absolute(dest + "/addons")
	
	# Copiar plugin CromAI do projeto master
	var addons_src := MASTER_PROJECT_PATH + "/addons/crom_ai"
	if DirAccess.dir_exists_absolute(addons_src):
		OS.execute("cp", ["-rf", addons_src, dest + "/addons/"])
	if FileAccess.file_exists(MASTER_PROJECT_PATH + "/icon.svg"):
		OS.execute("cp", ["-f", MASTER_PROJECT_PATH + "/icon.svg", dest + "/icon.svg"])
	
	# Criar cena vazia/padrão res://main.tscn e script res://main.gd no novo projeto
	var main_gd_content := "extends Node2D\n\nfunc _ready() -> void:\n\tprint(\"Seu novo projeto Godot com CromAI está pronto!\")\n"
	var f_gd := FileAccess.open(dest + "/main.gd", FileAccess.WRITE)
	if f_gd:
		f_gd.store_string(main_gd_content)
		f_gd.close()
		
	var main_tscn_content := """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1_main"]

[node name="Main" type="Node2D"]
script = ExtResource("1_main")

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="Label" type="Label" parent="CanvasLayer"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -20.0
offset_right = 200.0
offset_bottom = 20.0
grow_horizontal = 2
grow_vertical = 2
theme_override_font_sizes/font_size = 24
text = "Bem-vindo ao seu Novo Jogo!"
horizontal_alignment = 1
vertical_alignment = 1
"""
	var f_tscn := FileAccess.open(dest + "/main.tscn", FileAccess.WRITE)
	if f_tscn:
		f_tscn.store_string(main_tscn_content)
		f_tscn.close()
	
	# Gerar project.godot pré-configurado
	var cfg := """; Engine configuration file.
config_version=5

[application]
config/name="%s"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.6", "Compatibility")
config/icon="res://icon.svg"

[autoload]
CromWorldManager="*res://addons/crom_ai/world_state_manager.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/crom_ai/plugin.cfg")

[display]
window/size/viewport_width=1152
window/size/viewport_height=648
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
""" % project_name
	
	var f := FileAccess.open(dest + "/project.godot", FileAccess.WRITE)
	if f:
		f.store_string(cfg)
		f.close()
	
	# Registrar no projects.cfg do Godot como favorito
	var godot_cfg_path := OS.get_environment("HOME") + "/.local/share/godot/projects.cfg"
	if FileAccess.file_exists(godot_cfg_path):
		var old := FileAccess.get_file_as_string(godot_cfg_path)
		var f_c := FileAccess.open(godot_cfg_path, FileAccess.WRITE)
		if f_c:
			f_c.store_string("[%s]\n\nfavorite=true\n\n%s" % [dest, old])
			f_c.close()
	
	return dest

# --- Abrir projeto no Editor Godot ---

static func open_in_editor(project_path: String) -> void:
	OS.execute("godot", ["-e", "--path", project_path])

# --- Executar projeto (Play / F5) ---

static func run_project(project_path: String) -> void:
	OS.execute("godot", ["--path", project_path])

# --- Estatísticas de um projeto ---

static func get_stats(project_path: String) -> Dictionary:
	var stats := {
		"scenes": 0,
		"scripts": 0,
		"has_crom_ai": false,
		"has_icon": false,
		"name": "",
	}
	
	# Ler nome do project.godot
	var godot_file := project_path + "/project.godot"
	if FileAccess.file_exists(godot_file):
		var content := FileAccess.get_file_as_string(godot_file)
		var regex := RegEx.new()
		regex.compile("config/name=\"(.+?)\"")
		var result := regex.search(content)
		if result:
			stats["name"] = result.get_string(1)
	
	# Contar cenas e scripts recursivamente
	_count_files_recursive(project_path, stats)
	
	# Verificar se tem CromAI e ícone
	stats["has_crom_ai"] = DirAccess.dir_exists_absolute(project_path + "/addons/crom_ai")
	stats["has_icon"] = FileAccess.file_exists(project_path + "/icon.svg")
	
	return stats

# --- Helpers Privados ---

static func _build_project_info(path: String) -> Dictionary:
	var short_name := path.get_file()
	if short_name.is_empty():
		short_name = path
	var stats := get_stats(path)
	return {
		"path": path,
		"short_name": short_name,
		"display_name": stats["name"] if not stats["name"].is_empty() else short_name,
		"scenes": stats["scenes"],
		"scripts": stats["scripts"],
		"has_crom_ai": stats["has_crom_ai"],
	}

static func _count_files_recursive(dir_path: String, stats: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var full_path := dir_path + "/" + file_name
		if dir.current_is_dir():
			_count_files_recursive(full_path, stats)
		else:
			if file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
				stats["scenes"] += 1
			elif file_name.ends_with(".gd"):
				stats["scripts"] += 1
		file_name = dir.get_next()
	dir.list_dir_end()
