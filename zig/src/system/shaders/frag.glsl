#version 330 core

uniform sampler2D diffuse;

in vec2 uv_coord;

out vec4 out_color;

void main() {
    out_color = texture(diffuse, uv_coord);
    // out_color = vec4(uv_coord, 0, 0);
}
