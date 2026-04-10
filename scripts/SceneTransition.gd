# SceneTransition.gd — Sight Lines scene transition system (KAMA-30).
#
# Autoload singleton that lives on a CanvasLayer above all scenes.
# Call change_scene(path) to trigger a fade-to-black / swap / fade-in
# transition. Fire-and-forget: callers do not need to await.
#
# No class_name: autoloads are referenced by their autoload key only.
extends CanvasLayer

var _overlay : ColorRect


func _ready() -> void:
	layer = 128
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(760.0, 580.0)
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


## Fade to black, swap scene, then fade from black.
## Fire-and-forget — no need to await from the caller.
func change_scene(path: String) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file(path)
	tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, 0.35)
