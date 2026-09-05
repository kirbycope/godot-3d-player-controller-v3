shader_type spatial;
render_mode cull_back, depth_test_disabled, unshaded;

// --- UNIFORMS ---
// Grouping uniforms makes the material inspector clean and organized.

group_uniforms Distortion;
uniform sampler2D distortion_normal_map : hint_normal, repeat_enable;
uniform vec2 distortion_speed = vec2(0.1, 0.1);
uniform vec2 distortion_scale = vec2(1.0, 1.0);
uniform float distortion_strength = 0.1;

group_uniforms Depth_Fog;
uniform float depth_fog_distance = 20.0;
uniform sampler2D depth_1D_color_gradient : source_color, repeat_disable;

group_uniforms Border_Mask;
uniform sampler2D border_mask : source_color, hint_default_transparent, repeat_disable;
uniform float border_distortion_blend : hint_range(0.0, 1.0) = 0.0;

// Godot 4 Built-in Screen Textures
group_uniforms Internal;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;


//void vertex() {
	//// Locks the plane directly to the camera view for post-processing
	//POSITION = vec4(VERTEX.xy, 0.0, 1.0);
//}


void fragment() {
	// -------------------------------------------------------------------------
	// 1. CALCULATE DISTORTION
	// -------------------------------------------------------------------------
	// Scroll and scale the UVs for the normal map
	vec2 scrolled_uv = (SCREEN_UV + (TIME * distortion_speed)) * distortion_scale;
	
	// Sample the normal map and unpack it from [0, 1] range to [-1, 1] range
	vec2 normal_distortion = texture(distortion_normal_map, scrolled_uv).rg;
	normal_distortion = (normal_distortion * 2.0) - 1.0;
	
	// Calculate baseline scene depth (using undistorted SCREEN_UV) to scale the distortion.
	// This makes the distortion fade based on depth.
	float raw_baseline_depth = texture(depth_texture, SCREEN_UV).x;
	vec4 baseline_view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_baseline_depth, 1.0);
	float linear_baseline_depth = -(baseline_view_pos.z / baseline_view_pos.w);
	float baseline_depth_mask = clamp(linear_baseline_depth / depth_fog_distance, 0.0, 1.0);
	
	// Apply the depth mask to the distortion strength, then offset the SCREEN_UV
	float current_distortion_strength = mix(0.0, distortion_strength, baseline_depth_mask);
	vec2 distortion_offset = normal_distortion * current_distortion_strength;
	vec2 distorted_uv = SCREEN_UV - distortion_offset;
	
	
	// -------------------------------------------------------------------------
	// 2. SAMPLE SCREEN AND CUSTOM DEPTH
	// -------------------------------------------------------------------------
	// Grab the screen color using our new wobbly UVs
	vec3 screen_color = texture(screen_texture, distorted_uv).rgb;
	
	// Grab the raw depth using the wobbly UVs so the depth silhouette matches the distortion
	float raw_custom_depth = texture(depth_texture, distorted_uv).x;
	
	// Linearize the custom depth (your custom expression code is right here)
	vec4 custom_view_pos = INV_PROJECTION_MATRIX * vec4(distorted_uv * 2.0 - 1.0, raw_custom_depth, 1.0);
	float linear_custom_depth = -(custom_view_pos.z / custom_view_pos.w);
	
	// Normalize depth based on your max distance
	float custom_depth_mask = clamp(linear_custom_depth / depth_fog_distance, 0.0, 1.0);
	
	
	// -------------------------------------------------------------------------
	// 3. COLOR MIXING AND BORDER
	// -------------------------------------------------------------------------
	// Sample the gradient color based on the depth distance
	// Since it's a 1D gradient, we use the depth_mask for both X and Y
	vec4 fog_color_data = texture(depth_1D_color_gradient, vec2(custom_depth_mask));
	
	// Mix the screen color with the fog color based on the gradient's alpha channel
	vec3 base_with_fog = mix(screen_color, fog_color_data.rgb, fog_color_data.a);
	
	// Calculate UVs for the border mask (blending between distorted and undistorted)
	vec2 border_uv = mix(distorted_uv, SCREEN_UV, border_distortion_blend);
	vec4 border_color_data = texture(border_mask, border_uv);
	
	// Final Output: Mix the fogged underwater scene with your border mask
	ALBEDO = mix(base_with_fog, border_color_data.rgb, border_color_data.a);
}
