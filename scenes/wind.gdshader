shader_type canvas_item;

// La vitesse et la direction du vent (négatif = vers la gauche)
uniform float speed = 0.08;
// La force de la déformation
uniform float strength = 0.01;
// La texture de bruit qui va créer les vagues
uniform sampler2D noise_texture : repeat_enable;

void fragment() {
    // On calcule un décalage basé sur le temps et la vitesse
    vec2 shifting_uv = UV;
    shifting_uv.x += TIME * speed;

    // On lit la texture de bruit à cette position décalée
    float noise_value = texture(noise_texture, shifting_uv).r;

    // On déforme l'image finale en utilisant la valeur du bruit
    vec2 distorted_uv = UV;
    // On décale les pixels horizontalement (x) et un peu verticalement (y)
    distorted_uv.x -= noise_value * strength;
    distorted_uv.y += noise_value * strength * 0.2;

    // On applique la couleur de base du ColorRect à la position déformée
    COLOR = texture(TEXTURE, distorted_uv);
    // Optionnel : rendre les zones "vides" du bruit transparentes pour un effet plus subtil
    COLOR.a *= noise_value * 0.3; // Ajuste le 2.0 pour plus ou moins de visibilité
}