#version 330 core

uniform usampler2D diffuse;

uniform vec3 palette[16];
uniform vec3 character_palette[8];

in vec2 uv_coord;

out vec4 out_color;

void main() {
    uint x = texture(diffuse, uv_coord).r;
    out_color = vec4(float(x) / 255.0, 1, 1, 1);
}
