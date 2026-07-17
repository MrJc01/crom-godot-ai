package main

// ============================================================================
// Servidor MCP (Model Context Protocol) por stdio.
// Expõe as ferramentas do Editor Godot (plugin CromAI, WebSocket porta 8080)
// para o crom-agente via JSON-RPC 2.0 newline-delimited em stdin/stdout.
//
// Uso: crom-godot-agent --mcp-stdio [--port 8080]
// Registrado em ~/.crom/config.json na seção "mcp_servers" pelo plugin Godot.
// ============================================================================

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const mcpProtocolVersion = "2024-11-05"

type mcpRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
	ID      *int64          `json:"id,omitempty"`
}

type mcpError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type mcpResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   *mcpError   `json:"error,omitempty"`
	ID      int64       `json:"id"`
}

type mcpToolDef struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	InputSchema map[string]interface{} `json:"inputSchema"`
}

// schema é um helper para construir JSON Schemas de forma compacta.
// props: nome -> [tipo, descrição]. required: lista de obrigatórios.
func schema(props map[string][2]string, required ...string) map[string]interface{} {
	p := map[string]interface{}{}
	for name, td := range props {
		var t interface{} = td[0]
		if strings.Contains(td[0], "|") {
			parts := strings.Split(td[0], "|")
			t = parts
		}
		entry := map[string]interface{}{"description": td[1]}
		if td[0] == "array" {
			entry["type"] = "array"
			entry["items"] = map[string]interface{}{}
		} else {
			entry["type"] = t
		}
		p[name] = entry
	}
	s := map[string]interface{}{
		"type":       "object",
		"properties": p,
	}
	if len(required) > 0 {
		s["required"] = required
	}
	return s
}

// godotMCPTools define o catálogo de ferramentas expostas ao agente.
// O nome (sem o prefixo godot_) é a "action" enviada ao CommandProcessor do plugin.
var godotMCPTools = []mcpToolDef{
	{"godot_get_scene_tree", "Lê a árvore de nós da cena atualmente aberta no Editor Godot (nomes, tipos, caminhos e filhos).", schema(nil)},
	{"godot_get_open_editor_context", "Retorna o contexto do Editor Godot: scripts abertos, cena em edição e nós selecionados pelo usuário.", schema(nil)},
	{"godot_add_node", "Adiciona um nó novo na cena aberta no Editor Godot.", schema(map[string][2]string{
		"node_type":   {"string", "Classe Godot do nó (ex: Sprite2D, CharacterBody2D, Label, Node3D)"},
		"node_name":   {"string", "Nome do novo nó"},
		"parent_path": {"string", "Caminho do nó pai relativo à raiz da cena ('.' para a raiz)"},
		"properties":  {"object", "Propriedades iniciais (ex: {\"position\": [100, 200], \"text\": \"Olá\"})"},
	}, "node_type", "node_name")},
	{"godot_remove_node", "Remove um nó da cena aberta no Editor Godot.", schema(map[string][2]string{
		"node_path": {"string", "Caminho do nó relativo à raiz da cena"},
	}, "node_path")},
	{"godot_set_node_property", "Altera uma propriedade de um nó da cena (posição, escala, texto, cor, visibilidade, etc).", schema(map[string][2]string{
		"node_path": {"string", "Caminho do nó relativo à raiz da cena"},
		"property":  {"string", "Nome da propriedade (ex: position, scale, text, modulate, visible)"},
		"value":     {"string|number|boolean|array|object", "Novo valor. Vetores como array: [x, y] ou [x, y, z]; cores como [r, g, b, a]"},
	}, "node_path", "property", "value")},
	{"godot_move_node", "Move um nó 2D/3D/Control para uma posição na cena aberta no Editor.", schema(map[string][2]string{
		"node_path": {"string", "Caminho do nó relativo à raiz da cena"},
		"position":  {"array", "Posição destino: [x, y] para 2D/Control ou [x, y, z] para 3D"},
	}, "node_path", "position")},
	{"godot_rename_node", "Renomeia um nó da cena aberta no Editor Godot.", schema(map[string][2]string{
		"node_path": {"string", "Caminho atual do nó"},
		"new_name":  {"string", "Novo nome do nó"},
	}, "node_path", "new_name")},
	{"godot_reparent_node", "Move um nó para debaixo de outro pai na cena aberta (reparenting).", schema(map[string][2]string{
		"node_path":       {"string", "Caminho do nó a mover"},
		"new_parent_path": {"string", "Caminho do novo pai ('.' para a raiz da cena)"},
	}, "node_path", "new_parent_path")},
	{"godot_connect_signal", "Conecta um sinal de um nó a um método de outro nó, salvando a conexão na cena. USE ISTO sempre que criar um handler no padrão _on_<no>_<sinal> (ex.: ligar o 'timeout' de um Timer ao método _on_timer_timeout) — sem a conexão a cena roda mas o jogo não funciona.", schema(map[string][2]string{
		"from_node": {"string", "Caminho do nó que emite o sinal ('.' para a raiz)"},
		"signal":    {"string", "Nome do sinal (ex: timeout, pressed, body_entered, area_entered)"},
		"to_node":   {"string", "Caminho do nó que recebe o sinal ('.' para a raiz, onde está o script/método)"},
		"method":    {"string", "Nome do método a ser chamado (ex: _on_timer_timeout)"},
	}, "signal", "method")},
	{"godot_create_and_attach_script", "Cria um arquivo GDScript e anexa ao nó indicado da cena aberta. Cria diretórios se necessário.", schema(map[string][2]string{
		"node_path":     {"string", "Caminho do nó que receberá o script ('.' para a raiz)"},
		"script_path":   {"string", "Caminho res:// do arquivo .gd (ex: res://scripts/player.gd)"},
		"gdscript_code": {"string", "Código GDScript 4 completo do arquivo"},
	}, "script_path", "gdscript_code")},
	{"godot_create_scene", "Cria um arquivo de cena .tscn novo com um nó raiz do tipo indicado.", schema(map[string][2]string{
		"scene_path": {"string", "Caminho res:// da cena (ex: res://scenes/level_1.tscn)"},
		"root_type":  {"string", "Classe do nó raiz (padrão: Node2D)"},
		"root_name":  {"string", "Nome do nó raiz (padrão: derivado do arquivo)"},
	}, "scene_path")},
	{"godot_instantiate_scene", "Instancia uma cena .tscn existente como filha de um nó da cena aberta no Editor.", schema(map[string][2]string{
		"scene_path":  {"string", "Caminho res:// da cena a instanciar"},
		"parent_path": {"string", "Caminho do nó pai ('.' para a raiz)"},
		"node_name":   {"string", "Nome opcional para a instância"},
	}, "scene_path")},
	{"godot_save_scene", "Salva a cena atualmente aberta no Editor Godot no disco.", schema(nil)},
	{"godot_open_scene", "Abre uma cena .tscn no Editor Godot para edição.", schema(map[string][2]string{
		"scene_path": {"string", "Caminho res:// da cena"},
	}, "scene_path")},
	{"godot_set_project_setting", "Define uma configuração no project.godot (ex: display/window/size/viewport_width, application/run/main_scene).", schema(map[string][2]string{
		"setting": {"string", "Caminho da configuração (ex: application/run/main_scene)"},
		"value":   {"string|number|boolean|array|object", "Valor da configuração"},
	}, "setting", "value")},
	{"godot_add_input_action", "Cria uma ação de input no project.godot mapeada para teclas físicas.", schema(map[string][2]string{
		"action_name": {"string", "Nome da ação (ex: jump, move_left)"},
		"keys":        {"array", "Nomes das teclas (ex: [\"Space\"], [\"W\", \"Up\"])"},
	}, "action_name", "keys")},
	{"godot_play_scene", "Executa uma cena no Godot (ou a cena principal se scene_path for omitido) para testar o jogo.", schema(map[string][2]string{
		"scene_path": {"string", "Caminho res:// da cena a executar (opcional)"},
	})},
	{"godot_stop_scene", "Para a execução da cena em teste no Godot.", schema(nil)},
	{"godot_capture_screenshot", "Captura um screenshot do Editor/jogo em execução e salva como PNG, retornando o caminho do arquivo para análise visual.", schema(nil)},
	{"godot_read_project_file", "Lê um arquivo de texto do projeto Godot usando caminho res:// (scripts .gd, cenas .tscn, .cfg, .json...). O editor resolve o caminho mesmo com o projeto aberto.", schema(map[string][2]string{
		"file_path": {"string", "Caminho res:// do arquivo"},
	}, "file_path")},
	{"godot_modify_project_file", "Escreve/sobrescreve um arquivo de texto do projeto via res:// e força o re-scan do FileSystem do Editor (o Godot recarrega scripts e cenas na hora).", schema(map[string][2]string{
		"file_path":   {"string", "Caminho res:// do arquivo"},
		"new_content": {"string", "Conteúdo completo novo do arquivo"},
	}, "file_path", "new_content")},
	{"godot_list_project_dir", "Lista arquivos e subpastas de um diretório res:// do projeto Godot.", schema(map[string][2]string{
		"dir_path": {"string", "Caminho res:// do diretório (padrão: res://)"},
	})},
}

// runMCPStdioServer processa requisições JSON-RPC do stdin e responde no stdout.
// Todo log vai para stderr para não corromper o canal JSON-RPC.
func runMCPStdioServer(port int) {
	log.SetOutput(os.Stderr)
	log.Printf("[godot-mcp] Servidor MCP stdio iniciado (Godot esperado em ws://127.0.0.1:%d)", port)

	godot := NewGodotClient(port)
	writer := bufio.NewWriter(os.Stdout)
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 0, 1024*1024), 16*1024*1024)

	respond := func(resp mcpResponse) {
		resp.JSONRPC = "2.0"
		data, err := json.Marshal(resp)
		if err != nil {
			log.Printf("[godot-mcp] Erro ao serializar resposta: %v", err)
			return
		}
		writer.Write(data)
		writer.WriteByte('\n')
		writer.Flush()
	}

	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}

		var req mcpRequest
		if err := json.Unmarshal(line, &req); err != nil {
			log.Printf("[godot-mcp] Linha inválida ignorada: %v", err)
			continue
		}

		// Notificações (sem id) não recebem resposta
		if req.ID == nil {
			continue
		}
		id := *req.ID

		switch req.Method {
		case "initialize":
			respond(mcpResponse{ID: id, Result: map[string]interface{}{
				"protocolVersion": mcpProtocolVersion,
				"capabilities":    map[string]interface{}{"tools": map[string]interface{}{}},
				"serverInfo":      map[string]string{"name": "godot-editor-mcp", "version": "1.0.0"},
			}})

		case "ping":
			respond(mcpResponse{ID: id, Result: map[string]interface{}{}})

		case "tools/list":
			respond(mcpResponse{ID: id, Result: map[string]interface{}{"tools": godotMCPTools}})

		case "tools/call":
			var params struct {
				Name      string                 `json:"name"`
				Arguments map[string]interface{} `json:"arguments"`
			}
			if err := json.Unmarshal(req.Params, &params); err != nil {
				respond(mcpResponse{ID: id, Error: &mcpError{Code: -32602, Message: "parâmetros inválidos: " + err.Error()}})
				continue
			}
			text := callGodotTool(godot, params.Name, params.Arguments)
			respond(mcpResponse{ID: id, Result: map[string]interface{}{
				"content": []map[string]string{{"type": "text", "text": text}},
			}})

		default:
			respond(mcpResponse{ID: id, Error: &mcpError{Code: -32601, Message: "método não suportado: " + req.Method}})
		}
	}

	log.Printf("[godot-mcp] stdin encerrado, finalizando servidor MCP.")
}

// callGodotTool encaminha a chamada ao WebSocket do plugin, com conexão lazy e 1 retry.
func callGodotTool(godot *GodotClient, toolName string, args map[string]interface{}) string {
	action := strings.TrimPrefix(toolName, "godot_")
	known := false
	for _, t := range godotMCPTools {
		if t.Name == toolName {
			known = true
			break
		}
	}
	if !known {
		return fmt.Sprintf(`{"status":"error","message":"Ferramenta desconhecida: %s"}`, toolName)
	}
	if args == nil {
		args = map[string]interface{}{}
	}

	var resp map[string]interface{}
	var err error
	for attempt := 0; attempt < 2; attempt++ {
		if !godot.IsConnected() {
			if err = godot.Connect(); err != nil {
				continue
			}
		}
		resp, err = godot.SendCommand(action, args)
		if err == nil {
			break
		}
	}
	if err != nil {
		return fmt.Sprintf(`{"status":"error","message":"Não foi possível falar com o Editor Godot (o projeto está aberto com o plugin CromAI ativo?): %s"}`, strings.ReplaceAll(err.Error(), `"`, `'`))
	}

	// Screenshot: salva o PNG em disco e devolve só o caminho (evita estourar o contexto do LLM)
	if action == "capture_screenshot" {
		if b64, ok := resp["image_base64"].(string); ok {
			path, saveErr := saveScreenshot(b64)
			if saveErr != nil {
				return fmt.Sprintf(`{"status":"error","message":"Screenshot capturado mas falhou ao salvar: %s"}`, saveErr.Error())
			}
			return fmt.Sprintf(`{"status":"success","message":"Screenshot salvo. Use suas ferramentas de visão/arquivo para analisar a imagem.","file_path":"%s"}`, path)
		}
	}

	data, mErr := json.Marshal(resp)
	if mErr != nil {
		return fmt.Sprintf(`{"status":"error","message":"Falha ao serializar resposta do Godot: %s"}`, mErr.Error())
	}
	return string(data)
}

func saveScreenshot(b64 string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return "", err
	}
	baseDir := os.Getenv("GODOT_PROJECT_DIR")
	if baseDir == "" {
		baseDir = os.TempDir()
	} else {
		baseDir = filepath.Join(baseDir, ".crom", "screenshots")
	}
	if err := os.MkdirAll(baseDir, 0o755); err != nil {
		return "", err
	}
	path := filepath.Join(baseDir, fmt.Sprintf("godot_%s.png", time.Now().Format("20060102_150405")))
	if err := os.WriteFile(path, raw, 0o644); err != nil {
		return "", err
	}
	return path, nil
}
