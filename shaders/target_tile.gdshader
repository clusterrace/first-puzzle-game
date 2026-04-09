// target_tile.gdshader
// Purpose:  Diamond-shaped target tile with distinct lit/unlit states and an
//           animated win-pulse ring.  Applied to a ColorRect sized to one grid
//           cell (80 × 80 px by default).  All shape logic is in the shader;
//           the host rect is fully transparent outside the diamond.
// Author:   Godot Shader Specialist — KAMA-20
// Performance tier: Low (~22 ALU ops/fragment, no texture samples)
// Target platforms: GL Compatibility (OpenGL ES 3.0 / WebGL 2), Godot 4.6
//
// Usage:
//   Create one ColorRect per target cell, sized to (CELL, CELL) px.
//   Apply a unique ShaderMaterial instance (not shared) so each target can
//   have its own `lit` and `win_pulse` values.
//   TargetRenderer.gd manages these nodes automatically.
//
// Uniforms — State (updated from GDScript):
//   lit        — 0.0 = unlit (dim/desaturated), 1.0 = lit (warm glow)
//   win_pulse  — 0.0 = idle, 1.0 = pulse active; animated via TIME
//
// Uniforms — Colors (art-director configurable):
//   color_unlit — dim state fill color
//   color_lit   — lit state fill color
//
// Uniforms — Shape (tweak in editor, then lock):
//   diamond_size   — L1 radius of the diamond core (fraction of half-cell)
//   glow_width     — radial width of the lit glow ring
//   pulse_freq     — pulse oscillation frequency in Hz

shader_type canvas_item;
render_mode blend_mix;

group_uniforms State;
uniform float lit       : hint_range(0.0, 1.0) = 0.0;
uniform float win_pulse : hint_range(0.0, 1.0) = 0.0;

group_uniforms Colors;
uniform vec4 color_unlit : source_color = vec4(0.48, 0.20, 0.20, 1.0);
uniform vec4 color_lit   : source_color = vec4(1.00, 0.60, 0.10, 1.0);

group_uniforms Shape;
uniform float diamond_size : hint_range(0.10, 0.48) = 0.26;
uniform float glow_width   : hint_range(0.01, 0.20) = 0.09;
uniform float pulse_freq   : hint_range(0.50, 4.00) = 1.80;

void fragment() {
	// Remap UV so (0.5, 0.5) is the cell centre.
	vec2 uv = UV - 0.5;

	// L1 (taxicab) distance from centre — produces a diamond / rhombus shape.
	float l1 = abs(uv.x) + abs(uv.y);

	// ── Core diamond fill ─────────────────────────────────────────────────────
	float fill = 1.0 - smoothstep(diamond_size - 0.018, diamond_size, l1);

	// ── Lit glow ring (only when lit > 0) ────────────────────────────────────
	float ring_inner = diamond_size;
	float ring_outer = diamond_size + glow_width;
	float ring = smoothstep(ring_inner, ring_inner + 0.018, l1)
	           * (1.0 - smoothstep(ring_outer - 0.018, ring_outer, l1));
	ring *= lit;

	// ── Win pulse: an expanding concentric ring that breathes via TIME ────────
	// pulse_phase oscillates 0 → 1 → 0 at pulse_freq Hz.
	float pulse_phase = sin(TIME * 6.28318 * pulse_freq) * 0.5 + 0.5;
	// The ring's inner edge expands outward over the pulse cycle.
	float p_inner = ring_outer + pulse_phase * 0.08;
	float p_outer = p_inner + 0.05;
	float pulse_ring = smoothstep(p_inner, p_inner + 0.015, l1)
	                 * (1.0 - smoothstep(p_outer - 0.015, p_outer, l1));
	pulse_ring *= win_pulse * pulse_phase;

	// ── Composite alpha — clip fully transparent pixels early ─────────────────
	float a = max(fill, max(ring * 0.70, pulse_ring * 0.55));
	if (a < 0.005) {
		COLOR = vec4(0.0);
		return;
	}

	// ── Color resolve ─────────────────────────────────────────────────────────
	// Blend between unlit and lit color based on the `lit` uniform.
	vec4 base = mix(color_unlit, color_lit, lit);

	// Desaturate the unlit state: lerp toward a darkened greyscale.
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	base.rgb = mix(vec3(lum * 0.60), base.rgb, 0.45 + 0.55 * lit);

	// Compose: fill + brightened ring + brighter pulse ring.
	vec3 col = base.rgb * fill
	         + base.rgb * 1.50 * ring
	         + base.rgb * 1.80 * pulse_ring;

	COLOR = vec4(col, a * base.a);
}
