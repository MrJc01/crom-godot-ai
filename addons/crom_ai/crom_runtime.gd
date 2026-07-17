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
	var parsed = JSON.parse_string(msg)
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
	return { "status": "error", "message": "Ação de runtime desconhecida: '%s'." % action }

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
