s[
  cell field >x
  cell field >y
]s vec2

: v2>s @+ swap @ ;
: v2+ [by2] + ;
: v2! tuck cell + ! ! ;
( x y v2* -- )
: v2+! dup >r v2>s v2+ r> v2! ;

s[
  vec2 field >pos
  vec2 field >vel
  vec2 field >acc
]s transform

: tr.move >r
  r@ >vel v2>s r@ >acc v2+!
  r@ >pos v2>s r> >vel v2+! ;

: collsions hitboxes hb-ct range do.u>
    dup colliding? if dup hb-mark then
  hitbox + loop then 2drop ;

: forces hitboxes hb-ct range do.u>
    dup hb-marked? if dup hb-apply then
  hitbox + loop then ;

: physics collisions forces ;

#vert shader"

#version 330 core

layout (location = 0) in vec2 vertex;
layout (location = 1) in vec2 uv;

out vec2 uv_coord;

void main() {
    vec2 flipped_uv = vec2(uv.x, 1 - uv.y);
    uv_coord = flipped_uv;
    gl_Position = vec4(vertex, 0.0, 1.0);
}

"

#frag shader"

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

"

2dup program pixels-shader !
shader-free
shader-free
