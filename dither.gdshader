shader_type canvas_item;

#include "color.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool enable = true;

group_uniforms ExperimentalSetup;
uniform bool use_time = false;
uniform bool hard_clipping = true;
uniform bool show_unquantized = false;
uniform bool show_error = false;
uniform bool perceptual_error = false;
group_uniforms;

group_uniforms QuantizerSettings;
uniform uint bit_depth = 3;
uniform bool midriser = true;
uniform bool dither = true;
uniform bool subtractive = true;
uniform int noise_order : hint_range(1, 3) = 1;
group_uniforms;

#define delta (1.0 / float((1u << bit_depth) - 1u))

uvec3 pcg3d(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y*v.z; v.y += v.z*v.x; v.z += v.x*v.y;
	v ^= v >> 16u;
	v.x += v.y*v.z; v.y += v.z*v.x; v.z += v.x*v.y;
	return v;
}

float sample_noise(uvec2 xy) {
	uint z = use_time ? uint(TIME * 1000.0) : 0u;
	uvec3 xyz = uvec3(xy, z);
	vec3 noise = vec3(pcg3d(xyz))/float(0u - 1u) - 0.5;
	float result = 0.0;
	for (int i = 0; i < noise_order; ++i) {
		result += noise[i];
	}
	return result;
}

float compress(float x) {
	float headroom = 0.5 * float(noise_order) * delta;
	float a = 1.0 - 2.0 * headroom;
	float compressed = 0.5 + a * (x - 0.5);
	float clipped = clamp(x, headroom, 1.0 - headroom);
	return hard_clipping ? clipped : compressed;
}

float quantize(float x, float noise) {
	float v = dither ? noise * delta : 0.0;
	float y_midtread = delta * floor((x + v)/delta + 0.5);
	float y_midriser = delta * (floor((x + v)/delta) + 0.5);
	float y = midriser ? y_midriser : y_midtread;
	return clamp(subtractive ? y - v : y, 0.0, 1.0);
}

void fragment() {
	uvec2 xy = uvec2(vec2(SCREEN_UV.x / SCREEN_PIXEL_SIZE.x,
	                      SCREEN_UV.y / SCREEN_PIXEL_SIZE.y));
	float noise = sample_noise(xy);
	vec3 raw = texture(screen_texture, SCREEN_UV).rgb;
	float x = compress(luminance(raw));
	float y = show_unquantized ? x : quantize(x, noise);
	float e = 0.5 + y - x;
	float ep = lstar_to_y(0.5 + y_to_lstar(y) - y_to_lstar(x));
	float err = perceptual_error ? ep : e;
	float l = show_error ? err : y;
	COLOR.rgb = enable ? vec3(l) : raw;
}
