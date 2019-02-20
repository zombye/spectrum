/*\
 * Program Description:
 * First Depth of Field pass
 *
 * For "Simple" DoF:
 *   Horizontal blur
 * For "Standard" DoF:
 *   Generates DoF sprite
 * For "Complex" DOF:
 *   Generated DoF sprite and calculates CoC
\*/

//--// Settings

#include "/settings.glsl"

#if DOF == DOF_SIMPLE
const bool colortex3MipmapEnabled = true;
#endif

//--// Uniforms

uniform float aspectRatio;
uniform float centerDepthSmooth;

// Gbuffer Uniforms
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D depthtex1;

// Misc Samplers
uniform sampler2D colortex3;

// Custom Uniforms
uniform vec2 viewResolution;

uniform vec2 taaOffset;

//--// Shared Functions

#if defined STAGE_VERTEX
	//--// Vertex Outputs

	out vec2 screenCoord;

	//--// Vertex Functions

	void main() {
		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	//--// Fragment Outputs

	#if DOF == DOF_SIMPLE
		/* DRAWBUFFERS:01 */

		layout (location = 0) out vec4 colortex0Write;
		layout (location = 1) out vec4 colortex1Write;
	#else // DOF == DOF_STANDARD || DOF == DOF_COMPLEX
		/* DRAWBUFFERS:0 */

		layout (location = 0) out vec4 colortex0Write;
	#endif

	//--// Fragment Libraries

	#include "/lib/utility.glsl"
	#include "/lib/utility/encoding.glsl"
	#include "/lib/utility/packing.glsl"
	#include "/lib/utility/spaceConversion.glsl"

	#include "/lib/fragment/dofCommon.fsh"

	//--// Fragment Functions

	void main() {
		#if DOF == DOF_SIMPLE || DOF == DOF_COMPLEX
			const float sensorHeight = CAMERA_SENSOR_SIZE_MM * 1e-3;
			float focalLength = CalculateFocalLength(sensorHeight, gbufferProjection[1].y);
			float apertureRadius = CalculateApertureRadius(focalLength, CAMERA_FSTOP);

			float depth = abs(ScreenSpaceToViewSpace(texture(depthtex1, screenCoord).r, gbufferProjectionInverse));
			#ifdef CAMERA_AUTOFOCUS
				float focus = abs(ScreenSpaceToViewSpace(centerDepthSmooth, gbufferProjectionInverse));
			#else
				const float focus = CAMERA_FOCUS_DISTANCE;
			#endif

			float cocMetres = CalculateCircleOfConfusion(depth, focus, apertureRadius, focalLength);
			float cocSensor = cocMetres / sensorHeight;
			float cocPixels = cocSensor * viewResolution.y;
		#endif

		#if DOF == DOF_SIMPLE
			float lod = log2(2.0 * cocPixels / KERNEL_RADIUS);
			float filterRadius = cocSensor / (KERNEL_RADIUS * aspectRatio);

			vec4 valR = vec4(0), valG = vec4(0), valB = vec4(0);
			for (int i = -KERNEL_RADIUS; i <= KERNEL_RADIUS; ++i) {
				vec2 c = Clamp01(screenCoord + vec2(i * filterRadius, 0.0));

				vec3 texel = textureLod(colortex3, c, lod).rgb;
				vec4 c0_c1 = GetC0C1(i);
				//vec4 c0_c1 = GetC0C1(i * 1.25 / KERNEL_RADIUS);

				valR += texel.r * c0_c1;
				valG += texel.g * c0_c1;
				valB += texel.b * c0_c1;
			}

			vec4 texelRe0 = EncodeRGBE8(vec3(valR.x, valG.x, valB.x)); texelRe0.rgb = texelRe0.rgb * 0.5 + 0.5;
			vec4 texelIm0 = EncodeRGBE8(vec3(valR.y, valG.y, valB.y)); texelIm0.rgb = texelIm0.rgb * 0.5 + 0.5;
			vec4 texelRe1 = EncodeRGBE8(vec3(valR.z, valG.z, valB.z)); texelRe1.rgb = texelRe1.rgb * 0.5 + 0.5;
			vec4 texelIm1 = EncodeRGBE8(vec3(valR.w, valG.w, valB.w)); texelIm1.rgb = texelIm1.rgb * 0.5 + 0.5;

			colortex0Write = vec4(Pack2x8(texelRe0.xy), Pack2x8(texelRe0.zw), Pack2x8(texelIm0.xy), Pack2x8(texelIm0.zw));
			colortex1Write = vec4(Pack2x8(texelRe1.xy), Pack2x8(texelRe1.zw), Pack2x8(texelIm1.xy), Pack2x8(texelIm1.zw));
		#endif

		#if DOF == DOF_STANDARD || DOF == DOF_COMPLEX
			// Constants
			const float bladeAngle     = tau / CAMERA_IRIS_BLADE_COUNT;
			const float halfBladeAngle = bladeAngle / 2.0;
			const float bladeRotation  = radians(float(CAMERA_IRIS_BLADE_ROTATION));

			// Get distance to center and distance of diaphragm iris blades from center
			vec2 position = (screenCoord * vec2(aspectRatio, 1.0)) * 2.0 - 1.0;
			float angle = mod(atan(position.y, position.x) + bladeRotation, bladeAngle);

			float dist = cos(halfBladeAngle) / cos(halfBladeAngle - angle);
			      dist = mix(dist, 1.0, float(CAMERA_IRIS_BLADE_ROUNDING));

			// Determine if pixel is within iris
			float iris = step(dot(position, position), dist * dist);

			colortex0Write.rgb = vec3(iris);
		#endif

		#if DOF == DOF_COMPLEX
			colortex0Write.a = cocSensor;
		#endif
	}
#endif
