#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(r32f, set = 0, binding = 1) uniform image2D dither_buffer;

layout(push_constant, std430) uniform Params {
	ivec2 raster_size;
	int bit_depth;
	int noise_order;
	int dynamic_range_compression;
	int show_error;
} params;

#define delta (1.0 / float((1u << params.bit_depth) - 1u))
#define noise_max (float(params.noise_order) * delta / 2.0)

float luminance(vec3 c) {
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
}

float unquantized_input(ivec2 focus) {
	vec4 color = imageLoad(color_image, focus);
	float l = luminance(color.rgb);
	if (bool(params.dynamic_range_compression)) {
		return mix(noise_max, 1.0 - noise_max, l);
	} else {
		return l;
	}
}

void main() {
	ivec2 size = params.raster_size;
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);

	if (id.x < size.x && id.y < size.y) {
		float l = unquantized_input(id);
		imageStore(dither_buffer, id, vec4(l));
	}
}
