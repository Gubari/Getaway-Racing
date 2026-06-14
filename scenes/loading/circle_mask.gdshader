shader_type canvas_item;
// Maskira teksturu u krug sa mekom (anti-aliased) ivicom.
// `zoom` > 1 malo odzumira sliku ka centru da ceo logo (ukljucujuci tekst pri
// dnu) stane u krug; visak prostora popunjava zelena ivica logoa (edge clamp).

uniform float zoom : hint_range(1.0, 1.6) = 1.18;

void fragment() {
	vec2 tex_uv = (UV - vec2(0.5)) * zoom + vec2(0.5);
	float d = distance(UV, vec2(0.5));
	float edge = fwidth(d) + 0.003;
	float a = 1.0 - smoothstep(0.5 - edge, 0.5, d);
	COLOR = texture(TEXTURE, tex_uv);
	COLOR.a *= a;
}
