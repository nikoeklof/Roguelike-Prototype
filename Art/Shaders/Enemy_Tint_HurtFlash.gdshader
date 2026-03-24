shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // apply tint
    tex.rgb *= tint_color.rgb;

    // apply flash
    tex.rgb = mix(tex.rgb, vec3(1.0), flash_amount);

    COLOR = tex;
}