shader_type spatial;
render_mode depth_test_disabled, unshaded;

uniform sampler2D screenTex: hint_screen_texture, filter_linear;
uniform float frequency    : hint_range(-10.0, 4.0, 0.1) = 0.0;
uniform float size         : hint_range(0.001, 0.05, 0.001) = 0.015;
uniform float refraction_strength : hint_range(0.0, 0.1, 0.001) = 0.02; // Controls the bending
uniform float speed : hint_range(0.0, 1.0, 0.01) = 0.15; // Controls how fast they slide down

// Hi, I'm LeLu and..
// This is a new fork-modification based on Élie Michel shader
// you can find her version on https://www.shadertoy.com/view/MlfBWr (License: CC BY 3.0)
// I've modified it quite a lot.. so its SCREEN camera-based, drops can move, and the drops are now based on SCREEN_UV

// Very usefull functionss (thanks Élie)
vec2 rand(vec2 c){
    mat2 m = mat2(vec2(12.9898,0.16180),vec2(78.233,0.31415));
    return fract(sin(m * c) * vec2(43758.5453, 14142.1));
}

vec2 noise(vec2 p){
    vec2 co = floor(p);
    vec2 mu = fract(p);
    mu = 3.0*mu*mu-2.0*mu*mu*mu;
    vec2 a = rand((co+vec2(0.0,0.0)));
    vec2 b = rand((co+vec2(1.0,0.0)));
    vec2 c = rand((co+vec2(0.0,1.0)));
    vec2 d = rand((co+vec2(1.0,1.0)));
    return mix(mix(a, b, mu.x), mix(c, d, mu.x), mu.y);
}
//
//void vertex() {
    //// Overriding POSITION locks the vertices to screen space.
    //// This turns the mesh into a flat screen/UI element.
    //POSITION = vec4(-VERTEX.xy, 0.0, 1.0);
//}

void fragment()
{
    vec2 iResolution = VIEWPORT_SIZE;
    vec2 u = SCREEN_UV;

    vec2 noise_uv = SCREEN_UV * 0.1;
    vec2 n = noise(noise_uv * 200.0);

    // Instead lets start with the un-distorted screen, SCREEN_UV not UV..
    vec4 fragColor = texture(screenTex, SCREEN_UV);

    // Loop through the different inverse sizes of drops
    for (float r = 4.0 ; r > frequency ; r--) {

        // Here we do the sliding...
        // We create a specific UV for the drop positions and push it upwards over time
        // (Pushing coordinates up makes the drawn pixels move down)
        vec2 drop_uv = u;
        drop_uv.y -= TIME * speed * (5.0 - r) * 0.2; // Multiplying by (5.0 - r) adds a parallax effect

        vec2 x = iResolution.xy * r * size;
        vec2 p = 6.28 * drop_uv * x + (n - 0.5) * 2.0;
        vec2 s = sin(p);

        // Current drop properties
        vec2 grid_uv = round(drop_uv * x - 0.25) / x;
        vec4 d = vec4(noise(grid_uv * 200.0), noise(grid_uv));

        // Drop shape and fading
        float t = (s.x+s.y) * max(0.0, 1.0 - fract(TIME * (d.b + 0.1) + d.g) * 2.0);

        // d.r -> only x% of drops are kept on (thanks Élie)
        if (d.r < (5.0 - r) * 0.08 && t > 0.5) {

            // Calculate drop normal
            vec3 drop_normal = normalize(-vec3(cos(p), mix(0.2, 2.0, t - 0.5)));

            // Refract the background behind the drop using SCREEN_UV
            fragColor = textureLod(screenTex, SCREEN_UV - drop_normal.xy * refraction_strength, 0.0);
        }
    }

    ALBEDO = fragColor.rgb ;
}