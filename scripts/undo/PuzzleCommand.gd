class_name PuzzleCommand
## Abstract base for all reversible puzzle actions.
##
## Concrete subclasses implement execute() and undo() against a GridState.
## CommandHistory calls execute() when pushing and undo() when reversing.
##
## Subclasses:
##   PlacePieceCommand  — place a piece on a SLOT cell
##   RotatePieceCommand — rotate a player-placed piece 90° clockwise
##   RemovePieceCommand — remove a player-placed piece


## Applies this action to the grid.
## Returns true on success; false means the action was rejected and must not
## be added to the undo stack.
func execute() -> bool:
	push_error("PuzzleCommand.execute() must be overridden by subclass")
	return false


## Reverses this action, restoring the grid to its state before execute().
## Only called when execute() previously returned true.
func undo() -> void:
	push_error("PuzzleCommand.undo() must be overridden by subclass")
