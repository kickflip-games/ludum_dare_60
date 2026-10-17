// Original world-direction cloud field. No vendor shader source, atlas or raymarch.
// Integer lattice noise is continuous in 3D: no longitude seam or zenith singularity.
uniform float cloud_scale : hint_range(0.4, 2.0) = 1.0;
uniform vec2 cloud_wind = vec2(1.0, 0.28);
uniform vec3 cloud_offset = vec3(0.0);
uniform bool procedural_clouds = true;

float cloud_hash(ivec3 cell) {
	uvec3 q = uvec3(cell);
	uint h = (q.x * 1597334677u) ^ (q.y * 3812015801u) ^ (q.z * 2798796415u);
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	return float((h ^ (h >> 16u)) & 16777215u) / 16777215.0;
}

// Value and analytic gradient share eight lattice samples. The gradient gives
// broad moonlit upper faces without extra normal samples or screen-space shading.
vec4 cloud_noise(vec3 p) {
	ivec3 cell = ivec3(floor(p));
	vec3 f = fract(p);
	vec3 blend = f * f * (3.0 - 2.0 * f);
	vec3 slope = 6.0 * f * (1.0 - f);
	float a = cloud_hash(cell);
	float b = cloud_hash(cell + ivec3(1, 0, 0));
	float c = cloud_hash(cell + ivec3(0, 1, 0));
	float d = cloud_hash(cell + ivec3(1, 1, 0));
	float e = cloud_hash(cell + ivec3(0, 0, 1));
	float f1 = cloud_hash(cell + ivec3(1, 0, 1));
	float g = cloud_hash(cell + ivec3(0, 1, 1));
	float h = cloud_hash(cell + ivec3(1, 1, 1));
	vec4 planes = mix(vec4(a, c, e, g), vec4(b, d, f1, h), blend.x);
	float bottom = mix(planes.x, planes.y, blend.y);
	float top = mix(planes.z, planes.w, blend.y);
	float dx = mix(mix(b - a, d - c, blend.y), mix(f1 - e, h - g, blend.y), blend.z);
	float dy = mix(planes.y - planes.x, planes.w - planes.z, blend.z);
	return vec4(mix(bottom, top, blend.z), vec3(dx, dy, top - bottom) * slope);
}

float navigation_lane(vec3 d, vec3 star, vec3 wind, float irregularity) {
	// Long, softly meandering wind lanes lower the density field, rather than
// punching round alpha holes around stars. They stay fixed when focus changes.
	vec3 along = normalize(wind - star * dot(wind, star));
	vec3 across = cross(star, along);
	vec3 delta = d - star;
	float x = dot(delta, along);
	float y = dot(delta, across) + irregularity * min(abs(x), 0.2) * 0.4;
	return (1.0 - smoothstep(0.12, 0.50, abs(x)))
		* (1.0 - smoothstep(0.035, 0.19, abs(y)));
}

vec4 toon_clouds(vec3 d) {
	if (cloud_density <= 0.0 || d.y <= 0.0) { return vec4(0.0); }
	vec2 wind2 = cloud_wind / max(length(cloud_wind), 0.001);
	vec3 wind = vec3(wind2.x, 0.0, wind2.y);
	float high = smoothstep(0.25, 0.85, d.y);
	float stretch = mix(1.0, 0.58, high * cloud_variation);
	// A curved horizontal deck has no pole or wrap seam. Perspective naturally
	// flattens distant formations into banks instead of stretching tangent cards.
	vec2 deck = d.xz / (d.y + 0.28);
	vec3 p = vec3(dot(deck, wind2) * 2.4 * stretch,
		dot(deck, vec2(-wind2.y, wind2.x)) * 3.1, length(deck) * 0.18);
	p = p * cloud_scale + cloud_offset;
	// Translation of the field is coherent wind, not camera-relative rotation.
	p.x -= visual_time * cloud_speed * 0.012;
	p.z += visual_time * cloud_speed * 0.002;
	vec4 broad = cloud_noise(p * 0.49 + vec3(17.0, 3.0, 11.0));
	vec3 warped = p + broad.yzw * 0.24;
	vec4 billow = cloud_noise(warped);
	vec4 detail = cloud_noise(warped * 2.07 + vec3(7.0, 31.0, 19.0));
	vec4 fringe = cloud_noise(warped * 4.13 + vec3(23.0, 9.0, 41.0));
	float field = broad.x * 0.18 + billow.x * 0.55 + detail.x * 0.21 + fringe.x * 0.06;
	vec3 gradient = billow.yzw * 0.55 + detail.yzw * 0.43;
	// Broad low banks blend into a sparse, stretched upper layer.
	field += 0.095 * exp(-pow((d.y - 0.17) * 5.0, 2.0));
	field -= high * 0.10;
	float lane = max(navigation_lane(d, guiding_stars[0], wind, broad.x - 0.5),
		max(navigation_lane(d, guiding_stars[1], wind, broad.x - 0.5),
			navigation_lane(d, guiding_stars[2], wind, broad.x - 0.5)));
	field -= lane * 0.62;
	float threshold = mix(0.86, 0.34, cloud_density) - storm * 0.035 * cloud_density;
	float edge = mix(0.005, 0.025, cloud_softness);
	float alpha = smoothstep(threshold - edge, threshold + edge, field);
	alpha *= smoothstep(0.004, 0.055, d.y);
	float depth = clamp((field - threshold) / 0.20, 0.0, 1.0);
	float light = clamp(0.45 + (1.0 - depth) * 0.29 + gradient.x * 0.16 - gradient.y * 0.12, 0.0, 1.0);
	float bands = 0.35 + smoothstep(0.44, 0.48, light) * 0.35 + smoothstep(0.67, 0.71, light) * 0.30;
	vec3 shadow = vec3(0.110, 0.155, 0.210);
	vec3 body = vec3(0.185, 0.245, 0.305);
	vec3 moonlit = vec3(0.285, 0.355, 0.425);
	vec3 color = mix(shadow, body, bands);
	color = mix(color, moonlit, smoothstep(0.58, 0.82, light) * cloud_highlights * 0.65);
	color *= cloud_brightness * mix(1.0, 0.72, storm);
	return vec4(color * alpha, alpha);
}
