class_name ThemeConstants

# ==============================================================================
# Design Tokens — Paleta VS Code Dark+ Minimalista
# Equivalente ao tailwind.config.js ou _variables.scss
# Todas as cores, tamanhos e espaçamentos centralizados aqui.
# Nenhum componente de UI define cores inline — tudo vem deste arquivo.
# ==============================================================================

# --- Fundos das 5 Zonas Semânticas ---
const BG_ACTIVITY_BAR := Color(0.11, 0.11, 0.11)      # #1c1c1c
const BG_SIDEBAR      := Color(0.145, 0.145, 0.149)   # #252526
const BG_EDITOR       := Color(0.118, 0.118, 0.118)    # #1e1e1e
const BG_PANEL        := Color(0.10, 0.10, 0.10)       # #1a1a1a
const BG_STATUS_BAR   := Color(0.0, 0.48, 0.80)        # #007acc

# --- Fundos de Elementos ---
const BG_CARD         := Color(0.145, 0.145, 0.149)    # #252526
const BG_CARD_HOVER   := Color(0.18, 0.18, 0.20)       # hover sutil
const BG_INPUT        := Color(0.19, 0.19, 0.21)       # inputs e fields
const BG_BADGE        := Color(0.10, 0.23, 0.16)       # fundo do badge verde

# --- Bordas ---
const BORDER_DEFAULT  := Color(0.20, 0.20, 0.21)       # #333333
const BORDER_SUBTLE   := Color(0.16, 0.16, 0.17)       # #292929
const BORDER_ACCENT   := Color(0.2, 0.6, 1.0)          # azul VS Code (aba ativa)

# --- Texto ---
const TEXT_PRIMARY     := Color(0.88, 0.88, 0.88)       # #e0e0e0
const TEXT_SECONDARY   := Color(0.65, 0.65, 0.68)       # #a6a6ad
const TEXT_MUTED       := Color(0.45, 0.45, 0.48)       # #73737a
const TEXT_WHITE       := Color.WHITE

# --- Cores de Destaque (Accent) ---
const ACCENT_BLUE      := Color(0.2, 0.6, 1.0)          # #3399ff
const ACCENT_TEAL      := Color(0.306, 0.788, 0.690)    # #4ec9b0 (Agente ReAct)
const ACCENT_GREEN     := Color(0.416, 0.600, 0.333)    # #6a9955 (Testes / Sucesso)
const ACCENT_PURPLE    := Color(0.773, 0.525, 0.753)    # #c586c0 (Config / Sistema)
const ACCENT_YELLOW    := Color(0.863, 0.831, 0.584)    # #dcd495 (Aviso)
const ACCENT_RED       := Color(0.953, 0.545, 0.659)    # #f38ba8 (Erro)
const ACCENT_ORANGE    := Color(0.980, 0.702, 0.529)    # #fab387 (Tool calls)

# --- Badge Colors ---
const BADGE_ACTIVE_BG  := Color(0.10, 0.23, 0.16)       # fundo verde escuro
const BADGE_ACTIVE_FG  := Color(0.306, 0.788, 0.690)    # texto teal
const BADGE_INFO_BG    := Color(0.10, 0.16, 0.28)       # fundo azul escuro
const BADGE_INFO_FG    := Color(0.2, 0.6, 1.0)          # texto azul
const BADGE_WARN_BG    := Color(0.28, 0.22, 0.10)       # fundo amarelo escuro
const BADGE_WARN_FG    := Color(0.863, 0.831, 0.584)    # texto amarelo

# --- Tamanhos das Zonas ---
const ACTIVITY_BAR_WIDTH := 52
const SIDEBAR_WIDTH      := 250
const STATUS_BAR_HEIGHT  := 24
const TAB_BAR_HEIGHT     := 38
const PANEL_TAB_HEIGHT   := 32
const PANEL_MIN_HEIGHT   := 160

# --- Tipografia ---
const FONT_SIZE_H1       := 22
const FONT_SIZE_H2       := 18
const FONT_SIZE_H3       := 14
const FONT_SIZE_BODY     := 13
const FONT_SIZE_SMALL    := 12
const FONT_SIZE_TINY     := 11
const FONT_SIZE_BADGE    := 10
const FONT_SIZE_STATUS   := 11
const FONT_SIZE_TAB      := 13
const FONT_SIZE_LOG      := 13
const FONT_SIZE_ICON     := 18

# --- Espaçamento ---
const SPACING_XS         := 4
const SPACING_SM         := 8
const SPACING_MD         := 12
const SPACING_LG         := 16
const SPACING_XL         := 24
const SPACING_XXL        := 32

# --- Cantos Arredondados ---
const CORNER_RADIUS_SM   := 4
const CORNER_RADIUS_MD   := 6
const CORNER_RADIUS_LG   := 8
