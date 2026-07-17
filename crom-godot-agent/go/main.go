package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strings"
)

func main() {
	providerFlag := flag.String("provider", "ollama", "Provedor LLM: 'ollama', 'openrouter', 'openai', ou 'cromia'")
	modelFlag := flag.String("model", "llama3", "Nome do modelo (ex: llama3, gpt-4o, google/gemini-2.5-flash)")
	portFlag := flag.Int("port", 8080, "Porta WebSocket do plugin @tool rodando no Godot Editor")
	promptFlag := flag.String("prompt", "", "Executar uma instrução única sem abrir o modo interativo")
	mcpStdioFlag := flag.Bool("mcp-stdio", false, "Roda como servidor MCP stdio (JSON-RPC 2.0) expondo as ferramentas do Editor Godot")
	flag.Parse()

	// Modo MCP: stdout é reservado ao JSON-RPC; nenhum banner é impresso.
	if *mcpStdioFlag {
		runMCPStdioServer(*portFlag)
		return
	}

	fmt.Println("=================================================================")
	fmt.Printf("           CROM-GODOT-AGENT (Go ReAct Daemon v1.0)\n")
	fmt.Printf(" Provedor: %s | Modelo: %s | Porta Godot: %d\n", *providerFlag, *modelFlag, *portFlag)
	fmt.Println("=================================================================")

	// Conecta ao Godot na porta especificada
	godotClient := NewGodotClient(*portFlag)
	err := godotClient.Connect()
	if err != nil {
		fmt.Printf("[Aviso] Não foi possível conectar ao Godot imediatamente na porta %d:\n%v\n", *portFlag, err)
		fmt.Println("O Agente tentará reconectar automaticamente ao executar chamadas de ferramentas.")
	} else {
		fmt.Println("[Sucesso] Conectado ao servidor WebSocket do Godot 4!")
		// Envia um ping
		resp, _ := godotClient.SendCommand("ping", map[string]interface{}{})
		if resp != nil {
			fmt.Printf("[Godot Respondeu] %v\n", resp["message"])
		}
	}

	engine := NewReActEngine(godotClient, *providerFlag, *modelFlag)

	// Se passou --prompt na linha de comando, roda uma única vez e encerra
	if *promptFlag != "" {
		fmt.Printf("\n>>> Instrução enviada: %s\n\n", *promptFlag)
		answer, err := engine.RunIteration(*promptFlag)
		if err != nil {
			fmt.Printf("\n[Erro na execução] %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("\n>>> Resposta Final do Agente:\n%s\n", answer)
		return
	}

	// Caso contrário, entra em loop interativo de chat no terminal (TUI)
	scanner := bufio.NewScanner(os.Stdin)
	for {
		fmt.Print("\n[Crom-Godot-Agent] Digite sua instrução (ou '/exit' para sair): > ")
		if !scanner.Scan() {
			break
		}
		input := strings.TrimSpace(scanner.Text())
		if input == "" {
			continue
		}
		if input == "/exit" || input == "sair" {
			fmt.Println("Encerrando Crom-Godot-Agent. Até logo!")
			break
		}
		if input == "/clear" {
			fmt.Print("\033[H\033[2J")
			continue
		}

		fmt.Println("\n--- Agente PENSANDO e AGINDO ---")
		answer, err := engine.RunIteration(input)
		if err != nil {
			fmt.Printf("\n[Erro] %v\n", err)
		} else {
			fmt.Printf("\n[CromAgente Resposta]:\n%s\n", answer)
		}
	}
}
