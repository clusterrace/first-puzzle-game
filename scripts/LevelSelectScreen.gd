# LevelSelectScreen.gd — Sight Lines level-select UI (KAMA-23).
#
# Drawn entirely via _draw(). Displays one card per level showing the level
# number and completion state. All levels are always selectable (player can
# replay completed levels). Clicking a card starts that level in Game.tscn.
#
# Zero layout files: the card grid is computed from viewport dimensions at
# draw time. No Control nodes, no theme dependencies.
extends Node2D

# ── Layout ────────────────────────────────────────────────────────────────────
const CARD_W     : float = 120.0
const CARD_H     : float = 140.0
const CARD_GAP   : float = 20.0
const CARDS_Y    : float = 200.0
const VIEWPORT_W : float = 760.0
const VIEWPORT_H : float = 580.0

# ── Colours ───────────────────────────────────────────────────────────────────
const C_BG      := Color(0.08, 0.09, 0.12)
const C_CARD    := Color(0.12, 0.14, 0.18)
const C_HOVER   := Color(0.17, 0.20, 0.25)
const C_BORDER  := Color(0.25, 0.28, 0.36)
const C_DONE    := Color(0.22, 1.00, 0.45)
const C_TITLE   := Color(0.70, 0.72, 0.82)
const C_LABEL   := Color(0.58, 0.60, 0.70)
const C_DIM     := Color(0.38, 0.40, 0.50)

# ── State ─────────────────────────────────────────────────────────────────────
var _hover_idx : int  = -1
var _font      : Font


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_font = ThemeDB.fallback_font


# ── Helpers ───────────────────────────────────────────────────────────────────

func _cards_start_x() -> float:
	var count: int    = LevelManager.get_level_count()
	var total_w: float = count * CARD_W + (count - 1) * CARD_GAP
	return (VIEWPORT_W - total_w) / 2.0


func _card_rect(idx: int) -> Rect2:
	var x := _cards_start_x() + idx * (CARD_W + CARD_GAP)
	return Rect2(x, CARDS_Y, CARD_W, CARD_H)


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var count: int = LevelManager.get_level_count()

	if event is InputEventMouseMotion:
		var new_hover := -1
		for i: int in range(count):
			if _card_rect(i).has_point(event.position):
				new_hover = i
				break
		if new_hover != _hover_idx:
			_hover_idx = new_hover
			queue_redraw()

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for i: int in range(count):
			if _card_rect(i).has_point(event.position):
				LevelManager.current_index = i
				get_tree().change_scene_to_file("res://scenes/Game.tscn")
				return


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), C_BG)

	# Title
	draw_string(_font,
		Vector2(VIEWPORT_W / 2.0, 110.0),
		"SIGHT LINES",
		HORIZONTAL_ALIGNMENT_CENTER, VIEWPORT_W, 38, C_TITLE)

	draw_string(_font,
		Vector2(VIEWPORT_W / 2.0, 154.0),
		"Select a level",
		HORIZONTAL_ALIGNMENT_CENTER, VIEWPORT_W, 15, C_LABEL)

	# Level cards
	var count: int = LevelManager.get_level_count()
	for i: int in range(count):
		var rect     := _card_rect(i)
		var is_hover := (i == _hover_idx)
		var level_id := LevelManager.get_level_id(i)
		var is_done  := SaveManager.is_level_complete(level_id)

		# Card background
		draw_rect(rect, C_HOVER if is_hover else C_CARD)

		# Card border — green when completed
		var border_col := C_DONE if is_done else C_BORDER
		draw_rect(rect, border_col, false, 1.5)

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
