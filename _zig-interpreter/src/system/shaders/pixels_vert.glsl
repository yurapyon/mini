#version 330 core

layout (location = 0) in vec2 vertex;
layout (location = 1) in vec2 uv;

out vec2 uv_coord;

void main() {
    vec2 flipped_uv = vec2(uv.x, 1 - uv.y);
    uv_coord = flipped_uv;
    gl_Position = vec4(vertex, 0.0, 1.0);
}
