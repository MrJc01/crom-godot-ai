# CromAI Godot — Checklist de Pendências (fazer, conferir, testar)

> Estado em 2026-07-18. Este arquivo é a lista viva do que falta para o produto
> ficar 100%. Marque `[x]` conforme concluir. Seções: **FAZER**, **CONFERIR**,
> **TESTAR**, **RISCOS/DÍVIDA TÉCNICA**, e **JÁ FEITO** (referência).

---

## 🔴 FAZER (implementar)

### Distribuição / build
- [ ] **`releases/` está no `.gitignore`** e é regenerado à mão. Fazer o
      `scripts/build_release.sh` copiar o addon atualizado + só o binário da
      plataforma alvo, para o `releases/` sempre refletir o `addons/crom_ai/` atual.
      (Hoje sincronizei manualmente; isso não é versionado.)
- [ ] **Poda de binários por plataforma**: `crom_plugin._prune_foreign_binaries()`
      remove os binários de outras plataformas em projetos de usuário (~150MB a
      menos). **Falta validar ao vivo** (ver TESTAR). Considerar rodar a poda também
      quando o app IMPLANTA o addon num projeto novo (não só no `_enter_tree` do editor).
- [ ] **Windows: `killProcessTree` só mata o processo principal** (sem árvore).
      Implementar `taskkill /T /F` em `platform_windows.go` para matar a árvore.
- [ ] **Daemon windows**: compila agora, mas nunca foi executado no Windows.
      Rodar o fluxo real no Windows (ou confirmar que o alvo é só Linux/macOS).

### Qualidade do código do addon
- [ ] **Tipar as inferências de Variant pré-existentes** em `command_processor.gd`
      (e outros `.gd` do addon). Hoje removi a regra `gdscript/warnings/directory_rules`
      (`res://addons: 1`) do `project.godot` porque o re-parse do arquivo sob regra
      estrita quebrava o plugin. Se quiser re-ligar o lint estrito do addon, é
      preciso tipar TODA variável que infere de Variant (`params.get`, `JSON.parse_string`,
      `_get_world_manager()`, etc.).
- [ ] Remover o `crom_debug.log` gerado na raiz (adicionar ao `.gitignore`).

### MCP / ferramentas (opcional — catálogo)
- [ ] `godot_set_script_source` / `godot_detach_script` (editar/soltar script sem recriar).
- [ ] Helpers de TileMap, AnimationPlayer/AnimatedSprite2D, e Camera2D.
- [ ] `docs_search` RAG sobre a documentação (parcialmente coberto por
      `godot_class_reference`, que já dá a API autoritativa via ClassDB).

---

## 🟡 CONFERIR (revisar/decidir)

- [ ] **Remoção da regra de warnings do addon** (`project.godot`): confirmar que é
      aceitável desligar o lint estrito do addon (é o padrão do Godot para plugins).
      Alternativa: manter e tipar tudo (ver FAZER).
- [ ] **`unique_id=` no `.tscn`**: confirmado que é gerado pelo **próprio
      `ResourceSaver` do Godot 4.6.3** (recurso nativo de id estável de nó), NÃO é
      bug nosso e a cena carrega limpa. Decisão: **não mexer**. Conferir só se algum
      fluxo (merge/instantiate) reclamar.
- [ ] **Teto de custo por tarefa ($1.00)** e circuit breaker: confirmar que o valor
      faz sentido para o uso real (modelos baratos custam frações de centavo).
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

- **App implanta ~200MB de binários por projeto**: mitigado pela poda + pelo fix de
  quota do daemon, mas o ideal é implantar só o alvo atual desde o começo.
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
