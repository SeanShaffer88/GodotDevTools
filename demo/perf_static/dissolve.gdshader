shader_type spatial;
render_mode blend_mix, cull_back;

#ifdef USE_NOISE
uniform sampler2D noise_tex;
#endif
#ifdef USE_EDGE_GLOW
uniform vec4 edge_color : source_color;
#endif
#ifdef USE_VERTEX_WOBBLE
uniform float wobble = 0.1;
#endif

void fragment() {
	ALBEDO = vec3(1.0);
}
