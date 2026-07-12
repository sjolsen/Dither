#[compute]
#version 450

#define NTHREADS (1024)
#define bit_depth (4)
#define delta (1.0 / float((1u << bit_depth) - 1u))
#define noise_order (1)
#define noise_max (float(noise_order) * delta / 2.0)

layout(local_size_x = 1, local_size_y = NTHREADS, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(push_constant, std430) uniform Params {
	ivec2 raster_size;
} params;

uvec3 pcg3d(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y*v.z; v.y += v.z*v.x; v.z += v.x*v.y;
	v ^= v >> 16u;
	v.x += v.y*v.z; v.y += v.z*v.x; v.z += v.x*v.y;
	return v;
}

float sample_noise(uvec2 xy) {
	if (noise_order == 0) {
		return 0.0;
	}

	uint z = 0u;
	uvec3 xyz = uvec3(xy, z);
	vec3 noise = vec3(pcg3d(xyz)) / float(0u - 1u) - 0.5;
	float result = 0.0;
	for (int i = 0; i < noise_order; ++i) {
		result += noise[i];
	}
	return result;
}

float quantize(float x, float noise) {
	float v = noise * delta;
	float y = delta * floor((x + v) / delta + 0.5);
	return clamp(y, 0.0, 1.0);
}

void store_luminance(ivec2 focus, float l) {
	ivec2 size = ivec2(params.raster_size);
	if (0 <= focus.y && focus.y < size.y) {
		vec4 color = vec4(l, l, l, 1.0);
		imageStore(color_image, focus, color);
	}
}

void add_luminance(ivec2 focus, float d) {
	ivec2 size = ivec2(params.raster_size);
	if (0 <= focus.y && focus.y < size.y) {
		vec4 color = imageLoad(color_image, focus);
		color.rgb = color.rgb + vec3(d);
		imageStore(color_image, focus, color);
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
			vec4 color = imageLoad(color_image, focus);
			float gray = color.r;
			float q = quantize(gray, sample_noise(uvec2(x, y)));
			float e = q - gray;
			store_luminance(focus, q);
			add_luminance(focus + ivec2( 1, 0), e * -0.5090);
			add_luminance(focus + ivec2( 2, 0), e *  0.1008);
			add_luminance(focus + ivec2( 3, 0), e * -0.0009);
			add_luminance(focus + ivec2(-3, 1), e *  0.0015);
			add_luminance(focus + ivec2(-2, 1), e *  0.0057);
			add_luminance(focus + ivec2(-1, 1), e * -0.2549);
			add_luminance(focus + ivec2( 0, 1), e * -0.3802);
			add_luminance(focus + ivec2( 1, 1), e * -0.0180);
			add_luminance(focus + ivec2( 2, 1), e *  0.0834);
			add_luminance(focus + ivec2( 3, 1), e * -0.0255);
			add_luminance(focus + ivec2(-3, 2), e * -0.0082);
			add_luminance(focus + ivec2(-2, 2), e *  0.0447);
			add_luminance(focus + ivec2(-1, 2), e *  0.1114);
			add_luminance(focus + ivec2( 0, 2), e *  0.1007);
			add_luminance(focus + ivec2( 1, 2), e *  0.0627);
			add_luminance(focus + ivec2( 2, 2), e * -0.0106);
			add_luminance(focus + ivec2( 3, 2), e * -0.0154);
			add_luminance(focus + ivec2(-3, 3), e * -0.0035);
			add_luminance(focus + ivec2(-2, 3), e * -0.0256);
			add_luminance(focus + ivec2(-1, 3), e * -0.0244);
			add_luminance(focus + ivec2( 0, 3), e * -0.0193);
			add_luminance(focus + ivec2( 1, 3), e * -0.0234);
			add_luminance(focus + ivec2( 2, 3), e * -0.0111);
			add_luminance(focus + ivec2( 3, 3), e *  0.0077);
		}

		if (++x == size.x) {
			x = 0;
			y += NTHREADS;
		}
	}
}
