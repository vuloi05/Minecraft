shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_nearest;
uniform bool use_alpha_scissor = true;

varying vec4 uv_bounds;
varying vec2 local_uv;
varying vec4 v_color;

void vertex() {
    uv_bounds = CUSTOM0;
    local_uv = UV;
    v_color = COLOR;
}

void fragment() {
    vec2 frac_uv = fract(local_uv);
    
    // Ánh xạ UV cục bộ (0.0 -> 1.0) vào giới hạn của texture trên Atlas
    vec2 final_uv = vec2(
        mix(uv_bounds.x, uv_bounds.z, frac_uv.x),
        mix(uv_bounds.y, uv_bounds.w, frac_uv.y)
    );
    
    vec4 tex = texture(atlas, final_uv);
    ALBEDO = tex.rgb * v_color.rgb;
    ALPHA = tex.a * v_color.a;
    if (use_alpha_scissor) {
        ALPHA_SCISSOR_THRESHOLD = 0.5;
    }
}
