// ray_beam.gdshader
// Purpose:  Glowing sight-ray beam for the Sight Lines puzzle game.
//           Renders a bright core line with a soft additive glow halo using
//           UV.y (0 = one edge, 1 = other edge across the line width).
// Author:   Godot Shader Specialist — KAMA-20
// Performance tier: Low (~10 ALU ops/fragment, no texture samples)
// Target platforms: GL Compatibility (OpenGL ES 3.0 / WebGL 2), Godot 4.6
//
// Usage:
//   Apply as ShaderMaterial on Line2D nodes.
//   Line2D setup required for correct UV:
//     - texture         : 1×1 white ImageTexture (forces UV generation)
//     - texture_mode    : Line2D.LINE_TEXTURE_STRETCH
//     - begin_cap_mode  : Line2D.LINE_CAP_ROUND
//     - end_cap_mode    : Line2D.LINE_CAP_ROUND
//     - width           : 28 px  (controls the visible glow radius)
//   RayRenderer.gd manages these nodes; do not apply manually.
//
// Uniforms:
//   beam_color  — RGBA base color of the entire beam (alpha scales opacity)
//   core_frac   — normalised half-width of the bright core  (0–0.5)
//   glow_frac   — normalised half-width of the glow falloff (core_frac–1.0)
//   intensity   — brightness multiplier; keep ≤ 2.0 on mobile targets
//   fade_start  — UV.x fraction at which the terminal end begins to fade
//   fade_end    — UV.x fraction at which the terminal end reaches zero

shader_type canvas_item;
render_mode blend_add;

group_uniforms Appearance;
uniform vec4  beam_color : source_color = vec4(0.42, 0.84, 1.00, 1.00);
uniform float core_frac  : hint_range(0.01, 0.50) = 0.12;
uniform float glow_frac  : hint_range(0.10, 1.00) = 0.55;
uniform float intensity  : hint_range(0.10, 3.00) = 1.60;

group_uniforms TerminalFade;
uniform float fade_start : hint_range(0.00, 1.00) = 0.82;
uniform float fade_end   : hint_range(0.00, 1.00) = 1.00;

void fragment() {
	// UV.y: 0 = one edge of the line, 1 = opposite edge.
	// Map to a symmetric distance from the beam axis (0 = centre, 1 = edge).
	float dist = abs(UV.y - 0.5) * 2.0;

	// Bright core: tight falloff near the centreline.
	float core = 1.0 - smoothstep(0.0, core_frac * 2.0, dist);

	// Soft glow halo surrounding the core.
	float halo = 1.0 - smoothstep(core_frac * 2.0, glow_frac * 2.0, dist);

	float brightness = core + halo * 0.30;

	// Fade at the terminal end of the ray (UV.x → 1.0) so beams taper cleanly
	// when they stop at a wall or the grid boundary rather than cutting off hard.
	float end_alpha = 1.0 - smoothstep(fade_start, fade_end, UV.x);

	COLOR = vec4(beam_color.rgb * (brightness * intensity),
	             brightness * end_alpha * beam_color.a);
}
