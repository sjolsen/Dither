shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool enable = false;

uniform vec2 direction = vec2(0.0, 0.0);
uniform float weights[30];  // ceil(3 * sigma)
uniform int n_weights = 0;

void fragment() {
	if (!enable) discard;
	vec4 value = vec4(0.0);
	float total = 0.0;
	for (int i = 0; i < n_weights; ++i) {
		vec2 offset = float(1 + i) * direction * SCREEN_PIXEL_SIZE;
		value += weights[i] * texture(screen_texture, SCREEN_UV + offset);
		value += weights[i] * texture(screen_texture, SCREEN_UV - offset);
		total += 2.0 * weights[i];
	}
	value += (1.0 - total) * texture(screen_texture, SCREEN_UV);
	COLOR = value;
}
