shader_type canvas_item;
// 暗图怪物描边 / 轮廓光（阶段5，已知问题：雷泽谷、玄岩洞暗背景上深色怪物看不清）。
// 只用在 CreatureArt.RIM_MAP_KEYS 列出的地图；参数默认值在 creature_rim_dark.tres，美术可在编辑器里直接调。
// 两层效果，都很淡：
//   1) 外描边：剪影外侧一圈纸白（outline_*），按贴图像素宽度取样 8 个方向；
//   2) 轮廓光：剪影内侧朝光源（light_dir，左上，与 style_guide 左上光源一致）的边缘提亮（rim_*）。
// 节点的 modulate（受击闪白、死亡淡出）同时作用于本体和描边。
// 剪影判定：美术帧多为半透明笔触（岩傀约 3/4 像素是半透明），先按 alpha_threshold 把 alpha 转成剪影遮罩，
// 只有剪影外缘描边 / 提亮，内部半透明笔触不受影响。
// 注意：宽度单位是“贴图像素”，精灵缩放后屏幕上的宽度按比例变化；帧四周需留 ≥ outline_width_px 的透明边。

uniform vec4 outline_color : source_color = vec4(0.91, 0.87, 0.77, 1.0);
uniform float outline_alpha : hint_range(0.0, 1.0) = 0.45;
uniform float outline_width_px : hint_range(0.0, 6.0) = 2.0;
uniform vec4 rim_color : source_color = vec4(0.96, 0.90, 0.75, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.30;
uniform float rim_width_px : hint_range(0.0, 8.0) = 3.0;
uniform vec2 light_dir = vec2(-0.6, -0.8);
uniform float alpha_threshold : hint_range(0.01, 0.9) = 0.25;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

// 剪影遮罩（宏内联：TEXTURE 内置量不能传进自定义函数）
#define MASK(uv) smoothstep(alpha_threshold * 0.5, alpha_threshold, texture(TEXTURE, (uv)).a)

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = 0.0;
	if (outline_width_px > 0.0) {
		vec2 w = px * outline_width_px;
		n = max(n, MASK(UV + vec2( w.x, 0.0)));
		n = max(n, MASK(UV + vec2(-w.x, 0.0)));
		n = max(n, MASK(UV + vec2(0.0,  w.y)));
		n = max(n, MASK(UV + vec2(0.0, -w.y)));
		n = max(n, MASK(UV + w * 0.7071));
		n = max(n, MASK(UV - w * 0.7071));
		n = max(n, MASK(UV + vec2(w.x, -w.y) * 0.7071));
		n = max(n, MASK(UV + vec2(-w.x, w.y) * 0.7071));
	}
	float self_m = MASK(UV);
	float outline = clamp(n - self_m, 0.0, 1.0) * outline_alpha;
	vec2 ld = normalize(light_dir + vec2(1e-5));
	float toward = MASK(UV + ld * px * rim_width_px);
	float rim = self_m * (1.0 - toward) * rim_strength;
	vec4 body = vec4(mix(tex.rgb, rim_color.rgb, rim), tex.a) * vcol;
	float oa = outline * vcol.a;
	float a = body.a + oa * (1.0 - body.a);
	vec3 rgb = (body.rgb * body.a + outline_color.rgb * oa * (1.0 - body.a)) / max(a, 1e-4);
	COLOR = vec4(rgb, a);
}
