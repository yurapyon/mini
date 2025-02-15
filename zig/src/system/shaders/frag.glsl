#version 330 core

uniform sampler2D diffuse;

uniform vec3 palette[16];
uniform vec3 character_palette[8];

in vec2 uv_coord;

out vec4 out_color;

void main() {
    out_color = texture(diffuse, uv_coord);
}
