shader_type canvas_item;

uniform vec2 key_sample_uv = vec2(0.01, 0.01);
uniform float key_threshold : hint_range(0.0, 1.0) = 0.08;
uniform float transition : hint_range(0.0, 0.3) = 0.05;
uniform float luminance_weight : hint_range(0.0, 2.0) = 0.4;
uniform float saturation_weight : hint_range(0.0, 3.0) = 0.35;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	vec3 key_color = texture(TEXTURE, key_sample_uv).rgb;
	float max_channel = max(color.r, max(color.g, color.b));
	float min_channel = min(color.r, min(color.g, color.b));
	float saturation = max_channel - min_channel;
	float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	float key_luminance = dot(key_color, vec3(0.299, 0.587, 0.114));
	float color_distance = distance(color.rgb, key_color);
	float signal = color_distance + abs(luminance - key_luminance) * luminance_weight + saturation * saturation_weight;
	float alpha_mask = smoothstep(key_threshold, key_threshold + transition, signal);
	COLOR = vec4(color.rgb, color.a * alpha_mask);
}
