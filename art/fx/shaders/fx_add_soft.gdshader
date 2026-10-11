// 软加色：按底色亮度衰减加色量（底越亮加得越少），亮底上不发白；暗底上等同 Add。
// 需要读屏幕纹理，开销比 CanvasItemMaterial Add 大，只给同屏数量少的大特效（落雷、地爆、光柱）用。
shader_type canvas_item;
render_mode blend_mix, unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float knee : hint_range(0.0, 1.0) = 0.75;   // 0 = 纯 Add；1 = 底色全白时不加
void fragment() {
	vec4 s = texture(TEXTURE, UV) * COLOR;
	vec3 d = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(d, vec3(0.299, 0.587, 0.114));
	vec3 r = min(d + s.rgb * s.a * (1.0 - knee * l), vec3(1.0));
	COLOR = vec4(r, step(0.004, s.a));
}
