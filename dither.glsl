#[compute]
#version 450

#define NTHREADS (1024)

layout(local_size_x = 1, local_size_y = NTHREADS, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(r32f, set = 0, binding = 1) uniform image2D dither_buffer;

layout(push_constant, std430) uniform Params {
	ivec2 raster_size;
	int bit_depth;
	int noise_order;
} params;

#define delta (1.0 / float((1u << params.bit_depth) - 1u))
#define noise_max (float(params.noise_order) * delta / 2.0)

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

	uint z = 0u;
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

void diffuse_error(ivec2 focus, float d) {
	ivec2 size = ivec2(params.raster_size);
	if (0 <= focus.y && focus.y < size.y) {
		float l = imageLoad(dither_buffer, focus).r;
		imageStore(dither_buffer, focus, vec4(l + d));
	}
}

void main() {
	const int skew = 4;
	ivec2 size = ivec2(params.raster_size);
	int id = int(gl_GlobalInvocationID.y);

	// Break the image up into horizontal stripes and march through the
	// stripes on a diagonal.
	int i = 0 - id * skew;
	int x = i % size.x;
	int y = NTHREADS * ((i - x) / size.x) + id;
	while (y < size.y) {
		ivec2 focus = ivec2(x, y);

		if (y >= 0) {
			float gray = imageLoad(dither_buffer, focus).r;
			float q = quantize(gray, sample_noise(uvec2(x, y)));
			float e = q - gray;
			imageStore(color_image, focus, vec4(q, q, q, 1.0));
			diffuse_error(focus + ivec2( 1, 0), e * -0.5090);
			diffuse_error(focus + ivec2( 2, 0), e *  0.1008);
			diffuse_error(focus + ivec2( 3, 0), e * -0.0009);
			diffuse_error(focus + ivec2(-3, 1), e *  0.0015);
			diffuse_error(focus + ivec2(-2, 1), e *  0.0057);
			diffuse_error(focus + ivec2(-1, 1), e * -0.2549);
			diffuse_error(focus + ivec2( 0, 1), e * -0.3802);
			diffuse_error(focus + ivec2( 1, 1), e * -0.0180);
			diffuse_error(focus + ivec2( 2, 1), e *  0.0834);
			diffuse_error(focus + ivec2( 3, 1), e * -0.0255);
			diffuse_error(focus + ivec2(-3, 2), e * -0.0082);
			diffuse_error(focus + ivec2(-2, 2), e *  0.0447);
			diffuse_error(focus + ivec2(-1, 2), e *  0.1114);
			diffuse_error(focus + ivec2( 0, 2), e *  0.1007);
			diffuse_error(focus + ivec2( 1, 2), e *  0.0627);
			diffuse_error(focus + ivec2( 2, 2), e * -0.0106);
			diffuse_error(focus + ivec2( 3, 2), e * -0.0154);
			diffuse_error(focus + ivec2(-3, 3), e * -0.0035);
			diffuse_error(focus + ivec2(-2, 3), e * -0.0256);
			diffuse_error(focus + ivec2(-1, 3), e * -0.0244);
			diffuse_error(focus + ivec2( 0, 3), e * -0.0193);
			diffuse_error(focus + ivec2( 1, 3), e * -0.0234);
			diffuse_error(focus + ivec2( 2, 3), e * -0.0111);
			diffuse_error(focus + ivec2( 3, 3), e *  0.0077);
		}

		if (++x == size.x) {
			x = 0;
			y += NTHREADS;
		}
	}
}
