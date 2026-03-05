shader_type canvas_item;

// Colore della nebbia/vento (puoi cambiarlo dall'Inspector!)
uniform vec4 fog_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);

// Velocità e direzione (X per orizzontale, Y per verticale. Negativo = sinistra/su)
uniform vec2 scroll_speed = vec2(0.08, 0.01);

// Quanto è densa/visibile la nebbia
uniform float density : hint_range(0.0, 2.0) = 0.5;

// La forza del "vortice" interno per non farlo sembrare statico
uniform float distortion_strength = 0.05;

// La texture di rumore (Ricordati di attivarla come Seamless/Repeatable!)
uniform sampler2D noise_texture : repeat_enable;

void fragment() {
    // 1. Calcoliamo lo spostamento base nel tempo
    vec2 base_uv = UV + (scroll_speed * TIME);

    // 2. Creiamo una leggera distorsione leggendo il rumore scalato
    // Questo crea l'effetto "folata di vento" irregolare
    float distort = texture(noise_texture, base_uv * 0.5).r;
    vec2 final_uv = base_uv + vec2(distort * distortion_strength, distort * distortion_strength * 0.5);

    // 3. Leggiamo il valore del rumore finale con le coordinate distorte
    float noise = texture(noise_texture, final_uv).r;

    // 4. Applichiamo il colore scelto nell'Inspector
    COLOR.rgb = fog_color.rgb;

    // 5. Il trucco magico: smoothstep. 
    // Rende i bordi delle nuvole morbidissimi, tagliando via il rumore troppo debole.
    float fog_alpha = smoothstep(0.2, 0.8, noise);

    // 6. Output finale: moltiplichiamo per la densità
    COLOR.a = fog_alpha * density * fog_color.a;
}
