// 护盾球：贴图缓慢旋转 + 边缘菲涅尔提亮，中心半透明。贴图 fx_shield_sphere.png（原色护盾金）。
shader_type canvas_item;
uniform float body_alpha : hint_range(0.0, 1.0) = 0.45;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_gain : hint_range(0.0, 2.0) = 0.7;
uniform float spin = 0.25;   // 弧度/秒
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = TIME * spin;
	vec2 q = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * p;
	vec4 c = texture(TEXTURE, q * 0.5 + 0.5);
	c.a *= step(r, 0.97) + (1.0 - step(r, 0.97)) * texture(TEXTURE, UV).a;
	float rim = pow(clamp(r / 0.93, 0.0, 1.0), rim_power);
	c.rgb = min(c.rgb + rim * rim_gain, vec3(1.0));
	c.a *= mix(body_alpha, 1.0, rim);
	COLOR = c * COLOR;
}
