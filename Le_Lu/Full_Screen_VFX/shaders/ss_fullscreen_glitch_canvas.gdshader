shader_type canvas_item;


uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float shake_power = 0.03;                       // How far the screen tears
uniform float shake_rate : hint_range(0.0, 1.0) = 0.2;  // How frequently it glitches
uniform float shake_speed = 5.0;                        // How fast the glitch changes
uniform float shake_block_size = 30.5;                  // Size of the horizontal glitch chunks
uniform float shake_color_rate : hint_range(0.0, 1.0) = 0.01; // How far the RGB channels separate


float random(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    

    float enable_shift = float(random(trunc(TIME * shake_speed)) < shake_rate);
    

    vec2 fixed_uv = uv;
    fixed_uv.x += (random((trunc(uv.y * shake_block_size) / shake_block_size) + TIME) - 0.5) * shake_power * enable_shift;


    vec4 pixel_color = texture(screen_texture, fixed_uv);
    

    pixel_color.r = texture(screen_texture, fixed_uv + vec2(shake_color_rate * enable_shift, 0.0)).r;
    pixel_color.b = texture(screen_texture, fixed_uv + vec2(-shake_color_rate * enable_shift, 0.0)).b;


    COLOR = pixel_color;
}