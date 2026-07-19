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
		# 1d. BLOCO 5 — TileMap/Input/Editor/Animation/Physics (paridade pro)
		# ======================================================================
		"tilemap_fill_rect":
			return _tilemap_fill_rect(params)
		"tilemap_clear":
			return _tilemap_clear(params)
		"tilemap_get_info":
			return _tilemap_get_info(params)
		"simulate_mouse_click":
			return _simulate_mouse_click(params)
		"simulate_mouse_move":
			return _simulate_mouse_move(params)
		"simulate_sequence":
			return _simulate_sequence(params)
		"execute_editor_script":
			return _execute_editor_script(params)
		"reload_plugin":
			return _reload_plugin(params)
		"reload_project":
			return _reload_project()
		"remove_animation":
			return _remove_animation(params)
		"get_collision_info":
			return _get_collision_info(params)

		# ======================================================================
		# 1e. BLOCOS 6–16 — Todas as ferramentas restantes (paridade pro)
		# ======================================================================

		# --- Bloco 6: Audio ---
		"add_audio_player":
			return _add_audio_player(params)
		"add_audio_bus":
			return _add_audio_bus(params)
		"add_audio_bus_effect":
			return _add_audio_bus_effect(params)
		"set_audio_bus":
			return _set_audio_bus(params)
		"get_audio_bus_layout":
			return _get_audio_bus_layout(params)
		"get_audio_info":
			return _get_audio_info(params)

		# --- Bloco 7: Theme & UI ---
		"create_theme":
			return _create_theme(params)
		"set_theme_color":
			return _set_theme_color(params)
		"set_theme_constant":
			return _set_theme_constant(params)
		"set_theme_font_size":
			return _set_theme_font_size(params)
		"set_theme_stylebox":
			return _set_theme_stylebox(params)
		"get_theme_info":
			return _get_theme_info(params)

		# --- Bloco 8: Resource/Project ---
		"edit_resource":
			return _edit_resource(params)
		"get_resource_preview":
			return _get_resource_preview(params)
		"add_autoload":
			return _add_autoload(params)
		"remove_autoload":
			return _remove_autoload(params)
		"uid_to_project_path":
			return _uid_to_project_path(params)
		"project_path_to_uid":
			return _project_path_to_uid(params)
		"list_scripts":
			return _list_scripts(params)
		"search_in_files":
			return _search_in_files(params)

		# --- Bloco 9: Node/Selection ---
		"select_nodes":
			return _select_nodes(params)
		"clear_editor_selection":
			return _clear_editor_selection()
		"set_anchor_preset":
			return _set_anchor_preset(params)

		# --- Bloco 10: Runtime avançado ---
		"execute_game_script":
			return _execute_game_script(params)
		"start_recording":
			return _start_recording(params)
		"stop_recording":
			return _stop_recording(params)
		"replay_recording":
			return _replay_recording(params)
		"find_nodes_by_script":
			return _query_runtime("find_by_script", params)
		"get_autoload":
			return _get_autoload(params)
		"batch_get_properties":
			return _query_runtime("batch_get_properties", params)
		"find_nearby_nodes":
			return _query_runtime("find_nearby", params)
		"navigate_to":
			return _query_runtime("navigate_to", params)
		"move_to":
			return _query_runtime("move_to", params)

		# --- Bloco 11: Testing/QA ---
		"compare_screenshots":
			return _compare_screenshots(params)
		"run_stress_test":
			return _run_stress_test(params)
		"get_test_report":
			return _get_test_report(params)

		# --- Bloco 12: Particle + Navigation ---
		"create_particles":
			return _create_particles(params)
		"set_particle_material":
			return _set_particle_material(params)
		"set_particle_color_gradient":
			return _set_particle_color_gradient(params)
		"apply_particle_preset":
			return _apply_particle_preset(params)
		"get_particle_info":
			return _get_particle_info(params)
		"setup_navigation_region":
			return _setup_navigation_region(params)
		"setup_navigation_agent":
			return _setup_navigation_agent(params)
		"bake_navigation_mesh":
			return _bake_navigation_mesh(params)
		"set_navigation_layers":
			return _set_navigation_layers(params)
		"get_navigation_info":
			return _get_navigation_info(params)

		# --- Bloco 13: AnimationTree/StateMachine ---
		"create_animation_tree":
			return _create_animation_tree(params)
		"get_animation_tree_structure":
			return _get_animation_tree_structure(params)
		"set_tree_parameter":
			return _set_tree_parameter(params)
		"add_state_machine_state":
			return _add_state_machine_state(params)
		"remove_state_machine_state":
			return _remove_state_machine_state(params)
		"add_state_machine_transition":
			return _add_state_machine_transition(params)
		"remove_state_machine_transition":
			return _remove_state_machine_transition(params)
		"set_blend_tree_node":
			return _set_blend_tree_node(params)

		# --- Bloco 14: Shader + Export + Profiling ---
		"create_shader":
			return _create_shader(params)
		"read_shader":
			return _read_shader(params)
		"edit_shader":
			return _edit_shader(params)
		"assign_shader_material":
			return _assign_shader_material(params)
		"set_shader_param":
			return _set_shader_param(params)
		"get_shader_params":
			return _get_shader_params(params)
		"list_export_presets":
			return _list_export_presets()
		"export_project":
			return _export_project(params)
		"get_export_info":
			return _get_export_info()
		"get_performance_monitors":
			return _get_performance_monitors()
		"get_editor_performance":
			return _get_editor_performance()

		# --- Bloco 15: Batch/Refactoring + Analysis ---
		"find_nodes_by_type":
			return _find_nodes_by_type(params)
		"find_signal_connections":
			return _find_signal_connections(params)
		"batch_set_property":
			return _batch_set_property(params)
		"find_node_references":
			return _find_node_references(params)
		"get_scene_dependencies":
			return _get_scene_dependencies(params)
		"cross_scene_set_property":
			return _cross_scene_set_property(params)
		"find_script_references":
			return _find_script_references(params)
		"detect_circular_dependencies":
			return _detect_circular_dependencies(params)
		"analyze_scene_complexity":
			return _analyze_scene_complexity(params)
		"analyze_signal_flow":
			return _analyze_signal_flow(params)
		"find_unused_resources":
			return _find_unused_resources(params)
		"get_project_statistics":
			return _get_project_statistics()

		# --- Bloco 16: 3D ---
		"add_mesh_instance":
			return _add_mesh_instance(params)
		"setup_camera_3d":
			return _setup_camera_3d(params)
		"setup_lighting":
			return _setup_lighting(params)
		"setup_environment":
			return _setup_environment(params)
		"add_gridmap":
			return _add_gridmap(params)
		"set_material_3d":
			return _set_material_3d(params)

		"ping":
			return { "status": "success", "message": "Pong! CromAI Godot Bridge ativo." }
		_:
			return { "status": "error", "message": "Ação desconhecida: '%s'." % action }

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
	
	var scene_root: Node = _get_edited_scene_root()
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

var _working_root: Node = null
var _working_scene_path: String = ""

func _get_edited_scene_root() -> Node:
	if editor_plugin and editor_plugin.get_editor_interface():
		var r = editor_plugin.get_editor_interface().get_edited_scene_root()
		if r:
			return r
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		return tree.current_scene
	return _working_root

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
	_working_root = root
	_working_scene_path = scene_path

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return { "status": "error", "message": "Falha ao empacotar a cena (erro %d)." % pack_err }

	var parent_dir := scene_path.get_base_dir()
	if parent_dir != "" and parent_dir != "res://" and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	var save_err := ResourceSaver.save(packed, scene_path)
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
	elif _working_root and _working_scene_path != "":
		_set_owner_rec(_working_root, _working_root)
		var packed := PackedScene.new()
		var pack_err := packed.pack(_working_root)
		if pack_err == OK:
			var save_err := ResourceSaver.save(packed, _working_scene_path)
			if save_err == OK:
				_refresh_editor_filesystem()
				return { "status": "success", "message": "Cena em memória salva em '%s'." % _working_scene_path }
	return { "status": "error", "message": "Salvar cena indisponível." }

func _set_owner_rec(node: Node, root: Node) -> void:
	for c in node.get_children():
		c.owner = root
		_set_owner_rec(c, root)

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
	var gdscript_code: String = str(params.get("gdscript_code", params.get("script_content", params.get("code", ""))))
	
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
		
	var scene_root: Node = _get_edited_scene_root()
		
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
	var target_path := str(params.get("node_path", params.get("parent_path", ".")))
	var body: Node = _resolve_node(scene_root, target_path)
	if not body:
		var body_type := str(params.get("body_type", "CharacterBody2D"))
		if not ClassDB.class_exists(body_type) or not ClassDB.is_parent_class(body_type, "CollisionObject2D"):
			return { "status": "error", "message": "body_type inválido: '%s'." % body_type }
		body = ClassDB.instantiate(body_type)
		body.name = str(params.get("node_name", body_type))
		scene_root.add_child(body)
		body.owner = scene_root
	if params.has("position"):
		body.set("position", _coerce_value(body, "position", params.get("position")))
	if params.has("collision_layer"):
		body.set("collision_layer", int(params.get("collision_layer")))
	if params.has("collision_mask"):
		body.set("collision_mask", int(params.get("collision_mask")))

	var col: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not col:
		col = CollisionShape2D.new()
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
	return { "status": "success", "body": _rel_path(body), "collision_shape": _rel_path(col), "message": "PhysicsBody '%s' configurado com CollisionShape2D." % body.name }

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

# ==============================================================================
# BLOCO 5 — Paridade godot-mcp-pro: TileMap / Input / Editor / Animation / Physics
# ==============================================================================

# --- TileMap extras ---

# Preenche um retângulo de células num TileMap/TileMapLayer com um tile específico.
func _tilemap_fill_rect(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var node_path: String = str(params.get("node_path", "."))
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	var from_raw: Variant = params.get("from", [0, 0])
	var to_raw: Variant = params.get("to", [0, 0])
	if not (from_raw is Array and from_raw.size() >= 2 and to_raw is Array and to_raw.size() >= 2):
		return { "status": "error", "message": "'from' e 'to' devem ser [x, y]." }
	var from := Vector2i(int(from_raw[0]), int(from_raw[1]))
	var to := Vector2i(int(to_raw[0]), int(to_raw[1]))
	var source_id: int = int(params.get("source_id", 0))
	var atlas_raw: Variant = params.get("atlas_coords", [0, 0])
	var atlas_coords := Vector2i(
		int(atlas_raw[0]) if atlas_raw is Array and atlas_raw.size() >= 2 else 0,
		int(atlas_raw[1]) if atlas_raw is Array and atlas_raw.size() >= 2 else 0
	)
	var alt_id: int = int(params.get("alternative_tile", 0))

	# Normaliza o retângulo (garante min <= max)
	var min_x := mini(from.x, to.x)
	var max_x := maxi(from.x, to.x)
	var min_y := mini(from.y, to.y)
	var max_y := maxi(from.y, to.y)
	var count := 0

	if target is TileMapLayer:
		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				target.set_cell(Vector2i(x, y), source_id, atlas_coords, alt_id)
				count += 1
	elif target is TileMap:
		var layer: int = int(params.get("layer", 0))
		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				target.set_cell(layer, Vector2i(x, y), source_id, atlas_coords, alt_id)
				count += 1
	else:
		return { "status": "error", "message": "O nó '%s' (%s) não é TileMap ou TileMapLayer." % [target.name, target.get_class()] }
	_mark_scene_modified()
	return { "status": "success", "cells_filled": count, "message": "%d célula(s) preenchida(s) de (%d,%d) a (%d,%d)." % [count, min_x, min_y, max_x, max_y] }

# Limpa TODAS as células de um TileMap/TileMapLayer.
func _tilemap_clear(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var node_path: String = str(params.get("node_path", "."))
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	if target is TileMapLayer:
		target.clear()
	elif target is TileMap:
		var layer_raw: Variant = params.get("layer", null)
		if layer_raw != null:
			# Limpa só uma camada (set_cell com source -1 = erase)
			var layer: int = int(layer_raw)
			for c: Vector2i in target.get_used_cells(layer):
				target.erase_cell(layer, c)
		else:
			# Limpa TODAS as camadas
			for l in range(target.get_layers_count()):
				for c: Vector2i in target.get_used_cells(l):
					target.erase_cell(l, c)
	else:
		return { "status": "error", "message": "O nó '%s' (%s) não é TileMap ou TileMapLayer." % [target.name, target.get_class()] }
	_mark_scene_modified()
	return { "status": "success", "message": "TileMap '%s' limpo." % target.name }

# Retorna informações sobre um TileMap/TileMapLayer: TileSet, cell_size, camadas, etc.
func _tilemap_get_info(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var node_path: String = str(params.get("node_path", "."))
	var target: Node = _resolve_node(scene_root, node_path)
	if not target:
		return { "status": "error", "message": "Nó não encontrado em '%s'." % node_path }

	var info: Dictionary = { "status": "success", "node": target.name, "type": target.get_class() }

	if target is TileMapLayer:
		var ts: TileSet = target.tile_set
		info["has_tileset"] = ts != null
		if ts:
			info["tile_size"] = [ts.tile_size.x, ts.tile_size.y]
			info["sources_count"] = ts.get_source_count()
		info["used_cells"] = target.get_used_cells().size()
		info["message"] = "TileMapLayer '%s': %d célula(s) usada(s)." % [target.name, info["used_cells"]]
	elif target is TileMap:
		var ts: TileSet = target.tile_set
		info["has_tileset"] = ts != null
		if ts:
			info["tile_size"] = [ts.tile_size.x, ts.tile_size.y]
			info["sources_count"] = ts.get_source_count()
		var layers_info: Array = []
		for i in range(target.get_layers_count()):
			var lname: String = target.get_layer_name(i)
			var used: int = target.get_used_cells(i).size()
			layers_info.append({ "index": i, "name": lname if lname != "" else "Layer %d" % i, "used_cells": used, "enabled": target.is_layer_enabled(i) })
		info["layers"] = layers_info
		info["layer_count"] = target.get_layers_count()
		var total := 0
		for l in layers_info:
			total += int(l["used_cells"])
		info["total_used_cells"] = total
		info["message"] = "TileMap '%s': %d camada(s), %d célula(s) total." % [target.name, info["layer_count"], total]
	else:
		return { "status": "error", "message": "O nó '%s' (%s) não é TileMap ou TileMapLayer." % [target.name, target.get_class()] }
	return info

# --- Input extras ---

# Simula um clique do mouse (press + release) nas coordenadas especificadas.
func _simulate_mouse_click(params: Dictionary) -> Dictionary:
	var pos_raw: Variant = params.get("position", [0, 0])
	if not (pos_raw is Array and pos_raw.size() >= 2):
		return { "status": "error", "message": "'position' deve ser [x, y]." }
	var pos := Vector2(float(pos_raw[0]), float(pos_raw[1]))
	var button: int = int(params.get("button", MOUSE_BUTTON_LEFT))
	var double_click: bool = bool(params.get("double_click", false))

	# Press
	var ev_press := InputEventMouseButton.new()
	ev_press.button_index = button
	ev_press.pressed = true
	ev_press.position = pos
	ev_press.global_position = pos
	ev_press.double_click = double_click
	Input.parse_input_event(ev_press)

	# Release (1 frame depois)
	var ev_release := InputEventMouseButton.new()
	ev_release.button_index = button
	ev_release.pressed = false
	ev_release.position = pos
	ev_release.global_position = pos
	Input.parse_input_event(ev_release)

	var btn_name := "left" if button == MOUSE_BUTTON_LEFT else ("right" if button == MOUSE_BUTTON_RIGHT else "middle")
	return { "status": "success", "message": "Clique %s%s em (%.0f, %.0f) simulado." % [btn_name, " duplo" if double_click else "", pos.x, pos.y] }

# Simula um evento de movimento do mouse para as coordenadas especificadas.
func _simulate_mouse_move(params: Dictionary) -> Dictionary:
	var pos_raw: Variant = params.get("position", [0, 0])
	if not (pos_raw is Array and pos_raw.size() >= 2):
		return { "status": "error", "message": "'position' deve ser [x, y]." }
	var pos := Vector2(float(pos_raw[0]), float(pos_raw[1]))
	var relative_raw: Variant = params.get("relative", null)

	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	if relative_raw is Array and relative_raw.size() >= 2:
		ev.relative = Vector2(float(relative_raw[0]), float(relative_raw[1]))
	Input.parse_input_event(ev)
	return { "status": "success", "message": "Mouse movido para (%.0f, %.0f)." % [pos.x, pos.y] }

# Executa uma SEQUÊNCIA de inputs com delays entre cada passo.
# Cada step: { "type": "key"|"action"|"mouse_click"|"wait", "key": ..., "action": ..., "position": [...], "delay_ms": ... }
func _simulate_sequence(params: Dictionary) -> Dictionary:
	var steps_raw: Variant = params.get("steps", [])
	if not (steps_raw is Array) or steps_raw.size() == 0:
		return { "status": "error", "message": "'steps' deve ser um array não-vazio de inputs." }
	var default_delay: int = clampi(int(params.get("interval_ms", 100)), 0, 2000)
	var executed := 0

	for step_raw: Variant in steps_raw:
		if not (step_raw is Dictionary):
			continue
		var step: Dictionary = step_raw as Dictionary
		var step_type := str(step.get("type", "key"))
		var delay: int = int(step.get("delay_ms", default_delay))

		match step_type:
			"key":
				var key_name := str(step.get("key", ""))
				if key_name != "":
					var keycode := OS.find_keycode_from_string(key_name)
					if keycode != KEY_NONE:
						var ev := InputEventKey.new()
						ev.keycode = keycode
						ev.physical_keycode = keycode
						# Press
						ev.pressed = true
						Input.parse_input_event(ev)
						OS.delay_msec(clampi(int(step.get("hold_ms", 50)), 10, 1000))
						# Release
						var ev_r := InputEventKey.new()
						ev_r.keycode = keycode
						ev_r.physical_keycode = keycode
						ev_r.pressed = false
						Input.parse_input_event(ev_r)
						executed += 1
			"action":
				var action_name := str(step.get("action", ""))
				if action_name != "":
					Input.action_press(action_name)
					OS.delay_msec(clampi(int(step.get("hold_ms", 50)), 10, 1000))
					Input.action_release(action_name)
					executed += 1
			"mouse_click":
				var pos_raw: Variant = step.get("position", [0, 0])
				if pos_raw is Array and pos_raw.size() >= 2:
					var pos := Vector2(float(pos_raw[0]), float(pos_raw[1]))
					var ev_p := InputEventMouseButton.new()
					ev_p.button_index = MOUSE_BUTTON_LEFT
					ev_p.pressed = true
					ev_p.position = pos
					ev_p.global_position = pos
					Input.parse_input_event(ev_p)
					var ev_rel := InputEventMouseButton.new()
					ev_rel.button_index = MOUSE_BUTTON_LEFT
					ev_rel.pressed = false
					ev_rel.position = pos
					ev_rel.global_position = pos
					Input.parse_input_event(ev_rel)
					executed += 1
			"wait":
				# Só espera o delay
				executed += 1

		if delay > 0:
			OS.delay_msec(delay)

	return { "status": "success", "steps_executed": executed, "total_steps": steps_raw.size(), "message": "%d/%d passo(s) de input executado(s)." % [executed, steps_raw.size()] }

# --- Editor extras ---

# Executa um snippet GDScript no contexto do editor (via @tool script temporário).
func _execute_editor_script(params: Dictionary) -> Dictionary:
	var code: String = str(params.get("code", params.get("gdscript_code", "")))
	if code.strip_edges() == "":
		return { "status": "error", "message": "Parâmetro 'code' obrigatório (snippet GDScript a executar)." }

	# Prepara o script temporário
	var tmp_path := "res://.crom_editor_script_tmp.gd"
	# Garante que é @tool e tem uma função executável
	var full_code := "@tool\nextends EditorScript\n\nfunc _run() -> void:\n"
	# Indenta cada linha do código do usuário
	for line in code.split("\n"):
		full_code += "\t" + line + "\n"

	# Escreve no disco
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not f:
		return { "status": "error", "message": "Falha ao criar script temporário." }
	f.store_string(full_code)
	f.close()

	# Carrega e executa
	_refresh_editor_filesystem()
	var script: Script = ResourceLoader.load(tmp_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
	if not script:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return { "status": "error", "message": "Falha ao carregar script temporário." }

	var instance: Variant = script.new()
	if instance == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return { "status": "error", "message": "Falha ao instanciar EditorScript." }

	# EditorScript.run() é o ponto de entrada
	if instance.has_method("_run"):
		instance._run()

	# Limpa o temporário
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	_refresh_editor_filesystem()

	return { "status": "success", "message": "Script do editor executado com sucesso." }

# Desabilita e re-habilita um EditorPlugin pelo nome (recarrega).
func _reload_plugin(params: Dictionary) -> Dictionary:
	var plugin_name := str(params.get("plugin_name", params.get("name", "")))
	if plugin_name == "":
		return { "status": "error", "message": "Parâmetro 'plugin_name' obrigatório (nome da pasta do addon em addons/)." }

	# O caminho do plugin.cfg
	var cfg_path := "res://addons/%s/plugin.cfg" % plugin_name
	if not FileAccess.file_exists(cfg_path):
		return { "status": "error", "message": "Plugin não encontrado: '%s' (esperava %s)." % [plugin_name, cfg_path] }

	if not editor_plugin or not editor_plugin.get_editor_interface():
		return { "status": "error", "message": "EditorInterface indisponível." }

	# Desabilita
	EditorInterface.set_plugin_enabled(plugin_name, false)
	# Re-habilita
	EditorInterface.set_plugin_enabled(plugin_name, true)
	return { "status": "success", "message": "Plugin '%s' recarregado." % plugin_name }

# Solicita reinicialização do editor Godot.
func _reload_project() -> Dictionary:
	if not editor_plugin or not editor_plugin.get_editor_interface():
		return { "status": "error", "message": "EditorInterface indisponível." }
	EditorInterface.restart_editor()
	return { "status": "success", "message": "Editor Godot reiniciando... A conexão WebSocket será perdida. Reconecte após o restart." }

# --- Animation extras ---

# Remove uma animação de um AnimationPlayer.
func _remove_animation(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not (target is AnimationPlayer):
		return { "status": "error", "message": "node_path precisa apontar para um AnimationPlayer." }
	var player := target as AnimationPlayer
	var anim_name := str(params.get("animation_name", ""))
	if anim_name == "":
		return { "status": "error", "message": "Parâmetro 'animation_name' obrigatório." }
	if not player.has_animation(anim_name):
		return { "status": "error", "message": "Animação '%s' não existe no AnimationPlayer '%s'." % [anim_name, target.name] }

	# Procura em qual biblioteca a animação está
	var removed := false
	for lib_name: StringName in player.get_animation_library_list():
		var lib: AnimationLibrary = player.get_animation_library(lib_name)
		if lib and lib.has_animation(anim_name):
			lib.remove_animation(anim_name)
			removed = true
			break
	if not removed:
		return { "status": "error", "message": "Animação '%s' não encontrada em nenhuma biblioteca." % anim_name }
	_mark_scene_modified()
	return { "status": "success", "message": "Animação '%s' removida do AnimationPlayer '%s'." % [anim_name, target.name] }

# --- Physics extras ---

# Retorna informações de colisão de um corpo físico (shapes, layers, mask).
func _get_collision_info(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }

	var info: Dictionary = { "status": "success", "node": str(target.name), "type": target.get_class() }

	# collision_layer e collision_mask (CollisionObject2D e 3D)
	if "collision_layer" in target:
		info["collision_layer"] = int(target.get("collision_layer"))
		info["collision_mask"] = int(target.get("collision_mask"))
	else:
		return { "status": "error", "message": "O nó '%s' (%s) não é um corpo físico (sem collision_layer)." % [target.name, target.get_class()] }

	# Coleta shapes dos filhos CollisionShape2D/3D e CollisionPolygon2D/3D
	var shapes: Array = []
	for child in target.get_children():
		if child is CollisionShape2D:
			var shape_info: Dictionary = { "node": child.name, "type": "CollisionShape2D", "disabled": child.disabled }
			if child.shape:
				shape_info["shape_type"] = child.shape.get_class()
				if child.shape is RectangleShape2D:
					shape_info["size"] = [child.shape.size.x, child.shape.size.y]
				elif child.shape is CircleShape2D:
					shape_info["radius"] = child.shape.radius
				elif child.shape is CapsuleShape2D:
					shape_info["radius"] = child.shape.radius
					shape_info["height"] = child.shape.height
			else:
				shape_info["shape_type"] = "none"
			shapes.append(shape_info)
		elif child is CollisionPolygon2D:
			var poly_info: Dictionary = { "node": child.name, "type": "CollisionPolygon2D", "disabled": child.disabled }
			poly_info["vertex_count"] = child.polygon.size()
			shapes.append(poly_info)

	info["shapes"] = shapes
	info["shape_count"] = shapes.size()

	# Monitoramento (para Area2D)
	if target is Area2D:
		info["monitoring"] = target.monitoring
		info["monitorable"] = target.monitorable

	info["message"] = "%s '%s': layer=%d, mask=%d, %d shape(s)." % [target.get_class(), target.name, info.get("collision_layer", 0), info.get("collision_mask", 0), shapes.size()]
	return info

# ==============================================================================
# BLOCOS 6–16 — Todas as ferramentas restantes (paridade godot-mcp-pro)
# ==============================================================================

# --- Bloco 6: Audio ---

func _add_audio_player(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta no editor." }
	var parent_path := str(params.get("parent_path", "."))
	var parent: Node = _resolve_node(scene_root, parent_path)
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado em '%s'." % parent_path }
	var player_type := str(params.get("type", "AudioStreamPlayer"))
	if player_type not in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		player_type = "AudioStreamPlayer"
	var node: Node = ClassDB.instantiate(player_type)
	node.name = str(params.get("node_name", player_type))
	parent.add_child(node)
	node.owner = scene_root
	var stream_path := str(params.get("stream_path", ""))
	if stream_path != "" and FileAccess.file_exists(stream_path):
		var stream: AudioStream = ResourceLoader.load(stream_path) as AudioStream
		if stream:
			node.set("stream", stream)
	if params.has("bus"):
		node.set("bus", str(params.get("bus")))
	if params.has("volume_db"):
		node.set("volume_db", float(params.get("volume_db")))
	if params.has("autoplay"):
		node.set("autoplay", bool(params.get("autoplay")))
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(node), "message": "%s '%s' adicionado." % [player_type, node.name] }

func _add_audio_bus(params: Dictionary) -> Dictionary:
	var bus_name := str(params.get("bus_name", "NewBus"))
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	if params.has("send"):
		AudioServer.set_bus_send(idx, str(params.get("send")))
	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(idx, float(params.get("volume_db")))
	return { "status": "success", "bus_index": idx, "bus_name": bus_name, "message": "Bus de áudio '%s' criado (índice %d)." % [bus_name, idx] }

func _add_audio_bus_effect(params: Dictionary) -> Dictionary:
	var bus_name := str(params.get("bus_name", "Master"))
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return { "status": "error", "message": "Bus '%s' não encontrado." % bus_name }
	var effect_type := str(params.get("effect_type", "AudioEffectReverb"))
	if not ClassDB.class_exists(effect_type) or not ClassDB.is_parent_class(effect_type, "AudioEffect"):
		return { "status": "error", "message": "'%s' não é um AudioEffect válido." % effect_type }
	var effect: AudioEffect = ClassDB.instantiate(effect_type) as AudioEffect
	AudioServer.add_bus_effect(idx, effect)
	return { "status": "success", "message": "Efeito '%s' adicionado ao bus '%s'." % [effect_type, bus_name] }

func _set_audio_bus(params: Dictionary) -> Dictionary:
	var bus_name := str(params.get("bus_name", "Master"))
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return { "status": "error", "message": "Bus '%s' não encontrado." % bus_name }
	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(idx, float(params.get("volume_db")))
	if params.has("mute"):
		AudioServer.set_bus_mute(idx, bool(params.get("mute")))
	if params.has("solo"):
		AudioServer.set_bus_solo(idx, bool(params.get("solo")))
	if params.has("send"):
		AudioServer.set_bus_send(idx, str(params.get("send")))
	return { "status": "success", "message": "Bus '%s' atualizado." % bus_name }

func _get_audio_bus_layout(_params: Dictionary) -> Dictionary:
	var buses: Array = []
	for i in range(AudioServer.bus_count):
		var effects: Array = []
		for e in range(AudioServer.get_bus_effect_count(i)):
			var eff := AudioServer.get_bus_effect(i, e)
			effects.append({ "type": eff.get_class() if eff else "null", "enabled": AudioServer.is_bus_effect_enabled(i, e) })
		buses.append({ "name": AudioServer.get_bus_name(i), "index": i, "volume_db": AudioServer.get_bus_volume_db(i), "mute": AudioServer.is_bus_mute(i), "solo": AudioServer.is_bus_solo(i), "send": AudioServer.get_bus_send(i), "effects": effects })
	return { "status": "success", "bus_count": AudioServer.bus_count, "buses": buses }

func _get_audio_info(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var info: Dictionary = { "status": "success", "node": str(target.name), "type": target.get_class() }
	if "stream" in target:
		var s: Variant = target.get("stream")
		info["has_stream"] = s != null
		info["stream_type"] = s.get_class() if s else "none"
	if "bus" in target:
		info["bus"] = str(target.get("bus"))
	if "volume_db" in target:
		info["volume_db"] = float(target.get("volume_db"))
	if "autoplay" in target:
		info["autoplay"] = bool(target.get("autoplay"))
	info["message"] = "Info de áudio do nó '%s'." % target.name
	return info

# --- Bloco 7: Theme & UI ---

func _create_theme(params: Dictionary) -> Dictionary:
	var save_path := str(params.get("save_path", ""))
	var theme := Theme.new()
	if save_path != "":
		var dir := save_path.get_base_dir()
		if dir != "" and dir != "res://" and not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		var e := ResourceSaver.save(theme, save_path)
		if e != OK:
			return { "status": "error", "message": "Falha ao salvar tema (erro %d)." % e }
		_refresh_editor_filesystem()
		return { "status": "success", "message": "Tema salvo em '%s'." % save_path, "save_path": save_path }
	return { "status": "success", "message": "Tema criado (não salvo — informe save_path)." }

func _set_theme_color(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("theme" in target):
		return { "status": "error", "message": "Nó não encontrado ou não suporta tema." }
	var theme: Theme = target.get("theme")
	if not theme:
		theme = Theme.new()
		target.set("theme", theme)
	var item_name := str(params.get("item_name", ""))
	var type_name := str(params.get("type_name", target.get_class()))
	var color_raw: Variant = params.get("color", [1, 1, 1, 1])
	var color := Color.WHITE
	if color_raw is Array and color_raw.size() >= 3:
		color = Color(float(color_raw[0]), float(color_raw[1]), float(color_raw[2]), float(color_raw[3]) if color_raw.size() > 3 else 1.0)
	theme.set_color(item_name, type_name, color)
	_mark_scene_modified()
	return { "status": "success", "message": "Cor '%s' definida no tema para '%s'." % [item_name, type_name] }

func _set_theme_constant(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("theme" in target):
		return { "status": "error", "message": "Nó não encontrado ou não suporta tema." }
	var theme: Theme = target.get("theme")
	if not theme:
		theme = Theme.new()
		target.set("theme", theme)
	theme.set_constant(str(params.get("item_name", "")), str(params.get("type_name", target.get_class())), int(params.get("value", 0)))
	_mark_scene_modified()
	return { "status": "success", "message": "Constante de tema definida." }

func _set_theme_font_size(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("theme" in target):
		return { "status": "error", "message": "Nó não encontrado ou não suporta tema." }
	var theme: Theme = target.get("theme")
	if not theme:
		theme = Theme.new()
		target.set("theme", theme)
	theme.set_font_size(str(params.get("item_name", "font_size")), str(params.get("type_name", target.get_class())), int(params.get("size", 16)))
	_mark_scene_modified()
	return { "status": "success", "message": "Tamanho de fonte no tema definido." }

func _set_theme_stylebox(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("theme" in target):
		return { "status": "error", "message": "Nó não encontrado ou não suporta tema." }
	var theme: Theme = target.get("theme")
	if not theme:
		theme = Theme.new()
		target.set("theme", theme)
	var sb := StyleBoxFlat.new()
	var bg: Variant = params.get("bg_color", null)
	if bg is Array and bg.size() >= 3:
		sb.bg_color = Color(float(bg[0]), float(bg[1]), float(bg[2]), float(bg[3]) if bg.size() > 3 else 1.0)
	if params.has("corner_radius"):
		var r := int(params.get("corner_radius"))
		sb.corner_radius_top_left = r; sb.corner_radius_top_right = r; sb.corner_radius_bottom_left = r; sb.corner_radius_bottom_right = r
	if params.has("border_width"):
		var bw := int(params.get("border_width"))
		sb.border_width_left = bw; sb.border_width_right = bw; sb.border_width_top = bw; sb.border_width_bottom = bw
	theme.set_stylebox(str(params.get("item_name", "panel")), str(params.get("type_name", target.get_class())), sb)
	_mark_scene_modified()
	return { "status": "success", "message": "StyleBox definido no tema." }

func _get_theme_info(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("theme" in target):
		return { "status": "error", "message": "Nó não encontrado ou não suporta tema." }
	var theme: Theme = target.get("theme")
	if not theme:
		return { "status": "success", "has_theme": false, "message": "Nó '%s' não tem tema definido." % target.name }
	var info: Dictionary = { "status": "success", "has_theme": true }
	info["type_list"] = Array(theme.get_type_list())
	return info

# --- Bloco 8: Resource/Project ---

func _edit_resource(params: Dictionary) -> Dictionary:
	var res_path := str(params.get("resource_path", ""))
	if res_path == "" or not FileAccess.file_exists(res_path):
		return { "status": "error", "message": "Recurso não encontrado: '%s'." % res_path }
	var res: Resource = ResourceLoader.load(res_path)
	if not res:
		return { "status": "error", "message": "Falha ao carregar recurso '%s'." % res_path }
	var props: Dictionary = params.get("properties", {}) if params.get("properties") is Dictionary else {}
	for k in props:
		if k in res:
			res.set(k, _coerce_value(res, k, props[k]))
	var e := ResourceSaver.save(res, res_path)
	if e != OK:
		return { "status": "error", "message": "Falha ao salvar recurso (erro %d)." % e }
	_refresh_editor_filesystem()
	return { "status": "success", "message": "Recurso '%s' editado." % res_path }

func _get_resource_preview(params: Dictionary) -> Dictionary:
	var res_path := str(params.get("resource_path", ""))
	if res_path == "":
		return { "status": "error", "message": "Parâmetro 'resource_path' obrigatório." }
	# O EditorResourcePreview gera thumbnails, mas é assíncrono. Retornamos info básica.
	if not FileAccess.file_exists(res_path):
		return { "status": "error", "message": "Recurso '%s' não encontrado." % res_path }
	var res: Resource = ResourceLoader.load(res_path)
	if not res:
		return { "status": "error", "message": "Falha ao carregar recurso." }
	return { "status": "success", "resource_path": res_path, "type": res.get_class(), "message": "Recurso '%s' (%s)." % [res_path, res.get_class()] }

func _add_autoload(params: Dictionary) -> Dictionary:
	var autoload_name := str(params.get("name", ""))
	var path := str(params.get("path", ""))
	if autoload_name == "" or path == "":
		return { "status": "error", "message": "Parâmetros 'name' e 'path' obrigatórios." }
	ProjectSettings.set_setting("autoload/%s" % autoload_name, "*%s" % path)
	ProjectSettings.save()
	return { "status": "success", "message": "Autoload '%s' -> '%s' adicionado." % [autoload_name, path] }

func _remove_autoload(params: Dictionary) -> Dictionary:
	var autoload_name := str(params.get("name", ""))
	if autoload_name == "":
		return { "status": "error", "message": "Parâmetro 'name' obrigatório." }
	var setting := "autoload/%s" % autoload_name
	if not ProjectSettings.has_setting(setting):
		return { "status": "error", "message": "Autoload '%s' não existe." % autoload_name }
	ProjectSettings.set_setting(setting, null)
	ProjectSettings.save()
	return { "status": "success", "message": "Autoload '%s' removido." % autoload_name }

func _uid_to_project_path(params: Dictionary) -> Dictionary:
	var uid_str := str(params.get("uid", ""))
	if uid_str == "":
		return { "status": "error", "message": "Parâmetro 'uid' obrigatório." }
	var uid := ResourceUID.text_to_id(uid_str)
	if uid == ResourceUID.INVALID_ID:
		return { "status": "error", "message": "UID inválido: '%s'." % uid_str }
	if not ResourceUID.has_id(uid):
		return { "status": "error", "message": "UID não registrado: '%s'." % uid_str }
	var path := ResourceUID.get_id_path(uid)
	return { "status": "success", "uid": uid_str, "path": path, "message": "%s -> %s" % [uid_str, path] }

func _project_path_to_uid(params: Dictionary) -> Dictionary:
	var path := str(params.get("path", ""))
	if path == "":
		return { "status": "error", "message": "Parâmetro 'path' obrigatório." }
	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return { "status": "error", "message": "Nenhum UID para '%s'." % path }
	return { "status": "success", "path": path, "uid": ResourceUID.id_to_text(uid) }

func _list_scripts(params: Dictionary) -> Dictionary:
	var dir := str(params.get("dir_path", "res://"))
	var results: Array = []
	_walk_scripts(dir, results)
	return { "status": "success", "count": results.size(), "scripts": results }

func _walk_scripts(dir: String, out: Array) -> void:
	if out.size() >= 500:
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "" and out.size() < 500:
		if f in [".", ".."] or f.begins_with(".godot") or f == ".crom":
			f = d.get_next()
			continue
		var full := dir.path_join(f)
		if d.current_is_dir():
			_walk_scripts(full, out)
		elif f.ends_with(".gd") or f.ends_with(".cs"):
			out.append(full)
		f = d.get_next()
	d.list_dir_end()

func _search_in_files(params: Dictionary) -> Dictionary:
	var query := str(params.get("query", ""))
	if query == "":
		return { "status": "error", "message": "Parâmetro 'query' obrigatório." }
	var dir := str(params.get("dir_path", "res://"))
	var exts: Array = params.get("extensions", [".gd", ".tscn", ".tres", ".cfg"]) if params.get("extensions") is Array else [".gd", ".tscn", ".tres", ".cfg"]
	var results: Array = []
	_walk_search_content(dir, query.to_lower(), exts, results)
	return { "status": "success", "query": query, "count": results.size(), "matches": results }

func _walk_search_content(dir: String, q: String, exts: Array, out: Array) -> void:
	if out.size() >= 100:
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "" and out.size() < 100:
		if f in [".", ".."] or f.begins_with(".godot"):
			f = d.get_next()
			continue
		var full := dir.path_join(f)
		if d.current_is_dir():
			_walk_search_content(full, q, exts, out)
		else:
			var match_ext := false
			for ext in exts:
				if f.ends_with(str(ext)):
					match_ext = true
					break
			if match_ext:
				var content := FileAccess.get_file_as_string(full)
				if content.to_lower().contains(q):
					# Encontra a(s) linha(s) que contém
					var lines := content.split("\n")
					var matches: Array = []
					for li in range(lines.size()):
						if String(lines[li]).to_lower().contains(q):
							matches.append({ "line": li + 1, "content": String(lines[li]).strip_edges().substr(0, 200) })
							if matches.size() >= 5:
								break
					out.append({ "file": full, "matches": matches })
		f = d.get_next()
	d.list_dir_end()

# --- Bloco 9: Node/Selection ---

func _select_nodes(params: Dictionary) -> Dictionary:
	if not editor_plugin or not editor_plugin.get_editor_interface():
		return { "status": "error", "message": "EditorInterface indisponível." }
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var paths_raw: Variant = params.get("node_paths", [])
	if not (paths_raw is Array):
		return { "status": "error", "message": "'node_paths' deve ser um array." }
	var selection := editor_plugin.get_editor_interface().get_selection()
	selection.clear()
	var selected := 0
	for p: Variant in paths_raw:
		var node: Node = _resolve_node(scene_root, str(p))
		if node:
			selection.add_node(node)
			selected += 1
	return { "status": "success", "selected": selected, "message": "%d nó(s) selecionado(s)." % selected }

func _clear_editor_selection() -> Dictionary:
	if not editor_plugin or not editor_plugin.get_editor_interface():
		return { "status": "error", "message": "EditorInterface indisponível." }
	editor_plugin.get_editor_interface().get_selection().clear()
	return { "status": "success", "message": "Seleção limpa." }

func _set_anchor_preset(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is Control):
		return { "status": "error", "message": "Nó não é um Control." }
	var preset: int = int(params.get("preset", 0))  # PRESET_TOP_LEFT=0, PRESET_CENTER=8, PRESET_FULL_RECT=15, etc.
	(target as Control).set_anchors_preset(preset)
	if params.has("resize"):
		(target as Control).set_anchors_preset(preset, bool(params.get("resize")))
	_mark_scene_modified()
	return { "status": "success", "message": "Anchor preset %d aplicado a '%s'." % [preset, target.name] }

# --- Bloco 10: Runtime avançado (editor-side) ---

var _recording: Array = []
var _recording_active := false
var _recording_node := ""
var _recording_prop := ""

func _execute_game_script(params: Dictionary) -> Dictionary:
	var code := str(params.get("code", ""))
	if code == "":
		return { "status": "error", "message": "Parâmetro 'code' obrigatório." }
	return _query_runtime("execute_script", { "code": code })

func _start_recording(params: Dictionary) -> Dictionary:
	_recording.clear()
	_recording_active = true
	_recording_node = str(params.get("node_path", "."))
	_recording_prop = str(params.get("property", "position"))
	return { "status": "success", "message": "Gravação iniciada para '%s.%s'." % [_recording_node, _recording_prop] }

func _stop_recording(_params: Dictionary) -> Dictionary:
	_recording_active = false
	# Coleta as amostras finais do runtime
	var samples := int(_params.get("samples", 10))
	for i in range(samples):
		var r := _query_runtime("get_property", { "node_path": _recording_node, "property": _recording_prop })
		if r.get("status") == "success":
			_recording.append({ "frame": i, "value": r.get("value") })
		OS.delay_msec(100)
	return { "status": "success", "recording": _recording, "sample_count": _recording.size(), "message": "Gravação parada. %d amostras." % _recording.size() }

func _replay_recording(_params: Dictionary) -> Dictionary:
	if _recording.is_empty():
		return { "status": "error", "message": "Nenhuma gravação disponível. Use start_recording/stop_recording primeiro." }
	# Aplica cada frame da gravação ao nó
	for entry: Variant in _recording:
		if entry is Dictionary:
			_query_runtime("set_property", { "node_path": _recording_node, "property": _recording_prop, "value": entry.get("value") })
			OS.delay_msec(100)
	return { "status": "success", "message": "Replay concluído (%d frames)." % _recording.size() }

func _get_autoload(params: Dictionary) -> Dictionary:
	var autoloads: Array = []
	for prop in ProjectSettings.get_property_list():
		var pn: String = str(prop.get("name", ""))
		if pn.begins_with("autoload/"):
			var name := pn.trim_prefix("autoload/")
			autoloads.append({ "name": name, "path": str(ProjectSettings.get_setting(pn)) })
	return { "status": "success", "autoloads": autoloads, "count": autoloads.size() }

# --- Bloco 11: Testing/QA ---

func _compare_screenshots(params: Dictionary) -> Dictionary:
	var path_a := str(params.get("path_a", ""))
	var path_b := str(params.get("path_b", ""))
	if path_a == "" or path_b == "":
		return { "status": "error", "message": "Parâmetros 'path_a' e 'path_b' obrigatórios." }
	var img_a := Image.load_from_file(path_a)
	var img_b := Image.load_from_file(path_b)
	if not img_a or not img_b:
		return { "status": "error", "message": "Falha ao carregar imagens." }
	if img_a.get_size() != img_b.get_size():
		return { "status": "success", "identical": false, "diff_percentage": 100.0, "message": "Imagens com tamanhos diferentes (%s vs %s)." % [str(img_a.get_size()), str(img_b.get_size())] }
	var diff_pixels := 0
	var total := img_a.get_width() * img_a.get_height()
	for y in range(img_a.get_height()):
		for x in range(img_a.get_width()):
			if img_a.get_pixel(x, y) != img_b.get_pixel(x, y):
				diff_pixels += 1
	var pct := (float(diff_pixels) / float(total)) * 100.0
	return { "status": "success", "identical": diff_pixels == 0, "diff_pixels": diff_pixels, "total_pixels": total, "diff_percentage": pct, "message": "%.2f%% de pixels diferentes (%d/%d)." % [pct, diff_pixels, total] }

func _run_stress_test(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", ""))
	if scene_path == "":
		scene_path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var frames := clampi(int(params.get("frames", 300)), 30, 3000)
	var hv := _headless_validate(scene_path, frames)
	return { "status": "success", "frames": frames, "errors": hv.get("errors", []), "error_count": hv.get("errors", []).size(), "return_code": hv.get("return_code", -1), "message": "Stress test: %d frames, %d erro(s)." % [frames, hv.get("errors", []).size()] }

func _get_test_report(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", ""))
	if scene_path == "":
		scene_path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	# Run headless validation
	var hv := _headless_validate(scene_path, 90)
	var errors: Array = hv.get("errors", [])
	# Compile report
	var report: Dictionary = {
		"status": "success",
		"scene": scene_path,
		"error_count": errors.size(),
		"errors": errors,
		"passed": errors.size() == 0,
		"message": "Relatório: %s — %d erro(s)." % [scene_path, errors.size()]
	}
	return report

# --- Bloco 12: Particle ---

func _create_particles(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var is_2d := bool(params.get("2d", true))
	var node: Node
	if is_2d:
		node = GPUParticles2D.new()
	else:
		node = GPUParticles3D.new()
	node.name = str(params.get("node_name", "Particles"))
	parent.add_child(node)
	node.owner = scene_root
	if params.has("amount"):
		node.set("amount", int(params.get("amount")))
	if params.has("lifetime"):
		node.set("lifetime", float(params.get("lifetime")))
	if params.has("emitting"):
		node.set("emitting", bool(params.get("emitting")))
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(node), "message": "%s '%s' criado." % [node.get_class(), node.name] }

func _set_particle_material(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("process_material" in target):
		return { "status": "error", "message": "Nó não suporta process_material." }
	var mat := ParticleProcessMaterial.new()
	if params.has("direction"):
		var d: Variant = params.get("direction")
		if d is Array and d.size() >= 3:
			mat.direction = Vector3(float(d[0]), float(d[1]), float(d[2]))
	if params.has("spread"):
		mat.spread = float(params.get("spread"))
	if params.has("gravity"):
		var g: Variant = params.get("gravity")
		if g is Array and g.size() >= 3:
			mat.gravity = Vector3(float(g[0]), float(g[1]), float(g[2]))
	if params.has("initial_velocity_min"):
		mat.initial_velocity_min = float(params.get("initial_velocity_min"))
	if params.has("initial_velocity_max"):
		mat.initial_velocity_max = float(params.get("initial_velocity_max"))
	target.set("process_material", mat)
	_mark_scene_modified()
	return { "status": "success", "message": "Material de partícula definido em '%s'." % target.name }

func _set_particle_color_gradient(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("process_material" in target):
		return { "status": "error", "message": "Nó não suporta process_material." }
	var mat: ParticleProcessMaterial = target.get("process_material") as ParticleProcessMaterial
	if not mat:
		mat = ParticleProcessMaterial.new()
		target.set("process_material", mat)
	var gradient := Gradient.new()
	var colors_raw: Variant = params.get("colors", [])
	if colors_raw is Array:
		for i: int in range(colors_raw.size()):
			var c: Variant = colors_raw[i]
			if c is Array and c.size() >= 3:
				var offset: float = float(i) / max(1.0, float(colors_raw.size() - 1))
				if i == 0:
					gradient.set_color(0, Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0))
				else:
					gradient.add_point(offset, Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0))
	var gt := GradientTexture1D.new()
	gt.gradient = gradient
	mat.color_ramp = gt
	_mark_scene_modified()
	return { "status": "success", "message": "Gradiente de cor definido nas partículas." }

func _apply_particle_preset(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("process_material" in target):
		return { "status": "error", "message": "Nó não suporta process_material." }
	var preset := str(params.get("preset", "fire"))
	var mat := ParticleProcessMaterial.new()
	match preset:
		"fire":
			mat.direction = Vector3(0, -1, 0); mat.spread = 15.0; mat.gravity = Vector3(0, -20, 0)
			mat.initial_velocity_min = 20.0; mat.initial_velocity_max = 40.0
		"smoke":
			mat.direction = Vector3(0, -1, 0); mat.spread = 30.0; mat.gravity = Vector3(0, -5, 0)
			mat.initial_velocity_min = 5.0; mat.initial_velocity_max = 15.0
		"sparks":
			mat.direction = Vector3(0, -1, 0); mat.spread = 45.0; mat.gravity = Vector3(0, 98, 0)
			mat.initial_velocity_min = 50.0; mat.initial_velocity_max = 100.0
		"explosion":
			mat.direction = Vector3(0, 0, 0); mat.spread = 180.0; mat.gravity = Vector3(0, 98, 0)
			mat.initial_velocity_min = 80.0; mat.initial_velocity_max = 150.0
		_:
			return { "status": "error", "message": "Preset desconhecido: '%s'. Use: fire, smoke, sparks, explosion." % preset }
	target.set("process_material", mat)
	if "one_shot" in target and preset == "explosion":
		target.set("one_shot", true)
	_mark_scene_modified()
	return { "status": "success", "message": "Preset '%s' aplicado a '%s'." % [preset, target.name] }

func _get_particle_info(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var info: Dictionary = { "status": "success", "node": str(target.name), "type": target.get_class() }
	for prop in ["amount", "lifetime", "emitting", "one_shot", "explosiveness"]:
		if prop in target:
			info[prop] = var_to_str(target.get(prop))
	if "process_material" in target and target.get("process_material"):
		info["has_material"] = true
	else:
		info["has_material"] = false
	info["message"] = "Info de partículas de '%s'." % target.name
	return info

# --- Bloco 12: Navigation ---

func _setup_navigation_region(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var region := NavigationRegion2D.new()
	region.name = str(params.get("node_name", "NavigationRegion2D"))
	parent.add_child(region)
	region.owner = scene_root
	var mesh := NavigationPolygon.new()
	region.navigation_polygon = mesh
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(region), "message": "NavigationRegion2D '%s' criado." % region.name }

func _setup_navigation_agent(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var agent := NavigationAgent2D.new()
	agent.name = str(params.get("node_name", "NavigationAgent2D"))
	if params.has("target_desired_distance"):
		agent.target_desired_distance = float(params.get("target_desired_distance"))
	if params.has("path_desired_distance"):
		agent.path_desired_distance = float(params.get("path_desired_distance"))
	parent.add_child(agent)
	agent.owner = scene_root
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(agent), "message": "NavigationAgent2D '%s' criado." % agent.name }

func _bake_navigation_mesh(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is NavigationRegion2D):
		return { "status": "error", "message": "Nó não é NavigationRegion2D." }
	(target as NavigationRegion2D).bake_navigation_polygon()
	return { "status": "success", "message": "Navigation mesh baked para '%s'." % target.name }

func _set_navigation_layers(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	if "navigation_layers" in target:
		target.set("navigation_layers", int(params.get("layers", 1)))
		_mark_scene_modified()
		return { "status": "success", "message": "Navigation layers definidos." }
	return { "status": "error", "message": "Nó '%s' não suporta navigation_layers." % target.name }

func _get_navigation_info(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var info: Dictionary = { "status": "success", "node": str(target.name), "type": target.get_class() }
	if target is NavigationRegion2D:
		info["has_polygon"] = target.navigation_polygon != null
	if "navigation_layers" in target:
		info["navigation_layers"] = int(target.get("navigation_layers"))
	info["message"] = "Info de navegação de '%s'." % target.name
	return info

# --- Bloco 13: AnimationTree/StateMachine ---

func _create_animation_tree(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var tree := AnimationTree.new()
	tree.name = str(params.get("node_name", "AnimationTree"))
	var root_type := str(params.get("root_type", "AnimationNodeStateMachine"))
	if ClassDB.class_exists(root_type) and ClassDB.is_parent_class(root_type, "AnimationRootNode"):
		tree.tree_root = ClassDB.instantiate(root_type) as AnimationRootNode
	if params.has("anim_player"):
		tree.anim_player = NodePath(str(params.get("anim_player")))
	parent.add_child(tree)
	tree.owner = scene_root
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(tree), "message": "AnimationTree '%s' criado com %s." % [tree.name, root_type] }

func _get_animation_tree_structure(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is AnimationTree):
		return { "status": "error", "message": "Nó não é AnimationTree." }
	var tree := target as AnimationTree
	var info: Dictionary = { "status": "success", "node": str(tree.name) }
	info["active"] = tree.active
	info["has_root"] = tree.tree_root != null
	if tree.tree_root:
		info["root_type"] = tree.tree_root.get_class()
	info["anim_player"] = str(tree.anim_player)
	return info

func _set_tree_parameter(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is AnimationTree):
		return { "status": "error", "message": "Nó não é AnimationTree." }
	var param := str(params.get("parameter", ""))
	if param == "":
		return { "status": "error", "message": "Parâmetro 'parameter' obrigatório." }
	(target as AnimationTree).set(param, params.get("value"))
	_mark_scene_modified()
	return { "status": "success", "message": "Parâmetro '%s' definido." % param }

func _add_state_machine_state(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is AnimationTree):
		return { "status": "error", "message": "Nó não é AnimationTree." }
	var sm: AnimationNodeStateMachine = (target as AnimationTree).tree_root as AnimationNodeStateMachine
	if not sm:
		return { "status": "error", "message": "tree_root não é AnimationNodeStateMachine." }
	var state_name := str(params.get("state_name", ""))
	if state_name == "":
		return { "status": "error", "message": "Parâmetro 'state_name' obrigatório." }
	var node_type := str(params.get("node_type", "AnimationNodeAnimation"))
	var anim_node: AnimationNode = ClassDB.instantiate(node_type) as AnimationNode if ClassDB.class_exists(node_type) else AnimationNodeAnimation.new()
	if anim_node is AnimationNodeAnimation and params.has("animation"):
		anim_node.animation = str(params.get("animation"))
	var pos := Vector2(float(params.get("position_x", 0)), float(params.get("position_y", 0)))
	sm.add_node(state_name, anim_node, pos)
	_mark_scene_modified()
	return { "status": "success", "message": "Estado '%s' adicionado à state machine." % state_name }

func _remove_state_machine_state(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is AnimationTree):
		return { "status": "error", "message": "Nó não é AnimationTree." }
	var sm: AnimationNodeStateMachine = (target as AnimationTree).tree_root as AnimationNodeStateMachine
	if not sm:
		return { "status": "error", "message": "tree_root não é AnimationNodeStateMachine." }
	var state_name := str(params.get("state_name", ""))
	if not sm.has_node(state_name):
		return { "status": "error", "message": "Estado '%s' não encontrado." % state_name }
	sm.remove_node(state_name)
	_mark_scene_modified()
	return { "status": "success", "message": "Estado '%s' removido." % state_name }

func _add_state_machine_transition(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is AnimationTree):
		return { "status": "error", "message": "Nó não é AnimationTree." }
	var sm: AnimationNodeStateMachine = (target as AnimationTree).tree_root as AnimationNodeStateMachine
	if not sm:
		return { "status": "error", "message": "tree_root não é AnimationNodeStateMachine." }
	var from := str(params.get("from", ""))
	var to := str(params.get("to", ""))
	if from == "" or to == "":
		return { "status": "error", "message": "Parâmetros 'from' e 'to' obrigatórios." }
	var tr := AnimationNodeStateMachineTransition.new()
	if params.has("auto_advance"):
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO if bool(params.get("auto_advance")) else AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	sm.add_transition(from, to, tr)
	_mark_scene_modified()
	return { "status": "success", "message": "Transição '%s' -> '%s' adicionada." % [from, to] }

func _remove_state_machine_transition(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is AnimationTree):
		return { "status": "error", "message": "Nó não é AnimationTree." }
	var sm: AnimationNodeStateMachine = (target as AnimationTree).tree_root as AnimationNodeStateMachine
	if not sm:
		return { "status": "error", "message": "tree_root não é AnimationNodeStateMachine." }
	var from := str(params.get("from", ""))
	var to := str(params.get("to", ""))
	if from == "" or to == "":
		return { "status": "error", "message": "Parâmetros 'from' e 'to' obrigatórios." }
	sm.remove_transition(from, to)
	_mark_scene_modified()
	return { "status": "success", "message": "Transição '%s' -> '%s' removida." % [from, to] }

func _set_blend_tree_node(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not (target is AnimationTree):
		return { "status": "error", "message": "Nó não é AnimationTree." }
	var bt: AnimationNodeBlendTree = (target as AnimationTree).tree_root as AnimationNodeBlendTree
	if not bt:
		return { "status": "error", "message": "tree_root não é AnimationNodeBlendTree." }
	var node_name := str(params.get("blend_node_name", ""))
	var node_type := str(params.get("node_type", "AnimationNodeAnimation"))
	if node_name == "":
		return { "status": "error", "message": "Parâmetro 'blend_node_name' obrigatório." }
	var anim_node: AnimationNode = ClassDB.instantiate(node_type) as AnimationNode if ClassDB.class_exists(node_type) else AnimationNodeAnimation.new()
	var pos := Vector2(float(params.get("position_x", 0)), float(params.get("position_y", 0)))
	bt.add_node(node_name, anim_node, pos)
	_mark_scene_modified()
	return { "status": "success", "message": "Nó '%s' (%s) adicionado ao BlendTree." % [node_name, node_type] }

# --- Bloco 14: Shader ---

func _create_shader(params: Dictionary) -> Dictionary:
	var save_path := str(params.get("save_path", ""))
	var shader_type := str(params.get("shader_type", "canvas_item"))
	var code := str(params.get("code", ""))
	if code == "":
		code = "shader_type %s;\n\nvoid fragment() {\n\tCOLOR = vec4(1.0, 1.0, 1.0, 1.0);\n}\n" % shader_type
	if save_path == "":
		return { "status": "error", "message": "Parâmetro 'save_path' obrigatório (ex: res://my_shader.gdshader)." }
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if not f:
		return { "status": "error", "message": "Falha ao criar arquivo '%s'." % save_path }
	f.store_string(code)
	f.close()
	_refresh_editor_filesystem()
	return { "status": "success", "message": "Shader salvo em '%s'." % save_path, "save_path": save_path }

func _read_shader(params: Dictionary) -> Dictionary:
	var path := str(params.get("shader_path", params.get("save_path", "")))
	if path == "" or not FileAccess.file_exists(path):
		return { "status": "error", "message": "Shader não encontrado: '%s'." % path }
	var code := FileAccess.get_file_as_string(path)
	return { "status": "success", "shader_path": path, "code": code }

func _edit_shader(params: Dictionary) -> Dictionary:
	var path := str(params.get("shader_path", ""))
	var code := str(params.get("code", ""))
	if path == "" or code == "":
		return { "status": "error", "message": "Parâmetros 'shader_path' e 'code' obrigatórios." }
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return { "status": "error", "message": "Falha ao escrever em '%s'." % path }
	f.store_string(code)
	f.close()
	_refresh_editor_filesystem()
	return { "status": "success", "message": "Shader '%s' atualizado." % path }

func _assign_shader_material(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	var shader_path := str(params.get("shader_path", ""))
	if shader_path == "":
		return { "status": "error", "message": "Parâmetro 'shader_path' obrigatório." }
	var shader: Shader = ResourceLoader.load(shader_path) as Shader
	if not shader:
		return { "status": "error", "message": "Shader não encontrado/inválido: '%s'." % shader_path }
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if "material" in target:
		target.set("material", mat)
	else:
		return { "status": "error", "message": "Nó '%s' não suporta 'material'." % target.name }
	_mark_scene_modified()
	return { "status": "success", "message": "ShaderMaterial atribuído a '%s'." % target.name }

func _set_shader_param(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("material" in target):
		return { "status": "error", "message": "Nó não encontrado ou sem material." }
	var mat: ShaderMaterial = target.get("material") as ShaderMaterial
	if not mat:
		return { "status": "error", "message": "Material não é ShaderMaterial." }
	var param := str(params.get("param", ""))
	mat.set_shader_parameter(param, params.get("value"))
	_mark_scene_modified()
	return { "status": "success", "message": "Shader param '%s' definido." % param }

func _get_shader_params(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target or not ("material" in target):
		return { "status": "error", "message": "Nó não encontrado ou sem material." }
	var mat: ShaderMaterial = target.get("material") as ShaderMaterial
	if not mat or not mat.shader:
		return { "status": "error", "message": "Material não é ShaderMaterial ou sem shader." }
	var shader_params: Array = []
	for p in mat.shader.get_shader_uniform_list():
		shader_params.append({ "name": str(p.get("name", "")), "type": p.get("type", 0) })
	return { "status": "success", "params": shader_params }

# --- Bloco 14: Export ---

func _list_export_presets() -> Dictionary:
	var config_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(config_path):
		return { "status": "success", "presets": [], "message": "Nenhum preset de exportação encontrado." }
	var content := FileAccess.get_file_as_string(config_path)
	var presets: Array = []
	for line in content.split("\n"):
		var l := String(line).strip_edges()
		if l.begins_with("name="):
			presets.append(l.trim_prefix("name=").trim_prefix("\"").trim_suffix("\""))
	return { "status": "success", "presets": presets, "count": presets.size() }

func _export_project(params: Dictionary) -> Dictionary:
	var preset_name := str(params.get("preset", ""))
	var output_path := str(params.get("output_path", ""))
	if preset_name == "" or output_path == "":
		return { "status": "error", "message": "Parâmetros 'preset' e 'output_path' obrigatórios." }
	var bin := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var output: Array = []
	var code := OS.execute(bin, ["--headless", "--path", proj, "--export-debug", preset_name, output_path], output, true)
	var raw := str(output[0]) if output.size() > 0 else ""
	return { "status": "success", "return_code": code, "output": raw.substr(0, 2000), "message": "Export '%s' -> '%s' (code %d)." % [preset_name, output_path, code] }

func _get_export_info() -> Dictionary:
	var presets := _list_export_presets()
	return { "status": "success", "presets": presets.get("presets", []), "godot_version": str(Engine.get_version_info().get("string", "")), "message": "Info de exportação." }

# --- Bloco 14: Profiling ---

func _get_performance_monitors() -> Dictionary:
	var monitors: Dictionary = {}
	monitors["fps"] = Performance.get_monitor(Performance.TIME_FPS)
	monitors["process_time"] = Performance.get_monitor(Performance.TIME_PROCESS)
	monitors["physics_time"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	monitors["render_objects"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	monitors["render_draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	monitors["memory_static"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	monitors["object_count"] = Performance.get_monitor(Performance.OBJECT_COUNT)
	monitors["node_count"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	monitors["orphan_count"] = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	return { "status": "success", "monitors": monitors }

func _get_editor_performance() -> Dictionary:
	return _get_performance_monitors()  # Same data in editor context

# --- Bloco 15: Batch/Refactoring ---

func _find_nodes_by_type(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var type_name := str(params.get("type", ""))
	if type_name == "":
		return { "status": "error", "message": "Parâmetro 'type' obrigatório." }
	var found: Array = []
	_collect_by_type(scene_root, scene_root, type_name, found)
	return { "status": "success", "type": type_name, "count": found.size(), "nodes": found }

func _collect_by_type(node: Node, root: Node, type_name: String, out: Array) -> void:
	if node.is_class(type_name):
		out.append({ "name": String(node.name), "path": str(root.get_path_to(node)) if node != root else ".", "type": node.get_class() })
	for c in node.get_children():
		_collect_by_type(c, root, type_name, out)

func _find_signal_connections(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var signal_name := str(params.get("signal", ""))
	var connections: Array = []
	_collect_connections(scene_root, scene_root, signal_name, connections)
	return { "status": "success", "signal": signal_name, "count": connections.size(), "connections": connections }

func _collect_connections(node: Node, root: Node, signal_filter: String, out: Array) -> void:
	for sig in node.get_signal_list():
		var sn := str(sig.get("name", ""))
		if signal_filter != "" and sn != signal_filter:
			continue
		for conn in node.get_signal_connection_list(sn):
			out.append({ "from": str(root.get_path_to(node)) if node != root else ".", "signal": sn, "to": str(root.get_path_to(conn.get("callable").get_object())) if conn.get("callable") else "", "method": str(conn.get("callable").get_method()) if conn.get("callable") else "" })
	for c in node.get_children():
		_collect_connections(c, root, signal_filter, out)

func _batch_set_property(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var type_name := str(params.get("type", ""))
	var prop := str(params.get("property", ""))
	var value: Variant = params.get("value")
	if type_name == "" or prop == "":
		return { "status": "error", "message": "Parâmetros 'type' e 'property' obrigatórios." }
	var count := 0
	_apply_to_type(scene_root, type_name, prop, value, count)
	_mark_scene_modified()
	return { "status": "success", "modified": count, "message": "%d nó(s) do tipo '%s' tiveram '%s' alterado." % [count, type_name, prop] }

func _apply_to_type(node: Node, type_name: String, prop: String, value: Variant, count: int) -> void:
	if node.is_class(type_name) and prop in node:
		node.set(prop, _coerce_value(node, prop, value))
		count += 1
	for c in node.get_children():
		_apply_to_type(c, type_name, prop, value, count)

func _find_node_references(params: Dictionary) -> Dictionary:
	var node_name := str(params.get("node_name", ""))
	if node_name == "":
		return { "status": "error", "message": "Parâmetro 'node_name' obrigatório." }
	var results: Array = []
	_walk_search("res://", node_name.to_lower(), true, results)
	return { "status": "success", "query": node_name, "count": results.size(), "files": results }

func _get_scene_dependencies(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", ""))
	if scene_path == "" or not FileAccess.file_exists(scene_path):
		return { "status": "error", "message": "Cena não encontrada: '%s'." % scene_path }
	var content := FileAccess.get_file_as_string(scene_path)
	var deps: Array = []
	for line in content.split("\n"):
		var l := String(line).strip_edges()
		if l.begins_with("[ext_resource"):
			var path_match := l.find("path=\"")
			if path_match >= 0:
				var start := path_match + 6
				var end_pos := l.find("\"", start)
				if end_pos > start:
					deps.append(l.substr(start, end_pos - start))
	return { "status": "success", "scene": scene_path, "dependencies": deps, "count": deps.size() }

func _cross_scene_set_property(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", ""))
	var node_path := str(params.get("node_path", ""))
	var prop := str(params.get("property", ""))
	var value: Variant = params.get("value")
	if scene_path == "" or node_path == "" or prop == "":
		return { "status": "error", "message": "Parâmetros 'scene_path', 'node_path' e 'property' obrigatórios." }
	var packed: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if not packed:
		return { "status": "error", "message": "Cena '%s' não encontrada." % scene_path }
	var scene := packed.instantiate()
	if not scene:
		return { "status": "error", "message": "Falha ao instanciar cena." }
	var target: Node = scene if node_path in [".", ""] else scene.get_node_or_null(node_path)
	if not target:
		scene.queue_free()
		return { "status": "error", "message": "Nó '%s' não encontrado na cena '%s'." % [node_path, scene_path] }
	target.set(prop, _coerce_value(target, prop, value))
	var new_packed := PackedScene.new()
	new_packed.pack(scene)
	ResourceSaver.save(new_packed, scene_path)
	scene.queue_free()
	_refresh_editor_filesystem()
	return { "status": "success", "message": "Propriedade '%s' alterada em '%s' da cena '%s'." % [prop, node_path, scene_path] }

func _find_script_references(params: Dictionary) -> Dictionary:
	var script_path := str(params.get("script_path", ""))
	if script_path == "":
		return { "status": "error", "message": "Parâmetro 'script_path' obrigatório." }
	var results: Array = []
	_walk_search("res://", script_path.to_lower(), true, results)
	return { "status": "success", "query": script_path, "count": results.size(), "files": results }

func _detect_circular_dependencies(params: Dictionary) -> Dictionary:
	var scene_path := str(params.get("scene_path", ""))
	if scene_path == "":
		scene_path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var visited: Array = []
	var circular: Array = []
	_check_deps_recursive(scene_path, visited, circular)
	return { "status": "success", "circular": circular, "has_circular": circular.size() > 0, "message": "%d dependência(s) circular(es) encontrada(s)." % circular.size() }

func _check_deps_recursive(path: String, visited: Array, circular: Array) -> void:
	if path in visited:
		circular.append(path)
		return
	visited.append(path)
	if not FileAccess.file_exists(path):
		return
	var content := FileAccess.get_file_as_string(path)
	for line in content.split("\n"):
		var l := String(line).strip_edges()
		if l.begins_with("[ext_resource") and l.contains("path=\""):
			var start := l.find("path=\"") + 6
			var end_pos := l.find("\"", start)
			if end_pos > start:
				var dep := l.substr(start, end_pos - start)
				if dep.ends_with(".tscn"):
					_check_deps_recursive(dep, visited.duplicate(), circular)

# --- Bloco 15: Analysis ---

func _analyze_scene_complexity(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var stats := { "total_nodes": 0, "max_depth": 0, "scripts": 0, "types": {} }
	_count_nodes(scene_root, 0, stats)
	return { "status": "success", "stats": stats, "message": "%d nós, profundidade máxima %d, %d scripts." % [stats["total_nodes"], stats["max_depth"], stats["scripts"]] }

func _count_nodes(node: Node, depth: int, stats: Dictionary) -> void:
	stats["total_nodes"] = int(stats["total_nodes"]) + 1
	if depth > int(stats["max_depth"]):
		stats["max_depth"] = depth
	if node.get_script():
		stats["scripts"] = int(stats["scripts"]) + 1
	var t := node.get_class()
	var types: Dictionary = stats.get("types", {})
	types[t] = int(types.get(t, 0)) + 1
	stats["types"] = types
	for c in node.get_children():
		_count_nodes(c, depth + 1, stats)

func _analyze_signal_flow(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var connections: Array = []
	_collect_connections(scene_root, scene_root, "", connections)
	return { "status": "success", "connection_count": connections.size(), "connections": connections }

func _find_unused_resources(params: Dictionary) -> Dictionary:
	var dir := str(params.get("dir_path", "res://"))
	var all_files: Array = []
	_walk_search(dir, "", false, all_files)
	# Check which resource files aren't referenced in any .tscn/.gd
	var referenced: Dictionary = {}
	var scenes_and_scripts: Array = []
	_walk_search("res://", ".tscn", false, scenes_and_scripts)
	_walk_search("res://", ".gd", false, scenes_and_scripts)
	for f: Variant in scenes_and_scripts:
		if FileAccess.file_exists(str(f)):
			var content := FileAccess.get_file_as_string(str(f))
			referenced[str(f)] = content
	var unused: Array = []
	for f: Variant in all_files:
		var fs := str(f)
		if fs.ends_with(".tres") or fs.ends_with(".png") or fs.ends_with(".svg") or fs.ends_with(".wav") or fs.ends_with(".ogg"):
			var is_ref := false
			for _k: Variant in referenced:
				if String(referenced[_k]).contains(fs.get_file()):
					is_ref = true
					break
			if not is_ref:
				unused.append(fs)
	return { "status": "success", "unused": unused, "count": unused.size(), "message": "%d recurso(s) possivelmente não referenciado(s)." % unused.size() }

func _get_project_statistics() -> Dictionary:
	var stats: Dictionary = { "status": "success" }
	var scripts: Array = []; _walk_scripts("res://", scripts)
	stats["script_count"] = scripts.size()
	var scenes: Array = []; _walk_search("res://", ".tscn", false, scenes)
	stats["scene_count"] = scenes.size()
	var resources: Array = []; _walk_search("res://", ".tres", false, resources)
	stats["resource_count"] = resources.size()
	stats["name"] = str(ProjectSettings.get_setting("application/config/name", ""))
	stats["main_scene"] = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	stats["message"] = "Projeto: %d scripts, %d cenas, %d recursos." % [scripts.size(), scenes.size(), resources.size()]
	return stats

# --- Bloco 16: 3D ---

func _add_mesh_instance(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var mi := MeshInstance3D.new()
	mi.name = str(params.get("node_name", "MeshInstance3D"))
	var mesh_type := str(params.get("mesh_type", "BoxMesh"))
	if ClassDB.class_exists(mesh_type) and ClassDB.is_parent_class(mesh_type, "Mesh"):
		mi.mesh = ClassDB.instantiate(mesh_type) as Mesh
		if mi.mesh is BoxMesh and params.has("size"):
			var s: Variant = params.get("size")
			if s is Array and s.size() >= 3:
				(mi.mesh as BoxMesh).size = Vector3(float(s[0]), float(s[1]), float(s[2]))
		elif mi.mesh is SphereMesh and params.has("radius"):
			(mi.mesh as SphereMesh).radius = float(params.get("radius"))
	parent.add_child(mi)
	mi.owner = scene_root
	if params.has("position"):
		mi.position = _coerce_value(mi, "position", params.get("position"))
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(mi), "message": "MeshInstance3D '%s' com %s criado." % [mi.name, mesh_type] }

func _setup_camera_3d(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var cam := Camera3D.new()
	cam.name = str(params.get("node_name", "Camera3D"))
	if params.has("position"):
		cam.position = _coerce_value(cam, "position", params.get("position"))
	if params.has("fov"):
		cam.fov = float(params.get("fov"))
	if params.has("current"):
		cam.current = bool(params.get("current"))
	parent.add_child(cam)
	cam.owner = scene_root
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(cam), "message": "Camera3D '%s' criada." % cam.name }

func _setup_lighting(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var light_type := str(params.get("light_type", "DirectionalLight3D"))
	if not ClassDB.class_exists(light_type) or not ClassDB.is_parent_class(light_type, "Light3D"):
		light_type = "DirectionalLight3D"
	var light: Node = ClassDB.instantiate(light_type)
	light.name = str(params.get("node_name", light_type))
	parent.add_child(light)
	light.owner = scene_root
	if params.has("energy"):
		light.set("light_energy", float(params.get("energy")))
	if params.has("color"):
		light.set("light_color", _coerce_value(light, "light_color", params.get("color")))
	if params.has("position"):
		light.set("position", _coerce_value(light, "position", params.get("position")))
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(light), "message": "%s '%s' criado." % [light_type, light.name] }

func _setup_environment(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var we := WorldEnvironment.new()
	we.name = str(params.get("node_name", "WorldEnvironment"))
	var env := Environment.new()
	if params.has("bg_mode"):
		env.background_mode = int(params.get("bg_mode"))
	if params.has("bg_color"):
		env.background_color = _coerce_value(env, "background_color", params.get("bg_color"))
	if params.has("ambient_color"):
		env.ambient_light_color = _coerce_value(env, "ambient_light_color", params.get("ambient_color"))
	we.environment = env
	parent.add_child(we)
	we.owner = scene_root
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(we), "message": "WorldEnvironment '%s' criado." % we.name }

func _add_gridmap(params: Dictionary) -> Dictionary:
	var scene_root := _get_edited_scene_root()
	if not scene_root:
		return { "status": "error", "message": "Nenhuma cena aberta." }
	var parent := _resolve_node(scene_root, str(params.get("parent_path", ".")))
	if not parent:
		return { "status": "error", "message": "Nó pai não encontrado." }
	var gm := GridMap.new()
	gm.name = str(params.get("node_name", "GridMap"))
	parent.add_child(gm)
	gm.owner = scene_root
	if params.has("cell_size"):
		var cs: Variant = params.get("cell_size")
		if cs is Array and cs.size() >= 3:
			gm.cell_size = Vector3(float(cs[0]), float(cs[1]), float(cs[2]))
	_mark_scene_modified()
	return { "status": "success", "node": _rel_path(gm), "message": "GridMap '%s' criado." % gm.name }

func _set_material_3d(params: Dictionary) -> Dictionary:
	var target := _resolve_scene_node(params)
	if not target:
		return { "status": "error", "message": "Nó não encontrado." }
	if not (target is MeshInstance3D):
		return { "status": "error", "message": "Nó '%s' não é MeshInstance3D." % target.name }
	var mi := target as MeshInstance3D
	var mat := StandardMaterial3D.new()
	if params.has("albedo_color"):
		mat.albedo_color = _coerce_value(mat, "albedo_color", params.get("albedo_color"))
	if params.has("metallic"):
		mat.metallic = float(params.get("metallic"))
	if params.has("roughness"):
		mat.roughness = float(params.get("roughness"))
	if params.has("emission_color"):
		mat.emission_enabled = true
		mat.emission = _coerce_value(mat, "emission", params.get("emission_color"))
	var surface_idx := int(params.get("surface_index", 0))
	mi.set_surface_override_material(surface_idx, mat)
	_mark_scene_modified()
	return { "status": "success", "message": "Material 3D aplicado a '%s' (surface %d)." % [target.name, surface_idx] }

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
	# Extrai o zip da documentação (path relativo ao próprio addon — portável).
	var script_res: Script = get_script()
	var zip_path: String = script_res.resource_path.get_base_dir() + "/references/godot_docs_html.zip"
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
		return { "status": "error", "message": "Documentação offline não encontrada (references/godot_docs_html.zip no addon)." }

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
