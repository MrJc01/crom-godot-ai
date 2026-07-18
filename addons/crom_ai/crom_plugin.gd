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

	# Autoload que roda DENTRO do jogo (play_scene) e expõe o estado em runtime
	# na porta 8091 — permite verificar gameplay ("algo se moveu?").
	add_autoload_singleton("CromRuntime", "res://addons/crom_ai/crom_runtime.gd")

	# Implanta as skills do addon em res://.crom/skills/ para o crom-agente carregá-las.
	_deploy_skills()

	# Remove binários de OUTRAS plataformas do bin/ (economiza ~150MB por projeto).
	_prune_foreign_binaries()

	print("=========================================================")

# Retorna o sufixo do binário desta plataforma (ex: "linux-amd64", "windows-amd64.exe").
func _current_bin_suffix() -> String:
	var arch := "arm64" if Engine.get_architecture_name().contains("arm") else "amd64"
	match OS.get_name():
		"Windows":
			return "windows-%s.exe" % arch
		"macOS":
			return "darwin-%s" % arch
		_:
			return "linux-%s" % arch

# O addon é distribuído com os binários (crom-agente + godot-mcp) de TODOS os
# alvos (~200MB). Só o da plataforma atual é usado; os outros são removidos do
# projeto para não pesar ~150MB à toa. Mantém o binário atual e o CLI.
func _prune_foreign_binaries() -> void:
	# Guard: no repositório-FONTE do addon existe o marcador res://.crom_dev_source
	# (na raiz, fora de addons/ — então NÃO viaja quando o usuário copia o addon).
	# Ali mantemos todos os alvos; a poda só roda em projetos de usuário.
	if FileAccess.file_exists("res://.crom_dev_source"):
		return
	var bin_dir := "res://addons/crom_ai/bin"
	var suffix := _current_bin_suffix()
	var d := DirAccess.open(bin_dir)
	if d == null:
		return
	# Só poda se o binário desta plataforma existir (evita apagar tudo por engano).
	if not (FileAccess.file_exists(bin_dir + "/crom-agente-" + suffix) or FileAccess.file_exists(bin_dir + "/godot-mcp-" + suffix)):
		return
	d.list_dir_begin()
	var fname := d.get_next()
	var removed := 0
	while fname != "":
		if not d.current_is_dir() and (fname.begins_with("crom-agente-") or fname.begins_with("godot-mcp-")):
			# Mantém o binário desta plataforma e o CLI; remove os demais alvos.
			if not fname.ends_with(suffix) and fname != "crom-agente-cli":
				if DirAccess.remove_absolute(ProjectSettings.globalize_path(bin_dir + "/" + fname)) == OK:
					removed += 1
		fname = d.get_next()
	d.list_dir_end()
	if removed > 0:
		print("[CromAI Bridge] %d binário(s) de outras plataformas removido(s) (mantido: %s)." % [removed, suffix])

# Copia os arquivos .crom de addons/crom_ai/skills/ para res://.crom/skills/
# (só quando ausentes ou mais novos), onde o crom-agente os carrega no prompt.
func _deploy_skills() -> void:
	var src_dir := "res://addons/crom_ai/skills"
	var dst_dir := "res://.crom/skills"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(src_dir)):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst_dir))
	var d := DirAccess.open(src_dir)
	if d == null:
		return
	d.list_dir_begin()
	var fname := d.get_next()
	var copied := 0
	while fname != "":
		if not d.current_is_dir() and fname.ends_with(".crom"):
			var src := src_dir + "/" + fname
			var dst := dst_dir + "/" + fname
			# Sobrescreve para manter a skill sincronizada com a versão do addon.
			if FileAccess.file_exists(dst):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dst))
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst)) == OK:
				copied += 1
		fname = d.get_next()
	d.list_dir_end()
	if copied > 0:
		print("[CromAI Bridge] %d skill(s) implantada(s) em res://.crom/skills/ para o Crom Agente." % copied)

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
	OS.low_processor_usage_mode = false
	if websocket_server and websocket_server.has_method("process_network"):
		websocket_server.process_network()

func _exit_tree() -> void:
	remove_autoload_singleton("CromRuntime")
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

