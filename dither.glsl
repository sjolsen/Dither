#[compute]
#version 450

#define BLOCK_SIZE (16)

layout(local_size_x = 1, local_size_y = BLOCK_SIZE, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(r32f, set = 0, binding = 1) uniform image2D dither_buffer;

layout(push_constant, std430) uniform Params {
	ivec2 raster_size;
	int bit_depth;
	int noise_order;
	int error_diffusion;
	int timestamp;
	int dynamic_range_compression;
	int show_error;
} params;

#define delta (1.0 / float((1u << params.bit_depth) - 1u))
#define noise_max (float(params.noise_order) * delta / 2.0)

#define KERNEL_NONE (0)
#define KERNEL_FLOYD_STEINBERG (1)
#define KERNEL_ATKINSON (2)
#define KERNEL_OPTIMAL (3)

#define KERNEL (params.error_diffusion)

const int kernel_size[] = {0, 4, 6, 24};
const int kernel_skew[] = {0, 2, 2, 4};

const int kernel_x[][24] = {
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{1, -1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{1, 2, -1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{1, 2, 3, -3, -2, -1, 0, 1, 2, 3, -3, -2, -1, 0, 1, 2, 3, -3, -2, -1, 0, 1, 2, 3},
};

const int kernel_y[][24] = {
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 1, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3},
};

const float kernel_k[][24] = {
	{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	{
		-7.0 / 16.0, -3.0 / 16.0, -5.0 / 16.0, -1.0 / 16.0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
	},
	{
		-0.125, -0.125, -0.125, -0.125, -0.125, -0.125, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
	},
	{
		-0.5090, 0.1008, -0.0009, 0.0015, 0.0057, -0.2549, -0.3802, -0.0180,
		0.0834, -0.0255, -0.0082, 0.0447, 0.1114, 0.1007, 0.0627, -0.0106,
		-0.0154, -0.0035, -0.0256, -0.0244, -0.0193, -0.0234, -0.0111, 0.0077,
	},
};

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

uvec3 pcg3d(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y*v.z; v.y += v.z*v.x; v.z += v.x*v.y;
	v ^= v >> 16u;
	v.x += v.y*v.z; v.y += v.z*v.x; v.z += v.x*v.y;
	return v;
}

float sample_noise(uvec2 xy) {
	if (params.noise_order == 0) {
		return 0.0;
	}

	uint z = uint(params.timestamp);
	uvec3 xyz = uvec3(xy, z);
	vec3 noise = vec3(pcg3d(xyz)) / float(0u - 1u) - 0.5;
	float result = 0.0;
	for (int i = 0; i < params.noise_order; ++i) {
		result += noise[i];
	}
	return result;
}

float quantize(float x, float noise) {
	float v = noise * delta;
	float y = delta * floor((x + v) / delta + 0.5);
	return clamp(y, 0.0, 1.0);
}

ivec2 uv_to_xy(ivec2 uv) {
	ivec2 size = ivec2(params.raster_size);
	int u_skewed = uv.x - uv.y * kernel_skew[KERNEL];
	int x = u_skewed % size.x;
	int y = BLOCK_SIZE * ((u_skewed - x) / size.x) + uv.y;
	return ivec2(x, y);
}

ivec2 xy_to_uv(ivec2 xy) {
	ivec2 size = ivec2(params.raster_size);
	int v = xy.y % BLOCK_SIZE;
	int u_skewed = xy.x + ((xy.y - v) / BLOCK_SIZE) * size.x;
	int u = u_skewed + v * kernel_skew[KERNEL];
	return ivec2(u, v);
}

bool in_block(ivec2 xy) {
	ivec2 size = ivec2(params.raster_size);
	ivec2 uv = xy_to_uv(xy);
	int u_start = int(gl_WorkGroupID.x) * BLOCK_SIZE;
	int u_end = u_start + BLOCK_SIZE;
	return (0 <= xy.x && xy.x < size.x &&
		0 <= xy.y && xy.y < size.y &&
		u_start <= uv.x && uv.x < u_end &&
		0 <= uv.y && uv.y < BLOCK_SIZE);
}

void diffuse_error(ivec2 focus, float d) {
	ivec2 size = ivec2(params.raster_size);
	if (in_block(focus)) {
		float l = imageLoad(dither_buffer, focus).r;
		imageStore(dither_buffer, focus, vec4(l + d));
	}
}

void main() {
	ivec2 size = ivec2(params.raster_size);

	// Break the image up into horizontal stripes and march through the
	// stripes on a diagonal.
	for (int i = 0; i < BLOCK_SIZE; ++i) {
		int u = int(gl_WorkGroupID.x) * BLOCK_SIZE + i;
		int v = int(gl_LocalInvocationID.y);
		ivec2 focus = uv_to_xy(ivec2(u, v));

		if (in_block(focus)) {
			float gray = imageLoad(dither_buffer, focus).r;
			float q = quantize(gray, sample_noise(focus));
			float e = q - gray;

			if (bool(params.show_error)) {
				float original = unquantized_input(focus);
				float err = q - original;
				float l = 0.5 + 1.4 * err;
				imageStore(color_image, focus, vec4(l, l, l, 1.0));
			} else {
				imageStore(color_image, focus, vec4(q, q, q, 1.0));
			}

			if (bool(params.error_diffusion)) {
				for (int i = 0; i < kernel_size[KERNEL]; ++i) {
					ivec2 offset = ivec2(kernel_x[KERNEL][i], kernel_y[KERNEL][i]);
					float k = kernel_k[KERNEL][i];
					diffuse_error(focus + offset, e * k);
				}
			}
		}
	}
}
