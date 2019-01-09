/*\
 * Program Description:
 * Converts to sRGB and dithers before final output
\*/

//--// Settings

#include "/settings.glsl"

//--// Uniforms

uniform sampler2D colortex4;

//--// Shared Libraries

//--// Shared Functions

#if STAGE == STAGE_VERTEX
	//--// Vertex Outputs

	out vec2 screenCoord;

	//--// Vertex Functions

	void main() {
		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	//--// Fragment Outputs

	/* DRAWBUFFERS:0 */

	layout (location = 0) out vec3 color;

	//--// Fragment Libraries

	#include "/lib/utility.glsl"
	#include "/lib/utility/colorspace.glsl"
	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/encoding.glsl"

	//--// Fragment Functions

	vec3 Gamma(vec3 color) {
		color = pow(color, vec3(GAMMA_CHROMINANCE));
		float luminance = dot(color, lumacoeff_rec709);
		return color * pow(luminance, float(GAMMA_LUMINANCE) / float(GAMMA_CHROMINANCE)) / luminance;
	}
	vec3 Lift(vec3 color) {
		const vec3 liftSrgb = vec3(LIFT_R, LIFT_G, LIFT_B) / 255.0;
		vec3 lift = sign(liftSrgb) * SrgbToLinear(abs(liftSrgb));
		return color * (1.0 - lift) + lift;
	}

	void main() {
		color = DecodeRGBE8(textureLod(colortex4, screenCoord, 0.0));

		// Minor color grading
		color = Gamma(color);
		color = Lift(color);

		// Convert to output color space
		color = LinearToSrgb(color);

		// Apply dithering
		color += (Bayer4(gl_FragCoord.st) + (0.5 / 16.0)) / 255.0;
	}
#endif
