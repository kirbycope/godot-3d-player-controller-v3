shader_type spatial;

render_mode unshaded, cull_back,depth_test_disabled; 

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float shake_power = 0.03;                       
uniform float shake_rate : hint_range(0.0, 1.0) = 0.2;  
uniform float shake_speed = 5.0;                        
uniform float shake_block_size = 30.5;                  
uniform float shake_color_rate : hint_range(0.0, 1.0) = 0.01; 


float random(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453123);
}

//void vertex() {
    //POSITION = vec4(VERTEX.xy, 0.0, 1.0);
//}

void fragment() {

    vec2 uv = SCREEN_UV;
    
    // Determine if we should glitch this frame based on shake_rate and TIME
    float enable_shift = float(random(trunc(TIME * shake_speed)) < shake_rate);
    
    // Create the blocky displacement
    vec2 fixed_uv = uv;
    fixed_uv.x += (random((trunc(uv.y * shake_block_size) / shake_block_size) + TIME) - 0.5) * shake_power * enable_shift;

    // Sample the screen texture with the distorted UVs
    vec3 pixel_color = texture(screen_texture, fixed_uv).rgb;
    
    // Apply Chromatic Aberration (RGB split)
    pixel_color.r = texture(screen_texture, fixed_uv + vec2(shake_color_rate * enable_shift, 0.0)).r;
    pixel_color.b = texture(screen_texture, fixed_uv + vec2(-shake_color_rate * enable_shift, 0.0)).b;

    ALBEDO = pixel_color;
}