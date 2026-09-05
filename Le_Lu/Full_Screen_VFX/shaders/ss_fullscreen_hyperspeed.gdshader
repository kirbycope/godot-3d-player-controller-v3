shader_type spatial;
render_mode cull_back, depth_test_disabled, unshaded;

// Lines-Textures color uniforms
uniform float ColorIntensity = 1.0;
uniform vec2 Speed;
uniform vec2 Scale = vec2(1.0, 1.0);

uniform sampler2D Texture_Noise : source_color, repeat_enable;
uniform sampler2D Mask : source_color, repeat_disable;
uniform sampler2D Gradient_Color1D : source_color, repeat_disable;

// Radial Blur uniforms.. 
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float blur_falloff : hint_range(0.0, 1.0) = 0.5;
uniform int blur_samples : hint_range(0, 64) = 16;
uniform vec2 blur_center = vec2(0.5, 0.5);


vec2 get_polar_coords(vec2 uv) {
    vec2 dir = uv - vec2(0.5);
    float radius = length(dir) * 2.0;
    float angle = atan(dir.y, dir.x) / (PI * 2.0);
    return vec2(radius, angle);
}

vec3 get_radial_blur(vec2 screen_uv, sampler2D screen_tex) {
    // Take cheap screen cap.. duplicate a bunch of times.. and offset
    vec2 dir = screen_uv - clamp(blur_center, vec2(0.0), vec2(1.0));
    float dist = length(dir) * 2.0;
    float fall = pow(min(dist, 1.0), 3.0 * blur_falloff);
    float step_scale = blur_intensity / float(blur_samples) * 0.05;

    // Lets start with the unblurred screen pixel
    vec3 color = texture(screen_tex, screen_uv).rgb;

    // Loop to sample surrounding pixels based on direction..
    for (int i = 1; i <= blur_samples; i++) {
        float offset = float(i) * step_scale * fall;
        color += texture(screen_tex, screen_uv - dir * offset).rgb;
    }

    color /= float(blur_samples + 1);
    return color;
}

//
//void vertex() {
    //POSITION = vec4(VERTEX.xy, 0.0, 1.0);
//}

void fragment() {
    // Calculate VFX Noise Color stuff
    vec2 polar_uv = get_polar_coords(SCREEN_UV);
    vec2 scrolled_uv = polar_uv + (Speed * TIME);
    vec2 scaled_uv = scrolled_uv * Scale;
    
    float noise = texture(Texture_Noise, scaled_uv).r;
    vec4 mask_color = texture(Mask, SCREEN_UV);
    
    float multiplied = noise * mask_color.r;
    vec4 vfx_color = texture(Gradient_Color1D, vec2(multiplied));
    vfx_color.rgb *= ColorIntensity;
    
    // Calculate Background Blur
    vec3 blurred_bg = get_radial_blur(SCREEN_UV, screen_texture);
    
    // Combine Blur with lines
    ALBEDO = mix(blurred_bg, vfx_color.rgb, vfx_color.a);
    
    // Lets use the Mask for the final alpha so the quad fades out smoothly at the edges,
    // rather than rendering a hard, blocky square of blur on the friking screen.
    ALPHA = mask_color.r; 
}