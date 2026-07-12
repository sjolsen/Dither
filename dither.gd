@tool
extends CompositorEffect
class_name Dither


var _rd := RenderingServer.get_rendering_device()
var _pretreat := ComputeShader.new("res://pretreat.glsl")
var _dither := ComputeShader.new("res://dither.glsl")
var _bit_depth: int = 3
var _noise_order: int = 1


func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT


class _Pass:
	var view: int
	var buffers: RenderSceneBuffersRD
	var size: Vector2i
	var push_constant: PackedByteArray
	var compute_list: int


func _render_callback(_callback_type: int, render_data: RenderData) -> void:
	var buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	for view in range(buffers.get_view_count()):
		var cpass := _Pass.new()
		cpass.view = view
		cpass.buffers = buffers
		cpass.size = cpass.buffers.get_internal_size()
		cpass.push_constant = PackedInt32Array([
			cpass.size.x,
			cpass.size.y,
			_bit_depth,
			_noise_order,
		]).to_byte_array()

		cpass.compute_list = _rd.compute_list_begin()
		_run_pretreat(cpass)
		_rd.compute_list_add_barrier(cpass.compute_list)
		_run_dither(cpass)
		_rd.compute_list_end()


func _run_pretreat(cpass: _Pass) -> void:
	var image: RID = cpass.buffers.get_color_layer(cpass.view)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(image)
	var uniform_set: RID = UniformSetCacheRD.get_cache(_pretreat.shader, 0, [uniform])
	
	var wg_x := (cpass.size.x + 31) / 32
	var wg_y := (cpass.size.y + 31) / 32

	_rd.compute_list_bind_compute_pipeline(cpass.compute_list, _pretreat.pipeline)
	_rd.compute_list_bind_uniform_set(cpass.compute_list, uniform_set, 0)
	_rd.compute_list_set_push_constant(
		cpass.compute_list, cpass.push_constant, cpass.push_constant.size())
	_rd.compute_list_dispatch(cpass.compute_list, wg_x, wg_y, 1)


func _run_dither(cpass: _Pass) -> void:
	var image: RID = cpass.buffers.get_color_layer(cpass.view)
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(image)
	var uniform_set: RID = UniformSetCacheRD.get_cache(_dither.shader, 0, [uniform])

	_rd.compute_list_bind_compute_pipeline(cpass.compute_list, _dither.pipeline)
	_rd.compute_list_bind_uniform_set(cpass.compute_list, uniform_set, 0)
	_rd.compute_list_set_push_constant(
		cpass.compute_list, cpass.push_constant, cpass.push_constant.size())
	_rd.compute_list_dispatch(cpass.compute_list, 1, 1, 1)
