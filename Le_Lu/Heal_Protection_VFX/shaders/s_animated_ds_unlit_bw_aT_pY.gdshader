shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D sprite_sheet;
uniform sampler2D gradient_1d_texture:repeat_disable;
uniform vec2 frame_count = vec2(4.0, 3.0); // Columns, Rows
uniform bool is_loop = false;
uniform vec2 uv_offset = vec2(0.0);
uniform float alpha_scissor_treshold :hint_range(0.0, 1.0, 0.01) = 0.3;
varying vec2 anim_UV;

void vertex() {
    // Calculate frame offset (your original method)
    float last_cell = (frame_count.x * frame_count.y) - 1.0;
	
	float timex = COLOR.a;
	if (is_loop){ timex = TIME;}
    float frame_index = floor(timex * last_cell);
    vec2 frame_offset = vec2(
        mod(frame_index, frame_count.x) / frame_count.x,
        floor(frame_index / frame_count.x) / frame_count.y
    );

    // Apply texture scaling
    vec2 frame_size = vec2(1.0) / frame_count;
    anim_UV = (UV * frame_size + frame_offset);
	
		mat4 n_out2p0;
// GetBillboardMatrix:2
	{
		mat4 __mvm = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
		__mvm = __mvm * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		n_out2p0 = __mvm;
	}


// Output:0
	MODELVIEW_MATRIX = n_out2p0;
	
	
	
	
}

void fragment() {
	
    float img = texture(sprite_sheet, anim_UV+ uv_offset ).r;
	vec4 tex = texture(gradient_1d_texture,vec2(img));
    ALBEDO = tex.rgb * COLOR.rgb;
	
	float alphad = alpha_scissor_treshold;
	if (is_loop){alphad=alphad*COLOR.a;}
    ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD =  alphad;
}
