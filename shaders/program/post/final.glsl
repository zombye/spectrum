/*\
 * Program Description:
 * Converts to sRGB and dithers before final output
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex4;
#ifdef LUT
uniform sampler2D depthtex2;
#endif

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

	out vec2 screenCoord;

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

	in vec2 screenCoord;

	//--// Fragment Outputs //------------------------------------------------//

	out vec3 color;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"
	#include "/include/utility/colorspace.glsl"
	#include "/include/utility/dithering.glsl"
	#include "/include/utility/encoding.glsl"

	//--// Fragment Functions //----------------------------------------------//

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

	#ifdef LUT
		vec3 LookupColor(sampler2D lookupTable, vec3 color) {
			const ivec2 lutTile = ivec2(8, 8); // 8x8=64 8x16=128 16x8=128 16x16=256
			const int   lutSize = lutTile.x * lutTile.y;

			color.b *= lutSize - 1;
			int i0 = int(color.b);
			int i1 = i0 + 1;

			vec2 c0 = vec2(i0 % lutTile.x, i0 / lutTile.x);
			vec2 c1 = vec2(i1 % lutTile.x, i1 / lutTile.x);

			vec2 c = color.rg * ((lutSize - 1.0) / (lutSize * lutTile)) + (0.5 / (lutSize * lutTile));

			return mix(
				texture(lookupTable, c0 / lutTile + c).rgb,
				texture(lookupTable, c1 / lutTile + c).rgb,
				color.b - i0
			);
		}
	#endif

	void main() {
		color = DecodeRGBE8(textureLod(colortex4, screenCoord, 0.0));

		// Minor color grading
		color = Gamma(color);
		color = Lift(color);

		// Convert to output color space
		color = Clamp01(color);
		color = LinearToSrgb(color);

		#ifdef LUT
			// Apply LUT
			color = LookupColor(depthtex2, color);
		#endif

		// Apply dithering
		color += (Bayer4(gl_FragCoord.st) + (0.5 / 16.0)) / 255.0;

		/* this was used to create an identity lut
		const ivec2 lutTile = ivec2(8, 8);  // 8x8=64 8x16=128 16x8=128 16x16=256
		const int   lutSize = lutTile.x * lutTile.y;
		ivec2 px = ivec2(gl_FragCoord.st);

		color.r = px.x % lutSize;
		color.g = (lutSize - 1) - (px.y % lutSize);

		px /= lutSize;
		color.b = (px.x + (lutTile.y - px.y - 1) * lutTile.x);
		color = color / (lutSize - 1);
		//*/
	}
#endif
