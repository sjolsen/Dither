#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(push_constant, std430) uniform Params {
	ivec2 raster_size;
	int bit_depth;
	int noise_order;
} params;

#define delta (1.0 / float((1u << params.bit_depth) - 1u))
#define noise_max (float(params.noise_order) * delta / 2.0)

float luminance(vec3 c) {
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
}

void main() {
	ivec2 size = params.raster_size;
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);

	if (id.x < size.x && id.y < size.y) {
		vec4 color = imageLoad(color_image, id);
		float l = luminance(color.rgb);
		l = mix(noise_max, 1.0 - noise_max, l);
		color.rgb = vec3(l);
		imageStore(color_image, id, color);
	}
}
