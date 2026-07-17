@tool
extends EditorContextMenuPlugin

# ==============================================================================
# CromContextMenuPlugin — adiciona "Enviar para o Crom Agente" ao clicar com o
# botão direito em arquivos (FileSystem) ou nós (Scene Tree). O item selecionado
# vira um chip de contexto no chat do agente acoplado à IDE.
#
# mode: "files"  -> callback recebe PackedStringArray de caminhos de arquivo
#       "nodes"  -> callback recebe Array de Node selecionados
# ==============================================================================

var chat_dock: Control = null
var mode: String = "files"

func _popup_menu(paths: PackedStringArray) -> void:
	add_context_menu_item("Enviar para o Crom Agente", _on_send_to_agent)

func _on_send_to_agent(selection: Variant) -> void:
	if chat_dock == null or not is_instance_valid(chat_dock):
		push_warning("[CromContextMenu] Chat do Crom Agente indisponível.")
		return
	if mode == "nodes":
		var nodes: Array = []
		if selection is Array:
			nodes = selection
		elif selection is Node:
			nodes = [selection]
		if chat_dock.has_method("add_nodes_as_context"):
			chat_dock.add_nodes_as_context(nodes)
	else:
		var paths: Array = []
		if selection is PackedStringArray or selection is Array:
			paths = Array(selection)
		elif selection is String:
			paths = [selection]
		if chat_dock.has_method("add_paths_as_context"):
			chat_dock.add_paths_as_context(paths)
