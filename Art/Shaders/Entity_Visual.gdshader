shader_type canvas_item;

uniform vec4 base_tint = vec4(1.0);
uniform float hurt_flash : hint_range(0.0, 1.0) = 0.0;

uniform float debuff_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float poison_amount : hint_range(0.0, 1.0) = 0.0;
uniform float freeze_amount : hint_range(0.0, 1.0) = 0.0;
uniform float burn_amount : hint_range(0.0, 1.0) = 0.0;
uniform float shield_amount : hint_range(0.0, 1.0) = 0.0;

uniform float debuff_pulse_speed : hint_range(0.5, 5.0) = 2.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	tex_color.rgb *= base_tint.rgb;

	if (hurt_flash > 0.0) {
		tex_color.rgb = mix(tex_color.rgb, vec3(1.0), hurt_flash);
	}

	float pulse = sin(TIME * debuff_pulse_speed) * 0.5 + 0.5;

	// Generic debuff: dark red/purple pulse
	if (debuff_intensity > 0.0) {
		vec3 debuff_color = vec3(0.7, 0.1, 0.8);
		tex_color.rgb = mix(tex_color.rgb, debuff_color, debuff_intensity * 0.35 + debuff_intensity * pulse * 0.15);
	}

	// Poison: green tint pulse
	if (poison_amount > 0.0) {
		vec3 poison_color = vec3(0.2, 0.85, 0.2);
		tex_color.rgb = mix(tex_color.rgb, poison_color, poison_amount * 0.35 + poison_amount * pulse * 0.15);
	}

	// Freeze: blue-white pulse
	if (freeze_amount > 0.0) {
		vec3 freeze_color = vec3(0.5, 0.8, 1.0);
		tex_color.rgb = mix(tex_color.rgb, freeze_color, freeze_amount * 0.4 + freeze_amount * pulse * 0.1);
	}

	// Burn: orange-red flicker
	if (burn_amount > 0.0) {
		vec3 burn_color = vec3(1.0, 0.4, 0.05);
		tex_color.rgb = mix(tex_color.rgb, burn_color, burn_amount * 0.4 + burn_amount * pulse * 0.2);
	}

	// Shield: golden rim
	if (shield_amount > 0.0) {
		vec3 shield_color = vec3(1.0, 0.85, 0.2);
		tex_color.rgb = mix(tex_color.rgb, shield_color, shield_amount * 0.3 + shield_amount * pulse * 0.1);
	}

	COLOR = tex_color;
}