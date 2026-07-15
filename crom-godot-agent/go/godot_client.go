package main

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// GodotClient gerencia a conexão WebSocket com o plugin @tool no Godot Editor
type GodotClient struct {
	url  string
	conn *websocket.Conn
	mu   sync.Mutex
}

// NewGodotClient cria uma nova instância para comunicação na porta informada
func NewGodotClient(port int) *GodotClient {
	return &GodotClient{
		url: fmt.Sprintf("ws://127.0.0.1:%d", port),
	}
}

// Connect conecta ao servidor WebSocket rodando dentro do Godot
func (g *GodotClient) Connect() error {
	g.mu.Lock()
	defer g.mu.Unlock()

	dialer := websocket.Dialer{
		HandshakeTimeout: 5 * time.Second,
	}

	conn, _, err := dialer.Dial(g.url, nil)
	if err != nil {
		return fmt.Errorf("falha ao conectar no Godot (verifique se o Godot está aberto na cena/projeto com o plugin CromAI ativo na porta 8080): %v", err)
	}

	g.conn = conn
	return nil
}

// Close encerra a conexão com o Godot
func (g *GodotClient) Close() {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.conn != nil {
		g.conn.Close()
		g.conn = nil
	}
}

// IsConnected verifica se o cliente está conectado
func (g *GodotClient) IsConnected() bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.conn != nil
}

// SendCommand envia um comando JSON para o Godot e aguarda a resposta
func (g *GodotClient) SendCommand(action string, params map[string]interface{}) (map[string]interface{}, error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	if g.conn == nil {
		return nil, fmt.Errorf("não conectado ao Godot")
	}

	payload := map[string]interface{}{
		"action": action,
		"params": params,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("erro ao serializar payload: %v", err)
	}

	log.Printf("[CromAI -> Godot] %s", string(data))
	err = g.conn.WriteMessage(websocket.TextMessage, data)
	if err != nil {
		// Tenta reconectar e reenviar 1 vez
		log.Printf("[GodotClient] Erro ao enviar mensagem (%v). Tentando reconectar...", err)
		g.conn.Close()
		g.conn = nil
		return nil, err
	}

	// Aguarda resposta do Godot
	g.conn.SetReadDeadline(time.Now().Add(10 * time.Second))
	_, respData, err := g.conn.ReadMessage()
	if err != nil {
		return nil, fmt.Errorf("erro ao ler resposta do Godot: %v", err)
	}

	log.Printf("[Godot -> CromAI] %s", string(respData))
	var resp map[string]interface{}
	if err := json.Unmarshal(respData, &resp); err != nil {
		return nil, fmt.Errorf("erro ao parsear resposta do Godot: %v", err)
	}

	return resp, nil
}
