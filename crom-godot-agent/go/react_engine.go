package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
)

// ReActEngine executa o loop ReAct (Reasoning and Acting) conectando o modelo LLM ao Godot
type ReActEngine struct {
	Godot        *GodotClient
	Provider     string // "ollama", "openrouter", "openai", "cromia"
	BaseURL      string
	APIKey       string
	Model        string
	Messages     []map[string]interface{}
	RequireHITL  bool
}

// NewReActEngine inicializa o motor de agente
func NewReActEngine(godot *GodotClient, provider, model string) *ReActEngine {
	engine := &ReActEngine{
		Godot:       godot,
		Provider:    strings.ToLower(provider),
		Model:       model,
		RequireHITL: false,
	}

	switch engine.Provider {
	case "ollama":
		engine.BaseURL = "http://127.0.0.1:11434/v1/chat/completions"
	case "openrouter":
		engine.BaseURL = "https://openrouter.ai/api/v1/chat/completions"
		engine.APIKey = os.Getenv("OPENROUTER_API_KEY")
	case "cromia":
		engine.BaseURL = "https://cloud.ia.crom.run/api/v1/chat/completions"
		engine.APIKey = os.Getenv("CROMIA_API_KEY")
	default: // "openai" ou custom
		engine.BaseURL = "https://api.openai.com/v1/chat/completions"
		engine.APIKey = os.Getenv("OPENAI_API_KEY")
	}

	// Sistema de Prompt Caching e Instrução do Agente no Godot
	engine.Messages = []map[string]interface{}{
		{
			"role": "system",
			"content": `Você é o CromAgente especializado no Godot 4 (Antigravity/CromAI Bridge).
Você possui capacidade autônoma em DOIS MODOS principais:
1. MODO CONSTRUÇÃO (BUILD MODE):
   - Criar e manipular a SceneTree no editor do Godot ('get_scene_tree', 'add_node', 'remove_node', 'set_node_property').
   - Criar e anexar scripts GDScript dinamicamente ('create_and_attach_script').
   - Construir a ontologia e regras de jogo no CromWorldManager ('create_location', 'create_entity', 'define_rule', 'link_locations').

2. MODO JOGO (PLAY MODE):
   - Alternar para o modo play ('switch_mode' com mode="play").
   - Atuar como jogador corporificado: explorar locais ('look_around'), mover-se entre cenários ('move'), interagir com objetos e NPCs usando regras lógicas ('interact'), checar status ('check_inventory_and_status').
   - Executar e testar a cena rodando ('play_scene', 'stop_scene').

Sempre use as ferramentas disponíveis para inspecionar, criar e verificar os resultados antes de dar a resposta final ao usuário. Explique com clareza o seu raciocínio (Reasoning) antes e durante as ações.`,
		},
	}

	return engine
}

// GetTools retorna as ferramentas no padrão OpenAI Function Calling / MCP Tools
func (r *ReActEngine) GetTools() []map[string]interface{} {
	return []map[string]interface{}{
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "get_scene_tree",
				"description": "Retorna a árvore de nós (SceneTree) da cena atualmente aberta no Godot Editor.",
				"parameters": map[string]interface{}{
					"type":       "object",
					"properties": map[string]interface{}{},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "add_node",
				"description": "Adiciona um novo nó do Godot (ex: Node3D, Label3D, MeshInstance3D, CharacterBody2D) como filho de um nó existente.",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"node_type":   map[string]interface{}{"type": "string", "description": "Classe do Godot a instanciar (ex: Node3D, Label, Sprite2D, Area3D)"},
						"node_name":   map[string]interface{}{"type": "string", "description": "Nome que será atribuído ao novo nó"},
						"parent_path": map[string]interface{}{"type": "string", "description": "Caminho do nó pai na cena. Use '.' para a raiz da cena current"},
						"properties":  map[string]interface{}{"type": "object", "description": "Propriedades iniciais a aplicar (ex: {\"text\": \"Olá Mundo\"})"},
					},
					"required": []string{"node_type", "node_name"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "set_node_property",
				"description": "Altera o valor de uma propriedade de um nó no editor do Godot.",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"node_path": map[string]interface{}{"type": "string", "description": "Caminho ou nome do nó na cena"},
						"property":  map[string]interface{}{"type": "string", "description": "Nome da propriedade no Godot (ex: text, visible, position)"},
						"value":     map[string]interface{}{"description": "Valor a atribuir na propriedade"},
					},
					"required": []string{"node_path", "property", "value"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "create_and_attach_script",
				"description": "Cria um arquivo .gd com código GDScript e o anexa a um nó da cena aberta no Godot.",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"node_path":     map[string]interface{}{"type": "string", "description": "Caminho do nó onde o script será anexado (use '.' para a raiz)"},
						"script_path":   map[string]interface{}{"type": "string", "description": "Caminho res:// onde salvar (ex: res://scripts/inimigo.gd)"},
						"gdscript_code": map[string]interface{}{"type": "string", "description": "Código fonte completo em GDScript 4"},
					},
					"required": []string{"node_path", "script_path", "gdscript_code"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "create_location",
				"description": "[BUILD MODE] Cria um novo local (sala, cenário ou zona) na memória ontológica do mundo.",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"location_id": map[string]interface{}{"type": "string", "description": "ID único do local (ex: taverna_01, masmorra_sala1)"},
						"name":        map[string]interface{}{"type": "string", "description": "Nome visível do local"},
						"description": map[string]interface{}{"type": "string", "description": "Descrição detalhada do ambiente"},
					},
					"required": []string{"location_id", "name", "description"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "create_entity",
				"description": "[BUILD MODE] Cria uma entidade (item, baú, NPC, chave, monstro) dentro de um local.",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"entity_id":   map[string]interface{}{"type": "string", "description": "ID da entidade (ex: bau_01, chave_ouro, goblin)"},
						"location_id": map[string]interface{}{"type": "string", "description": "ID do local onde ela está situada"},
						"type":        map[string]interface{}{"type": "string", "description": "Tipo (ex: container, item, npc, weapon)"},
						"properties":  map[string]interface{}{"type": "object", "description": "Atributos livres (ex: {\"locked\": true, \"hp\": 30})"},
					},
					"required": []string{"entity_id", "location_id", "type"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "define_rule",
				"description": "[BUILD MODE] Define uma regra lógica de reação quando uma ação acontece no jogo.",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"trigger_action":   map[string]interface{}{"type": "string", "description": "Ação que dispara a regra (ex: abrir, atacar, conversar)"},
						"target_entity_id": map[string]interface{}{"type": "string", "description": "ID da entidade alvo (ex: bau_01)"},
						"conditions":       map[string]interface{}{"type": "object", "description": "Condições necessárias (ex: {\"has_item\": \"chave_01\"})"},
						"results":          map[string]interface{}{"type": "object", "description": "Resultados da ação (ex: {\"add_inventory\": \"espada\", \"change_property\": {\"locked\": false}, \"message\": \"O baú abriu!\"})"},
					},
					"required": []string{"trigger_action", "target_entity_id"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "link_locations",
				"description": "[BUILD MODE] Conecta dois locais com direções (norte, sul, leste, oeste, porta, etc).",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"location_a":    map[string]interface{}{"type": "string"},
						"location_b":    map[string]interface{}{"type": "string"},
						"direction":     map[string]interface{}{"type": "string", "description": "Direção de saída do A para B (ex: norte, sul, porta_fundos)"},
						"bidirectional": map[string]interface{}{"type": "boolean"},
					},
					"required": []string{"location_a", "location_b", "direction"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "switch_mode",
				"description": "Alterna entre modo 'build' (construção e edição do Godot) e modo 'play' (jogador interativo).",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"mode": map[string]interface{}{"type": "string", "enum": []string{"build", "play"}, "description": "Modo de operação do Agente"},
					},
					"required": []string{"mode"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "look_around",
				"description": "[PLAY MODE] Inspeciona o local atual no jogo, listando entidades visíveis e saídas disponíveis.",
				"parameters": map[string]interface{}{"type": "object", "properties": map[string]interface{}{}},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "move",
				"description": "[PLAY MODE] Move o jogador para outra direção ou sala pelo ID.",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"direction": map[string]interface{}{"type": "string", "description": "Direção ou ID do local de destino (ex: norte, taverna_01)"},
					},
					"required": []string{"direction"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "interact",
				"description": "[PLAY MODE] Executa uma ação interativa contra uma entidade (ex: abrir baú, pegar chave, atacar monstro).",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"action":       map[string]interface{}{"type": "string", "description": "Ação a executar (ex: abrir, pegar, examinar, usar)"},
						"target_id":    map[string]interface{}{"type": "string", "description": "ID do alvo interativo"},
						"with_item_id": map[string]interface{}{"type": "string", "description": "ID de um item do inventário usado na ação (ex: chave)"},
					},
					"required": []string{"action", "target_id"},
				},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "check_inventory_and_status",
				"description": "[PLAY MODE] Retorna o HP, status e lista de itens no inventário do jogador.",
				"parameters": map[string]interface{}{"type": "object", "properties": map[string]interface{}{}},
			},
		},
		{
			"type": "function",
			"function": map[string]interface{}{
				"name":        "play_scene",
				"description": "Inicia a execução visual de uma cena no Godot Editor.",
				"parameters": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"scene_path": map[string]interface{}{"type": "string", "description": "Caminho da cena (ex: res://scenes/main.tscn). Vazio para a cena principal."},
					},
				},
			},
		},
	}
}

// RunIteration envia o prompt do usuário para a LLM, executa ferramentas em loop até a resposta final
func (r *ReActEngine) RunIteration(userInput string) (string, error) {
	r.Messages = append(r.Messages, map[string]interface{}{
		"role":    "user",
		"content": userInput,
	})

	maxIterations := 10
	for iteration := 0; iteration < maxIterations; iteration++ {
		log.Printf("[ReActEngine] Iteração %d - Solicitando resposta da LLM (%s)...", iteration+1, r.Model)

		payload := map[string]interface{}{
			"model":    r.Model,
			"messages": r.Messages,
			"tools":    r.GetTools(),
		}

		body, err := json.Marshal(payload)
		if err != nil {
			return "", err
		}

		req, err := http.NewRequest("POST", r.BaseURL, bytes.NewBuffer(body))
		if err != nil {
			return "", err
		}
		req.Header.Set("Content-Type", "application/json")
		if r.APIKey != "" {
			req.Header.Set("Authorization", "Bearer "+r.APIKey)
		}

		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			return "", fmt.Errorf("erro ao conectar no endpoint LLM (%s): %v", r.BaseURL, err)
		}
		defer resp.Body.Close()

		respBytes, err := io.ReadAll(resp.Body)
		if err != nil {
			return "", err
		}

		if resp.StatusCode != http.StatusOK {
			return "", fmt.Errorf("erro HTTP %d da LLM: %s", resp.StatusCode, string(respBytes))
		}

		var completion struct {
			Choices []struct {
				Message struct {
					Role       string `json:"role"`
					Content    string `json:"content"`
					ToolCalls []struct {
						ID       string `json:"id"`
						Type     string `json:"type"`
						Function struct {
							Name      string `json:"name"`
							Arguments string `json:"arguments"`
						} `json:"function"`
					} `json:"tool_calls"`
				} `json:"message"`
			} `json:"choices"`
		}

		if err := json.Unmarshal(respBytes, &completion); err != nil {
			return "", fmt.Errorf("erro ao decodificar JSON da LLM: %v", err)
		}

		if len(completion.Choices) == 0 {
			return "", fmt.Errorf("nenhuma escolha retornada pela LLM")
		}

		msg := completion.Choices[0].Message

		// Adiciona a resposta da LLM ao histórico
		msgDict := map[string]interface{}{
			"role": msg.Role,
		}
		if msg.Content != "" {
			msgDict["content"] = msg.Content
		}
		if len(msg.ToolCalls) > 0 {
			msgDict["tool_calls"] = msg.ToolCalls
		}
		r.Messages = append(r.Messages, msgDict)

		// Se a LLM não chamou ferramentas, ou retornou apenas texto final, terminamos este turno ReAct!
		if len(msg.ToolCalls) == 0 {
			return msg.Content, nil
		}

		// Processa todas as chamadas de ferramentas de forma sequencial via GodotClient
		for _, toolCall := range msg.ToolCalls {
			fnName := toolCall.Function.Name
			argsJSON := toolCall.Function.Arguments

			log.Printf("[ReActEngine -> Executando Tool] %s com args: %s", fnName, argsJSON)

			var argsMap map[string]interface{}
			if err := json.Unmarshal([]byte(argsJSON), &argsMap); err != nil {
				argsMap = map[string]interface{}{"raw_args": argsJSON}
			}

			// Envia o comando via WebSocket para o Godot!
			var toolResult map[string]interface{}
			var toolErr error

			if !r.Godot.IsConnected() {
				errConn := r.Godot.Connect()
				if errConn != nil {
					toolResult = map[string]interface{}{"status": "error", "message": errConn.Error()}
				} else {
					toolResult, toolErr = r.Godot.SendCommand(fnName, argsMap)
				}
			} else {
				toolResult, toolErr = r.Godot.SendCommand(fnName, argsMap)
			}

			if toolErr != nil {
				toolResult = map[string]interface{}{"status": "error", "message": toolErr.Error()}
			}

			resultStr, _ := json.Marshal(toolResult)
			log.Printf("[ReActEngine -> Resultado Tool] %s: %s", fnName, string(resultStr))

			// Adiciona o resultado da tool ao histórico
			r.Messages = append(r.Messages, map[string]interface{}{
				"role":         "tool",
				"tool_call_id": toolCall.ID,
				"name":         fnName,
				"content":      string(resultStr),
			})
		}
	}

	return "Limite máximo de iterações ReAct atingido.", nil
}
