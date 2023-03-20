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

func _ready() -> void:
	changed.connect(_update_uniforms)
	changed.emit()

func _update_uniforms() -> void:
	var weights := _compute_weights()
	$Horizontal.update_uniforms(enable, weights)
	$Vertical.update_uniforms(enable, weights)

func _compute_weights() -> Array[float]:
	var n_weights := ceili(3.0 * sigma)
	var weights := [] as Array[float]
	weights.resize(n_weights)
	var total := _gaussian(0)
	for i in range(n_weights):
		weights[i] = _gaussian(float(1 + i) / sigma)
		total += 2.0 * weights[i]
	for i in range(n_weights):
		weights[i] /= total
	return weights
	
func _gaussian(x: float) -> float:
	return exp(-(x*x) / 2.0)
