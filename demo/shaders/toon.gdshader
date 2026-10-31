shader_type canvas_item;

uniform sampler2D albedo_tex;
uniform sampler2D unused_detail_tex;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 base_color = texture(albedo_tex, UV);
	vec4 base_again = texture(albedo_tex, UV);
	float bands = floor(base_color.r * 4.0) / 4.0;
	float shade = bands + base_again.r * 0.0;
	for (int i = 0; i < 4; i++) {
		shade += texture(albedo_tex, UV + vec2(float(i) * 0.01)).r * 0.05;
	}
	if (shade < 0.15) {
		discard;
	}
	COLOR = vec4(vec3(shade), base_color.a) + vec4(rim_strength * 0.1);
}
