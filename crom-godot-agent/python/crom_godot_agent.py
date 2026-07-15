#!/usr/bin/env python3
"""
Crom-Godot-Agent (Python ReAct Implementation)
Conecta ao servidor WebSocket do Godot 4 (@tool plugin na porta 8080) e executa o loop ReAct
permitindo à IA inspecionar a cena, criar nós, injetar scripts GDScript e atuar no modo Jogador (Play Mode).
"""

import os
import sys
import json
import time
import argparse
import requests
from websocket import create_connection, WebSocketException

class GodotClient:
    def __init__(self, port=8080):
        self.url = f"ws://127.0.0.1:{port}"
        self.ws = None

    def connect(self):
        try:
            self.ws = create_connection(self.url, timeout=5)
            return True
        except Exception as e:
            raise RuntimeError(f"Falha ao conectar no Godot em {self.url}. Verifique se o projeto está aberto com o plugin ativo: {e}")

    def close(self):
        if self.ws:
            try:
                self.ws.close()
            except:
                pass
            self.ws = None

    def is_connected(self):
        return self.ws is not None

    def send_command(self, action: str, params: dict) -> dict:
        if not self.is_connected():
            raise RuntimeError("Não conectado ao Godot")

        payload = {"action": action, "params": params}
        payload_str = json.dumps(payload)
        print(f"\n[CromAI -> Godot] {payload_str}")
        
        try:
            self.ws.send(payload_str)
            resp_str = self.ws.recv()
            print(f"[Godot -> CromAI] {resp_str}")
            return json.loads(resp_str)
        except Exception as e:
            self.close()
            raise RuntimeError(f"Erro durante comunicação com Godot: {e}")


class ReActEngine:
    def __init__(self, godot_client: GodotClient, provider="ollama", model="llama3"):
        self.godot = godot_client
        self.provider = provider.lower()
        self.model = model
        self.api_key = ""

        if self.provider == "ollama":
            self.base_url = "http://127.0.0.1:11434/v1/chat/completions"
        elif self.provider == "openrouter":
            self.base_url = "https://openrouter.ai/api/v1/chat/completions"
            self.api_key = os.environ.get("OPENROUTER_API_KEY", "")
        elif self.provider == "cromia":
            self.base_url = "https://cloud.ia.crom.run/api/v1/chat/completions"
            self.api_key = os.environ.get("CROMIA_API_KEY", "")
        else: # openai
            self.base_url = "https://api.openai.com/v1/chat/completions"
            self.api_key = os.environ.get("OPENAI_API_KEY", "")

        self.messages = [
            {
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
            }
        ]

    def get_tools(self):
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

    def run_iteration(self, user_input: str) -> str:
        self.messages.append({"role": "user", "content": user_input})
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        max_iterations = 10
        for i in range(max_iterations):
            print(f"\n[ReActEngine] Iteração {i+1} -> Consultando LLM ({self.model})...")
            payload = {
                "model": self.model,
                "messages": self.messages,
                "tools": self.get_tools()
            }

            resp = requests.post(self.base_url, headers=headers, json=payload, timeout=60)
            if resp.status_code != 200:
                raise RuntimeError(f"Erro HTTP {resp.status_code} da LLM: {resp.text}")

            data = resp.json()
            if not data.get("choices"):
                raise RuntimeError("LLM não retornou escolhas na resposta.")

            msg = data["choices"][0]["message"]
            msg_dict = {"role": msg["role"]}
            if msg.get("content"):
                msg_dict["content"] = msg["content"]
            if msg.get("tool_calls"):
                msg_dict["tool_calls"] = msg["tool_calls"]
            self.messages.append(msg_dict)

            tool_calls = msg.get("tool_calls")
            if not tool_calls:
                return msg.get("content", "Concluído.")

            for tc in tool_calls:
                fn_name = tc["function"]["name"]
                args_str = tc["function"]["arguments"]
                print(f"[ReAct Executando Tool] {fn_name}({args_str})")

                try:
                    args_dict = json.loads(args_str)
                except:
                    args_dict = {}

                if not self.godot.is_connected():
                    try:
                        self.godot.connect()
                    except Exception as conn_e:
                        tool_res = {"status": "error", "message": str(conn_e)}
                        self.messages.append({
                            "role": "tool",
                            "tool_call_id": tc["id"],
                            "name": fn_name,
                            "content": json.dumps(tool_res)
                        })
                        continue

                try:
                    tool_res = self.godot.send_command(fn_name, args_dict)
                except Exception as ex:
                    tool_res = {"status": "error", "message": str(ex)}

                self.messages.append({
                    "role": "tool",
                    "tool_call_id": tc["id"],
                    "name": fn_name,
                    "content": json.dumps(tool_res)
                })

        return "Limite de iterações ReAct atingido sem resposta textual final."


def main():
    parser = argparse.ArgumentParser(description="Crom-Godot-Agent Python CLI")
    parser.add_argument("--provider", default="ollama", choices=["ollama", "openrouter", "openai", "cromia"])
    parser.add_argument("--model", default="llama3", help="Modelo LLM a utilizar")
    parser.add_argument("--port", type=int, default=8080, help="Porta WebSocket do plugin no Godot")
    parser.add_argument("--prompt", type=str, default="", help="Executar prompt único e sair")
    args = parser.parse_args()

    print("=" * 65)
    print("         CROM-GODOT-AGENT (Python ReAct Daemon v1.0)")
    print(f" Provedor: {args.provider} | Modelo: {args.model} | Porta Godot: {args.port}")
    print("=" * 65)

    godot = GodotClient(port=args.port)
    try:
        godot.connect()
        print("[Sucesso] Conectado ao Godot 4 Editor WebSocket!")
        godot.send_command("ping", {})
    except Exception as e:
        print(f"[Aviso] Godot não conectado imediatamente ({e}). Reconexão será automática no loop.")

    engine = ReActEngine(godot, provider=args.provider, model=args.model)

    if args.prompt:
        print(f"\n>>> Executando instrução: {args.prompt}\n")
        try:
            res = engine.run_iteration(args.prompt)
            print(f"\n>>> Resposta Final:\n{res}\n")
        except Exception as err:
            print(f"\n[Erro] {err}\n")
            sys.exit(1)
        return

    while True:
        try:
            user_input = input("\n[Crom-Godot-Agent] Digite sua instrução (ou '/exit' para sair): > ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nEncerrando...")
            break

        if not user_input:
            continue
        if user_input in ["/exit", "sair", "exit"]:
            print("Até logo!")
            break
        if user_input == "/clear":
            print("\033[H\033[2J")
            continue

        try:
            res = engine.run_iteration(user_input)
            print(f"\n[CromAgente Resposta]:\n{res}\n")
        except Exception as e:
            print(f"\n[Erro na Iteração] {e}\n")


if __name__ == "__main__":
    main()
