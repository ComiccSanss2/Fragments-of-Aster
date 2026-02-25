shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.1) = 0.03;
uniform float speed = 8.0;
uniform float radius = 0.35; // Taille du cercle vide au centre
uniform float thickness = 0.15; // Épaisseur de la zone déformée

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    // Création du masque en forme d'anneau
    // Le centre (Lyra) et les bords lointains ne seront pas touchés
    float inner_edge = smoothstep(radius - thickness, radius, dist);
    float outer_edge = smoothstep(radius + thickness, radius, dist);
    float mask = inner_edge * outer_edge;
    
    vec2 offset = normalize(UV - center) * sin(dist * 30.0 - TIME * speed) * strength * mask;
    
    COLOR = texture(SCREEN_TEXTURE, SCREEN_UV + offset);
}