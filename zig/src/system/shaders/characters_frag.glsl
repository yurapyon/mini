#version 330 core

uniform usampler2D tex;

uniform vec3 palette[8];

in vec2 uv_coord;
flat in uint use_reverse;
flat in uint use_bold;
flat in uint palette_idx;
flat in vec2 uv_pixel_size;

out vec4 out_color;

void main() {
    bool bool_reverse = use_reverse != 0u;
    bool bool_bold = use_bold != 0u;

    vec3 color = palette[palette_idx];
    bool is_set = texture(tex, uv_coord).r != 0u;

    if (bool_bold) {
        vec2 previous_pixel_uv =
            vec2(uv_coord.x - uv_pixel_size.x, uv_coord.y);
        uint previous_pixel = texture(tex, previous_pixel_uv).r;
        is_set = is_set || previous_pixel != 0u;
    }

    if (bool_reverse) {
        is_set = !is_set;
    }

    out_color = vec4(color, is_set ? 1 : 0);
}
