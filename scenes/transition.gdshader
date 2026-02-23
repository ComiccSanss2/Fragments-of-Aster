shader_type canvas_item;

// La progression de la transition : 0.0 -> 1.0
uniform float cutoff : hint_range(0.0, 1.0) = 0.0;

// La douceur des bords
uniform float smooth_size : hint_range(0.0, 1.0) = 0.15;

// La couleur bleu foncé
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.2235, 1.0);

// "false" pour fermer l'écran, "true" pour l'ouvrir
uniform bool is_opening = false;

void fragment() {
	// PLUS BESOIN DE MASQUE ! On utilise la position X de l'écran (UV.x)
	// On décale un peu pour que le flou soit totalement invisible quand cutoff = 0 ou 1
	float sweep = cutoff * (1.0 + smooth_size) - smooth_size;
	
	// Calcul du balayage
	float step_val = smoothstep(sweep, sweep + smooth_size + 0.001, UV.x);
	
	float final_alpha;
	
	if (is_opening) {
		// En ouverture, on laisse la couleur derrière le balayage
		final_alpha = step_val;
	} else {
		// En fermeture, on met la couleur devant le balayage
		final_alpha = 1.0 - step_val;
	}
	
	COLOR = vec4(transition_color.rgb, final_alpha);
}