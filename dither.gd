@tool
extends CompositorEffect
class_name Dither


var _rd := RenderingServer.get_rendering_device()
var _pretreat := ComputeShader.new("res://pretreat.glsl")
var _dither := ComputeShader.new("res://dither.glsl")
var _buffer := DitherBuffer.new()
var _bit_depth: int = 3
var _noise_order: int = 1


func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT


class _Pass:
	var view: int
	var buffers: RenderSceneBuffersRD
	var size: Vector2i
	var push_constant: PackedByteArray
	var dither_buffer: RID
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
		cpass.dither_buffer = _buffer.grab(cpass.size)

		cpass.compute_list = _rd.compute_list_begin()
		_run_pretreat(cpass)
		_rd.compute_list_add_barrier(cpass.compute_list)
		_run_dither(cpass)
		_rd.compute_list_end()


func _uniforms(cpass: _Pass, shader: RID) -> RID:
	var image := RDUniform.new()
	image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	image.binding = 0
	image.add_id(cpass.buffers.get_color_layer(cpass.view))
	var buffer := RDUniform.new()
	buffer.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	buffer.binding = 1
	buffer.add_id(cpass.dither_buffer)
	return UniformSetCacheRD.get_cache(shader, 0, [image, buffer])


func _run_pretreat(cpass: _Pass) -> void:
	var wg_x := (cpass.size.x + 31) / 32
	var wg_y := (cpass.size.y + 31) / 32

	_rd.compute_list_bind_compute_pipeline(cpass.compute_list, _pretreat.pipeline)
	_rd.compute_list_bind_uniform_set(
		cpass.compute_list, _uniforms(cpass, _pretreat.shader), 0)
	_rd.compute_list_set_push_constant(
		cpass.compute_list, cpass.push_constant, cpass.push_constant.size())
	_rd.compute_list_dispatch(cpass.compute_list, wg_x, wg_y, 1)


func _run_dither(cpass: _Pass) -> void:
	_rd.compute_list_bind_compute_pipeline(cpass.compute_list, _dither.pipeline)
	_rd.compute_list_bind_uniform_set(
		cpass.compute_list, _uniforms(cpass, _dither.shader), 0)
	_rd.compute_list_set_push_constant(
		cpass.compute_list, cpass.push_constant, cpass.push_constant.size())
	_rd.compute_list_dispatch(cpass.compute_list, 1, 1, 1)
