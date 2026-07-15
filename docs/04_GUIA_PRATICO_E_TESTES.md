# 🚀 Guia Prático de Uso e Testes (`crom-godot-ai`)

Este guia mostra como você pode interagir com o ecossistema agora mesmo na sua máquina, testando o Agente ReAct tanto no modo de prototipagem (`@tool` e `scenes/main.tscn`) quanto pelo terminal via binário compilado em Go.

---

## 🖥️ 1. Abrindo na IDE Godot Padrão (`godot -e`)

Enquanto o nosso executável C++ modificado (`crom-godot-ide`) está sendo evoluído na pasta `external/godot/`, você pode abrir o projeto completo com o editor normal do Godot (`godot -e`):

```bash
# Abrir o projeto no editor da Godot Engine (Modo Edição / Editor UI normal):
/home/j/.local/bin/godot -e --path /home/j/Documentos/GitHub/crom-godot-ai
```

### O que você verá na IDE:
1. Ao carregar, o plugin `CromAI MCP & Play Bridge` é ativado no editor.
2. Na barra lateral direita (`DOCK_SLOT_RIGHT_UL`), o painel **🌌 CromAI Godot Agent** se abre por padrão junto às abas *Inspector* e *No*.
3. No painel direito, clique em **⚙️ Config**:
   * Escolha o provedor (`OpenRouter`, `Ollama Local`, `CromIA Cloud`).
   * Verifique ou digite o modelo (ex: `google/gemini-2.5-flash` ou `llama3`).
   * Digite sua API Key (se aplicável) e clique em **💾 Salvar Configurações**.
4. Agora digite no campo inferior:
   > *"Crie um nó CharacterBody2D chamado 'Jogador' na cena atual e adicione um script básico de movimentação."*
   E clique em **Enviar ➔**. A IA responderá na lateral e você verá o novo nó aparecendo na sua `SceneTree` do Godot na hora!

---

## 🎮 2. Executando o Jogo / Aplicação com o Chat Lateral (`F5`)

Se quiser rodar a cena de jogo principal com a interface visual de chat na mesma tela:

```bash
# Rodar apenas a cena principal interativa:
/home/j/.local/bin/godot res://scenes/main.tscn
```

Ou dentro da própria IDE aberta (`godot -e`), pressione a tecla **F5** (ou o ícone de ▶ no topo).
A tela se dividirá: o mundo 3D/2D à esquerda e o **Chat Lateral do Agente** à direita, permitindo que você interaja como jogador no **Modo Play** enquanto monitora os logs e ferramentas ReAct.

---

## 💻 3. Testando via Terminal / CLI em Go (`crom-godot-agent`)

Você também pode comandar o Godot de fora da IDE, pelo terminal, usando o nosso daemon compilado em Go:

```bash
cd /home/j/Documentos/GitHub/crom-godot-ai/crom-godot-agent/go

# Verificar conexão e rodar em modo interativo TUI:
./crom-godot-agent --provider openrouter --model google/gemini-2.5-flash

# Ou executar uma única ordem de construção sem abrir o chat interativo:
./crom-godot-agent --prompt "Crie um local no CromWorldManager chamado 'taverna_01' e adicione 2 NPCs interativos."
```

---

## 🔄 4. O Ciclo Completo: `Build Mode` ➔ `Play Mode`

O diferencial único deste motor é a transição de papel da Inteligência Artificial:

### A. Modo Construção (`Build Mode`)
* O usuário instrui: *"Monte uma sala do tesouro com uma porta trancada, uma chave de ouro e um baú."*
* O agente executa as ferramentas: `create_location`, `create_entity`, `define_rule`, `add_node`.
* O grafo do jogo e os elementos da árvore de cena são construídos na memória.

### B. Modo de Jogo (`Play Mode`)
* O usuário instrui: *"Agora mude para o modo de jogo e tente abrir a porta!"* ou clica no botão **🎮 Modo Play** no painel lateral.
* O agente executa a ferramenta `switch_mode("play")`.
* A partir desse momento, o agente passa a enxergar o mundo através das ferramentas corporificadas (`look_around`, `move`, `interact`, `check_inventory_and_status`), navegando, pegando a chave, usando na porta e relatando a experiência como um jogador real!
