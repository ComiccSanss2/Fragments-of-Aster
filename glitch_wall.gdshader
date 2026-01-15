shader_type canvas_item;

uniform float shake_power : hint_range(0.0, 0.5) = 0.03;
uniform float scanline_count : hint_range(0.0, 100.0) = 50.0;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    
    // 1. Distorsion horizontale (Effet "Vague de glitch")
    float wave = sin(uv.y * 20.0 + TIME * 10.0) * shake_power;
    uv.x += wave * random(vec2(TIME, uv.y));
    
    // 2. Création de bruit (Grain télé)
    float noise = random(uv + vec2(TIME * 10.0, 0.0));
    
    // 3. Scanlines (Lignes horizontales sombres)
    float scanline = sin(uv.y * scanline_count * 3.14 + TIME * 5.0);
    scanline = smoothstep(0.4, 0.5, scanline);
    
    // 4. Couleur de base (Rouge Sang / Noir Glitché)
    vec4 color = vec4(0.0);
    
    // Si le bruit est fort, on met du rouge brillant, sinon du noir/gris
    if (noise > 0.8) {
        color = vec4(0.6, 0.0, 0.0, 1.0); // Rouge glitch
    } else if (noise < 0.2) {
         color = vec4(0.1, 0.0, 0.0, 0.8); // Rouge très sombre transparent
    } else {
        color = vec4(0, 0.0, 0.0, 0.9); // Noir quasi opaque
    }
    
    // Application de la distorsion sur les bords
    if (uv.x < 0.0 || uv.x > 1.0) {
        color.a = 0.0;
    }
    
    COLOR = color;
}