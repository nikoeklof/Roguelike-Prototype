shader_type canvas_item;

// Existing parameters
uniform vec4 base_tint = vec4(1.0);
uniform float hurt_flash : hint_range(0.0, 1.0) = 0.0;

// NEW: Debuff parameters
uniform float debuff_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 debuff_color = vec4(0.8, 0.2, 0.2, 1.0);
uniform float debuff_pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform float debuff_glow : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Apply base tint
	tex_color.rgb *= base_tint.rgb;
	
	// Apply hurt flash (existing)
	if (hurt_flash > 0.0) {
		tex_color.rgb = mix(tex_color.rgb, vec3(1.0), hurt_flash);
	}
	
	// NEW: Apply debuff effects
	if (debuff_intensity > 0.0) {
		// Create pulsing effect
		float pulse = sin(TIME * debuff_pulse_speed) * 0.5 + 0.5;
		float pulse_amount = debuff_intensity * pulse * 0.3;
		
		// Apply debuff color tint
		vec3 debuff_tint = mix(tex_color.rgb, debuff_color.rgb, debuff_intensity * 0.4);
		
		// Add glow edge
		vec3 glow = debuff_color.rgb * debuff_glow * pulse_amount;
		
		tex_color.rgb = debuff_tint + glow;
		
		// Slight desaturation for debuffed units
		float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
		tex_color.rgb = mix(tex_color.rgb, vec3(gray), debuff_intensity * 0.2);
	}
	
	COLOR = tex_color;
}