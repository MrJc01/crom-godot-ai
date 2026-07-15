@tool
extends EditorPlugin

# ==============================================================================
# CromAI Plugin (@tool): O ponto de entrada principal do plugin no Godot
# ==============================================================================

var websocket_server: Node = null
var command_processor: Node = null
var chat_dock: Control = null

func _enter_tree() -> void:
	print("=========================================================")
	print("[CromAI Bridge] Carregando plugin do Editor no Godot...")
	
	# Instancia o Processador de Comandos passando a referência a este EditorPlugin
	var ProcessorClass = load("res://addons/crom_ai/command_processor.gd")
	if ProcessorClass:
		command_processor = ProcessorClass.new(self)
		command_processor.name = "CommandProcessor"
		add_child(command_processor)
		
	# Instancia o Servidor WebSocket na porta 8080
	var ServerClass = load("res://addons/crom_ai/websocket_server.gd")
	if ServerClass and command_processor:
		websocket_server = ServerClass.new(command_processor, 8080)
		websocket_server.name = "WebSocketServer"
		add_child(websocket_server)
		var started = websocket_server.start_server()
		if started:
			print("[CromAI Bridge] Sistema pronto! Conecte seu Servidor MCP/IA na porta 8080.")
		else:
			print("[CromAI Bridge] ERRO ao iniciar servidor na porta 8080.")
			
	# Carrega e abre de padrão o Chat Lateral (Dock) no editor do Godot!
	var DockScene = load("res://addons/crom_ai/chat_dock.tscn")
	if DockScene:
		chat_dock = DockScene.instantiate()
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, chat_dock)
		print("[CromAI Bridge] Painel de Chat Lateral aberto e fixado na barra direita do Editor Godot!")
			
	print("=========================================================")

func _process(_delta: float) -> void:
	if websocket_server and websocket_server.has_method("process_network"):
		websocket_server.process_network()

func _exit_tree() -> void:
	if chat_dock:
		remove_control_from_docks(chat_dock)
		chat_dock.queue_free()
		chat_dock = null
		
	if websocket_server:
		if websocket_server.has_method("stop_server"):
			websocket_server.stop_server()
		websocket_server.queue_free()
		websocket_server = null
	if command_processor:
		command_processor.queue_free()
		command_processor = null
	print("[CromAI Bridge] Plugin desativado.")

