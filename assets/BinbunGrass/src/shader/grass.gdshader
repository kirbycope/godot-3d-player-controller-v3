shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_toon, specular_toon;

uniform bool billboard = false;

uniform sampler2D shape_texture : source_color, filter_linear_mipmap;
uniform sampler2D shape_atlas : source_color, filter_linear_mipmap;
uniform bool use_atlas = true;

group_uniforms Colors;
uniform sampler2D noise_texture : filter_linear_mipmap;
uniform sampler2D color_gradient : source_color, filter_linear;
uniform vec4 color_root : source_color = vec4(0.12, 0.28, 0.10, 1.0);
uniform vec4 color_tip : source_color = vec4(0.55, 0.80, 0.22, 1.0);
uniform float random_variation : hint_range(0.0, 1.0, 0.001) = 0.002;

group_uniforms Wind;
uniform sampler2D wind_texture : filter_linear_mipmap;
uniform vec2 wind_velocity = vec2(1.5, 1.0);
uniform float wind_speed : hint_range(0.1, 5.0, 0.05) = 0.7;
uniform float sway_strength : hint_range(0.0, 1.0, 0.02) = 0.20;

// WeatherFX Global Wind & Biome
global uniform float weather_wind_strength;
global uniform vec3 weather_wind_direction;
// source_color hint is required to bind a ProjectSettings shader global of type "color"
global uniform vec4 weather_grass_tint : source_color;

group_uniforms Transparency;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.05) = 0.45;

varying flat int id;
varying vec3 world_origin;

vec2 atlas_uv(vec2 uv, int index, int size){
	int tile_count = size * size;
	int i = index % tile_count;
	float x = float(i % size);
	float y = float(i / size);
	vec2 tile_size = 1.0 / vec2(float(size));
	return uv * tile_size + (vec2(x, y) * tile_size);
}

float randomf(int index, int seed){
	float value = sin(float(index + seed)) * 0.5 + 0.5;
	return value;
}

vec3 wind(vec2 uv, vec3 orig) {
	float h = clamp(1.0 - uv.y, 0.0, 1.0);
	float bend = pow(h, 1.6) * sway_strength;
	
	// Dynamic wind direction
	vec2 wind_dir = normalize(wind_velocity);
	if (length(weather_wind_direction.xz) > 0.01) {
		wind_dir = normalize(weather_wind_direction.xz);
	}
	float cur_speed = wind_speed * max(weather_wind_strength, 0.8);
	
	// Stable wave coordinates anchored to clump origin to prevent vertex jitter
	float wave1 = sin(TIME * cur_speed + orig.x * 0.12 + orig.z * 0.12);
	float wave2 = sin(TIME * (cur_speed * 1.25) + orig.x * 0.22 - orig.z * 0.22) * 0.25;
	
	// Smooth noise panning
	float noise_val = texture(wind_texture, (orig.xz * 0.02) - (wind_dir * (TIME * cur_speed * 0.06))).r * 2.0 - 1.0;
	
	float total_sway = (wave1 + wave2 + noise_val * 0.3) * bend;
	
	return vec3(wind_dir.x * total_sway, -abs(total_sway) * 0.1, wind_dir.y * total_sway);
}

void vertex() {
	world_origin = MODEL_MATRIX[3].xyz;
	id = INSTANCE_ID;
	
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0],
			INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);
	}
	
	vec3 local_wind = (inverse(MODEL_MATRIX) * vec4(wind(UV, world_origin), 0.0)).xyz;
	VERTEX += local_wind;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float shape_value = texture(shape_texture, UV).r;
	if (use_atlas) {
		vec2 at_uv = atlas_uv(UV, id, 2);
		shape_value = texture(shape_atlas, at_uv).r;
	}

	if (shape_value < alpha_scissor_threshold) {
		discard;
	}

	float noise_value = texture(noise_texture, world_origin.xz * 0.08).r;
	if (randomf(id, 1) < random_variation) noise_value += 0.4;
	
	vec4 grad_sample = texture(color_gradient, vec2(noise_value, 0.0));
	vec3 base_tint = mix(color_root.rgb, color_tip.rgb, pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.2));
	vec3 b_tint = weather_grass_tint.rgb;
	if (length(b_tint) < 0.01) {
		b_tint = vec3(1.0);
	}
	vec3 color = grad_sample.rgb * base_tint * 1.35 * b_tint;

	ALBEDO = color;
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
	
	// Translucent backlight prevents blades from turning black in shadow or against sun
	BACKLIGHT = color * 0.45;
}


