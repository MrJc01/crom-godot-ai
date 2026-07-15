# 🌌 Visão Geral: Bootstrapping e a Criação do `crom-godot-ide`

## 🎯 Por que estamos modificando o Godot Engine?

A filosofia do **[crom-agente](https://github.com/MrJc01/crom-agente)** nasceu de uma necessidade real de **soberania e bootstrapping**: construir um agente autônomo e um ecossistema de desenvolvimento que não dependa de IDEs fechadas (como Cursor, Antigravity ou Claude Code) nem fique à mercê de mudanças abruptas de preço, políticas de acesso ou bloqueios de terceiros.

Quando olhamos para a evolução de ferramentas modernas de IA generativa de código, percebemos dois caminhos:
1. **Extensões/Plugins Convencionais:** Limitados pela API restrita do editor (como uma extensão comum do VS Code ou um simples addon no Godot).
2. **Modificações Nativas no Core (Forks de IDE):** O caminho escolhido por **Antigravity (IDE)** e **Void (Fork do VS Code)**, onde o código-fonte original do editor (`microsoft/vscode`) foi clonado e modificado em C++/TypeScript para que a IA habite nativamente o buffer, controle o diff visual, manipule a árvore de arquivos e execute o loop **ReAct (Reasoning and Acting)** com contexto profundo.

O objetivo do **`crom-godot-ide`** é aplicar **exatamente a mesma estratégia revolucionária** ao **Godot Engine (`godotengine/godot`)**.

---

## 📐 O Paralelo: Antigravity / VS Code vs. Crom / Godot Engine

| Aspecto | Estratégia Antigravity / Void (`vscode`) | Estratégia CromAI (`godot`) |
| :--- | :--- | :--- |
| **Repositório Base Clonado** | `microsoft/vscode` (C++ / TypeScript) | `godotengine/godot` (C++ Engine Source — clonado em `external/godot/`) |
| **Integração no Editor** | Modificação nativa na barra lateral (`Workbench`) e no buffer do editor de texto (`Monaco`). | Modificação nativa na barra lateral do editor (`EditorNode` C++) e no editor de scripts (`ScriptEditor`). |
| **Acesso ao Estado** | Árvore de arquivos, terminais PTY com sandbox, buffers de texto. | **Muito superior:** Árvore de nós visual (`SceneTree`), físicas, colisões, raycasts, ontologia do mundo e injeção direta de código `GDScript 4`. |
| **Duplo Papel (Build vs. Play)** | Focado em código/texto (Desenvolvedor). | **Desenvolvedor & Jogador:** A IA constrói o cenário e regras (`Build Mode`) e depois assume corporificadamente o controle de um personagem no jogo rodando (`Play Mode`)! |

---

## 🏗️ O Plano de Bootstrapping em Duas Velocidades

Para garantir agilidade de desenvolvimento e testes imediatos enquanto modificamos o pesado core de C++ do Godot, o projeto adota uma arquitetura em duas camadas complementares:

### 1. Camada de Ponte / Prototipagem (`res://addons/crom_ai/`)
Enquanto os patches em C++ são desenvolvidos, criamos um `EditorPlugin (@tool)` que roda na IDE normal do Godot (`4.6+`). Ele expõe uma API WebSocket/MCP na porta `8080` e incorpora um **Chat Lateral nativo** ancorado à barra direita da IDE (`DOCK_SLOT_RIGHT_UL`), permitindo testar toda a lógica ReAct (`native_react_engine.gd`) e manipular a cena em tempo real.

### 2. Camada Core C++ (`external/godot/` ➔ `crom-godot-ide`)
O verdadeiro objetivo final: modificar o código-fonte C++ oficial do Godot (já clonado em `external/godot/`) para compilar o nosso próprio executável **`crom-godot-ide`**. Nesse binário customizado:
* O painel lateral de IA é um dock C++ nativo em `editor/gui/`.
* O `ScriptEditor` intercepta modificações da LLM mostrando diffs em tempo real de GDScript.
* O motor de ontologia (`CromWorldManager`) roda diretamente nas classes do núcleo da engine (`core/object/`), rodando o jogo e alimentando a IA com precisão de frame sem overhead de WebSockets externos!

---

## 🎯 Metas e Rumo ao MIT

Conforme estabelecido no projeto original do **`crom-agente`**, o ecossistema segue duas metas claras para liberação 100% **MIT**:
1. **Meta de Lucro:** R$ 10.000.000 em receita gerada pelos produtos e jogos do ecossistema.
2. **Meta de Doações:** R$ 5.000.000 em apoio da comunidade.

Todo o avanço no `crom-godot-ide` alimenta diretamente essa autonomia, gerando jogos autônomos e ferramentas que financiam o treinamento de modelos de IA nacionais (como a consolidação de LLMs de 1B-7B com raciocínio latente e Think-Vetor sem custo abusivo de compute externo).
