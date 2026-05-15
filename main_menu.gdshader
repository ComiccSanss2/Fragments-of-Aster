shader_type canvas_item;

// Per Godot 4: leggiamo direttamente lo schermo dietro al ColorRect
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Parametri che puoi modificare in tempo reale dall'Inspector
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.05;
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 1.5;
uniform float glitch_intensity : hint_range(0.0, 0.1) = 0.002;
uniform float time_speed : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    float time = TIME * time_speed;

    float glitch_offset = sin(uv.y * 100.0 + time * 10.0) * glitch_intensity;
    glitch_offset += (fract(sin(dot(uv.xy + time, vec2(12.9898,78.233))) * 43758.5453) - 0.5) * (glitch_intensity * 2.0);
    uv.x += glitch_offset;

    float shift = chromatic_aberration / 1000.0;
    float r = texture(screen_texture, uv + vec2(shift, 0.0)).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - vec2(shift, 0.0)).b;
    
    vec3 color = vec3(r, g, b);

    float scanline = sin(uv.y * 800.0) * scanline_intensity;
    color -= scanline;

    float dist = distance(uv, vec2(0.5, 0.5));
    color *= smoothstep(1.5, 0.3, dist * 1.1);

    COLOR = vec4(color, 1.0);
}