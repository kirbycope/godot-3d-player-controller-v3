shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform sampler2D texture_mask;

uniform vec2 Texture_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Disolver_Texture : source_color;

void fragment() {

	vec2 disolv_offset = (UV) * Texture_Scale;

	float erosion = texture(Disolver_Texture, disolv_offset).r;

    vec4 tex = texture(texture_mask, UV);

    ALBEDO = COLOR.rgb;
	ALPHA = erosion * tex.r;
	ALPHA_SCISSOR_THRESHOLD = COLOR.a;
}