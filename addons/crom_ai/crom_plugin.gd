@tool
extends EditorPlugin

# ==============================================================================
# CromAI Plugin (@tool): O ponto de entrada principal do plugin no Godot
# ==============================================================================

var websocket_server: Node = null
var command_processor: Node = null
var chat_dock: Control = null
var _ctx_menu_files = null
var _ctx_menu_nodes = null

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
		print("[CromAI Bridge] Painel do Crom Agente fixado na barra direita do Editor Godot!")

	# Registra o menu de contexto "Enviar para o Crom Agente" (arquivos e nós)
	_register_context_menus()

	print("=========================================================")

func _register_context_menus() -> void:
	if not ClassDB.class_exists("EditorContextMenuPlugin"):
		return
	var CtxPlugin = load("res://addons/crom_ai/ui/context_menu_plugin.gd")
	if not CtxPlugin:
		return

	_ctx_menu_files = CtxPlugin.new()
	_ctx_menu_files.mode = "files"
	_ctx_menu_files.chat_dock = chat_dock
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _ctx_menu_files)

	_ctx_menu_nodes = CtxPlugin.new()
	_ctx_menu_nodes.mode = "nodes"
	_ctx_menu_nodes.chat_dock = chat_dock
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, _ctx_menu_nodes)
	print("[CromAI Bridge] Menu de contexto 'Enviar para o Crom Agente' registrado (FileSystem + Scene Tree).")

func _process(_delta: float) -> void:
	if websocket_server and websocket_server.has_method("process_network"):
		websocket_server.process_network()

func _exit_tree() -> void:
	if _ctx_menu_files:
		remove_context_menu_plugin(_ctx_menu_files)
		_ctx_menu_files = null
	if _ctx_menu_nodes:
		remove_context_menu_plugin(_ctx_menu_nodes)
		_ctx_menu_nodes = null

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

