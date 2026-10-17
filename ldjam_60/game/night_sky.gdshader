shader_type sky;
render_mode disable_fog;

uniform float visual_time = 0.0;
uniform float storm = 0.0;
uniform float lightning = 0.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.72;
uniform float twinkle_strength : hint_range(0.0, 0.5) = 0.16;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_speed : hint_range(0.0, 3.0) = 0.7;
uniform float target_focus : hint_range(0.0, 1.0) = 0.0;
const vec3 NORTH_STAR = vec3(0.0, 0.8290376, -0.5591929);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

// Cube faces avoid pinching or streaking at the zenith. Star positions stay
// fixed against world north; only intensity twinkles, never position or size.
vec3 star_coordinates(vec3 d) {
	vec3 axis = abs(d);
	vec2 uv;
	float face;
	if (axis.y >= axis.x && axis.y >= axis.z) {
		uv = d.xz / axis.y;
		face = d.y > 0.0 ? 1.0 : 2.0;
	} else if (axis.x >= axis.z) {
		uv = d.zy / axis.x;
		face = d.x > 0.0 ? 3.0 : 4.0;
	} else {
		uv = d.xy / axis.z;
		face = d.z > 0.0 ? 5.0 : 6.0;
	}
	return vec3(uv * 0.5 + 0.5, face);
}

// Subpixel coverage avoids harsh on/off star flicker while turning.
vec3 stars(vec2 uv, float cells, float seed, float density, float pixel_angle) {
	vec2 grid_scale = vec2(cells * 2.0, cells);
	vec2 grid = uv * grid_scale;
	vec2 id = floor(grid) + seed;
	float chance = hash(id);
	vec2 center = vec2(hash(id + 13.7), hash(id - 9.2)) * 0.7 + 0.15;
	vec2 offset = (fract(grid) - center) / grid_scale * 2.0;
	float distance_angle = length(offset) / sqrt(1.0 + dot(uv * 2.0 - 1.0, uv * 2.0 - 1.0));
	float bright = pow(hash(id + 41.3), 5.0);
	float radius = mix(0.00045, 0.0015, bright);
	float core = 1.0 - smoothstep(max(0.0, radius - pixel_angle * 0.5), radius + pixel_angle * 0.5, distance_angle);
	float halo = exp(-distance_angle * distance_angle / 0.000016) * bright * 0.08;
	float pulse = 1.0 + twinkle_strength * sin(visual_time * (0.65 + chance) + chance * 95.0);
	vec3 tint = mix(vec3(0.55, 0.72, 0.89), vec3(1.0, 0.86, 0.65), hash(id + 8.0));
	return tint * (core + halo) * mix(0.35, 1.5, bright) * pulse * step(chance, density);
}

float ellipse(vec2 p, vec2 center, vec2 axes) {
	return (length((p - center) / axes) - 1.0) * min(axes.x, axes.y);
}

// Broad lobes make painted cumulus silhouettes with soft edges and quiet bands.
float cloud_shape(vec2 p, float seed) {
	p.x *= mix(0.68, 1.0, seed);
	float form = ellipse(p, vec2(0.0, 0.07), vec2(0.48, 0.14));
	form = min(form, ellipse(p, vec2(-0.26, -0.025), vec2(0.24, 0.17 + seed * 0.08)));
	form = min(form, ellipse(p, vec2(-0.10 + seed * 0.24, -0.12), vec2(0.23, 0.22 + seed * 0.13)));
	form = min(form, ellipse(p, vec2(0.25, -0.015), vec2(0.25 - seed * 0.05, 0.16 + seed * 0.06)));
	return form;
}

vec2 cloud_field(vec2 p) {
	vec2 cell = floor(p);
	float nearest = 2.0;
	float shade = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cell + vec2(float(x), float(y));
			float seed = hash(id + 60.0);
			if (seed < cloud_density * mix(0.86, 1.2, storm)) {
				vec2 center = id + vec2(0.5) + vec2(hash(id + 3.0) - 0.5, hash(id + 7.0) - 0.5) * 0.35;
				vec2 local = (p - center) / mix(0.65, 1.1, hash(id - 4.0));
				float angle = (hash(id + 17.0) - 0.5) * 0.5;
				local = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * local;
				float shape = cloud_shape(local, seed);
				if (shape < nearest) {
					nearest = shape;
					shade = local.y;
				}
			}
		}
	}
	return vec2(nearest, shade);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float height = max(d.y, 0.0);
	vec3 night = mix(vec3(0.085, 0.15, 0.20), vec3(0.018, 0.032, 0.075), smoothstep(0.0, 0.9, height));
	if (AT_CUBEMAP_PASS) {
		// Only the gradient contributes to lighting; animated detail stays cheap.
		COLOR = night;
	} else {
		vec3 star_uv = star_coordinates(d);
		// Take derivatives of the continuous world direction, before face selection
		// can introduce a discontinuity. Face UV derivatives create bright seams.
		float pixel_angle = max(length(fwidth(d)), 0.0001);
		float band = exp(-pow((d.x * 0.65 + d.z * 0.4 + d.y * 0.2 - 0.15) * 5.0, 2.0));
		float dust = noise(d.xz * 6.0 + d.y * 3.0) * 0.6 + noise(d.xz * 15.0) * 0.4;
		night += vec3(0.019, 0.026, 0.048) * band * dust * height;
		vec3 starlight = stars(star_uv.xy, 40.0, star_uv.z * 137.0, star_density * 0.58, pixel_angle);
		starlight += stars(star_uv.xy, 20.0, 81.0 + star_uv.z * 137.0, star_density * 0.24, pixel_angle);
		// The reference is one of several bright stars until the instrument focuses.
		float separation = length(d - NORTH_STAR);
		float north = 1.0 - smoothstep(0.0010, 0.0010 + pixel_angle, separation);
		float glow = exp(-separation * separation / 0.000024) * (0.07 + target_focus * 0.19);
		starlight += vec3(1.0, 0.91, 0.72) * (north * (1.1 + target_focus * 0.4) + glow);
		night += starlight * smoothstep(0.015, 0.15, d.y) * mix(1.0, 0.78, storm);
		vec2 p = d.xz / (height + 0.65) * 3.9;
		p += vec2(-0.011, 0.004) * visual_time * cloud_speed;
		vec2 cloud = cloud_field(p);
		float cover = (1.0 - smoothstep(-0.012, 0.02, cloud.x)) * smoothstep(0.01, 0.13, d.y);
		float lit_top = 1.0 - smoothstep(-0.18, 0.08, cloud.y);
		float rim = smoothstep(-0.12, -0.015, cloud.x) * lit_top;
		vec3 paint = mix(vec3(0.08, 0.115, 0.18), vec3(0.17, 0.24, 0.30), lit_top * 0.65);
		paint += vec3(0.06, 0.075, 0.08) * rim;
		paint *= mix(1.0, 0.72, storm);
		// Veil rather than erase the navigation star, in a small feathered area.
		float star_window = 1.0 - smoothstep(0.025, 0.10, separation);
		float opacity = cover * mix(0.96, 0.99, storm);
		opacity = mix(opacity, min(opacity, 0.38), star_window);
		COLOR = mix(night, paint, opacity) + vec3(lightning);
	}
}
