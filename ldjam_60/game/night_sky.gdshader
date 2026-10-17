shader_type sky;
render_mode disable_fog;

uniform float visual_time = 0.0;
uniform float storm = 0.0;
uniform float lightning = 0.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.72;
uniform float twinkle_strength : hint_range(0.0, 0.5) = 0.16;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.62;
uniform float cloud_speed : hint_range(0.0, 3.0) = 0.7;
// Eight baked contour/paint maps, sampled only inside a cloud's tangent card.
uniform sampler2D cloud_atlas : filter_linear_mipmap, repeat_disable;
uniform vec4 cloud_centers[40];
uniform vec4 cloud_rights[40];
uniform vec4 cloud_ups[40];
uniform float cloud_brightness : hint_range(0.3, 1.5) = 0.85;
uniform float cloud_highlights : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_softness : hint_range(0.0, 1.0) = 0.60;
uniform float cloud_variation : hint_range(0.0, 1.0) = 0.35;
// Review harness only: 1 = coverage, 2 = underlying stars, 3 = cloud paint.
uniform int cloud_debug = 0;
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

// Both layers move around world up, never the camera. A fixed spherical
// tangent basis preserves silhouettes at the zenith and levels the horizon.
vec3 drift_direction(vec3 d, float angle) {
	return vec3(d.x * cos(angle) - d.z * sin(angle), d.y, d.x * sin(angle) + d.z * cos(angle));
}

vec4 painted_clouds(vec3 direction) {
	vec3 near_ray = drift_direction(direction, visual_time * cloud_speed * 0.0019);
	vec3 far_ray = drift_direction(direction, visual_time * cloud_speed * 0.0008);
	vec3 result = vec3(0.0);
	float coverage = 0.0;
	// Distant banks first, then nearer formations: explicit back-to-front
	// compositing in one sky pass, without any transparent geometry sorting.
	for (int index = 0; index < 40; index++) {
		int i = index < 16 ? index + 24 : index - 16;
		bool distant = i >= 24;
		float presence = smoothstep(cloud_centers[i].w - 0.035, cloud_centers[i].w + 0.035,
			cloud_density * mix(1.0, 1.12, storm));
		if (presence < 0.001) { continue; }
		vec3 ray = distant ? far_ray : near_ray;
		float facing = dot(ray, cloud_centers[i].xyz);
		if (facing < 0.3) { continue; }
		vec2 uv = vec2(dot(ray, cloud_rights[i].xyz), -dot(ray, cloud_ups[i].xyz)) / facing * 0.5 + 0.5;
		if (uv.x <= 0.015 || uv.x >= 0.985 || uv.y <= 0.025 || uv.y >= 0.975) { continue; }
		float family = cloud_rights[i].w;
		vec2 atlas_uv = (uv + vec2(mod(family, 4.0), floor(family / 4.0))) / vec2(4.0, 2.0);
		vec4 paint = texture(cloud_atlas, atlas_uv);
		float feather = mix(0.035, 0.22, cloud_softness);
		float alpha = smoothstep(0.5 - feather, 0.5 + feather, paint.a) * presence;
		alpha *= smoothstep(0.006, 0.075, direction.y);
		vec3 shadow = vec3(0.070, 0.100, 0.170);
		vec3 body = vec3(0.215, 0.285, 0.405);
		vec3 moonlight = vec3(0.395, 0.455, 0.610);
		vec3 color = mix(shadow, body, paint.r);
		color = mix(color, moonlight, paint.g * cloud_highlights * 0.75);
		float lavender = cloud_ups[i].w * paint.b * cloud_variation;
		color = mix(color, color * vec3(1.18, 0.96, 1.14), lavender);
		color *= cloud_brightness * mix(1.0, 0.76, storm);
		if (distant) {
			color = mix(vec3(0.09, 0.14, 0.20), color, 0.68);
			alpha *= 0.94;
		}
		// Reserve actual open sky around the principal star. This thins the
		// formation itself, so background stars never shine over opaque paint.
		float separation = length(direction - NORTH_STAR);
		alpha *= smoothstep(0.035, 0.19, separation);
		result = color * alpha + result * (1.0 - alpha);
		coverage = alpha + coverage * (1.0 - alpha);
	}
	return vec4(result, coverage);
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
		vec4 clouds = painted_clouds(d);
		COLOR = night * (1.0 - clouds.a) + clouds.rgb + vec3(lightning);
		if (cloud_debug == 1) { COLOR = vec3(clouds.a); }
		if (cloud_debug == 2) { COLOR = night; }
		if (cloud_debug == 3) { COLOR = clouds.rgb; }
	}
}
