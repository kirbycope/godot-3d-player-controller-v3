shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float Screen_distortioness = 0.1;
uniform vec2 Speed = vec2(0.1, 0.1); 
uniform vec2 Scale = vec2(1.0, 1.0);

uniform sampler2D Texture_Noise : source_color, repeat_enable;
uniform sampler2D Mask : source_color, repeat_disable;
uniform sampler2D Add_Texture : source_color, hint_default_black, repeat_disable;
uniform sampler2D Gradient_Color1D : source_color, repeat_disable;

uniform sampler2D SCREENTEX : source_color, hint_screen_texture;

uniform float DistortionPower = 1.0;
uniform float ColorIntensity = 1.0;
uniform float Mask_power = 1.0;

void fragment() {

    vec2 noise_uv = (UV * Scale) + (TIME * Speed);
    float noise_val = texture(Texture_Noise, noise_uv).r;


    float mask_val = texture(Mask, SCREEN_UV).r;
    float distortion_mask = pow(mask_val, DistortionPower);
    
    vec2 distortion_offset = (vec2(noise_val) - 0.5) * Screen_distortioness * distortion_mask;
    
    vec2 distorted_screen_uv = SCREEN_UV + distortion_offset;
    vec3 screen_color = texture(SCREENTEX, distorted_screen_uv).rgb;

    float color_mask = pow(mask_val, Mask_power);
    float add_tex_val = texture(Add_Texture, SCREEN_UV).r;
    float final_frost_val = (noise_val * color_mask) + add_tex_val;

    vec4 gradient_color = texture(Gradient_Color1D, vec2(final_frost_val));
    vec3 final_tint = gradient_color.rgb * ColorIntensity;

    vec3 blended_color = screen_color * final_tint;
    COLOR.rgb = mix(blended_color, final_tint, gradient_color.a);
}