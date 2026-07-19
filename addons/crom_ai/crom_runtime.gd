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
