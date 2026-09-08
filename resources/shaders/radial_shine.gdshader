shader_type canvas_item;

// Rays fanning out from the centre and turning slowly, fading with distance: the shine behind an item just found.
// Two ray sets turn against each other so the pattern never reads as a still picture. Alpha only; the colour is
// the uniform, so a dark ColorRect underneath decides the contrast.
uniform vec4 color: source_color = vec4(1.0, 0.92, 0.6, 1.0);
uniform int ray_count: hint_range(4, 64) = 14;
uniform float speed: hint_range(-2.0, 2.0) = 0.25;
uniform float sharpness: hint_range(0.5, 8.0) = 2.5;
uniform float inner_radius: hint_range(0.0, 0.5) = 0.06;
uniform float outer_radius: hint_range(0.1, 1.0) = 0.5;
uniform float glow: hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	float a = atan(p.y, p.x);
	float rays = pow(0.5 + 0.5 * sin(a * float(ray_count) + TIME * speed), sharpness);
	float rays_back = pow(0.5 + 0.5 * sin(-a * float(ray_count) * 0.5 + TIME * speed * 0.6 + 1.7), sharpness * 1.5);
	float fade = 1.0 - smoothstep(inner_radius, outer_radius, r);
	float core = glow * (1.0 - smoothstep(0.0, inner_radius * 3.0, r));
	float alpha = (rays * 0.75 + rays_back * 0.45 + core) * fade;
	COLOR = vec4(color.rgb, color.a * clamp(alpha, 0.0, 1.0));
}
