# ⚠️ DEPRECADO — não usar

Este diretório era uma implementação paralela do servidor MCP (`mcp_server.go`) e de
um agente ReAct. **Ele foi descontinuado.**

## MCP único e autoritativo
O servidor MCP do projeto agora é **um só**: o repositório
[`crom-godot-mcp`](https://github.com/MrJc01/crom-godot-mcp) (53 ferramentas,
inclui todo o laço de feedback + tilemap/animação/câmera/docs). Todas as
ferramentas que existiam aqui foram **portadas para lá**.

- Build do binário `godot-mcp`: use `crom-godot-mcp/build.sh` (fonte única).
- Não compile nem builde a partir deste diretório.

O daemon (agente) autoritativo é o `crom-agente` (em `external/crom-agente` / repo
`crom-agente`), não o `react_engine.go` daqui.
