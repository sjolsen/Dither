extends CanvasLayer

signal changed;

@export var enable: bool = false:
	set(x):
		enable = x
		changed.emit()

@export_range(0.0, 10.0, 0.1) var sigma: float = 3.0:
	set(x):
		sigma = x
		changed.emit()

func _update_uniforms() -> void:
	$Horizontal._update_uniforms(enable, sigma)
	$Vertical._update_uniforms(enable, sigma)

func _ready() -> void:
	changed.connect(_update_uniforms)
	changed.emit()
