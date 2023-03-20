extends ColorRect

func update_uniforms(enable: bool, weights: Array[float]) -> void:
	material.set_shader_parameter("enable", enable)
	material.set_shader_parameter("weights", weights)
	material.set_shader_parameter("n_weights", weights.size())
