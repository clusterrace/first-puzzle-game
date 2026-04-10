# PauseMenuOverlay.gd — Sight Lines pause menu overlay (KAMA-31).
#
# Rendered via _draw(), matching the project's Node2D draw() convention.
# Must run with PROCESS_MODE_WHEN_PAUSED (set by Game.gd at instantiation)
# so it receives input and redraws while get_tree().paused is true.
#
# Emits signals for Resume, Restart Level, and Quit to Menu — Game.gd handles
# the actual state changes to keep gameplay logic out of UI code.
extends Node2D

# ── Layout ────────────────────────────────────────────────────────────────────
const VIEWPORT_W : float = 760.0
const VIEWPORT_H : float = 580.0
const CARD_W     : float = 280.0
const CARD_H     : float = 216.0
const BTN_W      : float = 220.0
const BTN_H      : float = 48.0
const BTN_GAP    : float = 12.0

# ── Colours (shared palette — Game.gd / MainMenuScreen.gd) ───────────────────
const C_SCRIM  := Color(0.0,  0.0,  0.0,  0.68)
const C_CARD   := Color(0.10, 0.12, 0.16, 0.97)
const C_BORDER := Color(0.25, 0.28, 0.36)
const C_HOVER  := Color(0.17, 0.20, 0.25)
const C_BTN    := Color(0.12, 0.14, 0.18)
const C_TITLE  := Color(0.70, 0.72, 0.82)

## Emitted when the player chooses Resume (or presses Escape again).
signal resume_requested()
## Emitted when the player chooses Restart Level.
signal restart_requested()
## Emitted when the player chooses Quit to Menu.
signal quit_menu_requested()

var _hover_btn : int = -1   # 0=Resume  1=Restart Level  2=Quit to Menu
var _font      : Font


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_font = ThemeDB.fallback_font


# ── Layout helpers ─────────────────────────────────────────────────────────────

func _card_rect() -> Rect2:
	return Rect2(
		(VIEWPORT_W - CARD_W) / 2.0,
		(VIEWPORT_H - CARD_H) / 2.0,
		CARD_W, CARD_H
	)


func _btn_rect(idx: int) -> Rect2:
	var card := _card_rect()
	var bx   := card.position.x + (CARD_W - BTN_W) / 2.0
	var by   := card.position.y + 68.0 + idx * (BTN_H + BTN_GAP)
	return Rect2(bx, by, BTN_W, BTN_H)


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_hover := -1
		for i: int in range(3):
			if _btn_rect(i).has_point(event.position):
				new_hover = i
				break
		if new_hover != _hover_btn:
			_hover_btn = new_hover
			queue_redraw()

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for i: int in range(3):
			if _btn_rect(i).has_point(event.position):
				_on_btn_pressed(i)
				return

	if event is InputEventKey and event.pressed \
			and event.keycode == KEY_ESCAPE:
		_on_btn_pressed(0)   # Escape again → Resume


func _on_btn_pressed(idx: int) -> void:
	match idx:
		0: resume_requested.emit()
		1: restart_requested.emit()
		2: quit_menu_requested.emit()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Full-screen translucent scrim over the frozen game
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), C_SCRIM)

	# Card
	var card := _card_rect()
	draw_rect(card, C_CARD)
	draw_rect(card, C_BORDER, false, 1.5)

	# "PAUSED" heading
	draw_string(_font,
		Vector2(VIEWPORT_W / 2.0, card.position.y + 44.0),
		"PAUSED",
		HORIZONTAL_ALIGNMENT_CENTER, CARD_W, 26, C_TITLE)

	# Three action buttons
	var labels := ["Resume", "Restart Level", "Quit to Menu"]
	for i: int in range(3):
		var rect     := _btn_rect(i)
		var is_hover := (i == _hover_btn)
		draw_rect(rect, C_HOVER if is_hover else C_BTN)
		draw_rect(rect, C_BORDER, false, 1.5)
		draw_string(_font,
			Vector2(rect.position.x + BTN_W / 2.0, rect.position.y + BTN_H * 0.62),
			labels[i],
			HORIZONTAL_ALIGNMENT_CENTER, BTN_W, 17, C_TITLE)
