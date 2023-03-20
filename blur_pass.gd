extends ColorRect

func _update_uniforms(enable: bool, sigma: float) -> void:
	var n_weights := ceili(3.0 * sigma)
	var weights := [] as Array[float]
	weights.resize(n_weights)
	var total := _gaussian(0)
	for i in range(n_weights):
		weights[i] = _gaussian(float(1 + i) / sigma)
		total += 2.0 * weights[i]
	for i in range(n_weights):
		weights[i] /= total
	material.set_shader_parameter("enable", enable)
	material.set_shader_parameter("weights", weights)
	material.set_shader_parameter("n_weights", n_weights)
	
func _gaussian(x: float) -> float:
	return exp(-(x*x) / 2.0)
