shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

// --- Uniforms ---
group_uniforms Base_Settings;
uniform vec4 base_color : source_color = vec4(0.0, 1.0, 0.78, 0.3);
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;

group_uniforms Rim_Settings;
uniform vec4 rim_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform float rim_power : hint_range(0.1, 10.0) = 3.0;

group_uniforms Pattern_Settings;
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 speed_layer_1 = vec2(0.0, 0.15);
uniform vec2 speed_layer_2 = vec2(0.08, -0.1);
uniform float pattern_scale : hint_range(0.1, 10.0) = 2.0;
uniform float pattern_strength : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	// 1. Base Setup
	vec3 base_rgb = base_color.rgb;
	float base_alpha = base_color.a;
	
	// 2. Dual-Layer Scrolling Digital Energy
	vec2 uv_scaled = UV * pattern_scale;
	
	// Layer 1 scrolling
	vec2 uv_1 = uv_scaled + (TIME * speed_layer_1);
	float noise_1 = texture(noise_texture, uv_1).r;
	
	// Layer 2 scrolling (different direction)
	vec2 uv_2 = uv_scaled + (TIME * speed_layer_2);
	float noise_2 = texture(noise_texture, uv_2).r;
	
	// Intersect the waves for a chaotic digital effect
	float combined_pattern = noise_1 * noise_2 * pattern_strength;
	
	// 3. Fresnel Rim Glow Calculation
	// Calculates angle between camera direction (VIEW) and surface direction (NORMAL)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 final_rim = rim_color.rgb * fresnel;
	
	// 4. Combine Everything
	// Inject the pattern directly into the emissions and transparency
	ALBEDO = base_rgb + (final_rim * 0.5);
	EMISSION = (base_rgb * glow_intensity) + final_rim + (rim_color.rgb * combined_pattern * glow_intensity);
	ALPHA = clamp(base_alpha + fresnel + combined_pattern, 0.0, 1.0);
}
