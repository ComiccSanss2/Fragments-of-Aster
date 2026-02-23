shader_type canvas_item;

uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.2235, 1.0);
// Progression : 0.0 = Écran transparent, 1.0 = Écran tout noir
uniform float cutoff : hint_range(0.0, 1.0) = 0.0;
// Douceur du bord (0.0 = Net et pixelisé, 0.5 = Très flou)
uniform float smooth_size : hint_range(0.0, 1.0) = 0.05;
// Le ratio de l'écran (largeur / hauteur)
uniform float aspect_ratio = 1.777; 
// Le centre du cercle
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 adjusted_uv = UV - center;
	adjusted_uv.x *= aspect_ratio;
	
	float dist = length(adjusted_uv);
	
	// L'ASTUCE EST ICI : 
	// On calcule la taille normale, et on soustrait un peu plus à la fin pour fermer le trou à 100%
	float hole_size = (1.0 - cutoff) * 1.5;
	hole_size -= cutoff * (smooth_size + 0.01); 
	
	float alpha = smoothstep(hole_size, hole_size + smooth_size + 0.001, dist);
	
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}