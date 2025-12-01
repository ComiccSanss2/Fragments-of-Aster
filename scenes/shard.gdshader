shader_type canvas_item;

uniform float strength : hint_range(0.0, 0.2);
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = UV;
	vec2 dir = uv - center;
	float dist = length(dir);

	// ondulation subtile
	uv += dir * strength * sin(dist * 25.0);

	COLOR = texture(TEXTURE, uv);
}
