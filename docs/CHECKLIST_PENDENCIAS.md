# CromAI Godot — Checklist de Pendências (fazer, conferir, testar)

> Estado em 2026-07-18. Este arquivo é a lista viva do que falta para o produto
> ficar 100%. Marque `[x]` conforme concluir. Seções: **FAZER**, **CONFERIR**,
> **TESTAR**, **RISCOS/DÍVIDA TÉCNICA**, e **JÁ FEITO** (referência).

---

## 🔴 FAZER (implementar)

### Distribuição / build
- [x] **`releases/` sincronizado pelo script**: `scripts/build_release.sh` agora
      espelha `addons/crom_ai/` em `releases/addons/crom_ai/` (rsync `--delete`)
      levando só o binário do host + CLI, após todo export e também via alvo
      dedicado `./scripts/build_release.sh sync`. Validado ao vivo (bin/ caiu de
      ~227MB para ~95MB, addon idêntico fora bin/ e chat_history/).
- [ ] **Poda de binários por plataforma**: `crom_plugin._prune_foreign_binaries()`
      remove os binários de outras plataformas em projetos de usuário (~150MB a
      menos). **Falta validar ao vivo** (ver TESTAR). A implantação já nasce podada:
      `project_service.create_project` copia bin/ seletivamente (só plataforma
      atual + CLI, sem o lixo de runtime `bin/.crom` e sem `chat_history/`).
- [x] **Windows: `killProcessTree` mata a árvore** via `taskkill /T /F /PID` (com
      fallback para `Process.Kill`) em `platform_windows.go`. Compila e passa no
      `go vet` com `GOOS=windows`; execução real fica no item do daemon abaixo.
- [x] **Daemon windows**: confirmado pelo usuário que o Windows não é foco no momento;
      portanto, foco total em Linux/macOS. Compilação Windows preservada mas sem testes em OS nativo.

### Qualidade do código do addon
- [x] **Tipar as inferências de Variant pré-existentes** em `command_processor.gd`
      (e outros `.gd` do addon) e re-ligar o lint estrito (`gdscript/warnings/directory_rules = "res://addons: 1"`).
      Toda variável inferida de Variant (`params.get`, `JSON.parse_string`, `ClassDB.instantiate`) agora está devidamente tipada.
- [x] Remover o `crom_debug.log` gerado na raiz — já está no `.gitignore`, não
      está rastreado e o arquivo não existe mais na raiz.

### MCP / ferramentas (opcional — catálogo)
- [x] `godot_set_script_source` / `godot_detach_script` (editar/soltar script sem recriar).
- [x] Helpers de TileMap (`set_tilemap_cell`, `get_tilemap_cells`), AnimationPlayer/AnimatedSprite2D (`list_animations`, `play_animation`), e Camera2D (`set_camera_target`).
- [x] `docs_search` busca textual rápida sobre a documentação offline extraída de `references/godot_docs_html.zip`.

---

## 🟡 CONFERIR (revisar/decidir)

- [x] **Regra de warnings do addon** (`project.godot`): decidido ligar a regra estrita e tipar tudo (concluído nos arquivos `.gd`).
- [ ] **`unique_id=` no `.tscn`**: confirmado que é gerado pelo **próprio
      `ResourceSaver` do Godot 4.6.3** (recurso nativo de id estável de nó), NÃO é
      bug nosso e a cena carrega limpa. Decisão: **não mexer**. Conferir só se algum
      fluxo (merge/instantiate) reclamar.
- [x] **Teto de custo por tarefa** e circuit breaker: removido o limite de custo/iterações fixo padrão para permitir que o agente execute ciclos mais longos e crie jogos completos. Proteções estruturais contra loop infinito adicionadas (bloqueio de mesma ferramenta com mesmos argumentos chamada 3 vezes seguidas e retornos vazios consecutivos).
- [ ] **Modelo/chave**: o app usa `.crom/config.json` + `.env` por projeto e
      `~/.crom/global.json`. Padronizar de onde vem o modelo padrão (hoje há 3 fontes:
      global, projeto, e seletor da dock). Garantir que a chave NUNCA vá para o repo.

---

## 🟢 TESTAR (validar de ponta a ponta)

> O caminho real é: **dock → daemon (WS 9090) → MCP → editor (WS 8080)**. Testar
> por aí, não pelo CLI nativo.

- [ ] **Jogo completo com LLM leve** (o grande teste): pedir "crie um Snake jogável"
      e ir até `verify_playable` retornar `playable=true` + movimento. Até agora só
      validei uma tarefa simples (adicionar um Label) de ponta a ponta com
      `gemini-2.5-pro` via openrouter — **funcionou** após o fix de quota.
- [ ] **Poda de binários ao vivo**: abrir um projeto de usuário (sem `.crom_dev_source`)
      pelo hub e confirmar que `addons/crom_ai/bin/` fica só com o alvo atual. (No
      teste headless com `--quit-after` o `_enter_tree` do plugin não disparou; validar
      com o editor aberto de verdade.)
- [ ] **`verify_playable` em nó que não é a raiz** (ex.: a "cobra" é filha). Confirmar
      detecção de movimento passando `node_path` correto.
- [ ] **Sequência longa de ferramentas** sob o daemon: compactação de histórico,
      teto de custo, anti-loop e trava de conclusão Godot agindo numa build real.
- [ ] **Recurso inline de colisão** num jogo real (não só no dogfood): `add_nodes_batch`
      com `CollisionShape2D` + `shape` inline, e `get_node_config_warnings` limpo.
- [ ] **Multi-plataforma**: só Linux foi testado. Validar macOS (e Windows, se for alvo).
- [ ] **Hub / CRUD de projetos**: criar, abrir, e remover projeto pelo hub, e confirmar
      que abrir um projeto sobe o editor com o plugin + daemon corretamente.

---

## ⚠️ RISCOS / DÍVIDA TÉCNICA

- **App implanta ~200MB de binários por projeto**: resolvido na origem —
  `create_project` agora implanta só o alvo atual; a poda do plugin segue como
  rede de segurança para projetos implantados antes do fix.
- **Cache de parse do Godot mascara warnings**: ao substituir um `.gd` do addon, o
  re-parse pode expor warnings antes escondidos por cache. Manter o addon
  warning-limpo evita surpresas.
- **Corrida no boot**: `verify_playable`/tools falham se chamadas antes do editor
  abrir a porta 8080. No fluxo real (editor já aberto) não ocorre; em automação,
  esperar a 8080.
- **Chave de API**: garantir que nunca entre no git (já há `*.env`/`.env` no
  `.gitignore`). Revogar qualquer chave que tenha vazado no histórico.

---

## ✅ JÁ FEITO (nesta rodada — referência)

- Fix de **quota de disco** que abortava o loop (causa do "nada acontece no chat").
- **45 ferramentas** no crom-godot-mcp: `verify_playable` (validação headless
  autoritativa), `class_reference` (API via ClassDB), `add_nodes_batch`,
  `set_main_scene`, recurso **inline** em properties (colisão/textura), caminhos
  de nó **relativos**.
- **Skills** religadas (`.crom/skills/*.crom` injetadas no prompt).
- **Trava de conclusão Godot** (cutuca `verify_playable` antes de finalizar) + testes.
- **Teto de custo** duro + guards `.tscn` no write/edit_file.
- **Daemon compila para Windows** (syscalls Unix isolados por build tag).
- **Poda de binários** por plataforma (com guard `.crom_dev_source` no repo-fonte).
- **Fix de parse** do `command_processor.gd` (typing + remoção da regra estrita de
  warnings do addon) — o plugin e o hub voltaram a carregar limpos.
- **`build_release.sh` sincroniza `releases/`** (alvo `sync` + após cada export):
  addon espelhado com só o binário do host + CLI.
- **Implantação seletiva de binários**: `create_project` copia bin/ só com o alvo
  atual (chega de 200MB por projeto novo; `bin/.crom` e `chat_history/` não viajam).
- **`taskkill /T /F` no Windows**: `killProcessTree` do crom-agente mata a árvore
  inteira (cross-compila + `go vet` limpos).
