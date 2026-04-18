shader_type canvas_item;

uniform float dark_threshold : hint_range(0.0, 1.0) = 0.12;
uniform float transition : hint_range(0.0, 0.2) = 0.04;
uniform float saturation_weight : hint_range(0.0, 3.0) = 1.2;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float max_channel = max(color.r, max(color.g, color.b));
	float min_channel = min(color.r, min(color.g, color.b));
	float saturation = max_channel - min_channel;
	float signal = max(max_channel, max_channel + saturation * saturation_weight);
	float alpha_mask = smoothstep(dark_threshold, dark_threshold + transition, signal);
	COLOR = vec4(color.rgb, color.a * alpha_mask);
}
