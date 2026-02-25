shader_type canvas_item;

// La progression de la transition : 0.0 -> 1.0
uniform float cutoff : hint_range(0.0, 1.0) = 0.0;

// La douceur des bords (tu peux le mettre à 0.0 si tu veux des lignes ultra nettes)
uniform float smooth_size : hint_range(0.0, 1.0) = 0.15;

// La couleur bleu foncé
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.2235, 1.0);

// "false" pour fermer l'écran, "true" pour l'ouvrir
uniform bool is_opening = false;

// --- NOUVEAU : Réglage des bandes ---
// Le nombre de lignes horizontales (mets un nombre pair de préférence)
uniform float num_lines = 10.0;

void fragment() {
	// 1. On détermine dans quelle ligne on se trouve (0, 1, 2, 3...)
	float band_index = floor(UV.y * num_lines);

	// 2. On regarde si la ligne est paire (0.0) ou impaire (1.0)
	float is_odd = mod(band_index, 2.0);

	// 3. LA MAGIE : On alterne la direction
	// Si paire (is_odd == 0) -> on lit normalement de gauche à droite (UV.x)
	// Si impaire (is_odd == 1) -> on lit à l'envers de droite à gauche (1.0 - UV.x)
	float x_coord = mix(UV.x, 1.0 - UV.x, is_odd);

	// On décale un peu pour que le flou soit totalement invisible quand cutoff = 0 ou 1
	float sweep = cutoff * (1.0 + smooth_size) - smooth_size;

	// Calcul du balayage (on utilise notre nouveau x_coord alterné !)
	float step_val = smoothstep(sweep, sweep + smooth_size + 0.001, x_coord);

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