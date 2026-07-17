class_name ProjectsPage
extends Control

const ThemeConstants = preload("res://addons/crom_ai/core/theme_constants.gd")
const StyleFactory = preload("res://addons/crom_ai/core/style_factory.gd")
const ProjectService = preload("res://addons/crom_ai/core/project_service.gd")
const ProjectCard = preload("res://addons/crom_ai/ui/components/project_card.gd")
const IconProvider = preload("res://addons/crom_ai/core/icon_provider.gd")

# ==============================================================================
# Projects Page — CRUD de projetos: criar, buscar, listar, renomear,
# remover da lista e excluir do disco (com confirmação). Layout minimalista.
# ==============================================================================

signal log_requested(msg: String)

var _projects_list_box: VBoxContainer
var _empty_state: Control
var _input_name: LineEdit
var _search_input: LineEdit
var _count_label: Label
var _all_projects: Array[Dictionary] = []

func _ready() -> void:
	_build_layout()

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, ThemeConstants.SPACING_XL)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", ThemeConstants.SPACING_LG)
	margin.add_child(root)

	# --- Cabeçalho: título + criar ---
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", ThemeConstants.SPACING_XS)
	root.add_child(header)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	header.add_child(title_row)
	title_row.add_child(IconProvider.icon_rect("folder", 24, ThemeConstants.TEXT_PRIMARY))
	var title := Label.new()
	title.text = "Projetos"
	title.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_H1)
	title.add_theme_color_override("font_color", ThemeConstants.TEXT_PRIMARY)
	title_row.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Crie, abra e gerencie seus projetos Godot. Cada novo projeto já vem com o Crom Agente acoplado."
	subtitle.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_SMALL)
	subtitle.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	header.add_child(subtitle)

	# --- Barra: criar novo + busca ---
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	root.add_child(toolbar)

	_input_name = LineEdit.new()
	_input_name.placeholder_text = "Nome do novo projeto (ex: meu-rpg)"
	_input_name.custom_minimum_size = Vector2(260, 36)
	_input_name.text_submitted.connect(func(_t): _on_create_pressed())
	toolbar.add_child(_input_name)

	var btn_create := Button.new()
	btn_create.text = "Criar & abrir"
	btn_create.icon = IconProvider.get_icon("plus", 14, ThemeConstants.TEXT_PRIMARY)
	btn_create.custom_minimum_size = Vector2(0, 36)
	btn_create.pressed.connect(_on_create_pressed)
	toolbar.add_child(btn_create)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Buscar..."
	_search_input.custom_minimum_size = Vector2(200, 36)
	_search_input.right_icon = IconProvider.get_icon("search", 14, ThemeConstants.TEXT_MUTED)
	_search_input.text_changed.connect(_on_search_changed)
	toolbar.add_child(_search_input)

	root.add_child(HSeparator.new())

	# --- Contador ---
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_TINY)
	_count_label.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	root.add_child(_count_label)

	# --- Lista com scroll ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_projects_list_box = VBoxContainer.new()
	_projects_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_projects_list_box.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	scroll.add_child(_projects_list_box)

	# --- Estado vazio ---
	_empty_state = _build_empty_state()
	_projects_list_box.add_child(_empty_state)

	refresh()

func _build_empty_state() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", ThemeConstants.SPACING_SM)
	box.custom_minimum_size = Vector2(0, 200)
	box.visible = false

	var icon := IconProvider.icon_rect("folder_open", 40, ThemeConstants.TEXT_MUTED)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)

	var lbl := Label.new()
	lbl.text = "Nenhum projeto encontrado.\nCrie o primeiro no campo acima."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", ThemeConstants.FONT_SIZE_BODY)
	lbl.add_theme_color_override("font_color", ThemeConstants.TEXT_MUTED)
	box.add_child(lbl)
	return box

# --- Dados / render ------------------------------------------------------------

func refresh() -> void:
	_all_projects = ProjectService.list_projects()
	_render_list(_search_input.text if _search_input else "")

func _on_search_changed(text: String) -> void:
	_render_list(text)

func _render_list(filter: String) -> void:
	for c in _projects_list_box.get_children():
		if c != _empty_state:
			c.queue_free()

	var filtered: Array[Dictionary] = []
	var needle := filter.strip_edges().to_lower()
	for p in _all_projects:
		if needle == "" or str(p["display_name"]).to_lower().contains(needle) or str(p["path"]).to_lower().contains(needle):
			filtered.append(p)

	_empty_state.visible = filtered.is_empty()
	_count_label.text = "%d projeto(s)" % filtered.size() + ("" if needle == "" else " · filtro: \"%s\"" % filter)

	for p in filtered:
		var card := ProjectCard.new(p)
		card.open_editor_requested.connect(_on_open_editor)
		card.run_project_requested.connect(_on_run_project)
		card.rename_requested.connect(_on_rename_requested)
		card.remove_requested.connect(_on_remove_requested)
		card.delete_requested.connect(_on_delete_requested)
		card.favorite_toggled.connect(_on_favorite_toggled)
		_projects_list_box.add_child(card)

# --- Ações CRUD ----------------------------------------------------------------

func _on_create_pressed() -> void:
	var p_name := _input_name.text.strip_edges() if _input_name else ""
	var result := ProjectService.create_project(p_name)
	if not result["ok"]:
		_show_error_dialog(result["error"])
		return
	_input_name.text = ""
	log_requested.emit("Projeto criado em: " + result["path"])
	refresh()
	ProjectService.open_in_editor(result["path"])
	log_requested.emit("Abrindo o Editor Godot no novo projeto...")

func _on_open_editor(path: String) -> void:
	log_requested.emit("Abrindo Editor IDE em: " + path)
	ProjectService.open_in_editor(path)

func _on_run_project(path: String) -> void:
	log_requested.emit("Executando projeto: " + path)
	ProjectService.run_project(path)

func _on_favorite_toggled(path: String) -> void:
	ProjectService.toggle_favorite(path)
	refresh()

func _on_rename_requested(path: String, current_name: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Renomear Projeto"
	dialog.ok_button_text = "Renomear"
	dialog.add_cancel_button("Cancelar")
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(360, 0)
	var lbl := Label.new()
	lbl.text = "Novo nome de exibição (config/name em project.godot):"
	vbox.add_child(lbl)
	var input := LineEdit.new()
	input.text = current_name
	input.select_all()
	vbox.add_child(input)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.confirmed.connect(func():
		var res := ProjectService.rename_project(path, input.text)
		if res["ok"]:
			log_requested.emit("Projeto renomeado para: " + input.text)
			refresh()
		else:
			_show_error_dialog(res["error"])
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()
	input.grab_focus()

func _on_remove_requested(path: String) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.title = "Remover da Lista"
	confirm.dialog_text = "Remover \"%s\" da lista de projetos?\n\nOs arquivos NÃO serão apagados do disco." % path.get_file()
	confirm.ok_button_text = "Remover da lista"
	add_child(confirm)
	confirm.confirmed.connect(func():
		ProjectService.remove_from_list(path)
		log_requested.emit("Projeto removido da lista: " + path)
		refresh()
		confirm.queue_free()
	)
	confirm.canceled.connect(func(): confirm.queue_free())
	confirm.popup_centered()

func _on_delete_requested(path: String) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.title = "Excluir do Disco"
	confirm.dialog_text = "ATENÇÃO: isto apaga permanentemente a pasta:\n%s\n\nEsta ação não pode ser desfeita. Confirmar?" % path
	confirm.ok_button_text = "Excluir permanentemente"
	confirm.get_ok_button().add_theme_color_override("font_color", ThemeConstants.ACCENT_RED)
	add_child(confirm)
	confirm.confirmed.connect(func():
		var res := ProjectService.delete_project_from_disk(path)
		if res["ok"]:
			log_requested.emit("Projeto excluído do disco: " + path)
			refresh()
		else:
			_show_error_dialog(res["error"])
		confirm.queue_free()
	)
	confirm.canceled.connect(func(): confirm.queue_free())
	confirm.popup_centered()

func _show_error_dialog(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Aviso"
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()
