class_name StyleFactory

# ==============================================================================
# Style Factory — Cria StyleBoxFlat, temas de Button/Label/Panel
# Nenhum componente cria estilos inline. Todos chamam este factory.
# Equivalente a um CSS utility class system ou Tailwind @apply.
# ==============================================================================

# --- Panel / Card Styles ---

static func panel(bg_color: Color = ThemeConstants.BG_CARD, border_color: Color = ThemeConstants.BORDER_DEFAULT, corner_radius: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_bottom = 0
	sb.border_width_top = 0
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.content_margin_left = ThemeConstants.SPACING_MD
	sb.content_margin_right = ThemeConstants.SPACING_MD
	sb.content_margin_top = ThemeConstants.SPACING_MD
	sb.content_margin_bottom = ThemeConstants.SPACING_MD
	return sb

static func card() -> StyleBoxFlat:
	return panel(ThemeConstants.BG_CARD, ThemeConstants.BORDER_DEFAULT, ThemeConstants.CORNER_RADIUS_MD)

static func card_with_accent(accent_color: Color) -> StyleBoxFlat:
	var sb := card()
	sb.border_width_left = 3
	sb.border_color = accent_color
	return sb

# --- Zone Styles (Activity Bar, Sidebar, etc.) ---

static func zone_activity_bar() -> StyleBoxFlat:
	var sb := panel(ThemeConstants.BG_ACTIVITY_BAR)
	sb.border_width_right = 1
	sb.border_color = ThemeConstants.BORDER_DEFAULT
	return sb

static func zone_sidebar() -> StyleBoxFlat:
	var sb := panel(ThemeConstants.BG_SIDEBAR)
	sb.border_width_right = 1
	sb.border_color = ThemeConstants.BORDER_DEFAULT
	return sb

static func zone_editor() -> StyleBoxFlat:
	return panel(ThemeConstants.BG_EDITOR)

static func zone_panel() -> StyleBoxFlat:
	var sb := panel(ThemeConstants.BG_PANEL)
	sb.border_width_top = 1
	sb.border_color = ThemeConstants.BORDER_DEFAULT
	return sb

static func zone_status_bar() -> StyleBoxFlat:
	return panel(ThemeConstants.BG_STATUS_BAR)

# --- Tab Styles ---

static func tab_bar() -> StyleBoxFlat:
	return panel(ThemeConstants.BG_ACTIVITY_BAR)

static func tab_active() -> StyleBoxFlat:
	var sb := panel(ThemeConstants.BG_EDITOR)
	sb.border_width_top = 2
	sb.border_color = ThemeConstants.BORDER_ACCENT
	return sb

# --- Badge Styles ---

static func badge(bg_color: Color, fg_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = ThemeConstants.CORNER_RADIUS_SM
	sb.corner_radius_top_right = ThemeConstants.CORNER_RADIUS_SM
	sb.corner_radius_bottom_left = ThemeConstants.CORNER_RADIUS_SM
	sb.corner_radius_bottom_right = ThemeConstants.CORNER_RADIUS_SM
	sb.content_margin_left = ThemeConstants.SPACING_SM
	sb.content_margin_right = ThemeConstants.SPACING_SM
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

static func badge_active() -> StyleBoxFlat:
	return badge(ThemeConstants.BADGE_ACTIVE_BG, ThemeConstants.BADGE_ACTIVE_FG)

static func badge_info() -> StyleBoxFlat:
	return badge(ThemeConstants.BADGE_INFO_BG, ThemeConstants.BADGE_INFO_FG)

# --- Input / LineEdit Styles ---

static func input_field() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeConstants.BG_INPUT
	sb.border_color = ThemeConstants.BORDER_DEFAULT
	sb.border_width_bottom = 1
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.corner_radius_top_left = ThemeConstants.CORNER_RADIUS_SM
	sb.corner_radius_top_right = ThemeConstants.CORNER_RADIUS_SM
	sb.corner_radius_bottom_left = ThemeConstants.CORNER_RADIUS_SM
	sb.corner_radius_bottom_right = ThemeConstants.CORNER_RADIUS_SM
	sb.content_margin_left = ThemeConstants.SPACING_SM
	sb.content_margin_right = ThemeConstants.SPACING_SM
	return sb

# --- Helper: Apply panel style to a Control ---

static func apply_to(control: Control, style: StyleBoxFlat) -> void:
	control.add_theme_stylebox_override("panel", style)
