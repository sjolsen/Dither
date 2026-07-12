@tool
extends CompositorEffect
class_name Dither


var _rd := RenderingServer.get_rendering_device()
var _shader_file: RDShaderFile = load("res://dither.glsl")
var _shader := RID()
var _pipeline := RID()


func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	_shader_file.changed.connect(_reload_shader)
	_reload_shader()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _shader:
			_rd.free_rid(_shader)


func _reload_shader() -> void:
	if _shader:
		_rd.free_rid(_shader)

	var spirv := _shader_file.get_spirv()
	if spirv.compile_error_compute:
		push_error(spirv.compile_error_compute)
		assert(false)

	_shader = _rd.shader_create_from_spirv(spirv)
	_pipeline = _rd.compute_pipeline_create(_shader)


func _render_callback(_callback_type: int, render_data: RenderData) -> void:
	var buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()

	var size: Vector2i = buffers.get_internal_size()
	var push_constant := PackedInt32Array([size.x, size.y])
	var pc := push_constant.to_byte_array()

	for view in range(buffers.get_view_count()):
		var image: RID = buffers.get_color_layer(view)

		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = 0
		uniform.add_id(image)
		var uniform_set: RID = UniformSetCacheRD.get_cache(_shader, 0, [uniform])

		var compute_list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		_rd.compute_list_set_push_constant(compute_list, pc, pc.size())
		_rd.compute_list_dispatch(compute_list, 1, 1, 1)
		_rd.compute_list_end()
