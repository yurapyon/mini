#version 330 core

uniform sampler2D diffuse;

in vec2 uv_coord;

out vec4 out_color;

void main() {
    out_color = texture2D(diffuse, uv_coord);
}
