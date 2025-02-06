#version 330 core

layout (location = 0) in vec2 vertex;
layout (location = 1) in vec2 uv;

uniform mat3 screen;

out vec2 uv_coord;

void main() {
    uv_coord = uv;
    gl_Position = screen * vec3(vertex, 1.0);
}
