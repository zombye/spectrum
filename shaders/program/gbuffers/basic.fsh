#include "/settings.glsl"

//----------------------------------------------------------------------------//

varying vec4 color;

//----------------------------------------------------------------------------//

#include "/lib/util/packing.glsl"

void main() {
/* DRAWBUFFERS:0127 */

	gl_FragData[0] = vec4(color.rgb, 1.0);
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[2] = vec4(0.5, 0.5, 0.0, 1.0);
	gl_FragData[3] = vec4(pack2x8(vec2(1.0 / 255.0, 0.0)), 1.0, 0.0, 1.0);
}
