@tool
extends Node

# ==============================================================================
# NativeReActEngine (GDScript 4): Motor ReAct nativo rodando dentro do Godot
# Comunica-se via HTTP com Ollama, OpenRouter, CromIA ou OpenAI com suporte completo a Function Calling / Tools!
# ==============================================================================

signal message_added(role: String, text: String)
signal tool_executing(tool_name: String, args: Dictionary)
signal react_finished(final_answer: String)
signal error_occurred(err_msg: String)

var http_request: HTTPRequest = null
var command_processor: Node = null

var provider: String = "openrouter" # "openrouter", "ollama", "cromia", "openai"
var model: String = "google/gemini-2.5-flash"
var api_key: String = ""

var messages: Array = []
var is_busy: bool = false
var current_iterations: int = 0
var max_iterations: int = 20

func _init(processor: Node = null) -> void:
	command_processor = processor

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	_reset_messages()

func _reset_messages() -> void:
	messages.clear()
	messages.append({
		"role": "system",
		"content": """Você é o CromAgente especializado no Godot 4 (Antigravity/CromAI Bridge).
Você possui capacidade autônoma em DOIS MODOS principais:
1. MODO CONSTRUÇÃO (BUILD MODE):
   - Criar e manipular a SceneTree no editor do Godot ('get_scene_tree', 'add_node', 'remove_node', 'set_node_property').
   - Criar e anexar scripts GDScript dinamicamente ('create_and_attach_script').
   - Construir a ontologia e regras de jogo no CromWorldManager ('create_location', 'create_entity', 'define_rule', 'link_locations').

2. MODO JOGO (PLAY MODE):
   - Alternar para o modo play ('switch_mode' com mode="play").
   - Atuar como jogador corporificado: explorar locais ('look_around'), mover-se entre cenários ('move'), interagir com objetos e NPCs usando regras lógicas ('interact'), checar status ('check_inventory_and_status').
   - Executar e testar a cena rodando ('play_scene', 'stop_scene').

Sempre use as ferramentas disponíveis para inspecionar, criar e verificar os resultados antes de dar a resposta final ao usuário. Explique com clareza o seu raciocínio (Reasoning) antes e durante as ações."""
	})

func set_config(new_provider: String, new_model: String, new_api_key: String) -> void:
	provider = new_provider.to_lower()
	model = new_model
	api_key = new_api_key
	print("[NativeReActEngine] Configuração atualizada -> Provedor: %s | Modelo: %s" % [provider, model])

func send_user_prompt(user_text: String) -> void:
	if is_busy:
		emit_signal("error_occurred", "O agente já está processando uma instrução. Aguarde.")
		return
		
	if not http_request:
		http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.request_completed.connect(_on_http_request_completed)
		
	is_busy = true
	current_iterations = 0
	
	messages.append({
		"role": "user",
		"content": user_text
	})
	emit_signal("message_added", "user", user_text)
	_step_react_loop()

func _step_react_loop() -> void:
	if current_iterations >= max_iterations:
		is_busy = false
		var msg = "Limite máximo de iterações do ReAct atingido (%d)." % max_iterations
		emit_signal("message_added", "system", msg)
		emit_signal("react_finished", msg)
		return
		
	current_iterations += 1
	emit_signal("message_added", "system", "[Pensando... Iteração %d do modelo %s]" % [current_iterations, model])
	
	var url = "https://openrouter.ai/api/v1/chat/completions"
	match provider:
		"ollama":
			url = "http://127.0.0.1:11434/v1/chat/completions"
		"cromia":
			url = "https://cloud.ia.crom.run/api/v1/chat/completions"
		"openai":
			url = "https://api.openai.com/v1/chat/completions"
		_: # openrouter ou default
			url = "https://openrouter.ai/api/v1/chat/completions"
			
	var headers = ["Content-Type: application/json"]
	if api_key != "":
		headers.append("Authorization: Bearer " + api_key)
	elif provider == "openrouter" and api_key == "":
		# Tenta pegar var de ambiente ou avisa
		var env_key = OS.get_environment("OPENROUTER_API_KEY")
		if env_key != "":
			headers.append("Authorization: Bearer " + env_key)
			
	var payload = {
		"model": model,
		"messages": messages,
		"tools": _get_tools_definition()
	}
	
	var body_json = JSON.stringify(payload)
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if err != OK:
		is_busy = false
		var err_msg = "Falha ao iniciar requisição HTTP para %s (Erro %d)." % [url, err]
		emit_signal("error_occurred", err_msg)
		emit_signal("react_finished", err_msg)

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if not is_busy:
		return
		
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		is_busy = false
		var err_str = body.get_string_from_utf8() if body.size() > 0 else "Sem resposta"
		var err_msg = "Erro HTTP %d (%s) da API %s:\n%s" % [response_code, provider, model, err_str]
		emit_signal("error_occurred", err_msg)
		emit_signal("react_finished", err_msg)
		return
		
	var json_str = body.get_string_from_utf8()
	var parse_result = JSON.parse_string(json_str)
	if not (parse_result is Dictionary) or not parse_result.has("choices") or parse_result["choices"].size() == 0:
		is_busy = false
		var err_msg = "Resposta JSON inválida ou sem escolhas retornado pelo LLM."
		emit_signal("error_occurred", err_msg)
		emit_signal("react_finished", err_msg)
		return
		
	var choice = parse_result["choices"][0]
	var msg = choice.get("message", {})
	
	var role = str(msg.get("role", "assistant"))
	var content = str(msg.get("content", ""))
	var tool_calls = msg.get("tool_calls")
	
	# Adiciona ao histórico do agente
	var history_msg = { "role": role }
	if content != "" and content != "null":
		history_msg["content"] = content
		emit_signal("message_added", "assistant", content)
	if tool_calls is Array and tool_calls.size() > 0:
		history_msg["tool_calls"] = tool_calls
	messages.append(history_msg)
	
	# Se não houve chamada de ferramentas, terminamos por aqui
	if not (tool_calls is Array) or tool_calls.size() == 0:
		is_busy = false
		emit_signal("react_finished", content if content != "" else "Concluído.")
		return
		
	# Processa chamadas de ferramentas de forma sequencial
	for tc in tool_calls:
		var tc_id = str(tc.get("id", "call_%d" % randi()))
		var fn = tc.get("function", {})
		var fn_name = str(fn.get("name", ""))
		var args_str = str(fn.get("arguments", "{}"))
		
		var args_dict = JSON.parse_string(args_str)
		if not (args_dict is Dictionary):
			args_dict = {}
			
		emit_signal("tool_executing", fn_name, args_dict)
		emit_signal("message_added", "tool_call", "⚙️ Executando Ferramenta: %s(%s)" % [fn_name, args_str])
		
		var tool_result = { "status": "error", "message": "CommandProcessor não disponível." }
		if command_processor and command_processor.has_method("process_command"):
			var cmd_payload = JSON.stringify({ "action": fn_name, "params": args_dict })
			tool_result = command_processor.process_command(cmd_payload)
		else:
			# Instancia localmente se preciso
			var proc_class = load("res://addons/crom_ai/command_processor.gd")
			if proc_class:
				var temp_proc = proc_class.new(null)
				var cmd_payload = JSON.stringify({ "action": fn_name, "params": args_dict })
				tool_result = temp_proc.process_command(cmd_payload)
				
		var b64_img = ""
		if tool_result is Dictionary and tool_result.has("image_base64"):
			b64_img = str(tool_result["image_base64"])
			tool_result = { "status": "success", "message": "Captura de tela obtida com sucesso e anexada como imagem multimodal para análise visual." }
			
		var res_str = JSON.stringify(tool_result)
		emit_signal("message_added", "tool_res", "✅ Resultado: " + res_str)
		
		messages.append({
			"role": "tool",
			"tool_call_id": tc_id,
			"name": fn_name,
			"content": res_str
		})
		
		if b64_img != "":
			messages.append({
				"role": "user",
				"content": [
					{ "type": "text", "text": "[Inspeção Visual Automática] Imagem capturada da interface do Godot Editor / Cena em execução:" },
					{ "type": "image_url", "image_url": { "url": "data:image/png;base64," + b64_img } }
				]
			})
		
	# Chama a próxima iteração ReAct via timer ou call_deferred para alimentar a LLM com o resultado das ferramentas
	call_deferred("_step_react_loop")

func _get_tools_definition() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "get_scene_tree",
				"description": "Retorna a árvore de nós (SceneTree) da cena atualmente aberta no Godot Editor.",
				"parameters": {"type": "object", "properties": {}}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "add_node",
				"description": "Adiciona um novo nó do Godot como filho de um nó existente na cena.",
				"parameters": {
					"type": "object",
					"properties": {
						"node_type": {"type": "string", "description": "Classe do Godot a instanciar (ex: Node3D, Label, Sprite2D)"},
						"node_name": {"type": "string", "description": "Nome do nó"},
						"parent_path": {"type": "string", "description": "Caminho do pai. Use '.' para a raiz"},
						"properties": {"type": "object", "description": "Propriedades iniciais a atribuir"}
					},
					"required": ["node_type", "node_name"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "set_node_property",
				"description": "Altera o valor de uma propriedade de um nó no editor do Godot.",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": {"type": "string"},
						"property": {"type": "string"},
						"value": {"description": "Valor a atribuir na propriedade"}
					},
					"required": ["node_path", "property", "value"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_and_attach_script",
				"description": "Cria um arquivo .gd com código GDScript e o anexa a um nó da cena aberta no Godot.",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": {"type": "string"},
						"script_path": {"type": "string"},
						"gdscript_code": {"type": "string"}
					},
					"required": ["node_path", "script_path", "gdscript_code"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "capture_screenshot",
				"description": "Tira um print (captura de tela) da IDE ou da cena em execução no Godot e retorna em Base64 para inspeção visual.",
				"parameters": {"type": "object", "properties": {}}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "get_open_editor_context",
				"description": "Obtém a lista de scripts abertos, a cena atual que o usuário está editando e os nós atualmente selecionados no Inspetor.",
				"parameters": {"type": "object", "properties": {}}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "read_project_file",
				"description": "Lê o conteúdo completo de um script ou arquivo do projeto res:// para inspeção.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": {"type": "string", "description": "Caminho do arquivo (ex: res://scenes/main.gd)"}
					},
					"required": ["file_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "modify_project_file",
				"description": "Substitui ou atualiza o conteúdo de um arquivo no projeto e solicita que a engine recarregue.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": {"type": "string"},
						"new_content": {"type": "string"}
					},
					"required": ["file_path", "new_content"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_location",
				"description": "[BUILD MODE] Cria um novo local (sala, cenário ou zona) na memória ontológica do mundo.",
				"parameters": {
					"type": "object",
					"properties": {
						"location_id": {"type": "string"},
						"name": {"type": "string"},
						"description": {"type": "string"}
					},
					"required": ["location_id", "name", "description"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_entity",
				"description": "[BUILD MODE] Cria uma entidade (item, baú, NPC, chave, monstro) dentro de um local.",
				"parameters": {
					"type": "object",
					"properties": {
						"entity_id": {"type": "string"},
						"location_id": {"type": "string"},
						"type": {"type": "string"},
						"properties": {"type": "object"}
					},
					"required": ["entity_id", "location_id", "type"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "define_rule",
				"description": "[BUILD MODE] Define uma regra lógica de reação quando uma ação acontece no jogo.",
				"parameters": {
					"type": "object",
					"properties": {
						"trigger_action": {"type": "string"},
						"target_entity_id": {"type": "string"},
						"conditions": {"type": "object"},
						"results": {"type": "object"}
					},
					"required": ["trigger_action", "target_entity_id"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "link_locations",
				"description": "[BUILD MODE] Conecta dois locais com direções (norte, sul, leste, oeste, porta, etc).",
				"parameters": {
					"type": "object",
					"properties": {
						"location_a": {"type": "string"},
						"location_b": {"type": "string"},
						"direction": {"type": "string"},
						"bidirectional": {"type": "boolean"}
					},
					"required": ["location_a", "location_b", "direction"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "switch_mode",
				"description": "Alterna entre modo 'build' (construção e edição do Godot) e modo 'play' (jogador interativo).",
				"parameters": {
					"type": "object",
					"properties": {
						"mode": {"type": "string", "enum": ["build", "play"]}
					},
					"required": ["mode"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "look_around",
				"description": "[PLAY MODE] Inspeciona o local atual no jogo, listando entidades visíveis e saídas disponíveis.",
				"parameters": {"type": "object", "properties": {}}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "move",
				"description": "[PLAY MODE] Move o jogador para outra direção ou sala pelo ID.",
				"parameters": {
					"type": "object",
					"properties": {
						"direction": {"type": "string"}
					},
					"required": ["direction"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "interact",
				"description": "[PLAY MODE] Executa uma ação interativa contra uma entidade.",
				"parameters": {
					"type": "object",
					"properties": {
						"action": {"type": "string"},
						"target_id": {"type": "string"},
						"with_item_id": {"type": "string"}
					},
					"required": ["action", "target_id"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "check_inventory_and_status",
				"description": "[PLAY MODE] Retorna o HP, status e lista de itens no inventário do jogador.",
				"parameters": {"type": "object", "properties": {}}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "play_scene",
				"description": "Inicia a execução visual de uma cena no Godot Editor.",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": {"type": "string"}
					}
				}
			}
		}
	]
