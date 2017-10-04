#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Samplers
uniform sampler2D colortex2;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/dither.glsl"
#include "/lib/util/miscellaneous.glsl"

void main() {
	vec4 color = texture2D(colortex2, screenCoord);
	color.rgb = linearTosRGB(color.rgb);
	color += (bayer4(gl_FragCoord.st) / 255.0) + (0.5 / 255.0);

/* DRAWBUFFERS:0 */

	gl_FragColor = color;
}
