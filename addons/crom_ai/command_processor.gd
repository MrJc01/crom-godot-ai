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
	var parse_result: Variant = JSON.parse_string(command_json)
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
		"add_nodes_batch":
			return _add_nodes_batch(params)
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
		"set_main_scene":
			return _set_main_scene(params)
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
		"class_reference":
			return _class_reference(params)
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
		"get_runtime_scene_tree":
			return _query_runtime("get_tree", {})
		"get_runtime_property":
			return _query_runtime("get_property", params)
		"record_property_over_time":
			return _record_property_over_time(params)

		# ======================================================================
		# 1c. NOVAS FERRAMENTAS MCP (script edit, TileMap, Animation, Camera, Docs)
		# ======================================================================
		"set_script_source":
			return _set_script_source(params)
		"detach_script":
			return _detach_script(params)
		"set_tilemap_cell":
			return _set_tilemap_cell(params)
		"get_tilemap_cells":
			return _get_tilemap_cells(params)
		"list_animations":
			return _list_animations(params)
		"play_animation":
			return _play_animation(params)
		"set_camera_target":
			return _set_camera_target(params)
		"docs_search":
			return _docs_search(params)
		"verify_playable":
			return _verify_playable(params)
		"set_game_node_property":
			return _query_runtime("set_property", params)
		"get_game_node_properties":
			return _query_runtime("get_properties", params)
		"find_ui_elements":
			return _query_runtime("find_nodes", params)
		"click_button_by_text":
			return _query_runtime("click_button", params)
		"assert_node_state":
			return _assert_node_state(params)
		"assert_screen_text":
			return _assert_screen_text(params)
		"wait_for_node":
			return _wait_for_node(params)
		"get_node_properties":
			return _get_node_properties(params)
		"disconnect_signal":
			return _disconnect_signal(params)
		"find_nodes_in_group":
			return _find_nodes_in_group(params)
		"get_node_groups":
			return _get_node_groups(params)
		"delete_scene":
			return _delete_scene(params)
		"get_project_info":
			return _get_project_info()
		"search_files":
			return _search_files(params)
		"setup_physics_body":
			return _setup_physics_body(params)
		"set_physics_layers":
			return _set_physics_layers(params)
		"get_physics_layers":
			return _get_physics_layers(params)
		"add_raycast":
			return _add_raycast(params)
		"create_animation":
			return _create_animation(params)
		"add_animation_track":
			return _add_animation_track(params)
		"set_animation_keyframe":
			return _set_animation_keyframe(params)

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
		
	var tree_data: Dictionary = _serialize_node_tree(scene_root, scene_root)
	return { "status": "success", "scene_root_name": scene_root.name, "tree": tree_data }

func _serialize_node_tree(node: Node, scene_root: Node) -> Dictionary:
	var children_data = []
	for child in node.get_children():
		children_data.append(_serialize_node_tree(child, scene_root))

	var props = {
		"position": node.position if "position" in node else null,
		"visible": node.visible if "visible" in node else true
	}
	# Caminho RELATIVO à raiz da cena ("." para a raiz, "Player/Col" para filhos)
	# — é o que as ferramentas aceitam em node_path. Nunca o get_path() absoluto.
	var rel := "." if node == scene_root else str(scene_root.get_path_to(node))
	return {
		"name": node.name,
		"type": node.get_class(),
		"path": rel,
		"properties": props,
		"children": children_data
	}

func _add_node(params: Dictionary) -> Dictionary:
	var node_type: String = str(params.get("node_type", "Node"))
	var node_name: String = str(params.get("node_name", "NewNode"))
	var parent_path: String = str(params.get("parent_path", "."))
	
	if not ClassDB.class_exists(node_type):
		return { "status": "error", "message": "Classe/Tipo de nó desconhecido: '%s'." % node_type }
		
	var new_node: Variant = ClassDB.instantiate(node_type)
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
	# Caminho RELATIVO à raiz da cena (ex: "Player/Col") — é o que as outras
	# ferramentas esperam. NUNCA devolver o get_path() absoluto (inclui a
	# hierarquia interna do editor e quebra chamadas seguintes).
	var rel_path := str(scene_root.get_path_to(new_node))
	return { "status": "success", "message": "Nó '%s' (%s) adicionado em '%s'. Use node_path='%s'." % [node_name, node_type, parent_node.name, rel_path], "node_path": rel_path }

# Cria vários nós de uma vez (uma subárvore). Reduz round-trips — o modelo monta
# a cena inteira num passo. Processa em ordem: pais antes dos filhos. Cada item é
# {node_type, node_name, parent_path, properties} como em add_node.
func _add_nodes_batch(params: Dictionary) -> Dictionary:
	var specs: Variant = params.get("nodes", [])
	if not (specs is Array) or specs.is_empty():
		return { "status": "error", "message": "Envie 'nodes' como um array de {node_type, node_name, parent_path, properties}." }
	var results: Array = []
	var created := 0
	var failed := 0
	for spec in specs:
		if not (spec is Dictionary):
			results.append({ "status": "error", "message": "item inválido (esperado objeto)." })
			failed += 1
			continue
		var r := _add_node(spec)
		results.append(r)
		if r.get("status") == "success":
			created += 1
		else:
			failed += 1
	return {
		"status": "success" if failed == 0 else "partial",
		"created": created,
		"failed": failed,
		"results": results,
		"message": "%d nó(s) criado(s), %d falha(s)." % [created, failed]
	}

# Define a cena principal do projeto (application/run/main_scene) e salva. Um jogo
# PRECISA de cena principal para rodar (F5) e exportar.
func _set_main_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = str(params.get("scene_path", ""))
	if scene_path == "" or not scene_path.ends_with(".tscn"):
		return { "status": "error", "message": "Informe 'scene_path' terminando em .tscn." }
	if not FileAccess.file_exists(scene_path):
		return { "status": "error", "message": "Cena '%s' não existe no disco. Crie-a antes com godot_create_scene/godot_save_scene." % scene_path }
	ProjectSettings.set_setting("application/run/main_scene", scene_path)
	var err := ProjectSettings.save()
	if err != OK:
		return { "status": "error", "message": "Falha ao salvar project.godot (erro %d)." % err }
	return { "status": "success", "message": "Cena principal definida como '%s'." % scene_path }

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
	var value: Variant = params.get("value")
	
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

# Converte Arrays/Strings JSON em tipos nativos (Vector2/3, Color, recursos)
# baseado no valor atual da propriedade.
func _coerce_value(target: Object, property_name: String, value: Variant) -> Variant:
	# Recurso INLINE: {"__resource_type":"RectangleShape2D","size":[32,32]} cria o
	# recurso e o atribui — permite configurar shape de colisão, StyleBox, etc.
	# numa única chamada de add_node/set_node_property.
	if value is Dictionary and (value.has("__resource_type") or value.has("__resource")):
		var res_type: String = str(value.get("__resource_type", value.get("__resource", "")))
		if ClassDB.class_exists(res_type) and ClassDB.is_parent_class(res_type, "Resource"):
			var res: Variant = ClassDB.instantiate(res_type)
			for k in value:
				if k != "__resource_type" and k != "__resource" and k in res:
					res.set(k, _coerce_value(res, k, value[k]))
			return res

	# Caminho res:// para um recurso já no disco (textura de Sprite2D, .tres de
	# shape, PackedScene...) -> carrega e atribui o Resource, não a String.
	if value is String and value.begins_with("res://") and ResourceLoader.exists(value):
		var loaded: Resource = load(value)
		if loaded != null:
			return loaded

	var current: Variant = target.get(property_name)
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

# Caminho de um nó RELATIVO à raiz da cena editada ("." p/ raiz, "Player/Col").
# É o formato que todas as ferramentas aceitam; nunca devolver get_path() absoluto.
func _rel_path(node: Node) -> String:
	var root := _get_edited_scene_root()
	if root and node:
		return "." if node == root else str(root.get_path_to(node))
	return str(node.get_path()) if node else ""

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
		var sc: Variant = to_node.get_script()
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
	var pos: Variant = params.get("position")
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
	return { "status": "success", "message": "Nó '%s' renomeado para '%s'." % [old_name, target.name], "node_path": _rel_path(target) }

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
	return { "status": "success", "message": "Nó '%s' movido para debaixo de '%s'." % [target.name, new_parent.name], "node_path": _rel_path(target) }

func _create_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = str(params.get("scene_path", ""))
	var root_type: String = str(params.get("root_type", "Node2D"))
	var root_name: String = str(params.get("root_name", scene_path.get_file().get_basename().to_pascal_case()))

	if scene_path == "" or not scene_path.ends_with(".tscn"):
		return { "status": "error", "message": "O parâmetro 'scene_path' deve terminar em .tscn." }
	if not ClassDB.class_exists(root_type) or not ClassDB.is_parent_class(root_type, "Node"):
		return { "status": "error", "message": "Tipo de nó raiz inválido: '%s'." % root_type }

	var root: Variant = ClassDB.instantiate(root_type)
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
	var packed: Variant = load(scene_path)
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
	return { "status": "success", "message": "Instância de '%s' adicionada em '%s'." % [scene_path, parent_node.name], "node_path": _rel_path(instance) }

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
	var keys: Variant = params.get("keys", [])
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

	# CACHE_MODE_REPLACE: recarrega do disco e substitui o recurso em cache. Sem
	# isso, uma 2ª chamada (correção de bug) receberia o script ANTIGO em cache,
	# quebrando o loop "vê erro -> corrige -> reverifica".
	var loaded_script: Resource = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
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
	var click_pos: Variant = params.get("click_position", null)
	
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
	var img: Image = vp.get_texture().get_image()
	if not img:
		return { "status": "error", "message": "Falha ao obter imagem do viewport." }
	img.resize(640, 360) # Redimensiona para economizar tokens
	var buffer: PackedByteArray = img.save_png_to_buffer()
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
	var file_name: String = dir.get_next()
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
	var start: int = int(_log_baseline if _log_baseline > 0 and _log_baseline < size else maxi(0, size - max_bytes))
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
	var startn: int = int(maxi(0, lines.size() - n))
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
	var sc: Variant = target.get_script()
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

# Documentação viva: consulta a API AUTORITATIVA da versão do Godot em uso via
# ClassDB. Dá ao agente a assinatura correta (Godot 4) de qualquer classe ANTES
# de escrever código — evita drift Godot 3 (move_and_slide(v) x move_and_slide()).
# Se a classe não existir exatamente, devolve nomes de classes parecidos (busca).
func _class_reference(params: Dictionary) -> Dictionary:
	var cls := str(params.get("class_name", params.get("query", ""))).strip_edges()
	if cls == "":
		return { "status": "error", "message": "Informe 'class_name' (ex.: CharacterBody2D)." }
	if not ClassDB.class_exists(cls):
		# Busca fuzzy: classes cujo nome contém o termo (case-insensitive).
		var q := cls.to_lower()
		var matches: Array[String] = []
		for c in ClassDB.get_class_list():
			if str(c).to_lower().contains(q):
				matches.append(str(c))
				if matches.size() >= 30:
					break
		matches.sort()
		if matches.is_empty():
			return { "status": "error", "message": "Classe '%s' não existe e nada parecido foi encontrado." % cls }
		return { "status": "success", "query": cls, "did_you_mean": matches, "message": "Classe exata não encontrada. Classes parecidas: %s" % ", ".join(matches) }

	var methods: Array[String] = []
	for m in ClassDB.class_get_method_list(cls, false):
		var mn := str(m.get("name", ""))
		if mn.begins_with("_") and not (mn == "_ready" or mn == "_process" or mn == "_physics_process" or mn == "_input" or mn == "_draw"):
			continue
		var arg_parts: Array[String] = []
		for a in m.get("args", []):
			arg_parts.append("%s: %s" % [str(a.get("name", "arg")), type_string(int(a.get("type", 0)))])
		var ret := type_string(int(m.get("return", {}).get("type", 0)))
		methods.append("%s(%s) -> %s" % [mn, ", ".join(arg_parts), ret])
		if methods.size() >= 120:
			break

	var props: Array[String] = []
	for p in ClassDB.class_get_property_list(cls, false):
		var pn := str(p.get("name", ""))
		if pn != "" and not pn.begins_with("_"):
			props.append(pn)
		if props.size() >= 80:
			break

	var signals: Array[String] = []
	for s in ClassDB.class_get_signal_list(cls, false):
		var sn := str(s.get("name", ""))
		var sargs: Array[String] = []
		for a in s.get("args", []):
			sargs.append(str(a.get("name", "arg")))
		signals.append("%s(%s)" % [sn, ", ".join(sargs)])

	var constants: Array[String] = []
	for c in ClassDB.class_get_integer_constant_list(cls, false):
		constants.append(str(c))
		if constants.size() >= 60:
			break

	return {
		"status": "success",
		"class": cls,
		"inherits": ClassDB.get_parent_class(cls),
		"instantiable": ClassDB.can_instantiate(cls),
		"methods": methods,
		"properties": props,
		"signals": signals,
		"constants": constants,
		"message": "API Godot %s de %s (via ClassDB — autoritativa para esta versão)." % [Engine.get_version_info().get("string", "4.x"), cls]
	}

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
	return { "status": "success", "message": "Nó duplicado como '%s'." % dup.name, "node_path": _rel_path(dup) }

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
	var res: Variant = ClassDB.instantiate(res_type)
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

# ==============================================================================
# crom-godot-mcp — Fase 2: inspeção do JOGO EM EXECUÇÃO (via autoload CromRuntime)
# O editor não enxerga o processo do jogo; consultamos o servidor WS 8091 que o
# autoload crom_runtime.gd abre dentro do jogo rodado por play_scene.
# ==============================================================================

const _RUNTIME_PORT := 8091

# Consulta síncrona (com polling e timeout) ao jogo em execução.
func _query_runtime(action: String, params: Dictionary, timeout_ms: int = 2500) -> Dictionary:
	var ws := WebSocketPeer.new()
	if ws.connect_to_url("ws://127.0.0.1:%d" % _RUNTIME_PORT) != OK:
		return { "status": "error", "message": "Jogo não está rodando. Chame play_scene e aguarde ~1s antes de consultar o runtime." }
	var t0 := Time.get_ticks_msec()
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_CLOSED or (Time.get_ticks_msec() - t0) > timeout_ms:
			return { "status": "error", "message": "Jogo não respondeu na porta 8091. Rode play_scene e aguarde o jogo iniciar." }
		OS.delay_msec(20)
	ws.send_text(JSON.stringify({ "action": action, "params": params }))
	while (Time.get_ticks_msec() - t0) < timeout_ms:
		ws.poll()
		if ws.get_available_packet_count() > 0:
			var resp := ws.get_packet().get_string_from_utf8()
			ws.close()
			var parsed: Variant = JSON.parse_string(resp)
			return parsed if parsed is Dictionary else { "status": "error", "message": "Resposta inválida do jogo." }
		OS.delay_msec(20)
	ws.close()
	return { "status": "error", "message": "Timeout ao consultar o jogo em execução." }

# Amostra uma propriedade de um nó ao longo de N leituras — prova de movimento.
# Composite do FEEDBACK LOOP: roda a cena, espera o boot, checa erros de console
# e detecta se algo se move em runtime — e devolve um veredito único de "jogável".
# Fecha o loop que o agente precisa: montou -> rodou -> viu -> corrige/finaliza.
func _verify_playable(params: Dictionary) -> Dictionary:
	if not (editor_plugin and editor_plugin.get_editor_interface()):
		return { "status": "error", "message": "EditorInterface indisponível para rodar cena." }
	var scene_path: String = str(params.get("scene_path", ""))
	if scene_path == "":
		scene_path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var node_path: String = str(params.get("node_path", "."))
	var prop: String = str(params.get("property", "position"))
	var boot_wait_ms: int = clampi(int(params.get("boot_wait_ms", 2000)), 500, 8000)
	var check_movement: bool = bool(params.get("check_movement", true))

	# FASE A — validação AUTORITATIVA de erros via processo HEADLESS com stderr
	# capturado. O log do editor NÃO captura os erros de runtime do jogo (processo
	# separado), então rodar a cena headless é a única forma confiável de vê-los.
	var hv := _headless_validate(scene_path, 90)
	var error_list: Array = hv.get("errors", [])
	var has_errors: bool = error_list.size() > 0

	# FASE B — movimento (só se não houver erros; roda a cena no editor e consulta
	# o runtime na porta 8091). Erro já reprova sem precisar checar movimento.
	var movement: Variant = null  # null = não verificado
	var movement_detail := ""
	if not has_errors and check_movement:
		_play_scene({ "scene_path": scene_path })
		OS.delay_msec(boot_wait_ms)
		var rec := _record_property_over_time({ "node_path": node_path, "property": prop, "samples": 5, "interval_ms": 250 })
		if rec.get("status") == "success":
			movement = bool(rec.get("changed"))
			movement_detail = str(rec.get("message", ""))
		else:
			movement_detail = "runtime não respondeu (CromRuntime ausente ou cena não bootou): " + str(rec.get("message", ""))
		_stop_scene()

	# veredito
	var playable := not has_errors
	var verdict := ""
	if has_errors:
		verdict = "❌ NÃO jogável: %d erro(s) ao rodar (headless). Corrija-os e rode verify_playable de novo." % error_list.size()
	elif movement == false:
		verdict = "⚠️ Roda SEM erros, mas '%s.%s' não muda — nada se move. Verifique input/timer/sinais e process()." % [node_path, prop]
	elif movement == true:
		verdict = "✅ Jogável: 0 erros e movimento detectado em '%s.%s'." % [node_path, prop]
	else:
		verdict = "✅ Roda sem erros (headless). Movimento não verificado (runtime offline) — confira manualmente se algo deveria se mover."
	return {
		"status": "success",
		"playable": playable,
		"has_errors": has_errors,
		"error_count": error_list.size(),
		"errors": error_list,
		"movement_detected": movement,
		"movement_detail": movement_detail,
		"message": verdict
	}

# Roda a cena num processo HEADLESS separado por N frames e captura stdout+stderr,
# extraindo os erros (SCRIPT ERROR / Parse Error / etc.). É a fonte autoritativa
# de erros de execução — o log do editor não vê o processo do jogo.
func _headless_validate(scene_path: String, frames: int) -> Dictionary:
	if scene_path == "" or not scene_path.ends_with(".tscn"):
		return { "status": "error", "errors": [], "message": "scene_path inválido para validação headless." }
	var bin := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var output: Array = []
	# read_stderr=true funde o stderr (onde vão os SCRIPT ERROR) na saída capturada.
	var code := OS.execute(bin, ["--headless", "--path", proj, scene_path, "--quit-after", str(max(30, frames))], output, true)
	var raw := ""
	if output.size() > 0:
		raw = str(output[0])
	var errors: Array[String] = []
	for line in raw.split("\n"):
		var l := String(line).strip_edges()
		if l.contains("SCRIPT ERROR") or l.contains("Parse Error") or l.begins_with("ERROR:") or l.contains("Nonexistent") or l.contains("Invalid call") or l.contains("Failed to load") or l.contains("Can't create"):
			errors.append(l)
	return { "status": "success", "errors": errors, "return_code": code }

# QA: afirma que uma propriedade de um nó no JOGO EM EXECUÇÃO tem o valor esperado.
func _assert_node_state(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "."))
	var prop := str(params.get("property", ""))
	var expected := str(params.get("expected", ""))
	var r := _query_runtime("get_property", { "node_path": node_path, "property": prop })
	if r.get("status") != "success":
		return r
	var actual := str(r.get("value", ""))
	var ok := actual == expected or actual.contains(expected)
	return {
		"status": "success", "passed": ok, "node": node_path, "property": prop,
		"expected": expected, "actual": actual,
		"message": ("✅ ASSERT OK: %s.%s == %s" % [node_path, prop, expected]) if ok else ("❌ ASSERT FALHOU: %s.%s = %s (esperado: %s)" % [node_path, prop, actual, expected])
	}

# QA: afirma que um texto aparece na tela do jogo (Labels/Buttons visíveis).
func _assert_screen_text(params: Dictionary) -> Dictionary:
	var expected := str(params.get("text", ""))
	var r := _query_runtime("get_screen_text", {})
	if r.get("status") != "success":
		return r
	var texts: Array = r.get("texts", [])
	var found := false
	for t in texts:
		if str(t).contains(expected):
			found = true
			break
	return {
		"status": "success", "passed": found, "expected": expected, "screen_texts": texts,
		"message": ("✅ Texto '%s' está na tela." % expected) if found else ("❌ Texto '%s' NÃO está na tela. Textos: %s" % [expected, str(texts)])
	}

# Espera um nó aparecer no jogo em execução (polling com timeout).
func _wait_for_node(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", ""))
	var timeout_ms := clampi(int(params.get("timeout_ms", 3000)), 200, 10000)
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < timeout_ms:
		var r := _query_runtime("node_exists", { "node_path": node_path })
		if r.get("status") == "success" and bool(r.get("exists", false)):
			return { "status": "success", "found": true, "node_path": node_path, "message": "Nó '%s' apareceu." % node_path }
		OS.delay_msec(150)
	return { "status": "success", "found": false, "node_path": node_path, "message": "Nó '%s' não apareceu em %dms." % [node_path, timeout_ms] }

# Lista TODAS as propriedades editáveis de um nó na cena EDITADA (no editor).
func _get_node_properties(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var props: Dictionary = {}
	for p in target.get_property_list():
		var pn := str(p.get("name", ""))
		if pn != "" and not pn.begins_with("_") and (int(p.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0:
			props[pn] = var_to_str(target.get(pn))
	return { "status": "success", "node": str(target.name), "type": target.get_class(), "properties": props }

# Desconecta um sinal de um nó (o inverso de connect_signal).
func _disconnect_signal(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var from_path := str(params.get("from_node", params.get("node_path", ".")))
	var signal_name := str(params.get("signal", ""))
	var to_path := str(params.get("to_node", "."))
	var method := str(params.get("method", ""))
	if signal_name == "" or method == "":
		return { "status": "error", "message": "Parâmetros obrigatórios: 'signal' e 'method'." }
	var from_node: Node = scene_root if from_path in [".", ""] else scene_root.get_node_or_null(from_path)
	var to_node: Node = scene_root if to_path in [".", ""] else scene_root.get_node_or_null(to_path)
	if not from_node or not to_node:
		return { "status": "error", "message": "Nó emissor ou receptor não encontrado." }
	var cb := Callable(to_node, method)
	if not from_node.is_connected(signal_name, cb):
		return { "status": "error", "message": "Sinal '%s' não estava conectado a '%s'." % [signal_name, method] }
	from_node.disconnect(signal_name, cb)
	_mark_scene_modified()
	return { "status": "success", "message": "Sinal '%s' desconectado de '%s'." % [signal_name, method] }

# Retorna os nós da cena editada que pertencem a um grupo.
func _find_nodes_in_group(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var group := str(params.get("group", ""))
	if group == "":
		return { "status": "error", "message": "Parâmetro 'group' obrigatório." }
	var found: Array = []
	_collect_group_nodes(scene_root, scene_root, group, found)
	return { "status": "success", "group": group, "count": found.size(), "nodes": found }

func _collect_group_nodes(node: Node, scene_root: Node, group: String, out: Array) -> void:
	if node.is_in_group(group):
		out.append(str(scene_root.get_path_to(node)) if node != scene_root else ".")
	for c in node.get_children():
		_collect_group_nodes(c, scene_root, group, out)

# Grupos aos quais um nó pertence.
func _get_node_groups(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var groups: Array = []
	for g in target.get_groups():
		var gs := str(g)
		if not gs.begins_with("_"):
			groups.append(gs)
	return { "status": "success", "node": str(target.name), "groups": groups }

# Apaga um arquivo de cena .tscn do disco.
func _delete_scene(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", ""))
	if scene_path == "" or not scene_path.ends_with(".tscn"):
		return { "status": "error", "message": "Informe 'scene_path' terminando em .tscn." }
	if not FileAccess.file_exists(scene_path):
		return { "status": "error", "message": "Cena '%s' não existe." % scene_path }
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_path))
	if err != OK:
		return { "status": "error", "message": "Falha ao apagar (erro %d)." % err }
	_refresh_editor_filesystem()
	return { "status": "success", "message": "Cena '%s' apagada." % scene_path }

# Informações gerais do projeto.
func _get_project_info() -> Dictionary:
	return {
		"status": "success",
		"name": str(ProjectSettings.get_setting("application/config/name", "")),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"godot_version": str(Engine.get_version_info().get("string", "")),
		"features": var_to_str(ProjectSettings.get_setting("application/config/features", []))
	}

# Busca arquivos por nome (e opcionalmente conteúdo) sob res://.
func _search_files(params: Dictionary) -> Dictionary:
	var query := str(params.get("query", ""))
	if query == "":
		return { "status": "error", "message": "Parâmetro 'query' obrigatório." }
	var search_content := bool(params.get("search_content", false))
	var results: Array = []
	_walk_search("res://", query.to_lower(), search_content, results)
	return { "status": "success", "query": query, "count": results.size(), "files": results }

func _walk_search(dir: String, q: String, search_content: bool, out: Array) -> void:
	if out.size() >= 100:
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "" and out.size() < 100:
		if f in [".", ".."] or f.begins_with(".godot") or f == ".crom":
			f = d.get_next()
			continue
		var full := dir.path_join(f)
		if d.current_is_dir():
			_walk_search(full, q, search_content, out)
		else:
			var hit := f.to_lower().contains(q)
			if not hit and search_content and (f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres")):
				var content := FileAccess.get_file_as_string(full)
				hit = content.to_lower().contains(q)
			if hit:
				out.append(full)
		f = d.get_next()
	d.list_dir_end()

# Cria um corpo físico 2D com CollisionShape2D + shape num único passo.
func _setup_physics_body(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var body_type := str(params.get("body_type", "CharacterBody2D"))
	if not ClassDB.class_exists(body_type) or not ClassDB.is_parent_class(body_type, "CollisionObject2D"):
		return { "status": "error", "message": "body_type inválido: '%s' (use CharacterBody2D, RigidBody2D, StaticBody2D, Area2D)." % body_type }
	var parent_path := str(params.get("parent_path", "."))
	var parent: Node = scene_root if parent_path in [".", ""] else scene_root.get_node_or_null(parent_path)
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado em '%s'." % parent_path }
	var body: Node = ClassDB.instantiate(body_type)
	body.name = str(params.get("node_name", body_type))
	parent.add_child(body)
	body.owner = scene_root
	if params.has("position"):
		body.set("position", _coerce_value(body, "position", params.get("position")))
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	body.add_child(col)
	col.owner = scene_root
	var shape_type := str(params.get("shape_type", "RectangleShape2D"))
	if ClassDB.class_exists(shape_type) and ClassDB.is_parent_class(shape_type, "Shape2D"):
		var shape: Shape2D = ClassDB.instantiate(shape_type)
		if shape is RectangleShape2D and params.has("size"):
			shape.size = _coerce_value(shape, "size", params.get("size"))
		elif shape is CircleShape2D and params.has("radius"):
			shape.radius = float(params.get("radius"))
		col.shape = shape
	_mark_scene_modified()
	return { "status": "success", "body": _rel_path(body), "collision_shape": _rel_path(col), "message": "%s '%s' com CollisionShape2D criado." % [body_type, body.name] }

# Define collision_layer / collision_mask de um corpo físico.
func _set_physics_layers(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("collision_layer" in target):
		return { "status": "error", "message": "Nó não é um corpo físico (sem collision_layer)." }
	if params.has("layer"):
		target.set("collision_layer", int(params.get("layer")))
	if params.has("mask"):
		target.set("collision_mask", int(params.get("mask")))
	_mark_scene_modified()
	return { "status": "success", "collision_layer": int(target.get("collision_layer")), "collision_mask": int(target.get("collision_mask")) }

# Lê collision_layer / collision_mask de um corpo físico.
func _get_physics_layers(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("collision_layer" in target):
		return { "status": "error", "message": "Nó não é um corpo físico (sem collision_layer)." }
	return { "status": "success", "collision_layer": int(target.get("collision_layer")), "collision_mask": int(target.get("collision_mask")) }

# Adiciona um RayCast2D a um nó pai.
func _add_raycast(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var parent_path := str(params.get("parent_path", "."))
	var parent: Node = scene_root if parent_path in [".", ""] else scene_root.get_node_or_null(parent_path)
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var ray := RayCast2D.new()
	ray.name = str(params.get("node_name", "RayCast2D"))
	if params.has("target_position"):
		ray.target_position = _coerce_value(ray, "target_position", params.get("target_position"))
	ray.enabled = bool(params.get("enabled", true))
	parent.add_child(ray)
	ray.owner = scene_root
	_mark_scene_modified()
	return { "status": "success", "raycast": _rel_path(ray), "message": "RayCast2D '%s' adicionado." % ray.name }

# Cria uma Animation vazia num AnimationPlayer (na biblioteca padrão "").
func _create_animation(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not (target is AnimationPlayer):
		return { "status": "error", "message": "node_path precisa apontar para um AnimationPlayer." }
	var player := target as AnimationPlayer
	var anim_name := str(params.get("animation_name", ""))
	if anim_name == "":
		return { "status": "error", "message": "Parâmetro 'animation_name' obrigatório." }
	var lib: AnimationLibrary
	if player.has_animation_library(""):
		lib = player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	if lib.has_animation(anim_name):
		return { "status": "error", "message": "Animação '%s' já existe." % anim_name }
	var anim := Animation.new()
	anim.length = float(params.get("length", 1.0))
	anim.loop_mode = Animation.LOOP_LINEAR if bool(params.get("loop", false)) else Animation.LOOP_NONE
	lib.add_animation(anim_name, anim)
	_mark_scene_modified()
	return { "status": "success", "message": "Animação '%s' criada (%.2fs)." % [anim_name, anim.length] }

# Adiciona uma track de VALOR (nó:propriedade) a uma animação existente.
func _add_animation_track(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not (target is AnimationPlayer):
		return { "status": "error", "message": "node_path precisa apontar para um AnimationPlayer." }
	var player := target as AnimationPlayer
	var anim_name := str(params.get("animation_name", ""))
	var track_path := str(params.get("track_path", ""))
	if anim_name == "" or track_path == "":
		return { "status": "error", "message": "Parâmetros 'animation_name' e 'track_path' (ex: 'Sprite2D:position') obrigatórios." }
	if not player.has_animation(anim_name):
		return { "status": "error", "message": "Animação '%s' não existe." % anim_name }
	var anim := player.get_animation(anim_name)
	var idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath(track_path))
	_mark_scene_modified()
	return { "status": "success", "track_index": idx, "message": "Track de valor '%s' adicionada à animação '%s'." % [track_path, anim_name] }

# Insere um keyframe numa track (por índice OU por track_path).
func _set_animation_keyframe(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not (target is AnimationPlayer):
		return { "status": "error", "message": "node_path precisa apontar para um AnimationPlayer." }
	var player := target as AnimationPlayer
	var anim_name := str(params.get("animation_name", ""))
	if not player.has_animation(anim_name):
		return { "status": "error", "message": "Animação '%s' não existe." % anim_name }
	var anim := player.get_animation(anim_name)
	var track_idx := int(params.get("track_index", -1))
	if track_idx < 0 and params.has("track_path"):
		track_idx = anim.find_track(NodePath(str(params.get("track_path"))), Animation.TYPE_VALUE)
	if track_idx < 0 or track_idx >= anim.get_track_count():
		return { "status": "error", "message": "Track não encontrada (informe track_index ou track_path válido)." }
	var time := float(params.get("time", 0.0))
	anim.track_insert_key(track_idx, time, params.get("value"))
	_mark_scene_modified()
	return { "status": "success", "message": "Keyframe inserido em t=%.2fs na track %d." % [time, track_idx] }

func _record_property_over_time(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", "."))
	var prop := str(params.get("property", "position"))
	var samples := clampi(int(params.get("samples", 5)), 2, 20)
	var interval := clampi(int(params.get("interval_ms", 250)), 50, 1000)
	var values: Array[String] = []
	for i in range(samples):
		var r := _query_runtime("get_property", { "node_path": node_path, "property": prop })
		if r.get("status") != "success":
			if values.is_empty():
				return r
			break
		values.append(str(r.get("value")))
		if i < samples - 1:
			OS.delay_msec(interval)
	var changed := values.size() > 1 and values[0] != values[values.size() - 1]
	return {
		"status": "success",
		"node": node_path,
		"property": prop,
		"samples": values,
		"changed": changed,
		"message": ("'%s.%s' MUDOU ao longo do tempo — movimento/animação detectado." % [node_path, prop]) if changed else ("'%s.%s' NÃO mudou — nada se move (possível bug: timer parado, sinal não conectado, etc.)." % [node_path, prop])
	}

# ==============================================================================
# crom-godot-mcp — Ferramentas MCP adicionais (script edit, TileMap, Animation,
# Camera2D, docs_search)
# ==============================================================================

# Altera o código-fonte de um script que já está anexado a um nó (ou de um .gd
# no disco via script_path). Não recria o nó — só substitui o source_code.
func _set_script_source(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", ""))
	var script_path: String = str(params.get("script_path", ""))
	var code: String = str(params.get("gdscript_code", params.get("code", "")))
	if code == "":
		return { "status": "error", "message": "O parâmetro 'gdscript_code' é obrigatório." }

	var target_script: Script = null
	var resolved_path := script_path

	# Via node_path: pega o script do nó
	if node_path != "":
		var scene_root := _get_edited_scene_root()
		if not scene_root:
			return { "status": "error", "message": "Nenhuma cena aberta no editor." }
		var target: Node = _resolve_node(scene_root, node_path)
		if not target:
			return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }
		target_script = target.get_script() as Script
		if not target_script:
			return { "status": "error", "message": "O nó '%s' não tem script anexado. Use godot_create_and_attach_script para criar." % target.name }
		resolved_path = target_script.resource_path

	# Via script_path: carrega o script do disco
	elif script_path != "":
		if not FileAccess.file_exists(script_path):
			return { "status": "error", "message": "Script não encontrado: '%s'." % script_path }
		target_script = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
		if not target_script:
			return { "status": "error", "message": "Falha ao carregar o script '%s'." % script_path }
	else:
		return { "status": "error", "message": "Informe 'node_path' ou 'script_path'." }

	# Escreve no disco e recarrega
	if resolved_path != "":
		var f: FileAccess = FileAccess.open(resolved_path, FileAccess.WRITE)
		if not f:
			return { "status": "error", "message": "Falha ao escrever em '%s'." % resolved_path }
		f.store_string(code)
		f.close()
		_refresh_editor_filesystem()
		ResourceLoader.load(resolved_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
	return { "status": "success", "message": "Source de '%s' atualizado (%d bytes)." % [resolved_path, code.length()], "script_path": resolved_path }

# Remove o script de um nó sem excluir o arquivo .gd do disco.
func _detach_script(params: Dictionary) -> Dictionary:
	var node_path: String = str(params.get("node_path", "."))
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }
	if not target.get_script():
		return { "status": "success", "message": "O nó '%s' já não tem script." % target.name }
	var old_path: String = ""
	var sc: Script = target.get_script() as Script
	if sc:
		old_path = sc.resource_path
	target.set_script(null)
	_mark_scene_modified()
	return { "status": "success", "message": "Script removido do nó '%s'.%s" % [target.name, (" O arquivo '%s' permanece no disco." % old_path) if old_path != "" else ""] }

# --- TileMap helpers ---

# Define uma célula no TileMapLayer (Godot 4.3+). Para TileMap legado, usa set_cell.
func _set_tilemap_cell(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var node_path: String = str(params.get("node_path", "."))
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	var coords_raw: Variant = params.get("coords", [0, 0])
	if not (coords_raw is Array) or coords_raw.size() < 2:
		return { "status": "error", "message": "'coords' deve ser [x, y]." }
	var coords := Vector2i(int(coords_raw[0]), int(coords_raw[1]))
	var source_id: int = int(params.get("source_id", 0))
	var atlas_raw: Variant = params.get("atlas_coords", [0, 0])
	var atlas_coords := Vector2i(int(atlas_raw[0]) if atlas_raw is Array and atlas_raw.size() >= 2 else 0, int(atlas_raw[1]) if atlas_raw is Array and atlas_raw.size() >= 2 else 0)
	var alt_id: int = int(params.get("alternative_tile", 0))

	# TileMapLayer (Godot 4.3+)
	if target is TileMapLayer:
		target.set_cell(coords, source_id, atlas_coords, alt_id)
		_mark_scene_modified()
		return { "status": "success", "message": "Célula (%d, %d) definida no TileMapLayer '%s'." % [coords.x, coords.y, target.name] }
	# TileMap legado (layer como param)
	elif target is TileMap:
		var layer: int = int(params.get("layer", 0))
		target.set_cell(layer, coords, source_id, atlas_coords, alt_id)
		_mark_scene_modified()
		return { "status": "success", "message": "Célula (%d, %d) definida no TileMap '%s' (layer %d)." % [coords.x, coords.y, target.name, layer] }
	return { "status": "error", "message": "O nó '%s' (%s) não é TileMap ou TileMapLayer." % [target.name, target.get_class()] }

# Retorna as células usadas de um TileMap/TileMapLayer.
func _get_tilemap_cells(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var node_path: String = str(params.get("node_path", "."))
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	var cells: Array = []
	if target is TileMapLayer:
		for c: Vector2i in target.get_used_cells():
			cells.append([c.x, c.y])
	elif target is TileMap:
		var layer: int = int(params.get("layer", 0))
		for c: Vector2i in target.get_used_cells(layer):
			cells.append([c.x, c.y])
	else:
		return { "status": "error", "message": "O nó '%s' (%s) não é TileMap ou TileMapLayer." % [target.name, target.get_class()] }
	return { "status": "success", "cell_count": cells.size(), "cells": cells, "message": "%d célula(s) usada(s)." % cells.size() }

# --- Animation helpers ---

# Lista as animações de um AnimationPlayer ou os sprite_frames de um AnimatedSprite2D.
func _list_animations(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var node_path: String = str(params.get("node_path", "."))
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	var names: Array[String] = []
	if target is AnimationPlayer:
		for anim_name: StringName in target.get_animation_list():
			names.append(str(anim_name))
	elif target is AnimatedSprite2D:
		var frames: SpriteFrames = target.sprite_frames
		if frames:
			for anim_name: StringName in frames.get_animation_names():
				names.append(str(anim_name))
	else:
		return { "status": "error", "message": "O nó '%s' (%s) não é AnimationPlayer ou AnimatedSprite2D." % [target.name, target.get_class()] }
	return { "status": "success", "node": target.name, "animations": names, "message": "%d animação(ões) encontrada(s)." % names.size() }

# Toca uma animação por nome num AnimationPlayer ou AnimatedSprite2D.
func _play_animation(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var node_path: String = str(params.get("node_path", "."))
	var anim_name: String = str(params.get("animation_name", params.get("name", "")))
	if anim_name == "":
		return { "status": "error", "message": "O parâmetro 'animation_name' é obrigatório." }
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	if target is AnimationPlayer:
		if not target.has_animation(anim_name):
			return { "status": "error", "message": "Animação '%s' não existe no AnimationPlayer '%s'." % [anim_name, target.name] }
		target.play(anim_name)
		return { "status": "success", "message": "Animação '%s' tocando no AnimationPlayer '%s'." % [anim_name, target.name] }
	elif target is AnimatedSprite2D:
		target.play(anim_name)
		return { "status": "success", "message": "Animação '%s' tocando no AnimatedSprite2D '%s'." % [anim_name, target.name] }
	return { "status": "error", "message": "O nó '%s' (%s) não suporta play de animação." % [target.name, target.get_class()] }

# --- Camera2D helper ---

# Configura zoom, position e limits de uma Camera2D.
func _set_camera_target(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var node_path: String = str(params.get("node_path", "."))
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }
	if not (target is Camera2D):
		return { "status": "error", "message": "O nó '%s' (%s) não é Camera2D." % [target.name, target.get_class()] }

	var cam: Camera2D = target as Camera2D
	var changes: Array[String] = []

	if params.has("position"):
		var pos: Variant = params["position"]
		if pos is Array and pos.size() >= 2:
			cam.position = Vector2(pos[0], pos[1])
			changes.append("position=%s" % str(cam.position))
	if params.has("zoom"):
		var z: Variant = params["zoom"]
		if z is Array and z.size() >= 2:
			cam.zoom = Vector2(z[0], z[1])
		elif z is float or z is int:
			cam.zoom = Vector2(float(z), float(z))
		changes.append("zoom=%s" % str(cam.zoom))
	if params.has("limit_left"):
		cam.limit_left = int(params["limit_left"])
		changes.append("limit_left=%d" % cam.limit_left)
	if params.has("limit_top"):
		cam.limit_top = int(params["limit_top"])
		changes.append("limit_top=%d" % cam.limit_top)
	if params.has("limit_right"):
		cam.limit_right = int(params["limit_right"])
		changes.append("limit_right=%d" % cam.limit_right)
	if params.has("limit_bottom"):
		cam.limit_bottom = int(params["limit_bottom"])
		changes.append("limit_bottom=%d" % cam.limit_bottom)
	if params.has("smoothing_enabled"):
		cam.position_smoothing_enabled = bool(params["smoothing_enabled"])
		changes.append("smoothing=%s" % str(cam.position_smoothing_enabled))

	if changes.is_empty():
		return { "status": "error", "message": "Nenhuma propriedade foi alterada. Informe position, zoom, limit_*, ou smoothing_enabled." }
	_mark_scene_modified()
	return { "status": "success", "message": "Camera2D '%s' atualizada: %s." % [cam.name, ", ".join(changes)] }

# --- docs_search: busca textual na documentação Godot offline ---

var _docs_cache: Dictionary = {}  # path -> content
var _docs_index_built: bool = false

func _docs_ensure_extracted() -> String:
	var cache_dir := "user://crom_docs_cache"
	var marker := cache_dir.path_join(".extracted")
	if FileAccess.file_exists(marker):
		return cache_dir
	# Extrai o zip da documentação
	var zip_path := "res://addons/crom_ai/references/godot_docs_html.zip"
	var global_zip := ProjectSettings.globalize_path(zip_path)
	if not FileAccess.file_exists(global_zip):
		return ""
	var reader := ZIPReader.new()
	if reader.open(global_zip) != OK:
		return ""
	DirAccess.make_dir_recursive_absolute(cache_dir)
	for file_path: String in reader.get_files():
		if not file_path.ends_with(".html"):
			continue
		var data: PackedByteArray = reader.read_file(file_path)
		var dst := cache_dir.path_join(file_path.get_file())
		var f := FileAccess.open(dst, FileAccess.WRITE)
		if f:
			f.store_buffer(data)
			f.close()
	reader.close()
	# Marker de conclusão
	var mf := FileAccess.open(marker, FileAccess.WRITE)
	if mf:
		mf.store_string("ok")
		mf.close()
	return cache_dir

func _docs_search(params: Dictionary) -> Dictionary:
	var query: String = str(params.get("query", "")).strip_edges()
	if query == "":
		return { "status": "error", "message": "Parâmetro 'query' obrigatório (ex: 'TileMap', 'move_and_slide')." }
	var max_results: int = clampi(int(params.get("max_results", 5)), 1, 20)

	var cache_dir := _docs_ensure_extracted()
	if cache_dir == "":
		return { "status": "error", "message": "Documentação offline não encontrada em res://addons/crom_ai/references/godot_docs_html.zip." }

	# Busca nos HTMLs extraídos (substring case-insensitive)
	var dir := DirAccess.open(cache_dir)
	if not dir:
		return { "status": "error", "message": "Falha ao abrir cache de docs." }

	var query_lower := query.to_lower()
	var results: Array[Dictionary] = []

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".html"):
			# Checar no nome do arquivo primeiro (rápido)
			if fname.to_lower().contains(query_lower):
				var content := _docs_read_and_strip(cache_dir.path_join(fname), query_lower)
				results.append({ "file": fname.get_basename(), "snippet": content, "match": "title" })
				if results.size() >= max_results:
					break
			elif results.size() < max_results:
				# Busca no conteúdo (mais lento)
				var full_path := cache_dir.path_join(fname)
				if _docs_cache.has(full_path):
					var cached: String = _docs_cache[full_path]
					if cached.to_lower().contains(query_lower):
						var snippet := _docs_extract_snippet(cached, query_lower)
						results.append({ "file": fname.get_basename(), "snippet": snippet, "match": "content" })
				else:
					var raw := FileAccess.get_file_as_string(full_path)
					if raw.length() < 500000:  # skip gigantic files
						var stripped := _html_strip_tags(raw)
						_docs_cache[full_path] = stripped
						if stripped.to_lower().contains(query_lower):
							var snippet := _docs_extract_snippet(stripped, query_lower)
							results.append({ "file": fname.get_basename(), "snippet": snippet, "match": "content" })
		fname = dir.get_next()
	dir.list_dir_end()

	if results.is_empty():
		return { "status": "success", "results": [], "message": "Nenhum resultado para '%s'. Use godot_class_reference para API de classes." % query }
	return { "status": "success", "query": query, "result_count": results.size(), "results": results, "message": "%d resultado(s) encontrado(s) na documentação." % results.size() }

func _docs_read_and_strip(path: String, _query_lower: String) -> String:
	var raw := FileAccess.get_file_as_string(path)
	var stripped := _html_strip_tags(raw)
	_docs_cache[path] = stripped
	return _docs_extract_snippet(stripped, _query_lower)

func _docs_extract_snippet(text: String, query_lower: String) -> String:
	var idx := text.to_lower().find(query_lower)
	if idx < 0:
		return text.substr(0, mini(500, text.length()))
	var start := maxi(0, idx - 200)
	var end_pos := mini(text.length(), idx + query_lower.length() + 300)
	return text.substr(start, end_pos - start)

func _html_strip_tags(html: String) -> String:
	# Strip HTML rudimentar: remove tags e decodifica entidades comuns.
	var regex := RegEx.new()
	regex.compile("<[^>]+>")
	var result := regex.sub(html, "", true)
	result = result.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"').replace("&#39;", "'").replace("&nbsp;", " ")
	return result
