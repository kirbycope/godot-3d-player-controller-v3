shader_type spatial;
render_mode depth_test_disabled, unshaded, cull_back;

// --- UNIFORMS ---
uniform bool attach_to_camera = true;
uniform float color_intensity = 1.0;
uniform bool multiply_or_subtract = false;

// Distortion
uniform bool enable_tex_distortion = false;
uniform vec2 distortion_speed;
uniform vec2 distortion_scale = vec2(1.0, 1.0);
uniform sampler2D distortion_texture : source_color, repeat_enable;
uniform float distortion_intensity = 0.03;

// Main Noise
uniform vec2 speed;
uniform vec2 scale = vec2(1.0, 1.0);
uniform sampler2D texture_noise : source_color, repeat_enable;

// Masks and Color Mapping
uniform sampler2D mask : source_color, repeat_disable;
uniform sampler2D add_texture : source_color, hint_default_black, repeat_disable;
uniform sampler2D gradient_color_1d : source_color, repeat_disable;

//void vertex() {
    //// Overriding POSITION locks the vertices to screen space.
    //// This turns the mesh into a flat screen/UI element.
    //POSITION = vec4(VERTEX.xy, 0.0, 1.0);
//}

void fragment() {
    // 1. Calculate Distortion (if enabled)
    float distortion_offset = 0.0;
    if (enable_tex_distortion) {
        vec2 dist_uv = (UV + TIME * distortion_speed) * distortion_scale;
        float dist_noise = texture(distortion_texture, dist_uv).r;
        distortion_offset = dist_noise * distortion_intensity;
    }

    // 2. Base UV with distortion applied
    vec2 base_uv = UV + vec2(distortion_offset);

    // 3. Calculate Main Noise using the distorted UV
    vec2 noise_uv = (base_uv + TIME * speed) * scale;
    float noise_val = texture(texture_noise, noise_uv).r;

    // 4. Sample the Mask Texture
    vec4 mask_tex = texture(mask, UV);
    float mask_r = mask_tex.r;
    float mask_g = mask_tex.g;

    // 5. Apply Blend Mode (Multiply vs. Subtract)
    float blended_val;
    if (multiply_or_subtract) {
        blended_val = noise_val * mask_r;
    } else {
        blended_val = noise_val - mask_g;
    }

    // 6. Add Secondary Texture
    float add_val = texture(add_texture, UV).r;
    float final_val = blended_val + add_val;

    // 7. Map to Gradient
    // We use a vec2 where the X axis is our calculated value to sample the 1D gradient
    vec4 gradient_color = texture(gradient_color_1d, vec2(final_val, 0.0));

    // 8. Final Output
    ALBEDO = gradient_color.rgb * color_intensity;
    ALPHA = gradient_color.a;
}