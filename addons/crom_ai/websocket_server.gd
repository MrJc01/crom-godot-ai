@tool
extends Node

# ==============================================================================
# WebSocketServer para CromAI: Escuta na porta 8080 localmente dentro do Editor
# Recebe comandos JSON do Servidor MCP Python e responde com o estado do Godot.
# ==============================================================================

var tcp_server: TCPServer = null
var peers: Array[WebSocketPeer] = []
var port: int = 8080
var command_processor: Node = null

var tick_count := 0

func log_debug(msg: String) -> void:
	var f = FileAccess.open("res://crom_debug.log", FileAccess.READ_WRITE)
	if not f:
		f = FileAccess.open("res://crom_debug.log", FileAccess.WRITE)
	if f:
		f.seek_end()
		var timestamp = Time.get_datetime_string_from_system()
		f.store_line("[%s] %s" % [timestamp, msg])
		f.close()

func _init(processor: Node = null, listen_port: int = 8080) -> void:
	command_processor = processor
	port = listen_port

func start_server() -> bool:
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port, "127.0.0.1")
	if err != OK:
		print("[CromAI WebSocket] Falha ao escutar na porta %d. Erro: %d" % [port, err])
		log_debug("Falha ao escutar na porta %d. Erro: %d" % [port, err])
		return false
	print("[CromAI WebSocket] Servidor ativo e escutando na porta %d (ws://127.0.0.1:%d)" % [port, port])
	log_debug("Servidor ativo na porta %d. Desabilitando low_processor_usage_mode." % port)
	OS.low_processor_usage_mode = false
	return true

func stop_server() -> void:
	log_debug("Encerrando servidor.")
	for peer in peers:
		peer.close(1000, "Servidor sendo desativado")
	peers.clear()
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	print("[CromAI WebSocket] Servidor encerrado.")
	OS.low_processor_usage_mode = true

func process_network() -> void:
	if not tcp_server:
		return
		
	tick_count += 1
	if tick_count % 60 == 0:
		log_debug("Ticking process_network. Peers conectados: %d. low_processor: %s" % [peers.size(), str(OS.low_processor_usage_mode)])
		
	# Checa novas conexões
	while tcp_server.is_connection_available():
		var conn = tcp_server.take_connection()
		if conn:
			var ws = WebSocketPeer.new()
			# Aumenta buffer para 10MB para suportar envio de screenshots base64 gigantes
			ws.inbound_buffer_size = 10 * 1024 * 1024
			ws.outbound_buffer_size = 10 * 1024 * 1024
			ws.accept_stream(conn)
			peers.append(ws)
			print("[CromAI WebSocket] Novo cliente de agente conectado!")
			log_debug("Novo cliente de agente conectado de %s:%d" % [conn.get_status(), conn.get_requested_port() if conn.has_method("get_requested_port") else 0])
			
	# Processa peers existentes
	var idx = 0
	while idx < peers.size():
		var ws = peers[idx]
		ws.poll()
		
		var state = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var pkt = ws.get_packet()
				var msg = pkt.get_string_from_utf8()
				log_debug("Mensagem recebida: %s" % msg.left(200))
				_handle_message(ws, msg)
			idx += 1
		elif state == WebSocketPeer.STATE_CLOSED:
			print("[CromAI WebSocket] Cliente desconectado. Código: %d" % ws.get_close_code())
			log_debug("Cliente desconectado. Código: %d" % ws.get_close_code())
			peers.remove_at(idx)
		else:
			idx += 1

func _handle_message(ws: WebSocketPeer, message: String) -> void:
	# Processa o JSON com o CommandProcessor
	var response: Dictionary = {}
	if command_processor:
		response = command_processor.process_command(message)
	else:
		response = { "status": "error", "message": "CommandProcessor não inicializado." }
		
	# Serializa a resposta e envia de volta ao MCP
	var resp_json = JSON.stringify(response)
	log_debug("Enviando resposta: %s" % resp_json.left(200))
	ws.send_text(resp_json)
