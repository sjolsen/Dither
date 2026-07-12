extends Node


const _CAPTURE_DIR := "user://screenshots"


func _ready() -> void:
	DirAccess.make_dir_absolute(_CAPTURE_DIR)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("screen_capture"):
		var viewport := get_viewport()
		var basename := Time.get_datetime_string_from_system() + ".png"
		var filename := _CAPTURE_DIR.path_join(basename)
		viewport.get_texture().get_image().save_png(filename)
		viewport.set_input_as_handled()
		var link := ProjectSettings.globalize_path(filename)
		print_rich("Saved screenshot to [url=%s]%s[/url]" % [link, basename])
