//vegetation_sway.gdshader - suitable for grass

shader_type spatial;
render_mode cull_disabled;

// Wind parameters
uniform float windSpeed : hint_range(0.1, 5.0) = 1.0;
uniform float windStrength : hint_range(0.0, 1.0) = 0.15;
uniform sampler2D albedo : repeat_disable, source_color;

// Night time tint parameters
uniform vec3 nightColor : source_color = vec3(0.1, 0.2, 0.4); 
uniform float nightTime : hint_range(0.0, 1.0) = 0.0; 

// WeatherFX Global Wind
global uniform float weather_wind_strength;
global uniform vec3 weather_wind_direction;

void vertex(){
	float Y = max(0.0, 1.0 - VERTEX.y);
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float speed = windSpeed * max(weather_wind_strength, 0.8);
	float sway = sin(world_pos.x * 0.25 + world_pos.z * 0.25 + TIME * speed + Y) * (1.0 - Y) * windStrength;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.4;
}

void fragment() {
	vec4 loadAlbedo = texture(albedo, UV);

	// Apply night tint - lerp between original color and night color based on nightAmount
	vec3 finalColor = mix(loadAlbedo.rgb, loadAlbedo.rgb * nightColor, nightTime);

	ALBEDO = finalColor;
	ALPHA = loadAlbedo.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
	BACKLIGHT = finalColor * 0.35;
}

