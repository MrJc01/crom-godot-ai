# 🛠️ Modificando o Core C++ do Godot (`external/godot` ➔ `crom-godot-ide`)

Este documento serve como o guia de engenharia e referência exata para modificarmos o código-fonte oficial em C++ do Godot (clonado em `external/godot/`), transformando a engine no nosso fork autônomo **`crom-godot-ide`**.

---

## 🎯 1. Os Três Alvos do Patch C++ no Godot

Para igualar e superar o que o **Antigravity / Void** fizeram no VS Code (`microsoft/vscode`), nossas alterações no C++ do Godot concentram-se em 3 arquivos principais dentro de `external/godot/editor/`:

### A. Embutindo o Painel Lateral da IA (`editor/editor_node.cpp` e `editor/editor_node.h`)
No Godot padrão, os painéis laterais (Inspector, Node, History) são instanciados e adicionados aos docks no construtor e inicialização de `EditorNode`.
Nós adicionamos o nosso **`CromAIEngineDock` (herdeiro de `VBoxContainer` / `Control`)** nativamente ao `EditorNode`:

```cpp
// Em external/godot/editor/editor_node.h
class CromAIEngineDock; // Forward declaration do nosso painel de IA

class EditorNode : public Node {
    // ...
private:
    CromAIEngineDock *crom_ai_dock = nullptr;
    // ...
};
```

```cpp
// Em external/godot/editor/editor_node.cpp (dentro de EditorNode::_init_docks)
#include "editor/gui/crom_ai_engine_dock.h"

void EditorNode::_init_docks() {
    // ... inicializações existentes do Inspector e Node Dock ...

    // [CROM-GODOT-IDE PATCH] Instancia e fixa o painel de Inteligência Artificial
    crom_ai_dock = memnew(CromAIEngineDock);
    crom_ai_dock->set_name(TTR("CromAI Agent"));
    add_control_to_dock(DOCK_SLOT_RIGHT_UL, crom_ai_dock);
    
    print_verbose("[CromGodotIDE] Painel C++ nativo de IA carregado e acoplado ao EditorNode.");
}
```

### B. Diffs em Tempo Real no Editor de Código (`editor/plugins/script_editor_plugin.cpp`)
Quando a LLM solicita uma edição de arquivo via `replace_file_content` ou `create_and_attach_script`, ao invés de apenas sobrescrever o arquivo no disco de forma silenciosa, interceptamos o buffer no `ScriptEditor` do Godot para renderizar um **diff visual inline** (linhas verdes para adição, vermelhas para remoção) com botões de **[Aceitar] / [Rejeitar]**:

```cpp
// Em external/godot/editor/plugins/script_editor_plugin.cpp
void ScriptEditor::apply_agent_code_diff(const String &p_script_path, const String &p_target_content, const String &p_replacement_content) {
    Ref<Script> script = ResourceLoader::load(p_script_path);
    if (script.is_null()) return;

    ScriptEditorBase *se = _get_current_editor();
    if (se && se->get_edited_resource() == script) {
        // Aciona o modo de diff visual no buffer atual do CodeEdit C++
        se->show_inline_diff(p_target_content, p_replacement_content);
    }
}
```

### C. Canal de Memória Direto com o `SceneTree` (`core/object/class_db.cpp`)
Criamos métodos estáticos expostos diretamente à Engine via C++ (`ClassDB::bind_method`) para que o Agente ReAct consulte nós, posições físicas e raycasts sem passar pela serialização JSON de WebSockets quando executado internamente:

```cpp
// Em external/godot/core/object/class_db.cpp ou módulo customizado modules/crom_ai/
void CromEngineBridge::_bind_methods() {
    ClassDB::bind_static_method("CromEngineBridge", D_METHOD("get_scene_tree_fast_dump"), &CromEngineBridge::get_scene_tree_fast_dump);
    ClassDB::bind_static_method("CromEngineBridge", D_METHOD("execute_agent_node_action", "action", "params"), &CromEngineBridge::execute_agent_node_action);
}
```

---

## 🛠️ 2. Como Compilar a Engine Modificada (`scons`)

Uma vez aplicados os patches dentro de `external/godot/`, a compilação do executável **`crom-godot-ide`** é feita com o sistema de build oficial do Godot (`SCons`):

### Requisitos no Linux (Ubuntu / Debian / Arch / Fedora):
```bash
# Ubuntu / Debian / Linux Mint
sudo apt-get install build-essential scons pkg-config libx11-dev libxcursor-dev libxinerama-dev \
    libgl1-mesa-dev libglu-dev libasound2-dev libpulse-dev libudev-dev libxi-dev libxrandr-dev libwayland-dev
```

### Comando de Build (Binário do Editor C++):
```bash
cd /home/j/Documentos/GitHub/crom-godot-ai/external/godot

# Compila o editor para Linux 64-bit usando todos os núcleos da CPU (-j8 ou -j16)
scons platform=linuxbsd target=editor arch=x86_64 use_llvm=no -j$(nproc)
```

Após o término da compilação, o novo binário aparecerá em:
`external/godot/bin/godot.linuxbsd.editor.x86_64`

Você poderá renomeá-lo ou linká-lo como `crom-godot-ide`:
```bash
cp external/godot/bin/godot.linuxbsd.editor.x86_64 /home/j/.local/bin/crom-godot-ide
```

E rodar diretamente no projeto:
```bash
crom-godot-ide --path /home/j/Documentos/GitHub/crom-godot-ai
```
