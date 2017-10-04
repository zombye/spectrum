#include "/settings.glsl"

//----------------------------------------------------------------------------//

#include "/lib/util/packing.glsl"

void main() {
/* DRAWBUFFERS:01 */
	gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[1] = vec4(0.5, 0.5, 0.0, 1.0);
}
