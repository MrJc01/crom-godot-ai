class_name ProjectService

# ==============================================================================
# Project Service — CRUD completo dos projetos Godot do usuário.
# Sem caminhos hardcoded: usa o executável do Godot em execução, o diretório
# de dados oficial do Godot por plataforma e um diretório de projetos
# configurável (user://crom_hub.cfg).
# Nenhuma lógica de UI aqui.
# ==============================================================================

const HUB_CONFIG_PATH := "user://crom_hub.cfg"

# --- Ambiente ------------------------------------------------------------------

static func godot_binary() -> String:
	return OS.get_executable_path()

static func master_project_path() -> String:
	# O hub roda dentro do projeto master; res:// é a fonte do plugin CromAI.
	return ProjectSettings.globalize_path("res://").rstrip("/")

static func default_projects_dir() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(HUB_CONFIG_PATH) == OK:
		var saved := str(cfg.get_value("hub", "projects_dir", ""))
		if saved != "":
			return saved
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs == "":
		docs = OS.get_environment("HOME")
	return docs.path_join("Godot")

static func set_default_projects_dir(dir: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(HUB_CONFIG_PATH)
	cfg.set_value("hub", "projects_dir", dir)
	cfg.save(HUB_CONFIG_PATH)

# Caminho do projects.cfg oficial do Godot por plataforma
static func godot_projects_cfg_path() -> String:
	match OS.get_name():
		"Windows":
			return OS.get_environment("APPDATA").path_join("Godot").path_join("projects.cfg")
		"macOS":
			return OS.get_environment("HOME").path_join("Library/Application Support/Godot/projects.cfg")
		_:
			var xdg := OS.get_environment("XDG_DATA_HOME")
			if xdg == "":
				xdg = OS.get_environment("HOME").path_join(".local/share")
			return xdg.path_join("godot/projects.cfg")

# --- Read: listar projetos -------------------------------------------------------

static func list_projects() -> Array[Dictionary]:
	var projects: Array[Dictionary] = []
	var seen_paths: Array[String] = []

	var cfg := ConfigFile.new()
	var cfg_path := godot_projects_cfg_path()
	if FileAccess.file_exists(cfg_path) and cfg.load(cfg_path) == OK:
		for section in cfg.get_sections():
			var p_path := String(section)
			if not seen_paths.has(p_path) and FileAccess.file_exists(p_path.path_join("project.godot")):
				seen_paths.append(p_path)
				var info := _build_project_info(p_path)
				info["favorite"] = bool(cfg.get_value(section, "favorite", false))
				projects.append(info)

	# Garante que o próprio projeto master apareça
	var master := master_project_path()
	if not seen_paths.has(master) and FileAccess.file_exists(master.path_join("project.godot")):
		var info := _build_project_info(master)
		info["favorite"] = true
		projects.append(info)

	projects.sort_custom(func(a, b):
		if a["favorite"] != b["favorite"]:
			return a["favorite"]
		return str(a["display_name"]).naturalnocasecmp_to(str(b["display_name"])) < 0
	)
	return projects

# --- Create ---------------------------------------------------------------------

# Valida o nome e cria o projeto. Retorna {"ok": bool, "path": String, "error": String}
static func create_project(project_name: String, base_dir: String = "") -> Dictionary:
	project_name = project_name.strip_edges()
	if project_name.is_empty():
		return { "ok": false, "path": "", "error": "Informe um nome para o projeto." }

	var slug := project_name.to_lower().replace(" ", "-")
	var regex := RegEx.new()
	regex.compile("^[a-z0-9][a-z0-9_-]*$")
	if not regex.search(slug):
		return { "ok": false, "path": "", "error": "Use apenas letras, números, '-' e '_' no nome." }

	if base_dir == "":
		base_dir = default_projects_dir()
	var dest := base_dir.path_join(slug)
	if DirAccess.dir_exists_absolute(dest):
		return { "ok": false, "path": dest, "error": "Já existe uma pasta '%s' em %s." % [slug, base_dir] }

	var err := DirAccess.make_dir_recursive_absolute(dest.path_join("addons"))
	if err != OK:
		return { "ok": false, "path": dest, "error": "Falha ao criar diretório (%d). Verifique permissões." % err }

	# Copia o plugin CromAI do projeto master
	var addons_src := master_project_path().path_join("addons/crom_ai")
	if DirAccess.dir_exists_absolute(addons_src):
		_copy_dir_recursive(addons_src, dest.path_join("addons/crom_ai"))
	var icon_src := master_project_path().path_join("icon.svg")
	if FileAccess.file_exists(icon_src):
		DirAccess.copy_absolute(icon_src, dest.path_join("icon.svg"))

	_write_text(dest.path_join("main.gd"),
		"extends Node2D\n\nfunc _ready() -> void:\n\tprint(\"Projeto %s pronto. Converse com o Crom Agente na aba lateral da IDE.\")\n" % project_name)

	_write_text(dest.path_join("main.tscn"), """[gd_scene load_steps=2 format=3]

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
offset_left = -220.0
offset_top = -20.0
offset_right = 220.0
offset_bottom = 20.0
grow_horizontal = 2
grow_vertical = 2
theme_override_font_sizes/font_size = 24
text = "%s"
horizontal_alignment = 1
vertical_alignment = 1
""" % project_name)

	_write_text(dest.path_join("project.godot"), """; Engine configuration file.
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
""" % project_name)

	register_in_godot_list(dest, true)
	return { "ok": true, "path": dest, "error": "" }

# --- Update ---------------------------------------------------------------------

static func rename_project(project_path: String, new_name: String) -> Dictionary:
	new_name = new_name.strip_edges()
	if new_name.is_empty():
		return { "ok": false, "error": "Informe o novo nome." }
	var godot_file := project_path.path_join("project.godot")
	if not FileAccess.file_exists(godot_file):
		return { "ok": false, "error": "project.godot não encontrado em %s." % project_path }

	var content := FileAccess.get_file_as_string(godot_file)
	var regex := RegEx.new()
	regex.compile("config/name=\"(.*?)\"")
	if not regex.search(content):
		return { "ok": false, "error": "Campo config/name não encontrado no project.godot." }
	content = regex.sub(content, "config/name=\"%s\"" % new_name.c_escape())
	_write_text(godot_file, content)
	return { "ok": true, "error": "" }

static func toggle_favorite(project_path: String) -> void:
	var cfg := ConfigFile.new()
	var cfg_path := godot_projects_cfg_path()
	if cfg.load(cfg_path) != OK:
		return
	var current := bool(cfg.get_value(project_path, "favorite", false))
	cfg.set_value(project_path, "favorite", not current)
	cfg.save(cfg_path)

static func register_in_godot_list(project_path: String, favorite: bool = false) -> void:
	var cfg := ConfigFile.new()
	var cfg_path := godot_projects_cfg_path()
	cfg.load(cfg_path) # ignora erro: cria arquivo novo se não existir
	cfg.set_value(project_path, "favorite", favorite)
	DirAccess.make_dir_recursive_absolute(cfg_path.get_base_dir())
	cfg.save(cfg_path)

# --- Delete ---------------------------------------------------------------------

# Remove apenas da lista do Godot (não toca nos arquivos)
static func remove_from_list(project_path: String) -> void:
	var cfg := ConfigFile.new()
	var cfg_path := godot_projects_cfg_path()
	if cfg.load(cfg_path) != OK:
		return
	if cfg.has_section(project_path):
		cfg.erase_section(project_path)
		cfg.save(cfg_path)

# Exclui a pasta do projeto do disco. Guardas: precisa conter project.godot
# e não pode ser o projeto master (o hub em execução).
static func delete_project_from_disk(project_path: String) -> Dictionary:
	if not FileAccess.file_exists(project_path.path_join("project.godot")):
		return { "ok": false, "error": "Pasta não parece ser um projeto Godot (sem project.godot). Nada foi excluído." }
	if project_path.simplify_path() == master_project_path().simplify_path():
		return { "ok": false, "error": "Não é possível excluir o projeto master em execução." }
	_delete_dir_recursive(project_path)
	remove_from_list(project_path)
	return { "ok": true, "error": "" }

# --- Ações ----------------------------------------------------------------------

static func open_in_editor(project_path: String) -> void:
	OS.create_process(godot_binary(), ["--editor", "--path", project_path])

static func run_project(project_path: String) -> void:
	OS.create_process(godot_binary(), ["--path", project_path])

static func reveal_in_file_manager(project_path: String) -> void:
	OS.shell_show_in_file_manager(project_path)

# --- Estatísticas ----------------------------------------------------------------

static func get_stats(project_path: String) -> Dictionary:
	var stats := {
		"scenes": 0,
		"scripts": 0,
		"has_crom_ai": false,
		"name": "",
	}
	var godot_file := project_path.path_join("project.godot")
	if FileAccess.file_exists(godot_file):
		var regex := RegEx.new()
		regex.compile("config/name=\"(.+?)\"")
		var result := regex.search(FileAccess.get_file_as_string(godot_file))
		if result:
			stats["name"] = result.get_string(1)

	_count_files_recursive(project_path, stats)
	stats["has_crom_ai"] = DirAccess.dir_exists_absolute(project_path.path_join("addons/crom_ai"))
	return stats

# --- Helpers privados -------------------------------------------------------------

static func _build_project_info(path: String) -> Dictionary:
	var short_name := path.get_file()
	if short_name.is_empty():
		short_name = path
	var stats := get_stats(path)
	return {
		"path": path,
		"short_name": short_name,
		"display_name": stats["name"] if not str(stats["name"]).is_empty() else short_name,
		"scenes": stats["scenes"],
		"scripts": stats["scripts"],
		"has_crom_ai": stats["has_crom_ai"],
		"favorite": false,
	}

static func _count_files_recursive(dir_path: String, stats: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		# Ignora ocultos e código do addon (conta só o código do usuário)
		if file_name.begins_with(".") or file_name == "addons":
			file_name = dir.get_next()
			continue
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_count_files_recursive(full_path, stats)
		elif file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
			stats["scenes"] += 1
		elif file_name.ends_with(".gd"):
			stats["scripts"] += 1
		file_name = dir.get_next()
	dir.list_dir_end()

static func _copy_dir_recursive(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	var dir := DirAccess.open(src)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var s := src.path_join(entry)
			var d := dst.path_join(entry)
			if dir.current_is_dir():
				_copy_dir_recursive(s, d)
			else:
				DirAccess.copy_absolute(s, d)
		entry = dir.get_next()
	dir.list_dir_end()

static func _delete_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full := path.path_join(entry)
			if dir.current_is_dir():
				_delete_dir_recursive(full)
			else:
				dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

static func _write_text(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()
