/*\
 * Program Description:
 * Converts to sRGB and dithers before final output
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform float aspectRatio;

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
	#include "/include/utility/color.glsl"
	#include "/include/utility/dithering.glsl"
	#include "/include/utility/encoding.glsl"

	//--// Fragment Functions //----------------------------------------------//

	vec2 LensDistortion(vec2 uv, float distortionAmt) {
		vec2 sensorSize = (1e-3 * CAMERA_SENSOR_SIZE_MM) * vec2(aspectRatio / CAMERA_ANAMORPHIC_SCALE, 1.0);
		uv = sensorSize * (uv - 0.5);

		float d = dot(uv, uv) / dot(0.5 * sensorSize, 0.5 * sensorSize);
		uv *= (1.0 + distortionAmt * d) / max(1.0 + CAMERA_LENS_DISTORTION, 1.0);

		return uv / sensorSize + 0.5;
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
		if (CAMERA_LENS_DISTORTION != 0 || CAMERA_CHROMATIC_ABBERATION != 0) {
			if (CAMERA_CHROMATIC_ABBERATION == 0) {
				vec2 uv = LensDistortion(screenCoord, CAMERA_LENS_DISTORTION);
				color = DecodeRGBE8(textureLod(colortex4, uv, 0.0));
			} else {
				vec2 uvR = LensDistortion(screenCoord, CAMERA_LENS_DISTORTION + CAMERA_CHROMATIC_ABBERATION);
				vec2 uvG = LensDistortion(screenCoord, CAMERA_LENS_DISTORTION);
				vec2 uvB = LensDistortion(screenCoord, CAMERA_LENS_DISTORTION - CAMERA_CHROMATIC_ABBERATION);
				color.r = DecodeRGBE8(textureLod(colortex4, uvR, 0.0)).r;
				color.g = DecodeRGBE8(textureLod(colortex4, uvG, 0.0)).g;
				color.b = DecodeRGBE8(textureLod(colortex4, uvB, 0.0)).b;
			}
		} else {
			color = DecodeRGBE8(textureLod(colortex4, screenCoord, 0.0));
		}

		// Convert to output color space
		color = Clamp01(color);
		color = SrgbFromLinear(color);

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
