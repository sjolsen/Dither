extends RefCounted
class_name DitherBuffer


var _format := RDTextureFormat.new()
var _texture := RID()
var _rd := RenderingServer.get_rendering_device()


func _init() -> void:
	_format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	_format.width = 0
	_format.height = 0
	_format.depth = 1
	_format.array_layers = 1
	_format.mipmaps = 1
	_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _texture:
			_rd.free_rid(_texture)


func grab(size: Vector2i) -> RID:
	if Vector2i(_format.width, _format.height) != size:
		if _texture:
			_rd.free_rid(_texture)

		_format.width = size.x
		_format.height = size.y
		_texture = _rd.texture_create(_format, RDTextureView.new(), [])

	_rd.texture_clear(_texture, Color(0.0, 0.0, 0.0, 1.0), 0, 1, 0, 1)
	return _texture
