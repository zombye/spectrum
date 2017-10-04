#include "/settings.glsl"

//----------------------------------------------------------------------------//

varying vec4 color;

//----------------------------------------------------------------------------//

#include "/lib/util/packing.glsl"

void main() {
/* DRAWBUFFERS:01 */

	gl_FragData[0] = vec4(pack2x8(color.rg), pack2x8(vec2(color.b, 1.0 / 255.0)), 0.0, 1.0);
	gl_FragData[1] = vec4(0.5, 0.5, 0.0, 0.0);
}
