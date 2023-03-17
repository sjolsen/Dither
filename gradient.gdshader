shader_type canvas_item;

#include "color.gdshaderinc"

void fragment() {
	if (UV.y > 0.5) {
		COLOR.rgb = vec3(lstar_to_y(1.0 - UV.x));
	} else {
		COLOR.rgb = vec3(UV.x);
	}
}
