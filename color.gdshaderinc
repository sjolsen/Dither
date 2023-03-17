float luminance(vec3 c) {
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
}

float y_to_lstar(float y) {
	const float d = 6.0 / 29.0;
	const float d2 = pow(d, 2);
	const float d3 = pow(d, 3);
	y = clamp(y, 0.0, 1.0);
	float f = y > d3 ? pow(y, 1.0/3.0) : y / (3.0 * d2) + 4.0 / 29.0;
	return 1.16 * f - 0.16;
}

float lstar_to_y(float l) {
	const float d = 6.0 / 29.0;
	const float d2 = pow(d, 2);
	l = clamp(l, 0.0, 1.0);
	float t = (l + 0.16) / 1.16;
	return t > d ? pow(t, 3) : 3.0 * d2 * (t - 4.0 / 29.0);
}
