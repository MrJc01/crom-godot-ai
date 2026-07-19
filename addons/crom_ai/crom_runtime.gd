extends Node

# ==============================================================================
# CromRuntime — autoload que roda DENTRO do jogo executado (play_scene).
# O editor/plugin não enxerga o processo do jogo; este nó abre um servidor
# WebSocket na porta 8091 para o editor consultar o estado do jogo em execução
# (árvore de nós viva, propriedades de nós — ex.: a posição da cobra a cada frame).
# É o que permite verificar GAMEPLAY ("algo se moveu?"), não só ausência de erro.
# ==============================================================================

const PORT := 8091

var _server: TCPServer = null
var _peers: Array[WebSocketPeer] = []

func _ready() -> void:
	# Só faz sentido no jogo em execução, não dentro do editor.
	if Engine.is_editor_hint():
		set_process(false)
		return
	_server = TCPServer.new()
	if _server.listen(PORT, "127.0.0.1") == OK:
		set_process(true)
	else:
		set_process(false)

func _process(_delta: float) -> void:
	if not _server:
		return
	while _server.is_connection_available():
		var conn := _server.take_connection()
		if conn:
			var ws := WebSocketPeer.new()
			ws.accept_stream(conn)
			_peers.append(ws)
	var i := 0
	while i < _peers.size():
		var ws := _peers[i]
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var msg := ws.get_packet().get_string_from_utf8()
				ws.send_text(JSON.stringify(_handle(msg)))
			i += 1
		elif st == WebSocketPeer.STATE_CLOSED:
			_peers.remove_at(i)
		else:
			i += 1

func _handle(msg: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(msg)
	if not (parsed is Dictionary):
		return { "status": "error", "message": "JSON inválido." }
	var action := str(parsed.get("action", ""))
	var params: Dictionary = parsed.get("params", {}) if parsed.get("params") is Dictionary else {}
	var scene := get_tree().current_scene
	match action:
		"ping":
			return { "status": "success", "message": "crom_runtime vivo no jogo." }
		"get_tree":
			if not scene:
				return { "status": "error", "message": "Nenhuma cena atual em execução." }
			return { "status": "success", "tree": _serialize(scene, 0) }
		"get_property":
			var np := str(params.get("node_path", "."))
			var prop := str(params.get("property", ""))
			var n: Node = scene if np in [".", ""] else (scene.get_node_or_null(np) if scene else null)
			if not n:
				return { "status": "error", "message": "Nó '%s' não encontrado no jogo." % np }
			if not (prop in n):
				return { "status": "error", "message": "Propriedade '%s' não existe em '%s'." % [prop, n.name] }
			return { "status": "success", "node": np, "property": prop, "value": var_to_str(n.get(prop)) }
		"set_property":
			var np := str(params.get("node_path", "."))
			var prop := str(params.get("property", ""))
			var n: Node = _resolve_rt(np)
			if not n:
				return { "status": "error", "message": "Nó '%s' não encontrado no jogo." % np }
			if not (prop in n):
				return { "status": "error", "message": "Propriedade '%s' não existe em '%s'." % [prop, n.name] }
			n.set(prop, _coerce_rt(n.get(prop), params.get("value")))
			return { "status": "success", "node": np, "property": prop, "value": var_to_str(n.get(prop)) }
		"get_properties":
			var np := str(params.get("node_path", "."))
			var n: Node = _resolve_rt(np)
			if not n:
				return { "status": "error", "message": "Nó '%s' não encontrado no jogo." % np }
			var props: Dictionary = {}
			for p in n.get_property_list():
				var pn := str(p.get("name", ""))
				if pn != "" and not pn.begins_with("_") and (int(p.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0:
					props[pn] = var_to_str(n.get(pn))
			return { "status": "success", "node": np, "type": n.get_class(), "properties": props }
		"node_exists":
			var np := str(params.get("node_path", ""))
			return { "status": "success", "exists": _resolve_rt(np) != null }
		"find_nodes":
			var type_filter := str(params.get("type", ""))
			var results: Array = []
			if scene:
				_find_by_type(scene, scene, type_filter, results)
			return { "status": "success", "type": type_filter, "count": results.size(), "nodes": results }
		"get_screen_text":
			var texts: Array = []
			if scene:
				_collect_text(scene, texts)
			return { "status": "success", "texts": texts }
		"click_button":
			var text := str(params.get("text", ""))
			var btn: BaseButton = _find_button_by_text(scene, text) if scene else null
			if not btn:
				return { "status": "error", "message": "Botão com texto '%s' não encontrado no jogo." % text }
			if btn.has_signal("pressed"):
				btn.emit_signal("pressed")
			return { "status": "success", "message": "Botão '%s' acionado." % text }
		"execute_script":
			var code := str(params.get("code", ""))
			var expression := Expression.new()
			var err := expression.parse(code)
			if err != OK:
				return { "status": "error", "message": "Erro de parse na expressão GDScript em runtime: %s" % expression.get_error_text() }
			var res: Variant = expression.execute([], scene)
			if expression.has_execute_failed():
				return { "status": "error", "message": "Falha ao executar expressão GDScript em runtime." }
			return { "status": "success", "result": var_to_str(res) }
		"find_by_script":
			var script_path := str(params.get("script_path", ""))
			var results: Array = []
			if scene:
				_find_by_script_rec(scene, scene, script_path, results)
			return { "status": "success", "script": script_path, "count": results.size(), "nodes": results }
		"batch_get_properties":
			var paths: Array = params.get("node_paths", []) if params.get("node_paths") is Array else []
			var props: Array = params.get("properties", []) if params.get("properties") is Array else []
			var res: Dictionary = {}
			for p in paths:
				var n := _resolve_rt(str(p))
				if n:
					var item: Dictionary = {}
					for pr in props:
						var prs := str(pr)
						if prs in n:
							item[prs] = var_to_str(n.get(prs))
					res[str(p)] = item
			return { "status": "success", "results": res }
		"find_nearby":
			var pos_raw: Variant = params.get("position", [0, 0])
			var radius := float(params.get("radius", 100.0))
			var results: Array = []
			if scene and pos_raw is Array and pos_raw.size() >= 2:
				var target_pos := Vector2(float(pos_raw[0]), float(pos_raw[1]))
				_find_nearby_rec(scene, scene, target_pos, radius, results)
			return { "status": "success", "count": results.size(), "nodes": results }
		"navigate_to":
			var agent_path := str(params.get("agent_path", ""))
			var agent := _resolve_rt(agent_path)
			var target_raw: Variant = params.get("target", [0, 0])
			if agent and "target_position" in agent and target_raw is Array and target_raw.size() >= 2:
				agent.set("target_position", Vector2(float(target_raw[0]), float(target_raw[1])))
				return { "status": "success", "message": "Target position definido no NavigationAgent." }
			return { "status": "error", "message": "Nó agência ou posição alvo inválida." }
		"move_to":
			var np := str(params.get("node_path", ""))
			var n := _resolve_rt(np)
			var target_raw: Variant = params.get("target", [0, 0])
			if n and target_raw is Array and target_raw.size() >= 2:
				if "position" in n:
					if n.position is Vector2:
						n.position = Vector2(float(target_raw[0]), float(target_raw[1]))
					elif n.position is Vector3 and target_raw.size() >= 3:
						n.position = Vector3(float(target_raw[0]), float(target_raw[1]), float(target_raw[2]))
					return { "status": "success", "message": "Nó '%s' movido." % np }
			return { "status": "error", "message": "Falha ao mover nó em runtime." }
	return { "status": "error", "message": "Ação de runtime desconhecida: '%s'." % action }


func _resolve_rt(np: String) -> Node:
	var scene := get_tree().current_scene
	if not scene:
		return null
	if np in [".", ""]:
		return scene
	return scene.get_node_or_null(np)

func _coerce_rt(current: Variant, value: Variant) -> Variant:
	if value is Array:
		if current is Vector2 and value.size() >= 2:
			return Vector2(value[0], value[1])
		if current is Vector3 and value.size() >= 3:
			return Vector3(value[0], value[1], value[2])
		if current is Color and value.size() >= 3:
			return Color(value[0], value[1], value[2], value[3] if value.size() > 3 else 1.0)
	return value

func _find_by_type(node: Node, scene: Node, type_filter: String, out: Array) -> void:
	if type_filter == "" or node.is_class(type_filter):
		out.append({ "name": String(node.name), "type": node.get_class(), "path": str(scene.get_path_to(node)) })
	for c in node.get_children():
		_find_by_type(c, scene, type_filter, out)

func _collect_text(node: Node, out: Array) -> void:
	if (node is Label or node is Button) and "text" in node:
		var t := str(node.text).strip_edges()
		if t != "":
			out.append(t)
	for c in node.get_children():
		_collect_text(c, out)

func _find_button_by_text(node: Node, text: String) -> BaseButton:
	if node is Button and "text" in node and str(node.text).strip_edges() == text.strip_edges():
		return node
	for c in node.get_children():
		var r: BaseButton = _find_button_by_text(c, text)
		if r:
			return r
	return null

func _serialize(node: Node, depth: int) -> Dictionary:
	var children := []
	if depth < 4:
		for c in node.get_children():
			children.append(_serialize(c, depth + 1))
	var d := { "name": String(node.name), "type": node.get_class(), "children": children }
	if "position" in node:
		d["position"] = var_to_str(node.position)
	if "visible" in node:
		d["visible"] = node.visible
	return d

func _find_by_script_rec(node: Node, scene: Node, script_path: String, out: Array) -> void:
	var s: Script = node.get_script()
	if s and s.resource_path == script_path:
		out.append({ "name": String(node.name), "type": node.get_class(), "path": str(scene.get_path_to(node)) })
	for c in node.get_children():
		_find_by_script_rec(c, scene, script_path, out)

func _find_nearby_rec(node: Node, scene: Node, target_pos: Vector2, radius: float, out: Array) -> void:
	if "position" in node and node.position is Vector2:
		if (node.position as Vector2).distance_to(target_pos) <= radius:
			out.append({ "name": String(node.name), "type": node.get_class(), "path": str(scene.get_path_to(node)), "distance": (node.position as Vector2).distance_to(target_pos) })
	for c in node.get_children():
		_find_nearby_rec(c, scene, target_pos, radius, out)

