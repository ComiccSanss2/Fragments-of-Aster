shader_type canvas_item;

// La progression de la transition : 0.0 = Transparent, 1.0 = Tout Noir
uniform float cutoff : hint_range(0.0, 1.0) = 0.0;

// La douceur des bords (0.0 = Pixel Art dur, 0.5 = Flou)
uniform float smooth_size : hint_range(0.0, 1.0) = 0.0;

// La texture qui définit la forme (Noir et Blanc)
uniform sampler2D mask : source_color;

void fragment() {
	// On lit la valeur de la texture de masque (entre 0 et 1)
	float value = texture(mask, UV).r;
	
	// Si 'value' est plus petit que 'cutoff', on affiche le noir.
	// smoothstep permet de gérer la douceur des bords.
	float alpha = smoothstep(cutoff, cutoff + smooth_size, value * (1.0 - smooth_size) + smooth_size);
	
	// On inverse : on veut que ce soit NOIR quand le cutoff augmente
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - alpha);
}