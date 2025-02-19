#version 330 core

layout (location = 0) in vec2 vertex;
layout (location = 1) in vec2 uv;
layout (location = 2) in uint character;
layout (location = 3) in uint attributes;

const uint buffer_width = 80u;
const uint buffer_height = 40u;
const uint character_width = 8u;
const uint character_height = 10u;
const uint spritesheet_width = 16u * character_width;
const uint spritesheet_height = 16u * character_height;

uniform mat3 screen;

out vec2 uv_coord;
flat out uint use_reverse;
flat out uint use_bold;
flat out uint palette_idx;
flat out vec2 uv_pixel_size;

void main() {
    use_reverse = attributes & 0x10u;
    use_bold = attributes & 0x08u;
    palette_idx = attributes & 0x07u;

    uv_pixel_size.x = 1.0 / float(spritesheet_width);
    uv_pixel_size.y = 1.0 / float(spritesheet_height);

    // TODO move uv by characterw/h
    vec2 flipped_uv = vec2(uv.x, 1 - uv.y);
    uv_coord = flipped_uv;

    uint id = uint(gl_InstanceID);

    uint x = (id % buffer_width) * character_width;
    uint y = (id / buffer_width) * character_height;
    vec2 displace = vec2(x, y);

    vec3 pos = screen * vec3(vertex + displace, 0.0);

    gl_Position = vec4(pos, 1.0);
}
