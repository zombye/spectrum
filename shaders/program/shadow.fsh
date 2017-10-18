#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Samplers
uniform sampler2D tex;

//----------------------------------------------------------------------------//

varying vec4 tint;
varying vec2 baseUV;

varying vec3 normal;

varying vec4 metadata;

//----------------------------------------------------------------------------//

void main() {
/* DRAWBUFFERS:01 */

	gl_FragData[0] = texture2D(tex, baseUV) * tint; if (gl_FragData[0].a < 0.102) discard;
	gl_FragData[0].rgb = pow(gl_FragData[0].rgb, vec3(2.2));
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, float(metadata.x > 7.9 && metadata.x < 9.1));
}
