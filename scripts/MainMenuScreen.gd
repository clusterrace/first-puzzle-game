# MainMenuScreen.gd — Sight Lines main menu (KAMA-30).
#
# Drawn entirely via _draw(), matching LevelSelectScreen conventions.
# Zero Control nodes; layout is computed from viewport dimensions.
# Buttons: Start Game (→ LevelSelect via SceneTransition) and Quit.
extends Node2D

# ── Layout ────────────────────────────────────────────────────────────────────
const VIEWPORT_W : float = 760.0
const VIEWPORT_H : float = 580.0

const BTN_W : float = 220.0
const BTN_H : float = 52.0

# ── Colours ───────────────────────────────────────────────────────────────────
const C_BG     := Color(0.08, 0.09, 0.12)
const C_CARD   := Color(0.12, 0.14, 0.18)
const C_HOVER  := Color(0.17, 0.20, 0.25)
const C_BORDER := Color(0.25, 0.28, 0.36)
const C_TITLE  := Color(0.70, 0.72, 0.82)
const C_LABEL  := Color(0.58, 0.60, 0.70)
const C_DIM    := Color(0.38, 0.40, 0.50)

# ── State ─────────────────────────────────────────────────────────────────────
var _hover_btn : int = -1   # 0 = Start Game, 1 = Quit; -1 = none
var _font      : Font


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_font = ThemeDB.fallback_font


# ── Helpers ───────────────────────────────────────────────────────────────────

func _btn_rect(idx: int) -> Rect2:
	var bx := (VIEWPORT_W - BTN_W) / 2.0
	var by := 295.0 + idx * (BTN_H + 14.0)
	return Rect2(bx, by, BTN_W, BTN_H)


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_hover := -1
		for i: int in range(2):
			if _btn_rect(i).has_point(event.position):
				new_hover = i
				break
		if new_hover != _hover_btn:
			_hover_btn = new_hover
			queue_redraw()

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for i: int in range(2):
			if _btn_rect(i).has_point(event.position):
				_on_btn_pressed(i)
				return


func _on_btn_pressed(idx: int) -> void:
	match idx:
		0: SceneTransition.change_scene("res://scenes/LevelSelect.tscn")
		1: get_tree().quit()


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), C_BG)

	# Game title
	draw_string(_font,
		Vector2(VIEWPORT_W / 2.0, 172.0),
		"SIGHT LINES",
		HORIZONTAL_ALIGNMENT_CENTER, VIEWPORT_W, 52, C_TITLE)

	# Subtitle
	draw_string(_font,
		Vector2(VIEWPORT_W / 2.0, 220.0),
		"a sight-line puzzle game",
		HORIZONTAL_ALIGNMENT_CENTER, VIEWPORT_W, 15, C_DIM)

	# Buttons
	var btn_labels := ["Start Game", "Quit"]
	for i: int in range(2):
		var rect     := _btn_rect(i)
		var is_hover := (i == _hover_btn)
		draw_rect(rect, C_HOVER if is_hover else C_CARD)
		draw_rect(rect, C_BORDER, false, 1.5)
		draw_string(_font,
			Vector2(rect.position.x + BTN_W / 2.0, rect.position.y + BTN_H * 0.62),
			btn_labels[i],
			HORIZONTAL_ALIGNMENT_CENTER, BTN_W, 18, C_TITLE)

	# Version hint bottom-right
	draw_string(_font,
		Vector2(VIEWPORT_W - 10.0, VIEWPORT_H - 8.0),
		"v0.1",
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, C_DIM)
