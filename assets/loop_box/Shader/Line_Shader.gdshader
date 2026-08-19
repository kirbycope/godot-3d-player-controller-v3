shader_type spatial;
render_mode unshaded,cull_disabled;

uniform sampler2D Shift_Power_Curve:repeat_disable;
uniform sampler2D Scale_Curve:repeat_disable;
uniform sampler2D Noise_Texture_X;
uniform sampler2D Noise_Texture_Y;
uniform vec2 Scroll_Speed = vec2(1.0, 1.0);
uniform float Power = 1.0;
uniform float Thickness = 1.0;

vec2 Get_Scrolled_UV(vec2 UV_, vec2 Scroll_Speed_) {
	return UV_ + Scroll_Speed_ * TIME;
}

void vertex() {
	float Sampled_Scale_Curve = texture(Scale_Curve, vec2(UV.y, 0.0)).r;
	VERTEX.xy *= Thickness * Sampled_Scale_Curve;

	float Sampled_Curve = texture(Shift_Power_Curve, vec2(UV.y, 0.0)).r;
	Sampled_Curve *= Power;

	vec2 Scroll_UV = Get_Scrolled_UV(vec2(0.5,UV.y), Scroll_Speed);
	float Sampled_Noise_X = texture(Noise_Texture_X, Scroll_UV).r;
	Sampled_Noise_X -= 0.5;
	float Sampled_Noise_Y = texture(Noise_Texture_Y, Scroll_UV).r;
	Sampled_Noise_Y -= 0.5;

	VERTEX.x += Sampled_Noise_X * Sampled_Curve;
	VERTEX.y += Sampled_Noise_Y * Sampled_Curve;
}
group_uniforms Fragment_Group;
uniform vec4 Color_Power:source_color = vec4(1.0);
uniform sampler2D Color_Noise_Texture:source_color;
uniform sampler2D Gradient_Texture:source_color;
uniform vec2 Color_Scroll = vec2(1.0, 1.0);

void fragment() {
	vec2 Color_Scroll_UV = Get_Scrolled_UV(UV, Color_Scroll);
	vec4 Sampled_Color_Noise = texture(Color_Noise_Texture, Color_Scroll_UV).rgba;
	vec4 Sampled_Gradient = texture(Gradient_Texture, vec2(UV.y, 0.0)).rgba;

	ALBEDO = Sampled_Color_Noise.rgb * Color_Power.rgb * Sampled_Gradient.rgb;
	ALPHA = Sampled_Color_Noise.a * Sampled_Gradient.a;
}