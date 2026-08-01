shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
stencil_mode write, compare_always, 1;

void fragment() {
    // Keep it invisible so it doesn't draw color, just stencil
    ALPHA = 0.0;
}

