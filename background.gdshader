shader_type canvas_item;

// Ça crée un slider dans l'inspecteur pour régler le flou !
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	// On dit à Godot d'utiliser les Mipmaps pour créer un flou parfait
	COLOR = textureLod(TEXTURE, UV, blur_amount);
}