shader_type canvas_item;

// Cattura il mondo (Layer 1), escludendo il giocatore (Layer 2)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// PARAMETRI AGGRESSIVI - Valori di default pompati
uniform float glitch_intensity : hint_range(0.0, 0.5) = 1; // Strappo orizzontale MOLTO forte
uniform float vertical_jitter_force : hint_range(0.0, 0.5) = 1; // Salti verticali dell'immagine
uniform float rgb_split_intensity : hint_range(0.0, 0.2) = 1; // Separazione colori violentissima
uniform float speed : hint_range(0.0, 100.0) = 40.0; // Frequenza isterica

// Funzione matematica per generare rumore semi-casuale
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    float time_step = floor(TIME * speed);
    
    // 1. Jitter Verticale (Salta su e giù istericamente)
    float vj_noise = random(vec2(time_step, 12.0));
    if (vj_noise > 0.6) {
        uv.y += (vj_noise - 0.5) * vertical_jitter_force;
    }

    // 2. Tearing Orizzontale Violento (Tutto lo schermo si strappa in blocchi)
    // Usiamo blocchi più grandi e instabili
    float block_noise = random(vec2(floor(uv.y * 8.0), time_step));
    float offset = (block_noise - 0.5) * glitch_intensity;
    
    // Lo strappo è costante e aggressivo
    uv.x += offset;

    // 3. Aberrazione Cromatica Estrema (RGB Split)
    // Facciamo oscillare la separazione per renderla instabile
    float split_wobble = sin(TIME * speed * 0.5) * 0.5 + 0.5;
    float current_split = rgb_split_intensity * split_wobble;
    
    // Separiamo i canali (Cyan e Rosso si staccano violentemente sullo sfondo rosso)
    float r = texture(screen_texture, vec2(uv.x + current_split, uv.y)).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, vec2(uv.x - current_split, uv.y)).b;

    // Output finale sul ColorRect
    COLOR = vec4(r, g, b, 1.0);
}