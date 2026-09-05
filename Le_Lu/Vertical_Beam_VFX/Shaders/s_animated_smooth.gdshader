shader_type spatial;
render_mode blend_mix, unshaded, cull_back;

uniform sampler2D sprite_sheet;
uniform vec2 frame_count = vec2(4.0, 3.0); // Columns, Rows
uniform float transition_speed = 0.5; // Controls how fast the transition happens (0-1)
uniform float time_scale = 1.0; // Global animation speed control
uniform vec4 color_base : source_color;

varying float transparency; // Global animation speed control
varying vec2 anim_UV;
varying vec2 next_anim_UV;
varying float blend_factor;

void vertex() {
    // Calculate current and next frame indices
    float last_cell = (frame_count.x * frame_count.y) - 1.0;
    float frame_progress = fract(COLOR.a * time_scale);
    float frame_index = floor(COLOR.a * time_scale * last_cell);
    float next_frame_index = min(frame_index + 1.0, last_cell);
    
    // Calculate frame offsets
    vec2 frame_size = vec2(1.0) / frame_count;
    
    // Current frame offset
    vec2 frame_offset = vec2(
        mod(frame_index, frame_count.x) / frame_count.x,
        floor(frame_index / frame_count.x) / frame_count.y
    );
    
    // Next frame offset
    vec2 next_frame_offset = vec2(
        mod(next_frame_index, frame_count.x) / frame_count.x,
        floor(next_frame_index / frame_count.x) / frame_count.y
    );
    
    // Apply texture scaling
    anim_UV = (UV * frame_size + frame_offset);
    next_anim_UV = (UV * frame_size + next_frame_offset);
    
    // Calculate blend factor based on progress between frames
    blend_factor = smoothstep(0.0, transition_speed, frame_progress);
}

void fragment() {
    // Sample both current and next frame
    vec4 current_tex = texture(sprite_sheet, anim_UV);
    vec4 next_tex = texture(sprite_sheet, next_anim_UV);
    
    // Blend between frames
    vec4 tex = mix(current_tex, next_tex, blend_factor);
    
	transparency = COLOR.r;
	
    ALBEDO = tex.rgb * color_base.rgb;
    ALPHA = tex.a * transparency;
}
