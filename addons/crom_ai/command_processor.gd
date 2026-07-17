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
		"move_node":
			return _move_node(params)
		"rename_node":
			return _rename_node(params)
		"reparent_node":
			return _reparent_node(params)
		"connect_signal":
			return _connect_signal(params)
		"create_and_attach_script":
			return _create_and_attach_script(params)
		"create_scene":
			return _create_scene(params)
		"instantiate_scene":
			return _instantiate_scene(params)
		"save_scene":
			return _save_scene()
		"open_scene":
			return _open_scene(params)
		"set_project_setting":
			return _set_project_setting(params)
		"add_input_action":
			return _add_input_action(params)
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
		# 1b. LAÇO DE FEEDBACK, INSPEÇÃO E QA (crom-godot-mcp fases 1/3/5/6/7)
		# ======================================================================
		"get_console_errors":
			return _get_console_errors(params)
		"get_output":
			return _get_output(params)
		"clear_output":
			return _clear_output()
		"gdscript_check":
			return _gdscript_check(params)
		"read_script":
			return _read_script(params)
		"list_node_methods":
			return _list_node_methods(params)
		"list_node_signals":
			return _list_node_signals(params)
		"get_node_config_warnings":
			return _get_node_config_warnings(params)
		"duplicate_node":
			return _duplicate_node(params)
		"add_to_group":
			return _add_to_group(params)
		"remove_from_group":
			return _remove_from_group(params)
		"get_project_setting":
			return _get_project_setting(params)
		"list_input_actions":
			return _list_input_actions()
		"create_resource":
			return _create_resource(params)
		"simulate_key":
			return _simulate_key(params)
		"simulate_action":
			return _simulate_action(params)

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

func _resolve_node(scene_root: Node, path: String) -> Node:
	if not scene_root:
		return null
	if path == "." or path == "":
		return scene_root
	if path.begins_with("/root/"):
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.root.has_node(path):
			return tree.root.get_node(path)
		var root_path = str(scene_root.get_path())
		if path.begins_with(root_path):
			var rel = path.substr(root_path.length())
			if rel.begins_with("/"):
				rel = rel.substr(1)
			if rel == "":
				return scene_root
			return scene_root.get_node_or_null(rel)
	return scene_root.get_node_or_null(path)

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
		parent_node = _resolve_node(scene_root, parent_path)
		if not parent_node:
			return { "status": "error", "message": "Nó pai não encontrado em '%s'." % parent_path }
			
	parent_node.add_child(new_node)
	new_node.owner = scene_root
	
	# Aplica propriedades iniciais se enviadas
	if params.has("properties") and params["properties"] is Dictionary:
		for prop in params["properties"]:
			if prop in new_node:
				new_node.set(prop, _coerce_value(new_node, prop, params["properties"][prop]))

	_mark_scene_modified()
	return { "status": "success", "message": "Nó '%s' (%s) adicionado em '%s' da cena '%s'." % [node_name, node_type, parent_node.name, scene_root.scene_file_path], "node_path": str(new_node.get_path()) }

func _remove_node(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", ""))
	if node_path == "":
		return { "status": "error", "message": "O parâmetro 'node_path' é obrigatório." }
		
	var scene_root: Node = null
	if editor_plugin and editor_plugin.get_editor_interface():
		scene_root = editor_plugin.get_editor_interface().get_edited_scene_root()
		
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
		
	var target = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }
		
	target.queue_free()
	_mark_scene_modified()
	return { "status": "success", "message": "Nó '%s' removido com sucesso da cena '%s'." % [node_path, scene_root.scene_file_path] }

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
		
	var target = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }
		
	if not (property_name in target):
		return { "status": "error", "message": "Propriedade '%s' não existe no nó '%s'." % [property_name, target.name] }
		
	value = _coerce_value(target, property_name, value)
	target.set(property_name, value)
	_mark_scene_modified()
	return { "status": "success", "message": "Propriedade '%s' de '%s' atualizada para %s na cena '%s'." % [property_name, target.name, str(value), scene_root.scene_file_path] }

# Converte Arrays/Strings JSON em tipos nativos (Vector2/3, Color) baseado no valor atual da propriedade
func _coerce_value(target: Object, property_name: String, value: Variant) -> Variant:
	if value is Dictionary and value.has("__resource_type"):
		var res_type = str(value["__resource_type"])
		if ClassDB.class_exists(res_type) and ClassDB.is_parent_class(res_type, "Resource"):
			var res = ClassDB.instantiate(res_type)
			for k in value:
				if k != "__resource_type" and k in res:
					res.set(k, _coerce_value(res, k, value[k]))
			return res

	var current = target.get(property_name)
	if value is Array:
		if current is Vector2 and value.size() >= 2:
			return Vector2(value[0], value[1])
		if current is Vector3 and value.size() >= 3:
			return Vector3(value[0], value[1], value[2])
		if current is Color and value.size() >= 3:
			return Color(value[0], value[1], value[2], value[3] if value.size() > 3 else 1.0)
	if value is String and current is Color:
		return Color.from_string(value, Color.WHITE)
	return value

func _get_edited_scene_root() -> Node:
	if editor_plugin and editor_plugin.get_editor_interface():
		return editor_plugin.get_editor_interface().get_edited_scene_root()
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.current_scene
	return null

func _mark_scene_modified() -> void:
	if editor_plugin and Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()
		# Salva a cena automaticamente para manter o arquivo .tscn em sincronia com o disco
		EditorInterface.save_scene()

# Conecta um sinal de um nó a um método de outro nó, de forma PERSISTENTE (a
# conexão é gravada no .tscn). Sem isso o agente cria handlers como
# _on_timer_timeout mas o sinal nunca é ligado — a cena roda sem erro, porém o
# jogo não funciona (ex.: o Timer nunca chama o método e a cobra não se move).
func _connect_signal(params: Dictionary) -> Dictionary:
	var from_path: String = str(params.get("from_node", params.get("node_path", ".")))
	var signal_name: String = str(params.get("signal", params.get("signal_name", "")))
	var to_path: String = str(params.get("to_node", "."))
	var method: String = str(params.get("method", params.get("method_name", "")))

	if signal_name == "" or method == "":
		return { "status": "error", "message": "Parâmetros obrigatórios: 'signal' e 'method'." }

	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }

	var from_node: Node = scene_root if from_path in [".", ""] else scene_root.get_node_or_null(from_path)
	var to_node: Node = scene_root if to_path in [".", ""] else scene_root.get_node_or_null(to_path)
	if not from_node:
		return { "status": "error", "message": "Nó emissor não encontrado em '%s'." % from_path }
	if not to_node:
		return { "status": "error", "message": "Nó receptor não encontrado em '%s'." % to_path }
	if not from_node.has_signal(signal_name):
		return { "status": "error", "message": "O nó '%s' não tem o sinal '%s'." % [from_node.name, signal_name] }

	# Checa o método de forma tolerante: has_method pode retornar falso logo após
	# anexar um script (cache do editor), mesmo com o método definido. Também olha
	# a lista de métodos do script. Se ainda assim não achar, conecta com um AVISO
	# em vez de bloquear (CONNECT_PERSIST salva na cena; o Godot resolve em runtime).
	var method_ok := to_node.has_method(method)
	if not method_ok:
		var sc = to_node.get_script()
		if sc and sc is Script:
			for m in sc.get_script_method_list():
				if str(m.get("name", "")) == method:
					method_ok = true
					break
	var note := ""
	if not method_ok:
		note = " [aviso: o método '%s' não foi encontrado agora — verifique o nome no script; a conexão foi salva e o Godot valida ao rodar]" % method

	var callable := Callable(to_node, method)
	if from_node.is_connected(signal_name, callable):
		return { "status": "success", "message": "Sinal '%s' de '%s' já estava conectado a %s().%s" % [signal_name, from_node.name, method, note] }

	# CONNECT_PERSIST faz a conexão ser salva na cena (.tscn), valendo em runtime.
	var err := from_node.connect(signal_name, callable, CONNECT_PERSIST)
	if err != OK:
		return { "status": "error", "message": "Falha ao conectar o sinal (erro %d)." % err }
	_mark_scene_modified()
	return { "status": "success", "message": "Sinal '%s' de '%s' conectado a %s.%s() e salvo na cena.%s" % [signal_name, from_node.name, to_node.name, method, note] }

func _move_node(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", ""))
	var pos = params.get("position")
	if node_path == "" or not (pos is Array) or pos.size() < 2:
		return { "status": "error", "message": "Parâmetros obrigatórios: 'node_path' e 'position' ([x, y] ou [x, y, z])." }

	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var target = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	if target is Node3D:
		target.position = Vector3(pos[0], pos[1], pos[2] if pos.size() > 2 else target.position.z)
	elif target is Node2D or target is Control:
		target.position = Vector2(pos[0], pos[1])
	else:
		return { "status": "error", "message": "Nó '%s' (%s) não possui posição espacial." % [target.name, target.get_class()] }
	_mark_scene_modified()
	return { "status": "success", "message": "Nó '%s' movido para %s." % [target.name, str(target.position)] }

func _rename_node(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", ""))
	var new_name: String = str(params.get("new_name", "")).strip_edges()
	if node_path == "" or new_name == "":
		return { "status": "error", "message": "Parâmetros obrigatórios: 'node_path' e 'new_name'." }

	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var target = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	var old_name := String(target.name)
	target.name = new_name
	_mark_scene_modified()
	return { "status": "success", "message": "Nó '%s' renomeado para '%s'." % [old_name, target.name], "node_path": str(target.get_path()) }

func _reparent_node(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", ""))
	var new_parent_path: String = str(params.get("new_parent_path", ""))
	if node_path == "" or new_parent_path == "":
		return { "status": "error", "message": "Parâmetros obrigatórios: 'node_path' e 'new_parent_path'." }

	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var target = _resolve_node(scene_root, node_path)
	var new_parent = _resolve_node(scene_root, new_parent_path)
	if not target or not new_parent:
		return { "status": "error", "message": "Nó ou novo pai não encontrado ('%s' -> '%s')." % [node_path, new_parent_path] }
	if target == scene_root:
		return { "status": "error", "message": "Não é possível reparentar o nó raiz da cena." }

	target.reparent(new_parent)
	target.owner = scene_root
	for child in target.find_children("*", "", true, false):
		child.owner = scene_root
	_mark_scene_modified()
	return { "status": "success", "message": "Nó '%s' movido para debaixo de '%s'." % [target.name, new_parent.name], "node_path": str(target.get_path()) }

func _create_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = str(params.get("scene_path", ""))
	var root_type: String = str(params.get("root_type", "Node2D"))
	var root_name: String = str(params.get("root_name", scene_path.get_file().get_basename().to_pascal_case()))

	if scene_path == "" or not scene_path.ends_with(".tscn"):
		return { "status": "error", "message": "O parâmetro 'scene_path' deve terminar em .tscn." }
	if not ClassDB.class_exists(root_type) or not ClassDB.is_parent_class(root_type, "Node"):
		return { "status": "error", "message": "Tipo de nó raiz inválido: '%s'." % root_type }

	var root = ClassDB.instantiate(root_type)
	root.name = root_name if root_name != "" else "Root"

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		root.free()
		return { "status": "error", "message": "Falha ao empacotar a cena (erro %d)." % pack_err }

	var parent_dir := scene_path.get_base_dir()
	if parent_dir != "" and parent_dir != "res://" and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var save_err := ResourceSaver.save(packed, scene_path)
	root.free()
	if save_err != OK:
		return { "status": "error", "message": "Falha ao salvar a cena em '%s' (erro %d)." % [scene_path, save_err] }
	_refresh_editor_filesystem()
	# Abre a cena recém-criada no editor: sem isso, add_node/set_node_property seguintes
	# falham com "nenhuma cena aberta".
	var opened := false
	if editor_plugin and Engine.is_editor_hint():
		EditorInterface.open_scene_from_path(scene_path)
		opened = true
	return { "status": "success", "message": "Cena '%s' criada com raiz %s ('%s')%s." % [scene_path, root_type, root_name, " e aberta no editor" if opened else ""] }

func _instantiate_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = str(params.get("scene_path", ""))
	var parent_path: String = str(params.get("parent_path", "."))
	var node_name: String = str(params.get("node_name", ""))

	if not FileAccess.file_exists(scene_path):
		return { "status": "error", "message": "Cena não encontrada: '%s'." % scene_path }
	var packed = load(scene_path)
	if not (packed is PackedScene):
		return { "status": "error", "message": "O arquivo '%s' não é uma PackedScene válida." % scene_path }

	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor para instanciar." }
	var parent_node: Node = scene_root
	if parent_path != "." and parent_path != "":
		parent_node = _resolve_node(scene_root, parent_path)
		if not parent_node:
			return { "status": "error", "message": "Nó pai não encontrado em '%s'." % parent_path }

	var instance: Node = packed.instantiate()
	if node_name != "":
		instance.name = node_name
	parent_node.add_child(instance)
	instance.owner = scene_root
	_mark_scene_modified()
	return { "status": "success", "message": "Instância de '%s' adicionada em '%s'." % [scene_path, parent_node.name], "node_path": str(instance.get_path()) }

func _save_scene() -> Dictionary:
	if editor_plugin and Engine.is_editor_hint():
		var err = EditorInterface.save_scene()
		if err != OK:
			return { "status": "error", "message": "Falha ao salvar a cena aberta (erro %d)." % err }
		var root := _get_edited_scene_root()
		var path := root.scene_file_path if root else ""
		return { "status": "success", "message": "Cena salva com sucesso%s." % (" em '%s'" % path if path != "" else "") }
	return { "status": "error", "message": "Salvar cena só está disponível dentro do Editor." }

func _open_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = str(params.get("scene_path", ""))
	if not FileAccess.file_exists(scene_path):
		return { "status": "error", "message": "Cena não encontrada: '%s'." % scene_path }
	if editor_plugin and Engine.is_editor_hint():
		EditorInterface.open_scene_from_path(scene_path)
		return { "status": "success", "message": "Cena '%s' aberta no editor." % scene_path }
	return { "status": "error", "message": "Abrir cena só está disponível dentro do Editor." }

func _set_project_setting(params: Dictionary) -> Dictionary:
	var setting: String = str(params.get("setting", ""))
	if setting == "" or not params.has("value"):
		return { "status": "error", "message": "Parâmetros obrigatórios: 'setting' e 'value'." }
	if setting.begins_with("autoload") or setting.begins_with("editor_plugins"):
		return { "status": "error", "message": "Alterar '%s' via agente não é permitido por segurança." % setting }

	ProjectSettings.set_setting(setting, params["value"])
	var err := ProjectSettings.save()
	if err != OK:
		return { "status": "error", "message": "Configuração aplicada em memória, mas falhou ao salvar project.godot (erro %d)." % err }
	return { "status": "success", "message": "Configuração '%s' definida para %s e salva no project.godot." % [setting, str(params["value"])] }

func _add_input_action(params: Dictionary) -> Dictionary:
	var action_name: String = str(params.get("action_name", "")).strip_edges()
	var keys = params.get("keys", [])
	if action_name == "" or not (keys is Array) or keys.is_empty():
		return { "status": "error", "message": "Parâmetros obrigatórios: 'action_name' e 'keys' (ex: [\"W\", \"Up\"])." }

	var events: Array = []
	for k in keys:
		var key_ev := InputEventKey.new()
		var keycode := OS.find_keycode_from_string(str(k))
		if keycode == KEY_NONE:
			return { "status": "error", "message": "Tecla desconhecida: '%s'. Use nomes como 'W', 'Space', 'Up', 'Escape'." % str(k) }
		key_ev.physical_keycode = keycode
		events.append(key_ev)

	ProjectSettings.set_setting("input/" + action_name, { "deadzone": 0.5, "events": events })
	var err := ProjectSettings.save()
	if err != OK:
		return { "status": "error", "message": "Ação criada em memória, mas falhou ao salvar project.godot (erro %d)." % err }
	return { "status": "success", "message": "Ação de input '%s' criada com %d tecla(s) e salva." % [action_name, events.size()] }

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
		
	var has_node_path: bool = params.has("node_path")
	if has_node_path:
		if not scene_root:
			return { "status": "error", "message": "Script '%s' salvo no disco, mas falhou ao anexar: nenhuma cena aberta no editor. Use 'godot_open_scene' para abrir a cena antes de anexar o script." % script_path }
		var target = _resolve_node(scene_root, node_path)
		if not target:
			return { "status": "error", "message": "Script '%s' salvo no disco, mas falhou ao anexar: nó '%s' não encontrado na cena '%s'." % [script_path, node_path, scene_root.name] }
		target.set_script(loaded_script)
		_mark_scene_modified()
		return { "status": "success", "message": "Script %s criado, anexado ao nó '%s' da cena '%s' e salvo." % [script_path, target.name, scene_root.scene_file_path] }
			
	return { "status": "success", "message": "Script %s criado e salvo com sucesso no disco." % script_path }

func _play_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = str(params.get("scene_path", ""))
	if editor_plugin and editor_plugin.get_editor_interface():
		# Marca o baseline do console ANTES de rodar, para que get_console_errors
		# capture só os erros DESTA execução.
		var lp := _godot_log_path()
		if FileAccess.file_exists(lp):
			var lf := FileAccess.open(lp, FileAccess.READ)
			if lf:
				_log_baseline = lf.get_length()
				lf.close()
		if scene_path != "":
			editor_plugin.get_editor_interface().play_custom_scene(scene_path)
		else:
			editor_plugin.get_editor_interface().play_main_scene()
		return { "status": "success", "message": "Execução iniciada. Aguarde ~1-2s e chame godot_get_console_errors para verificar se rodou SEM erros; se houver erro, corrija e rode de novo." }
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


# ==============================================================================
# crom-godot-mcp — Fase 1: LAÇO DE FEEDBACK (o agente enxerga os próprios erros)
# ==============================================================================

var _log_baseline: int = 0

func _godot_log_path() -> String:
	# Log do editor; captura também o stdout/stderr do jogo rodado via play_scene.
	return "user://logs/godot.log"

func _read_log_tail(max_bytes: int = 60000) -> String:
	var p := _godot_log_path()
	if not FileAccess.file_exists(p):
		return ""
	var f := FileAccess.open(p, FileAccess.READ)
	if not f:
		return ""
	var size := f.get_length()
	var start := _log_baseline if _log_baseline > 0 and _log_baseline < size else max(0, size - max_bytes)
	f.seek(start)
	var txt := f.get_buffer(size - start).get_string_from_utf8()
	f.close()
	return txt

# Lê os erros recentes do console (SCRIPT ERROR / Parse Error / ERROR).
func _get_console_errors(params: Dictionary) -> Dictionary:
	var txt := _read_log_tail()
	if txt == "":
		return { "status": "success", "errors": [], "message": "Nenhum log encontrado (rode play_scene primeiro; ou não há erros)." }
	var errors: Array[String] = []
	var lines := txt.split("\n")
	for i in range(lines.size()):
		var l := String(lines[i]).strip_edges()
		if l.contains("SCRIPT ERROR") or l.contains("Parse Error") or l.begins_with("ERROR:") or l.contains("Nonexistent") or l.contains("Invalid call") or l.contains("Failed to load"):
			errors.append(l)
			# anexa a linha seguinte (normalmente o 'at: arquivo:linha')
			if i + 1 < lines.size():
				var nxt := String(lines[i + 1]).strip_edges()
				if nxt.begins_with("at:") or nxt.begins_with("   at:"):
					errors.append("  " + nxt)
	if errors.is_empty():
		return { "status": "success", "errors": [], "message": "Console limpo: nenhum erro detectado desde o último clear/execução." }
	return { "status": "success", "error_count": errors.size(), "errors": errors, "message": "%d erro(s) no console. Corrija e rode de novo." % errors.size() }

# Devolve as últimas linhas do Output (prints, avisos, tudo).
func _get_output(params: Dictionary) -> Dictionary:
	var n := int(params.get("lines", 60))
	var txt := _read_log_tail()
	var lines := txt.split("\n")
	var out: Array[String] = []
	var startn := max(0, lines.size() - n)
	for i in range(startn, lines.size()):
		var l := String(lines[i]).strip_edges()
		if l != "":
			out.append(l)
	return { "status": "success", "output": out }

# Marca a posição atual do log como baseline: get_console_errors/get_output só
# olham o que vier DEPOIS. Use antes de um novo teste para ter leitura limpa.
func _clear_output() -> Dictionary:
	var p := _godot_log_path()
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			_log_baseline = f.get_length()
			f.close()
	return { "status": "success", "message": "Baseline do console definido. Erros/output agora só a partir daqui." }

# Valida a sintaxe de um GDScript SEM rodar a cena (parse via GDScript.reload).
func _gdscript_check(params: Dictionary) -> Dictionary:
	var path: String = str(params.get("script_path", params.get("file_path", "")))
	var code: String = str(params.get("gdscript_code", params.get("code", "")))
	var gd := GDScript.new()
	if code != "":
		gd.source_code = code
	elif path != "" and FileAccess.file_exists(path):
		gd.source_code = FileAccess.get_file_as_string(path)
	else:
		return { "status": "error", "message": "Informe 'script_path' existente ou 'gdscript_code'." }
	var err := gd.reload(true)
	if err != OK:
		return { "status": "error", "valid": false, "message": "GDScript com erro de sintaxe/parse (erro %d). Veja get_console_errors para detalhes." % err }
	return { "status": "success", "valid": true, "message": "Sintaxe do GDScript OK." }

# ==============================================================================
# crom-godot-mcp — Fase 5/6: inspeção de scripts e nós
# ==============================================================================

func _resolve_scene_node(params: Dictionary) -> Node:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return null
	var np := str(params.get("node_path", "."))
	return scene_root if np in [".", ""] else scene_root.get_node_or_null(np)

func _read_script(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var sc = target.get_script()
	if not sc:
		return { "status": "success", "has_script": false, "message": "O nó '%s' não tem script." % target.name }
	return { "status": "success", "has_script": true, "script_path": sc.resource_path, "source": sc.source_code }

func _list_node_methods(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var methods: Array[String] = []
	for m in target.get_method_list():
		var mn := str(m.get("name", ""))
		if not mn.begins_with("_") or mn.begins_with("_on_") or mn == "_ready" or mn == "_process":
			methods.append(mn)
	return { "status": "success", "node": str(target.name), "type": target.get_class(), "methods": methods }

func _list_node_signals(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var sigs: Array[String] = []
	for s in target.get_signal_list():
		sigs.append(str(s.get("name", "")))
	return { "status": "success", "node": str(target.name), "type": target.get_class(), "signals": sigs }

func _get_node_config_warnings(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var warns: Array = []
	if target.has_method("get_configuration_warnings"):
		warns = target.get_configuration_warnings()
	var arr: Array[String] = []
	for w in warns:
		arr.append(str(w))
	return { "status": "success", "node": str(target.name), "warnings": arr, "message": ("Sem avisos." if arr.is_empty() else "%d aviso(s) de configuração." % arr.size()) }

func _duplicate_node(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var target := scene_root.get_node_or_null(str(params.get("node_path", "")))
	if not target or target == scene_root:
		return { "status": "error", "message": "Nó inválido para duplicar." }
	var dup := target.duplicate()
	if params.has("new_name"):
		dup.name = str(params["new_name"])
	target.get_parent().add_child(dup)
	dup.owner = scene_root
	for c in dup.find_children("*", "", true, false):
		c.owner = scene_root
	_mark_scene_modified()
	return { "status": "success", "message": "Nó duplicado como '%s'." % dup.name, "node_path": str(dup.get_path()) }

func _add_to_group(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	var group := str(params.get("group", ""))
	if not target or group == "":
		return { "status": "error", "message": "Parâmetros: 'node_path' e 'group'." }
	target.add_to_group(group, true)
	_mark_scene_modified()
	return { "status": "success", "message": "Nó '%s' adicionado ao grupo '%s'." % [target.name, group] }

func _remove_from_group(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	var group := str(params.get("group", ""))
	if not target or group == "":
		return { "status": "error", "message": "Parâmetros: 'node_path' e 'group'." }
	target.remove_from_group(group)
	_mark_scene_modified()
	return { "status": "success", "message": "Nó '%s' removido do grupo '%s'." % [target.name, group] }

# ==============================================================================
# crom-godot-mcp — Fase 7: recursos e projeto (leitura)
# ==============================================================================

func _get_project_setting(params: Dictionary) -> Dictionary:
	var setting := str(params.get("setting", ""))
	if setting == "":
		return { "status": "error", "message": "Parâmetro 'setting' obrigatório." }
	if not ProjectSettings.has_setting(setting):
		return { "status": "success", "exists": false, "message": "Configuração '%s' não definida (usa o padrão)." % setting }
	return { "status": "success", "exists": true, "setting": setting, "value": ProjectSettings.get_setting(setting) }

func _list_input_actions() -> Dictionary:
	var actions: Array[String] = []
	for a in InputMap.get_actions():
		actions.append(str(a))
	return { "status": "success", "actions": actions }

func _create_resource(params: Dictionary) -> Dictionary:
	var res_type := str(params.get("resource_type", ""))
	var save_path := str(params.get("save_path", ""))
	if res_type == "" or not ClassDB.class_exists(res_type):
		return { "status": "error", "message": "resource_type inválido: '%s'." % res_type }
	if not ClassDB.is_parent_class(res_type, "Resource"):
		return { "status": "error", "message": "'%s' não é um Resource." % res_type }
	var res = ClassDB.instantiate(res_type)
	if not (res is Resource):
		return { "status": "error", "message": "Falha ao instanciar '%s'." % res_type }
	if params.has("properties") and params["properties"] is Dictionary:
		for k in params["properties"]:
			if k in res:
				res.set(k, _coerce_value(res, k, params["properties"][k]))
	if save_path != "":
		var dir := save_path.get_base_dir()
		if dir != "" and dir != "res://" and not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		var e := ResourceSaver.save(res, save_path)
		if e != OK:
			return { "status": "error", "message": "Falha ao salvar recurso (erro %d)." % e }
		_refresh_editor_filesystem()
		return { "status": "success", "message": "Recurso %s salvo em %s." % [res_type, save_path], "save_path": save_path }
	return { "status": "success", "message": "Recurso %s criado (não salvo — informe save_path para persistir)." % res_type }

# ==============================================================================
# crom-godot-mcp — Fase 4: simulação de input (para testar jogabilidade)
# ==============================================================================

func _simulate_key(params: Dictionary) -> Dictionary:
	var key_name := str(params.get("key", "")).strip_edges()
	if key_name == "":
		return { "status": "error", "message": "Parâmetro 'key' obrigatório (ex: Up, W, Space, Enter)." }
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return { "status": "error", "message": "Tecla desconhecida: '%s'." % key_name }
	var pressed := bool(params.get("pressed", true))
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
	return { "status": "success", "message": "Tecla '%s' (%s) enviada." % [key_name, "pressed" if pressed else "released"] }

func _simulate_action(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", "")).strip_edges()
	if action == "":
		return { "status": "error", "message": "Parâmetro 'action' obrigatório (ex: ui_accept, jump)." }
	var pressed := bool(params.get("pressed", true))
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	return { "status": "success", "message": "Ação '%s' (%s) simulada." % [action, "press" if pressed else "release"] }
