@tool
extends Node

# ==============================================================================
# CommandProcessor: Processa comandos JSON recebidos via WebSocket/MCP
# Realiza edições no SceneTree no Editor, injeção de scripts @tool, e consulta/modifica o WorldState
# ==============================================================================

var editor_plugin: EditorPlugin = null

func _init(plugin: EditorPlugin = null) -> void:
	editor_plugin = plugin

func process_command(command_json: String) -> Dictionary:
	var parse_result = JSON.parse_string(command_json)
	if parse_result == null or not (parse_result is Dictionary):
		return { "status": "error", "message": "JSON inválido mal formatado." }
	
	var cmd: Dictionary = parse_result
	var action: String = str(cmd.get("action", "")).to_lower()
	var params: Dictionary = cmd.get("params", {}) if cmd.get("params") is Dictionary else cmd
	
	print("[CromAI CommandProcessor] Processando ação: ", action)
	
	# ==========================================================================
	# 1. FERRAMENTAS DO EDITOR E CENA GODOT (MCP TOOLS: BUILD MODE)
	# ==========================================================================
	match action:
		"get_scene_tree":
			return _get_scene_tree()
		"add_node":
			return _add_node(params)
		"remove_node":
			return _remove_node(params)
		"set_node_property":
			return _set_node_property(params)
		"create_and_attach_script":
			return _create_and_attach_script(params)
		"play_scene":
			return _play_scene(params)
		"stop_scene":
			return _stop_scene()
		"simulate_editor_input":
			return _simulate_editor_input(params)
		"capture_screenshot":
			return _capture_screenshot(params)
		"get_open_editor_context":
			return _get_open_editor_context()
		"read_project_file":
			return _read_project_file(params)
		"modify_project_file":
			return _modify_project_file(params)
		"list_project_dir":
			return _list_project_dir(params)
			
			
		# ======================================================================
		# 2. FERRAMENTAS DO MUNDO / ONTOLOGIA (WORLD STATE: BUILD MODE)
		# ======================================================================
		"create_location":
			var wm = _get_world_manager()
			return wm.create_location(str(params.get("location_id", "")), str(params.get("name", "")), str(params.get("description", "")))
		"create_entity":
			var wm = _get_world_manager()
			return wm.create_entity(str(params.get("entity_id", "")), str(params.get("location_id", "")), str(params.get("type", "item")), params.get("properties", {}))
		"define_rule":
			var wm = _get_world_manager()
			return wm.define_rule(str(params.get("trigger_action", "")), str(params.get("target_entity_id", "")), params.get("conditions", {}), params.get("results", {}))
		"link_locations":
			var wm = _get_world_manager()
			return wm.link_locations(str(params.get("location_a", "")), str(params.get("location_b", "")), str(params.get("direction", "")), bool(params.get("bidirectional", true)))
			
		# ======================================================================
		# 3. FERRAMENTAS DE JOGADOR (PLAY MODE)
		# ======================================================================
		"look_around":
			return _get_world_manager().look_around()
		"move":
			return _get_world_manager().move(str(params.get("direction", params.get("target", ""))))
		"interact":
			return _get_world_manager().interact(str(params.get("action", "examinar")), str(params.get("target_id", "")), str(params.get("with_item_id", "")))
		"check_inventory_and_status":
			return _get_world_manager().check_inventory_and_status()
			
		# ======================================================================
		# 4. SISTEMA E CONTROLE
		# ======================================================================
		"switch_mode":
			return _get_world_manager().switch_mode(str(params.get("mode", "build")))
		"get_world_state":
			return _get_world_manager().get_world_state(str(params.get("query", "")))
		"reset_world":
			return _get_world_manager().reset_world()
		"ping":
			return { "status": "success", "message": "Pong! CromAI Godot Bridge ativo." }
		_:
			return { "status": "error", "message": "Ação desconhecida: '%s'." % action }

func _get_world_manager() -> Node:
	if Engine.has_singleton("CromWorldManager"):
		return Engine.get_singleton("CromWorldManager")
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("CromWorldManager"):
		return tree.root.get_node("CromWorldManager")
	var script = load("res://addons/crom_ai/world_state_manager.gd")
	if script:
		var instance = script.new()
		instance.name = "CromWorldManager"
		if tree and tree.root:
			tree.root.add_child(instance)
		return instance
	return self

# --- Implementações do Editor ---

func _get_scene_tree() -> Dictionary:
	var scene_root: Node = null
	var tree = Engine.get_main_loop() as SceneTree
	
	if editor_plugin and editor_plugin.get_editor_interface():
		scene_root = editor_plugin.get_editor_interface().get_edited_scene_root()
		
	if not scene_root and tree:
		scene_root = tree.current_scene
		
	if not scene_root or (tree and scene_root == tree.root):
		return { "status": "error", "message": "Nenhuma cena de jogo ativa para obter a árvore de nós no momento." }
		
	var tree_data = _serialize_node_tree(scene_root)
	return { "status": "success", "scene_root_name": scene_root.name, "tree": tree_data }

func _serialize_node_tree(node: Node) -> Dictionary:
	var children_data = []
	for child in node.get_children():
		children_data.append(_serialize_node_tree(child))
		
	var props = {
		"position": node.position if "position" in node else null,
		"visible": node.visible if "visible" in node else true
	}
	return {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"properties": props,
		"children": children_data
	}

func _add_node(params: Dictionary) -> Dictionary:
	var node_type: String = str(params.get("node_type", "Node"))
	var node_name: String = str(params.get("node_name", "NewNode"))
	var parent_path: String = str(params.get("parent_path", "."))
	
	if not ClassDB.class_exists(node_type):
		return { "status": "error", "message": "Classe/Tipo de nó desconhecido: '%s'." % node_type }
		
	var new_node = ClassDB.instantiate(node_type)
	if not new_node or not (new_node is Node):
		return { "status": "error", "message": "Falha ao instanciar o nó '%s'." % node_type }
		
	new_node.name = node_name
	
	var scene_root: Node = null
	if editor_plugin and editor_plugin.get_editor_interface():
		scene_root = editor_plugin.get_editor_interface().get_edited_scene_root()
	else:
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			scene_root = tree.current_scene if tree.current_scene else tree.root
			
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta para adicionar nó." }
		
	var parent_node: Node = scene_root
	if parent_path != "." and parent_path != "":
		parent_node = scene_root.get_node_or_null(parent_path)
		if not parent_node:
			return { "status": "error", "message": "Nó pai não encontrado em '%s'." % parent_path }
			
	parent_node.add_child(new_node)
	new_node.owner = scene_root
	
	# Aplica propriedades iniciais se enviadas
	if params.has("properties") and params["properties"] is Dictionary:
		for prop in params["properties"]:
			if prop in new_node:
				new_node.set(prop, params["properties"][prop])
				
	return { "status": "success", "message": "Nó '%s' (%s) adicionado em '%s'." % [node_name, node_type, parent_node.name], "node_path": str(new_node.get_path()) }

func _remove_node(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", ""))
	if node_path == "":
		return { "status": "error", "message": "O parâmetro 'node_path' é obrigatório." }
		
	var scene_root: Node = null
	if editor_plugin and editor_plugin.get_editor_interface():
		scene_root = editor_plugin.get_editor_interface().get_edited_scene_root()
		
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
		
	var target = scene_root.get_node_or_null(node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }
		
	target.queue_free()
	return { "status": "success", "message": "Nó '%s' removido com sucesso." % node_path }

func _set_node_property(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", ""))
	var property_name: String = str(params.get("property", params.get("property_name", "")))
	var value = params.get("value")
	
	if node_path == "" or property_name == "":
		return { "status": "error", "message": "Os parâmetros 'node_path' e 'property' são obrigatórios." }
		
	var scene_root: Node = null
	if editor_plugin and editor_plugin.get_editor_interface():
		scene_root = editor_plugin.get_editor_interface().get_edited_scene_root()
		
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
		
	var target = scene_root.get_node_or_null(node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }
		
	if not (property_name in target):
		return { "status": "error", "message": "Propriedade '%s' não existe no nó '%s'." % [property_name, target.name] }
		
	# Lida com conversão básica de tipos comuns (Vetor2, Vetor3, etc se virem em Dict/Array)
	if value is Array and value.size() == 2 and property_name == "position":
		value = Vector2(value[0], value[1])
	elif value is Array and value.size() == 3 and property_name == "position":
		value = Vector3(value[0], value[1], value[2])
		
	target.set(property_name, value)
	return { "status": "success", "message": "Propriedade '%s' de '%s' atualizada para %s." % [property_name, target.name, str(value)] }

func _create_and_attach_script(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", "."))
	var script_path: String = str(params.get("script_path", "res://scripts/generated_script.gd"))
	var gdscript_code: String = str(params.get("gdscript_code", params.get("code", "")))
	
	if gdscript_code == "":
		return { "status": "error", "message": "O código 'gdscript_code' não pode ser vazio." }
		
	# Criar diretórios pai se não existirem
	var parent_dir := script_path.get_base_dir()
	if parent_dir != "" and parent_dir != "res://":
		if not DirAccess.dir_exists_absolute(parent_dir):
			DirAccess.make_dir_recursive_absolute(parent_dir)
		
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		return { "status": "error", "message": "Falha ao escrever arquivo de script em '%s'." % script_path }
		
	file.store_string(gdscript_code)
	file.close()
	
	# Força recarregamento do recurso no editor
	_refresh_editor_filesystem()
		
	var loaded_script = load(script_path)
	if not loaded_script:
		return { "status": "success", "message": "Script salvo com sucesso em '%s' (Aviso: falha temporária ao carregar o script na engine, provavelmente devido a preloads de recursos ou cenas ainda não criados. Prossiga criando as dependências faltantes)." % script_path }
		
	var scene_root: Node = null
	if editor_plugin and editor_plugin.get_editor_interface():
		scene_root = editor_plugin.get_editor_interface().get_edited_scene_root()
		
	if scene_root:
		var target = scene_root.get_node_or_null(node_path)
		if target:
			target.set_script(loaded_script)
			return { "status": "success", "message": "Script %s criado e anexado ao nó '%s'." % [script_path, target.name] }
			
	return { "status": "success", "message": "Script %s criado e salvo com sucesso." % script_path }

func _play_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = str(params.get("scene_path", ""))
	if editor_plugin and editor_plugin.get_editor_interface():
		if scene_path != "":
			editor_plugin.get_editor_interface().play_custom_scene(scene_path)
		else:
			editor_plugin.get_editor_interface().play_main_scene()
		return { "status": "success", "message": "Execução de cena iniciada no Godot." }
	return { "status": "error", "message": "EditorInterface indisponível para rodar cena." }

func _stop_scene() -> Dictionary:
	if editor_plugin and editor_plugin.get_editor_interface():
		editor_plugin.get_editor_interface().stop_playing_scene()
		return { "status": "success", "message": "Execução de cena interrompida." }
	return { "status": "error", "message": "EditorInterface indisponível." }

func _simulate_editor_input(params: Dictionary) -> Dictionary:
	var action_name: String = str(params.get("action_name", "ui_accept"))
	var pressed: bool = bool(params.get("pressed", true))
	var key_name: String = str(params.get("key_name", "")).to_lower()
	var click_pos = params.get("click_position", null)
	
	var ev = InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	Input.parse_input_event(ev)
	
	var msg = "Input de ação '%s' (pressed: %s) simulado." % [action_name, str(pressed)]
	
	if key_name != "":
		var key_ev = InputEventKey.new()
		key_ev.pressed = pressed
		match key_name:
			"left", "left_arrow": key_ev.keycode = KEY_LEFT
			"right", "right_arrow": key_ev.keycode = KEY_RIGHT
			"up", "up_arrow": key_ev.keycode = KEY_UP
			"down", "down_arrow": key_ev.keycode = KEY_DOWN
			"space": key_ev.keycode = KEY_SPACE
			"w": key_ev.keycode = KEY_W
			"a": key_ev.keycode = KEY_A
			"s": key_ev.keycode = KEY_S
			"d": key_ev.keycode = KEY_D
		Input.parse_input_event(key_ev)
		msg += " Tecla física '%s' enviada." % key_name
		
	if click_pos is Array and click_pos.size() == 2:
		var mouse_ev = InputEventMouseButton.new()
		mouse_ev.button_index = MOUSE_BUTTON_LEFT
		mouse_ev.pressed = pressed
		mouse_ev.position = Vector2(click_pos[0], click_pos[1])
		Input.parse_input_event(mouse_ev)
		msg += " Clique do mouse em (%d, %d) enviado." % [click_pos[0], click_pos[1]]
		
	return { "status": "success", "message": msg }

func _capture_screenshot(_params: Dictionary) -> Dictionary:
	var vp = get_viewport()
	if editor_plugin and editor_plugin.get_editor_interface():
		vp = editor_plugin.get_editor_interface().get_base_control().get_viewport()
	if not vp:
		return { "status": "error", "message": "Viewport não encontrado para captura." }
	var img = vp.get_texture().get_image()
	if not img:
		return { "status": "error", "message": "Falha ao obter imagem do viewport." }
	img.resize(640, 360) # Redimensiona para economizar tokens
	var buffer = img.save_png_to_buffer()
	var b64 = Marshalls.raw_to_base64(buffer)
	return { "status": "success", "image_base64": b64, "format": "png" }

func _get_open_editor_context() -> Dictionary:
	var res = { "status": "success", "open_scripts": [], "edited_scene": "", "selected_nodes": [] }
	if editor_plugin and editor_plugin.get_editor_interface():
		var ei = editor_plugin.get_editor_interface()
		if ei.get_script_editor():
			for sc in ei.get_script_editor().get_open_scripts():
				if sc and sc.resource_path != "":
					res["open_scripts"].append(sc.resource_path)
		var root = ei.get_edited_scene_root()
		if root and root.scene_file_path != "":
			res["edited_scene"] = root.scene_file_path
		if ei.get_selection():
			for node in ei.get_selection().get_selected_nodes():
				res["selected_nodes"].append(str(node.name) + " (" + str(node.get_class()) + ")")
	return res

func _read_project_file(params: Dictionary) -> Dictionary:
	var path: String = str(params.get("file_path", ""))
	
	# Verificar se o arquivo existe
	if not FileAccess.file_exists(path):
		return { "status": "error", "message": "Arquivo não encontrado: " + path }
		
	# Filtrar extensões permitidas de texto para evitar leitura de arquivos binários
	var ext = path.get_extension().to_lower()
	var safe_exts = ["gd", "md", "txt", "json", "tscn", "cfg", "xml", "html", "css", "js", "tres", "gitignore", "svg", "ini"]
	if ext != "" and not ext in safe_exts:
		return { "status": "error", "message": "Tipo de arquivo binário ou não suportado para leitura direta: ." + ext }
		
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return { "status": "error", "message": "Não foi possível abrir o arquivo: " + path }
		
	# Impedir leitura de arquivos muito grandes (maiores que 500 KB) para evitar crash de CowData
	var file_size = f.get_length()
	if file_size > 500000:
		f.close()
		return { "status": "error", "message": "Arquivo muito grande para leitura direta (%d bytes). Limite máximo de 500 KB." % file_size }
		
	var content = f.get_as_text()
	f.close()
	return { "status": "success", "file_path": path, "content": content }

func _modify_project_file(params: Dictionary) -> Dictionary:
	var path: String = str(params.get("file_path", ""))
	var content: String = str(params.get("new_content", ""))
	if path == "":
		return { "status": "error", "message": "Caminho de arquivo inválido." }
	# Criar diretórios pai se não existirem
	var parent_dir := path.get_base_dir()
	if parent_dir != "" and parent_dir != "res://":
		if not DirAccess.dir_exists_absolute(parent_dir):
			DirAccess.make_dir_recursive_absolute(parent_dir)
			
	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return { "status": "error", "message": "Falha ao salvar arquivo em: " + path }
	f.store_string(content)
	f.close()
	_refresh_editor_filesystem()
	return { "status": "success", "message": "Arquivo atualizado com sucesso: " + path }

func _list_project_dir(params: Dictionary) -> Dictionary:
	var path: String = str(params.get("dir_path", "res://"))
	if not DirAccess.dir_exists_absolute(path):
		return { "status": "error", "message": "Diretório não encontrado: " + path }
	var dir = DirAccess.open(path)
	if not dir:
		return { "status": "error", "message": "Não foi possível abrir o diretório: " + path }
	
	var files := []
	var directories := []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			if dir.current_is_dir():
				directories.append(file_name)
			else:
				files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return {
		"status": "success",
		"dir_path": path,
		"files": files,
		"directories": directories
	}

func _refresh_editor_filesystem() -> void:
	if Engine.is_editor_hint():
		var ef = EditorInterface.get_resource_filesystem()
		if ef:
			ef.scan()
			ef.scan_sources()

