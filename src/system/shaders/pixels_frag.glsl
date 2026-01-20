#version 330 core

uniform usampler2D tex;

uniform vec3 palette[16];

in vec2 uv_coord;

out vec4 out_color;

void main() {
    uint color_idx = texture(tex, uv_coord).r;
    vec3 color = palette[color_idx];
    out_color = vec4(color, 1);
}
