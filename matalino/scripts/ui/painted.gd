class_name Painted
extends Control
## A control that draws itself with painter.call(self, rect).

var painter: Callable
## Redraw every frame (for animated content).
var animate := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if animate:
		queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, Rect2(Vector2.ZERO, size))
