// 亮底（青竹山、亮天空、UI 亮面）上的发光特效：改用 Mix 混合，并在特效外侧垫一圈 #1C1E21 柔和墨晕，避免 Add 叠加后发白过曝。
// 用法：CanvasItem 的 material = ShaderMaterial(本着色器)；颜色仍用 modulate / self_modulate。
shader_type canvas_item;
render_mode blend_mix;
uniform vec4 halo_color : source_color = vec4(0.110, 0.118, 0.129, 1.0);   // #1C1E21
uniform float halo_alpha : hint_range(0.0, 1.0) = 0.45;
uniform float halo_radius_px : hint_range(0.0, 16.0) = 4.0;
uniform float glow_gain : hint_range(0.5, 2.0) = 1.0;
void fragment() {
	vec4 fx = texture(TEXTURE, UV) * COLOR;
	fx.rgb = min(fx.rgb * glow_gain, vec3(1.0));
	vec2 px = TEXTURE_PIXEL_SIZE * halo_radius_px;
	float s = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		vec2 d = vec2(cos(a), sin(a)) * px;
		s += texture(TEXTURE, UV + d).a + texture(TEXTURE, UV + d * 0.5).a;
	}
	float h = clamp(s / 16.0 * halo_alpha * 1.6, 0.0, 1.0) * COLOR.a;
	float a = fx.a + h * (1.0 - fx.a);
	vec3 rgb = (fx.rgb * fx.a + halo_color.rgb * h * (1.0 - fx.a)) / max(a, 0.0001);
	COLOR = vec4(rgb, a);
}
