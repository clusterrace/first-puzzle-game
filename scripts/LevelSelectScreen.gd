# LevelSelectScreen.gd — Sight Lines level-select UI (KAMA-35).
#
# Scrollable multi-row layout with difficulty group labels.
# Each group occupies one centered card row:
#   Easy (1–5) · Medium (6–8) · Medium+ (9–12)
# Mouse-wheel and arrow keys scroll the content when 12+ levels are loaded.
# The header (title + subtitle) is fixed and never scrolls.
#
# Zero layout files: the card grid is computed from viewport dimensions at
# draw time. No Control nodes, no theme dependencies.
extends Node2D

# ── Layout ────────────────────────────────────────────────────────────────────
const CARD_W         : float = 120.0
const CARD_H         : float = 140.0
const CARD_GAP       : float = 20.0
const VIEWPORT_W     : float = 760.0
const VIEWPORT_H     : float = 580.0
const HEADER_H       : float = 120.0  # fixed title zone; cards scroll beneath it
const GROUP_PAD_TOP  : float = 16.0   # space above each group label
const GROUP_LABEL_H  : float = 24.0   # group label text row height
const GROUP_PAD_BOT  : float = 14.0   # space between label and cards
const GROUP_SPACING  : float = 24.0   # space below card row before next group
const SCROLL_BAR_W   : float = 5.0
const SCROLL_SPEED   : float = 40.0

# ── Difficulty groups (0-based inclusive level-index ranges) ──────────────────
const GROUP_NAMES    : Array[String] = ["Easy", "Medium", "Medium+"]
const GROUP_STARTS   : Array[int]    = [0, 5, 8]
const GROUP_ENDS     : Array[int]    = [4, 7, 11]

# ── Colours ───────────────────────────────────────────────────────────────────
const C_BG           := Color(0.08, 0.09, 0.12)
const C_CARD         := Color(0.12, 0.14, 0.18)
const C_HOVER        := Color(0.17, 0.20, 0.25)
const C_BORDER       := Color(0.25, 0.28, 0.36)
const C_DONE         := Color(0.22, 1.00, 0.45)
const C_TITLE        := Color(0.70, 0.72, 0.82)
const C_LABEL        := Color(0.58, 0.60, 0.70)
const C_DIM          := Color(0.38, 0.40, 0.50)
const C_SCROLL_TRACK := Color(0.15, 0.17, 0.22)
const C_SCROLL_THUMB := Color(0.35, 0.38, 0.50)
const C_EASY         := Color(0.30, 0.90, 0.50)
const C_MEDIUM       := Color(0.95, 0.80, 0.30)
const C_MEDIUM_PLUS  := Color(0.95, 0.50, 0.25)

# ── State ─────────────────────────────────────────────────────────────────────
var _hover_idx : int   = -1
var _scroll_y  : float = 0.0
var _content_h : float = 0.0
var _font      : Font


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_content_h = _compute_content_height()


# ── Layout helpers ─────────────────────────────────────────────────────────────

func _compute_content_height() -> float:
	var count: int = LevelManager.get_level_count()
	var h: float = HEADER_H
	for g: int in range(GROUP_NAMES.size()):
		if GROUP_STARTS[g] >= count:
			break
		h += GROUP_PAD_TOP + GROUP_LABEL_H + GROUP_PAD_BOT + CARD_H + GROUP_SPACING
	return h


func _max_scroll() -> float:
	return maxf(0.0, _content_h - VIEWPORT_H)


## Y of the top edge of group [param g]'s block, in scroll-adjusted screen space.
func _group_top_y(g: int) -> float:
	var count: int = LevelManager.get_level_count()
	var y: float = HEADER_H - _scroll_y
	for i: int in range(g):
		if GROUP_STARTS[i] >= count:
			break
		y += GROUP_PAD_TOP + GROUP_LABEL_H + GROUP_PAD_BOT + CARD_H + GROUP_SPACING
	return y


## Returns the group index for [param level_idx], or -1 if not in any group.
func _group_for_level(level_idx: int) -> int:
	for g: int in range(GROUP_NAMES.size()):
		if level_idx >= GROUP_STARTS[g] and level_idx <= GROUP_ENDS[g]:
			return g
	return -1


## Returns the scroll-adjusted Rect2 for the card at [param level_idx].
func _card_rect(level_idx: int) -> Rect2:
	var g: int = _group_for_level(level_idx)
	if g == -1:
		return Rect2()
	var count: int     = LevelManager.get_level_count()
	var g_start: int   = GROUP_STARTS[g]
	var g_end: int     = min(GROUP_ENDS[g], count - 1)
	var n: int         = g_end - g_start + 1
	var row_w: float   = n * CARD_W + (n - 1) * CARD_GAP
	var start_x: float = (VIEWPORT_W - row_w) / 2.0
	var pos: int       = level_idx - g_start
	var card_x: float  = start_x + pos * (CARD_W + CARD_GAP)
	var card_y: float  = _group_top_y(g) + GROUP_PAD_TOP + GROUP_LABEL_H + GROUP_PAD_BOT
	return Rect2(card_x, card_y, CARD_W, CARD_H)


func _group_label_color(g: int) -> Color:
	match g:
		0: return C_EASY
		1: return C_MEDIUM
		2: return C_MEDIUM_PLUS
	return C_LABEL


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var count: int = LevelManager.get_level_count()

	if event is InputEventMouseMotion:
		var new_hover: int = -1
		for i: int in range(count):
			var r := _card_rect(i)
			if r.has_point(event.position) and event.position.y >= HEADER_H:
				new_hover = i
				break
		if new_hover != _hover_idx:
			_hover_idx = new_hover
			queue_redraw()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_y = clampf(_scroll_y + SCROLL_SPEED, 0.0, _max_scroll())
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_y = clampf(_scroll_y - SCROLL_SPEED, 0.0, _max_scroll())
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for i: int in range(count):
				var r := _card_rect(i)
				if r.has_point(event.position) and event.position.y >= HEADER_H:
					LevelManager.current_index = i
					get_tree().change_scene_to_file("res://scenes/Game.tscn")
					return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DOWN:
			_scroll_y = clampf(_scroll_y + SCROLL_SPEED, 0.0, _max_scroll())
			queue_redraw()
		elif event.keycode == KEY_UP:
			_scroll_y = clampf(_scroll_y - SCROLL_SPEED, 0.0, _max_scroll())
			queue_redraw()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), C_BG)

	# Groups and cards (drawn before header overdraw; anything above HEADER_H
	# will be masked when we repaint the header zone below).
	var count: int = LevelManager.get_level_count()
	for g: int in range(GROUP_NAMES.size()):
		var g_start: int = GROUP_STARTS[g]
		if g_start >= count:
			break
		var g_end: int    = min(GROUP_ENDS[g], count - 1)
		var top_y: float  = _group_top_y(g)
		var label_y: float = top_y + GROUP_PAD_TOP + GROUP_LABEL_H

		# Group label — only if in the scrollable view zone
		if label_y > HEADER_H and label_y < VIEWPORT_H + GROUP_LABEL_H:
			draw_string(_font,
				Vector2(VIEWPORT_W / 2.0, label_y),
				GROUP_NAMES[g],
				HORIZONTAL_ALIGNMENT_CENTER, VIEWPORT_W, 16, _group_label_color(g))

		for i: int in range(g_start, g_end + 1):
			var rect := _card_rect(i)
			# Skip fully-out-of-view cards
			if rect.position.y + CARD_H <= HEADER_H or rect.position.y >= VIEWPORT_H:
				continue

			var is_hover: bool   = (i == _hover_idx)
			var level_id: String = LevelManager.get_level_id(i)
			var is_done: bool    = SaveManager.is_level_complete(level_id)

			# Card background
			draw_rect(rect, C_HOVER if is_hover else C_CARD)
			# Card border — green when completed
			draw_rect(rect, C_DONE if is_done else C_BORDER, false, 1.5)

			# Level number (large)
			draw_string(_font,
				Vector2(rect.position.x + CARD_W / 2.0, rect.position.y + 48.0),
				str(i + 1),
				HORIZONTAL_ALIGNMENT_CENTER, CARD_W, 32, C_TITLE)

			# Completion indicator
			if is_done:
				draw_string(_font,
					Vector2(rect.position.x + CARD_W / 2.0, rect.position.y + 90.0),
					"\u2713",
					HORIZONTAL_ALIGNMENT_CENTER, CARD_W, 24, C_DONE)
			else:
				draw_string(_font,
					Vector2(rect.position.x + CARD_W / 2.0, rect.position.y + 90.0),
					"\u2014",
					HORIZONTAL_ALIGNMENT_CENTER, CARD_W, 16, C_DIM)

			# "Play" hint on hovered card
			if is_hover:
				draw_string(_font,
					Vector2(rect.position.x + CARD_W / 2.0, rect.position.y + 122.0),
					"Play",
					HORIZONTAL_ALIGNMENT_CENTER, CARD_W, 13, C_LABEL)

	# Overdraw the header zone to clip any cards scrolled above it.
	draw_rect(Rect2(0, 0, VIEWPORT_W, HEADER_H), C_BG)

	# Titles — always fixed, painted on top of everything.
	draw_string(_font,
		Vector2(VIEWPORT_W / 2.0, 65.0),
		"SIGHT LINES",
		HORIZONTAL_ALIGNMENT_CENTER, VIEWPORT_W, 38, C_TITLE)
	draw_string(_font,
		Vector2(VIEWPORT_W / 2.0, 100.0),
		"Select a level",
		HORIZONTAL_ALIGNMENT_CENTER, VIEWPORT_W, 15, C_LABEL)

	# Scrollbar — only when content exceeds viewport height.
	if _max_scroll() > 0.0:
		_draw_scrollbar()


func _draw_scrollbar() -> void:
	var max_s: float   = _max_scroll()
	var track_h: float = VIEWPORT_H - HEADER_H
	var thumb_h: float = maxf(30.0, track_h * (VIEWPORT_H / _content_h))
	var thumb_y: float = HEADER_H + (_scroll_y / max_s) * (track_h - thumb_h)
	var bar_x: float   = VIEWPORT_W - SCROLL_BAR_W - 4.0
	draw_rect(Rect2(bar_x, HEADER_H, SCROLL_BAR_W, track_h), C_SCROLL_TRACK)
	draw_rect(Rect2(bar_x, thumb_y, SCROLL_BAR_W, thumb_h), C_SCROLL_THUMB)
