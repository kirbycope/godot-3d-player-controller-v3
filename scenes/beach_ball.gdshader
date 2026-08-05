shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Beach Ball Colors (matching classic beach ball: Red, White, Blue, White, Yellow, White)
uniform vec4 color_1 : source_color = vec4(0.92, 0.18, 0.15, 1.0);     // Red
uniform vec4 color_2 : source_color = vec4(0.08, 0.48, 0.88, 1.0);     // Blue
uniform vec4 color_3 : source_color = vec4(0.96, 0.76, 0.12, 1.0);     // Yellow
uniform vec4 color_white : source_color = vec4(0.95, 0.95, 0.95, 1.0); // White stripe
uniform vec4 cap_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);   // Top/bottom cap color
uniform vec4 valve_color : source_color = vec4(0.85, 0.85, 0.85, 1.0); // Valve cap color
uniform vec4 seam_color : source_color = vec4(0.15, 0.15, 0.15, 0.4);  // Heat weld seam color

// Pattern Settings
uniform int num_panels : hint_range(2, 16) = 6;
uniform bool alternate_white = true;
uniform float panel_offset : hint_range(0.0, 6.2831853) = 0.0;
uniform float cap_size : hint_range(0.0, 0.3) = 0.08;
uniform float valve_size : hint_range(0.0, 0.15) = 0.01;
uniform float seam_width : hint_range(0.001, 0.05) = 0.008;
uniform float seam_depth : hint_range(0.0, 0.1) = 0.02;

// Inflatable Plastic Material Properties
uniform float roughness : hint_range(0.0, 1.0) = 0.18;
uniform float specular : hint_range(0.0, 1.0) = 0.6;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.3;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.1;
uniform float panel_bulge : hint_range(0.0, 0.05) = 0.008;

varying vec3 v_local_pos;
varying vec3 v_local_normal;

void vertex() {
	v_local_pos = VERTEX;
	v_local_normal = NORMAL;
	
	// Inflatable panel bulging along normals
	float angle = atan(VERTEX.x, VERTEX.z) + panel_offset + PI;
	float norm_angle = fract(angle / (2.0 * PI));
	float p = norm_angle * float(num_panels);
	float panel_frac = fract(p);
	
	// Fade bulging near the top and bottom poles
	float pole_dist = 1.0 - abs(NORMAL.y);
	float pole_fade = sin(clamp(pole_dist / 0.8, 0.0, 1.0) * PI * 0.5);
	
	float bulge = sin(panel_frac * PI) * panel_bulge * pole_fade;
	VERTEX += NORMAL * bulge;
}

void fragment() {
	vec3 norm = normalize(v_local_normal);
	
	// Calculate longitude angle around Y axis
	float angle = atan(v_local_pos.x, v_local_pos.z) + panel_offset + PI;
	float norm_angle = fract(angle / (2.0 * PI));
	
	float total_panels = float(num_panels);
	float raw_panel = norm_angle * total_panels;
	int panel_idx = int(floor(raw_panel));
	float panel_frac = fract(raw_panel);
	
	// Base panel color selection
	vec4 base_color = color_white;
	
	if (alternate_white) {
		// Even indices get stripe colors (Red, Blue, Yellow...), odd indices get white
		if (panel_idx % 2 == 0) {
			int color_idx = (panel_idx / 2) % 3;
			if (color_idx == 0) base_color = color_1;
			else if (color_idx == 1) base_color = color_2;
			else base_color = color_3;
		} else {
			base_color = color_white;
		}
	} else {
		// Direct color sequence
		int color_idx = panel_idx % 3;
		if (color_idx == 0) base_color = color_1;
		else if (color_idx == 1) base_color = color_2;
		else base_color = color_3;
	}
	
	// Pole distance (0 at poles, 1 at equator)
	float pole_dist = 1.0 - abs(norm.y);
	
	// Apply top/bottom circular caps
	float cap_mask = smoothstep(cap_size + seam_width, cap_size, pole_dist);
	vec4 final_color = mix(base_color, cap_color, cap_mask);
	
	// Top inflation valve detail
	if (norm.y > 0.0 && pole_dist < valve_size) {
		float valve_ring = smoothstep(valve_size * 0.7, valve_size, pole_dist);
		vec4 current_valve = mix(valve_color, valve_color * 0.85, valve_ring);
		float valve_mask = smoothstep(valve_size, valve_size - seam_width, pole_dist);
		final_color = mix(final_color, current_valve, valve_mask);
	}
	
	// Seam lines calculation
	float dist_to_panel_edge = min(panel_frac, 1.0 - panel_frac);
	float panel_seam = smoothstep(seam_width, 0.0, dist_to_panel_edge);
	
	float cap_edge_dist = abs(pole_dist - cap_size);
	float cap_seam = smoothstep(seam_width, 0.0, cap_edge_dist) * (1.0 - cap_mask * 0.5);
	
	float seam_mask = clamp(max(panel_seam, cap_seam), 0.0, 1.0);
	
	// Darken/tint along heat-welded seams
	final_color = mix(final_color, seam_color, seam_mask * seam_color.a);
	
	// Apply normal perturbation along vertical seams to catch highlights realistically
	if (seam_mask > 0.0) {
		float norm_dir = (panel_frac < 0.5) ? -1.0 : 1.0;
		vec3 tangent = normalize(vec3(norm.z, 0.0, -norm.x));
		NORMAL = normalize(NORMAL + tangent * norm_dir * panel_seam * seam_depth);
	}
	
	// Output PBR material attributes for inflatable vinyl plastic
	ALBEDO = final_color.rgb;
	ROUGHNESS = mix(roughness, roughness * 1.5, seam_mask);
	SPECULAR = specular;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
}
