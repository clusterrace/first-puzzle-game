# LevelCompleteOverlay.gd — Sight Lines level complete overlay (KAMA-32).
#
# Rendered via _draw() with a _process()-driven animation for celebration
# feedback. Follows the PauseMenuOverlay.gd pattern: Node2D in a CanvasLayer,
# emits signals, Game.gd handles all actual state transitions.
#
# When is_final_level is true, hides "Next Level" and shows a completion
# message instead.
extends Node2D

# ── Layout ────────────────────────────────────────────────────────────────────
const VIEWPORT_W : float = 760.0
const VIEWPORT_H : float = 580.0
const CARD_W     : float = 320.0
const BTN_W      : float = 240.0
const BTN_H      : float = 48.0
const BTN_GAP    : float = 12.0

# ── Colours (shared palette — Game.gd / PauseMenuOverlay.gd) ─────────────────
const C_SCRIM  := Color(0.0,  0.0,  0.0,  0.72)
const C_CARD   := Color(0.10, 0.12, 0.16, 0.97)
const C_BORDER := Color(0.25, 0.28, 0.36)
const C_HOVER  := Color(0.17, 0.20, 0.25)
const C_BTN    := Color(0.12, 0.14, 0.18)
const C_TITLE  := Color(0.70, 0.72, 0.82)
const C_WIN    := Color(0.22, 1.00, 0.45)

# Fixed sparkle seed positions as fractions of the viewport (deterministic,
# so no RNG is needed at runtime — they drift via sin/cos over time).
const _SPARKS : Array = [
	Vector2(0.12, 0.18), Vector2(0.78, 0.15), Vector2(0.22, 0.72),
	Vector2(0.85, 0.68), Vector2(0.50, 0.08), Vector2(0.38, 0.85),
	Vector2(0.68, 0.28), Vector2(0.08, 0.50), Vector2(0.92, 0.40),
	Vector2(0.55, 0.78),
]

## Emitted when the player presses Next Level.
signal next_level_requested()
## Emitted when the player presses Back to Menu.
signal back_to_menu_requested()

## Set before making the node visible so the overlay renders the correct copy.
var is_final_level : bool = false

var _hover_btn : int   = -1   # 0 = primary, 1 = secondary (see _btn_labels)
var _font      : Font
var _time      : float = 0.0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ── Layout helpers ─────────────────────────────────────────────────────────────

func _btn_count() -> int:
	return 1 if is_final_level else 2


func _card_h() -> float:
	return 100.0 + _btn_count() * (BTN_H + BTN_GAP)


func _card_rect() -> Rect2:
	var h := _card_h()
	return Rect2(
		(VIEWPORT_W - CARD_W) / 2.0,
		(VIEWPORT_H - h) / 2.0,
		CARD_W, h
	)


func _btn_rect(idx: int) -> Rect2:
	var card := _card_rect()
	var bx   := card.position.x + (CARD_W - BTN_W) / 2.0
	var by   := card.position.y + 78.0 + idx * (BTN_H + BTN_GAP)
	return Rect2(bx, by, BTN_W, BTN_H)


func _btn_labels() -> Array:
	if is_final_level:
		return ["Back to Menu"]
	return ["Next Level", "Back to Menu"]


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_hover := -1
		for i: int in range(_btn_count()):
			if _btn_rect(i).has_point(event.position):
				new_hover = i
				break
		if new_hover != _hover_btn:
			_hover_btn = new_hover
			queue_redraw()

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for i: int in range(_btn_count()):
			if _btn_rect(i).has_point(event.position):
				_on_btn_pressed(i)
				return


func _on_btn_pressed(idx: int) -> void:
	if is_final_level:
		back_to_menu_requested.emit()
		return
	match idx:
		0: next_level_requested.emit()
		1: back_to_menu_requested.emit()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Full-screen scrim
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), C_SCRIM)

	_draw_sparkles()

	var card := _card_rect()

	# Animated glow halo around the card
	var glow_a := 0.10 + 0.07 * sin(_time * 2.4)
	draw_rect(card.grow(6.0), Color(C_WIN.r, C_WIN.g, C_WIN.b, glow_a))
	draw_rect(card.grow(3.0), Color(C_WIN.r, C_WIN.g, C_WIN.b, glow_a * 0.6))

	# Card background
	draw_rect(card, C_CARD)

	# Animated border (pulses green)
	var border_a := 0.45 + 0.30 * sin(_time * 2.0)
	draw_rect(card, Color(C_WIN.r, C_WIN.g, C_WIN.b, border_a), false, 1.5)

	# Heading
	var heading := "All Puzzles Solved!" if is_final_level else "Level Complete!"
	var title_a := 0.88 + 0.12 * sin(_time * 3.2)
	draw_string(_font,
		Vector2(VIEWPORT_W / 2.0, card.position.y + 44.0),
		heading,
		HORIZONTAL_ALIGNMENT_CENTER, CARD_W, 24,
		Color(C_WIN.r, C_WIN.g, C_WIN.b, title_a))

	# Sub-text for final level
	if is_final_level:
		draw_string(_font,
			Vector2(VIEWPORT_W / 2.0, card.position.y + 64.0),
			"You illuminated every puzzle",
			HORIZONTAL_ALIGNMENT_CENTER, CARD_W, 14, C_TITLE)

	# Buttons
	var labels := _btn_labels()
	for i: int in range(labels.size()):
		var rect     := _btn_rect(i)
		var is_hover := (i == _hover_btn)
		draw_rect(rect, C_HOVER if is_hover else C_BTN)
		draw_rect(rect, C_BORDER, false, 1.5)
		draw_string(_font,
			Vector2(rect.position.x + BTN_W / 2.0, rect.position.y + BTN_H * 0.62),
			labels[i],
			HORIZONTAL_ALIGNMENT_CENTER, BTN_W, 17, C_TITLE)


func _draw_sparkles() -> void:
	for i: int in range(_SPARKS.size()):
		var phase := _time * 1.6 + i * 0.85
		var alpha := (sin(phase) * 0.5 + 0.5) * 0.55
		if alpha < 0.06:
			continue
		var sx := _SPARKS[i].x * VIEWPORT_W + sin(_time * 0.28 + i * 1.1) * 9.0
		var sy := _SPARKS[i].y * VIEWPORT_H + cos(_time * 0.22 + i * 1.4) * 7.0
		var r  := 1.8 + 1.2 * sin(phase * 1.6)
		var col := Color(C_WIN.r, C_WIN.g, C_WIN.b, alpha)
		draw_circle(Vector2(sx, sy), r, col)
		# Cross-hair sparkle arms
		var arm := r * 2.4
		draw_line(Vector2(sx - arm, sy), Vector2(sx + arm, sy), col, 1.0)
		draw_line(Vector2(sx, sy - arm), Vector2(sx, sy + arm), col, 1.0)
