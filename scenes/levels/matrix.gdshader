shader_type canvas_item;

// --- PARTE MISTICA (Colori e Flusso) ---
uniform vec4 mystic_color_1 : source_color = vec4(0.4, 0.1, 0.8, 1.0); // Viola profondo
uniform vec4 mystic_color_2 : source_color = vec4(0.1, 0.8, 0.7, 1.0); // Turchese luminoso
uniform float flow_speed : hint_range(0.1, 2.0) = 0.5;
// Usa una FastNoiseLite texture qui, seamless, per il flusso principale
uniform sampler2D flow_noise_tex : repeat_enable;

// --- PARTE GLITCH (Distorsione e Scatti) ---
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float glitch_speed : hint_range(1.0, 20.0) = 10.0;
uniform float block_size : hint_range(5.0, 50.0) = 20.0; // Quanto sono grandi i blocchi corrotti

// Funzione random semplice per i glitch scattosi
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    
    // --- 1. CALCOLO DEL GLITCH ---
    // Creiamo un "tempo a scatti" per far sembrare il glitch digitale
    float jerky_time = floor(TIME * glitch_speed);
    
    // Creiamo blocchi pixelati usando floor(uv * size) / size
    vec2 block_uv = floor(uv * block_size) / block_size;
    
    // Generiamo un valore di distorsione casuale per ogni blocco, che cambia a scatti nel tempo
    float glitch_noise = random(block_uv + jerky_time);
    
    // Decidiamo SE glitchare in questo momento (se il rumore supera una soglia)
    float is_glitching = step(1.0 - glitch_intensity, glitch_noise);
    
    // Calcoliamo l'offset di distorsione orizzontale
    float glitch_offset_x = (glitch_noise - 0.5) * 2.0 * is_glitching * 0.1;

    
    // --- 2. ABERRAZIONE CROMATICA (RGB Split) ---
    // Quando glitcha, separiamo i canali Rosso, Verde e Blu
    vec2 uv_r = uv + vec2(glitch_offset_x, 0.0);
    vec2 uv_g = uv;
    vec2 uv_b = uv - vec2(glitch_offset_x, 0.0);
    
    
    // --- 3. FLUSSO MISTICO (La base dell'energia) ---
    // Facciamo scorrere la texture del rumore lentamente nel tempo
    vec2 flow_uv = uv + vec2(TIME * flow_speed * 0.1, TIME * flow_speed * 0.2);
    
    // Campioniamo il rumore tre volte (una per canale) usando gli UV distorti dal glitch
    float noise_r = texture(flow_noise_tex, flow_uv + uv_r).r;
    float noise_g = texture(flow_noise_tex, flow_uv + uv_g).r;
    float noise_b = texture(flow_noise_tex, flow_uv + uv_b).r;
    
    // Combiniamo i canali per creare l'effetto RGB split
    vec3 final_noise = vec3(noise_r, noise_g, noise_b);
    
    // Usiamo il rumore per mixare tra i due colori mistici
    vec3 aura_color = mix(mystic_color_1.rgb, mystic_color_2.rgb, final_noise.g);
    
    // Aggiungiamo i bordi colorati dati dall'aberrazione cromatica
    aura_color += final_noise * is_glitching * 0.5;


    // --- 4. MASCHERA DI TRASPARENZA (Bordi sfumati) ---
    // Calcoliamo la distanza dal centro (0.5, 0.5)
    float dist_from_center = distance(uv, vec2(0.5));
    // Creiamo un cerchio morbido: luminoso al centro (0.0), sfumato ai bordi (0.5)
    // smoothstep(bordo_esterno, bordo_interno, valore)
    float mask = smoothstep(0.6, 0.2, dist_from_center);
    
    // La luminosità aumenta quando glitcha
    float brightness = 1.0 + (is_glitching * 0.5);
    
    // --- OUTPUT FINALE ---
    COLOR.rgb = aura_color * brightness;
    // L'alpha è la maschera circolare moltiplicata per l'intensità media del rumore
    // (più è luminoso, più è opaco)
    COLOR.a = mask * ((noise_r + noise_g + noise_b) / 3.0) * 1.2;
}