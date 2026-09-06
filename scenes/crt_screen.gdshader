// The glass of an old CRT monitor: the picture bulges toward the edges, every row carries a scanline, the
// corners fall off and the phosphors glow (emission, so the screen lights up at night and blooms with glow on).
shader_type spatial;

uniform sampler2D screen_texture : source_color, filter_nearest, repeat_disable;
uniform float curvature : hint_range(1.0, 20.0) = 6.0; // Higher is flatter glass.
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float glow : hint_range(0.0, 4.0) = 1.4; // Phosphor brightness.
uniform vec2 screen_resolution = vec2(320.0, 200.0);

void fragment() {
	// Pixels near the edges pull outward, as on a curved tube.
	vec2 centred = UV * 2.0 - 1.0;
	vec2 offset = abs(centred.yx) / curvature;
	centred += centred * offset * offset;
	vec2 uv = centred * 0.5 + 0.5;
	vec3 picture = vec3(0.0);
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
		// A little colour fringing from the shadow mask.
		float fringe = 0.6 / screen_resolution.x;
		picture.r = texture(screen_texture, uv + vec2(fringe, 0.0)).r;
		picture.g = texture(screen_texture, uv).g;
		picture.b = texture(screen_texture, uv - vec2(fringe, 0.0)).b;
		float scanline = 1.0 - scanline_strength * (0.5 + 0.5 * cos(uv.y * screen_resolution.y * TAU));
		float vignette = 1.0 - vignette_strength * dot(centred, centred) * 0.5;
		picture *= scanline * vignette;
	}
	ALBEDO = vec3(0.02);
	ROUGHNESS = 0.25;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	EMISSION = picture * glow;
}
