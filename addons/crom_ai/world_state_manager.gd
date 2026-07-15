@tool
extends Node

# ==============================================================================
# CromWorldManager: Sistema de Estado, Ontologia e Regras para IA (MCP / Godot)
# Permite que o Agente atue no modo BUILD (construção) e no modo PLAY (jogo).
# ==============================================================================

signal world_state_changed()
signal mode_changed(new_mode: String)

var current_mode: String = "build" # "build" | "play"

# Estado da Ontologia do Mundo
var locations: Dictionary = {} # location_id -> { "name": String, "description": String, "exits": Dictionary }
var entities: Dictionary = {}  # entity_id -> { "location_id": String, "type": String, "properties": Dictionary }
var rules: Array = []          # Lista de regras [{ "trigger_action": String, "target_entity_id": String, "conditions": Dictionary, "results": Dictionary }]

# Estado do Jogador no Modo "Play"
var player_state: Dictionary = {
	"current_location": "",
	"hp": 100,
	"max_hp": 100,
	"inventory": [],
	"status": ["healthy"]
}

func _ready() -> void:
	print("[CromWorldManager] Inicializado no modo: ", current_mode)
	# Registro dinâmico de teclas de ação para evitar erros de InputMap
	for key_name in ["w", "s", "a", "d"]:
		if not InputMap.has_action(key_name):
			InputMap.add_action(key_name)
			var ev = InputEventKey.new()
			match key_name:
				"w": ev.physical_keycode = KEY_W
				"s": ev.physical_keycode = KEY_S
				"a": ev.physical_keycode = KEY_A
				"d": ev.physical_keycode = KEY_D
			InputMap.action_add_event(key_name, ev)

# ==============================================================================
# 1. FERRAMENTAS DE CONSTRUÇÃO (BUILD MODE)
# ==============================================================================

func create_location(location_id: String, name: String, description: String) -> Dictionary:
	locations[location_id] = {
		"id": location_id,
		"name": name,
		"description": description,
		"exits": {} # direction -> target_location_id
	}
	if player_state["current_location"] == "":
		player_state["current_location"] = location_id
	
	emit_signal("world_state_changed")
	return { "status": "success", "message": "Local '%s' (%s) criado com sucesso." % [name, location_id], "location": locations[location_id] }

func create_entity(entity_id: String, location_id: String, type: String, properties: Dictionary = {}) -> Dictionary:
	if not locations.has(location_id) and location_id != "inventory":
		return { "status": "error", "message": "Local '%s' não existe." % location_id }
	
	entities[entity_id] = {
		"id": entity_id,
		"location_id": location_id,
		"type": type,
		"properties": properties
	}
	emit_signal("world_state_changed")
	return { "status": "success", "message": "Entidade '%s' (%s) adicionada ao local '%s'." % [entity_id, type, location_id], "entity": entities[entity_id] }

func define_rule(trigger_action: String, target_entity_id: String, conditions: Dictionary = {}, results: Dictionary = {}) -> Dictionary:
	var rule = {
		"trigger_action": trigger_action,
		"target_entity_id": target_entity_id,
		"conditions": conditions,
		"results": results
	}
	rules.append(rule)
	emit_signal("world_state_changed")
	return { "status": "success", "message": "Regra definida: Ação '%s' em '%s'." % [trigger_action, target_entity_id], "rule": rule }

func link_locations(location_a: String, location_b: String, direction: String, bidirectional: bool = true) -> Dictionary:
	if not locations.has(location_a) or not locations.has(location_b):
		return { "status": "error", "message": "Ambos os locais devem existir para criar conexão." }
	
	locations[location_a]["exits"][direction.to_lower()] = location_b
	
	if bidirectional:
		var opp = _get_opposite_direction(direction.to_lower())
		if opp != "":
			locations[location_b]["exits"][opp] = location_a
			
	emit_signal("world_state_changed")
	return { "status": "success", "message": "Conectado '%s' -> '%s' via '%s'." % [location_a, location_b, direction] }

func _get_opposite_direction(dir: String) -> String:
	match dir:
		"norte", "north": return "south" if dir == "north" else "sul"
		"sul", "south": return "north" if dir == "south" else "norte"
		"leste", "east": return "west" if dir == "east" else "oeste"
		"oeste", "west": return "east" if dir == "west" else "leste"
		"cima", "up": return "down" if dir == "up" else "baixo"
		"baixo", "down": return "up" if dir == "down" else "cima"
		"entra", "enter", "dentro", "in": return "out" if dir == "in" else "fora"
		"sai", "exit", "fora", "out": return "in" if dir == "out" else "dentro"
	return ""

# ==============================================================================
# 2. FERRAMENTAS DE JOGO (PLAY MODE)
# ==============================================================================

func look_around() -> Dictionary:
	var loc_id = player_state["current_location"]
	if not locations.has(loc_id):
		return { "status": "error", "message": "O jogador está em um local desconhecido (%s)." % loc_id }
	
	var loc = locations[loc_id]
	var visible_entities = []
	for e_id in entities:
		if entities[e_id]["location_id"] == loc_id:
			visible_entities.append(entities[e_id])
			
	return {
		"status": "success",
		"location_id": loc_id,
		"name": loc["name"],
		"description": loc["description"],
		"exits": loc["exits"],
		"entities": visible_entities
	}

func move(direction_or_location_id: String) -> Dictionary:
	var loc_id = player_state["current_location"]
	if not locations.has(loc_id):
		return { "status": "error", "message": "Local atual inválido." }
	
	var loc = locations[loc_id]
	var target_id = ""
	
	# Verifica se é uma direção válida nas saídas do local atual
	var dir_clean = direction_or_location_id.to_lower()
	if loc["exits"].has(dir_clean):
		target_id = loc["exits"][dir_clean]
	elif locations.has(direction_or_location_id):
		# Se passou diretamente o ID de outro local E existe conexão para lá
		for d in loc["exits"]:
			if loc["exits"][d] == direction_or_location_id:
				target_id = direction_or_location_id
				break
	
	if target_id == "":
		return { "status": "error", "message": "Não é possível mover para '%s' a partir daqui. Saídas disponíveis: %s" % [direction_or_location_id, JSON.stringify(loc["exits"])] }
	
	player_state["current_location"] = target_id
	var look_result = look_around()
	look_result["message"] = "Você se moveu para '%s'." % look_result["name"]
	return look_result

func interact(action: String, target_id: String, with_item_id: String = "") -> Dictionary:
	if not entities.has(target_id):
		return { "status": "error", "message": "Alvo '%s' não existe no mundo." % target_id }
	
	var target = entities[target_id]
	if target["location_id"] != player_state["current_location"] and target["location_id"] != "inventory":
		return { "status": "error", "message": "Alvo '%s' não está no local atual nem no inventário." % target_id }
	
	# Avalia regras aplicáveis
	for rule in rules:
		if rule["trigger_action"].to_lower() == action.to_lower() and rule["target_entity_id"] == target_id:
			# Verifica condições
			if _check_conditions(rule["conditions"], with_item_id, target):
				# Aplica resultados
				var outcome = _apply_results(rule["results"], target)
				outcome["status"] = "success"
				outcome["action"] = action
				outcome["target"] = target_id
				return outcome
			else:
				return { "status": "failure", "message": "Você tenta '%s' em '%s', mas as condições não foram atendidas (faltando item ou requisito)." % [action, target_id] }
				
	# Comportamento padrão de fallback caso não haja regra específica
	match action.to_lower():
		"pegar", "take", "pickup":
			if target["location_id"] == player_state["current_location"] and target["type"] in ["item", "arma", "chave", "consumivel", "weapon", "key"]:
				target["location_id"] = "inventory"
				player_state["inventory"].append(target_id)
				return { "status": "success", "message": "Você pegou '%s' e colocou no inventário." % target_id }
			else:
				return { "status": "failure", "message": "Você não pode pegar '%s'." % target_id }
		"examinar", "examine", "inspect":
			return { "status": "success", "message": "Você examina '%s': %s." % [target_id, JSON.stringify(target["properties"])], "properties": target["properties"] }
		_:
			return { "status": "failure", "message": "Nada acontece ao tentar '%s' em '%s'." % [action, target_id] }

func _check_conditions(conditions: Dictionary, used_item: String, target: Dictionary) -> bool:
	for key in conditions:
		match key:
			"has_item":
				if not player_state["inventory"].has(conditions[key]):
					return false
			"used_item":
				if used_item != conditions[key]:
					return false
			"property_equals":
				var prop_dict = conditions[key]
				for p in prop_dict:
					if not target["properties"].has(p) or target["properties"][p] != prop_dict[p]:
						return false
	return true

func _apply_results(results: Dictionary, target: Dictionary) -> Dictionary:
	var msg_parts = []
	for key in results:
		match key:
			"add_inventory":
				var item_id = results[key]
				if entities.has(item_id):
					entities[item_id]["location_id"] = "inventory"
					if not player_state["inventory"].has(item_id):
						player_state["inventory"].append(item_id)
				msg_parts.append("Recebeu item: " + item_id)
			"change_property":
				var props = results[key]
				for p in props:
					target["properties"][p] = props[p]
				msg_parts.append("Propriedades de '%s' alteradas." % target["id"])
			"change_hp":
				var delta = int(results[key])
				player_state["hp"] = clamp(player_state["hp"] + delta, 0, player_state["max_hp"])
				msg_parts.append("HP alterado em %d (Atual: %d/%d)." % [delta, player_state["hp"], player_state["max_hp"]])
			"message", "text":
				msg_parts.append(str(results[key]))
			"teleport_to":
				player_state["current_location"] = str(results[key])
				msg_parts.append("Teletransportado para " + str(results[key]))
	
	if msg_parts.is_empty():
		msg_parts.append("Ação realizada com sucesso.")
		
	return { "message": " ".join(msg_parts) }

func check_inventory_and_status() -> Dictionary:
	var inv_items = []
	for e_id in player_state["inventory"]:
		if entities.has(e_id):
			inv_items.append(entities[e_id])
		else:
			inv_items.append({ "id": e_id, "type": "unknown" })
			
	return {
		"status": "success",
		"hp": player_state["hp"],
		"max_hp": player_state["max_hp"],
		"current_location": player_state["current_location"],
		"player_status": player_state["status"],
		"inventory": inv_items
	}

# ==============================================================================
# 3. FERRAMENTAS DE SISTEMA E CONTROLE
# ==============================================================================

func switch_mode(mode: String) -> Dictionary:
	var clean_mode = mode.to_lower()
	if clean_mode not in ["build", "play"]:
		return { "status": "error", "message": "Modo inválido. Use 'build' ou 'play'." }
	
	current_mode = clean_mode
	emit_signal("mode_changed", current_mode)
	
	if current_mode == "play":
		# Se não tiver local atual definido, pega o primeiro
		if player_state["current_location"] == "" and not locations.is_empty():
			player_state["current_location"] = locations.keys()[0]
		var ctx = look_around()
		ctx["message"] = "=== MODO DE JOGO ATIVADO === O jogo começou. O que você faz?"
		return ctx
	else:
		return { "status": "success", "message": "=== MODO DE CONSTRUÇÃO (BUILD) ATIVADO === Edições divinas no estado e na cena permitidas." }

func get_world_state(query: String = "") -> Dictionary:
	var state = {
		"current_mode": current_mode,
		"locations_count": locations.size(),
		"entities_count": entities.size(),
		"rules_count": rules.size(),
		"player_state": player_state,
		"locations": locations,
		"entities": entities,
		"rules": rules
	}
	if query != "" and state.has(query):
		return { "status": "success", "query": query, "data": state[query] }
	return { "status": "success", "world_state": state }

func reset_world() -> Dictionary:
	locations.clear()
	entities.clear()
	rules.clear()
	player_state = {
		"current_location": "",
		"hp": 100,
		"max_hp": 100,
		"inventory": [],
		"status": ["healthy"]
	}
	current_mode = "build"
	emit_signal("world_state_changed")
	return { "status": "success", "message": "O estado do mundo foi completamente reiniciado." }
