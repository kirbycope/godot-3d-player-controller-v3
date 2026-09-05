shader_type spatial;
render_mode cull_back, depth_test_disabled, unshaded;

uniform float melt_amount : hint_range(0.0, 1.0) = 0.0;

uniform float blue_amount : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D slush_base : filter_linear_mipmap,repeat_enable;   // The Black/White Noise (Mask)
uniform vec2 scale_1 = vec2(1.0,1.0);
uniform vec2 offset_1 = vec2(0.0,0.0);

group_uniforms distortion;
uniform sampler2D slush_normal : filter_linear_mipmap,repeat_enable; // The Blue/Purple Normal Map (Distortion)
uniform vec2 scale_normal = vec2(1.0,1.0);
uniform vec2 offset_normal = vec2(0.0,0.0);
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.03;

group_uniforms mask;
uniform bool enable_mask = false;
uniform sampler2D slush_mask : filter_linear_mipmap,repeat_disable,hint_default_white;   // The Black/White Noise (Mask)
uniform vec2 scale_mask = vec2(1.0,1.0);
uniform vec2 offset_mask = vec2(0.0,0.0);

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

group_uniforms blur;
uniform sampler2D curve_blur : filter_linear_mipmap;
uniform float blur_intensity : hint_range(0.0, 10.0) = 2.0;

//void vertex() {
    //// Overriding POSITION locks the vertices to screen space.
    //// This turns the mesh into a flat screen/UI element.
    //POSITION = vec4(VERTEX.xy, 0.0, 1.0);
//}

void fragment() {
    // We slide both textures down as the snow melts
    vec2 slide_uv = SCREEN_UV*scale_1 + offset_1;
    slide_uv.y -= melt_amount * 0.3;

	vec2 slide_uv_normal = SCREEN_UV*scale_normal + offset_normal;
	slide_uv_normal.y -= melt_amount * -0.03;

	float slush_maske = texture(slush_mask, SCREEN_UV*scale_mask + offset_mask).r;

    // 'base' determines WHERE the snow is.
    // 'norm' determines HOW the light/image bends.
	
    float snow_mask_val = texture(slush_base, slide_uv).r;
    vec3 normal_sample = texture(slush_normal, slide_uv_normal).rgb;

    // We erode the snow mask based on melt_amount
    float threshold = melt_amount;
    float slush_alpha = smoothstep(threshold, threshold + 0.1, snow_mask_val);


    // Normal maps store vectors in RGB. We convert [0.0, 1.0] to [-1.0, 1.0]
    vec2 normal_offset = (normal_sample.xy * 2.0) - 1.0;

    // We only want distortion at the "melting edge" (water), not in the solid white snow.
    // The water_edge defines that thin rim where ice turns to liquid.
    float water_edge = (1.0 - slush_alpha) * smoothstep(threshold - 0.15, threshold, snow_mask_val);

    // Apply distortion.. 2 actually..
    // - Strong distortion on the water edge
    // - Slight distortion on the solid snow (for icy look)
    vec2 distortion = normal_offset * refraction_strength;
    vec2 final_uv = SCREEN_UV + (distortion * water_edge) + (distortion * slush_alpha * 0.2);

    // Blur the solid snow areas, keep the water clear
    float blur = mix(0.0, blur_intensity*(1.0-melt_amount), slush_alpha);
    vec3 screen_col = textureLod(SCREEN_TEXTURE, final_uv, blur).rgb;

    // White/Blue Snow Color
    vec3 snow_color = vec3(0.9, 0.95, 1.0);

	float mix_factor = texture( curve_blur, vec2(melt_amount)).r;

    // Mix based on slush_alpha (Solid Snow)
    vec3 final_col = mix(screen_col, snow_color, slush_alpha * mix_factor  );

    // Global Cold Tint
    vec3 cold_tint = mix(vec3(1.0), vec3(0.85, 0.92, 1.1), blue_amount * smoothstep(0.9, 0.0, melt_amount) );
    final_col *= cold_tint;

    ALBEDO = final_col;
	ALPHA  =  enable_mask ? slush_maske : 1.0;

}