extends Object
class_name ComputeShader


@export
var shader := RID()

@export
var pipeline := RID()

var _rd := RenderingServer.get_rendering_device()
var _shader_file: RDShaderFile


func _init(path: String) -> void:
	_shader_file = load(path)
	_shader_file.changed.connect(_reload_shader)
	_reload_shader()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader:
			_rd.free_rid(shader)


func _reload_shader() -> void:
	if shader:
		_rd.free_rid(shader)

	var spirv := _shader_file.get_spirv()
	if spirv.compile_error_compute:
		push_error(spirv.compile_error_compute)
		assert(false)

	shader = _rd.shader_create_from_spirv(spirv)
	pipeline = _rd.compute_pipeline_create(shader)
