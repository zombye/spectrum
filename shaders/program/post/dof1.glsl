/*\
 * Program Description:
 * Second Depth of Field pass
 *
 * For "Simple" DoF:
 *   Vertical blur
 * For "Standard" DoF:
 *   Performs standard DoF
 * For "Complex" DoF:
 *   TODO: Performs a more complex DoF with per-sample CoC
 *   Currently same as "Standard" DoF
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

#ifndef DOF_SIMPLE
const bool colortex0MipmapEnabled = true;
const bool colortex3MipmapEnabled = true;
#endif

//--// Uniforms //------------------------------------------------------------//

uniform float aspectRatio;
uniform float centerDepthSmooth;

uniform sampler2D depthtex1;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;

//--// Camera uniforms

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Custom uniforms

uniform vec2 viewResolution;

uniform vec2 taaOffset;

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

	/* DRAWBUFFERS:5 */

	layout (location = 0) out vec4 color;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"
	#include "/include/utility/encoding.glsl"
	#include "/include/utility/fastMath.glsl"
	#include "/include/utility/packing.glsl"
	#include "/include/utility/spaceConversion.glsl"

	#include "/include/fragment/dofCommon.fsh"

	//--// Fragment Functions //----------------------------------------------//

	void main() {
		#ifdef DOF
			#ifdef DOF_COMPLEX
				float cocSensor = texture(colortex0, screenCoord).a;
				float cocPixels = cocSensor * viewResolution.y;
			#else
				vec2 sensorSize = (1e-3 * CAMERA_SENSOR_SIZE_MM) * vec2(aspectRatio / CAMERA_ANAMORPHIC_SCALE, 1.0);
				vec2 focalLength = CalculateFocalLength(sensorSize, Diagonal(gbufferProjection).xy);
				vec2 apertureDiameter = CalculateApertureDiameter(focalLength, CAMERA_FSTOP);
				vec2 apertureRadius = apertureDiameter / 2.0;

				float depth = abs(ScreenSpaceToViewSpace(texture(depthtex1, screenCoord).r, gbufferProjectionInverse));
				#if CAMERA_FOCUS < 0
					float focus = abs(ScreenSpaceToViewSpace(centerDepthSmooth, gbufferProjectionInverse));
				#else
					const float focus = CAMERA_FOCUS;
				#endif

				vec2 cocMetres = CalculateCircleOfConfusion(depth, focus, apertureRadius, focalLength);
				vec2 cocSensor = cocMetres / sensorSize;
				vec2 cocPixels = cocSensor * viewResolution;
			#endif

			#ifdef DOF_SIMPLE
				float filterRadius = cocSensor.y / KERNEL_RADIUS;

				vec4 valR = vec4(0), valG = vec4(0), valB = vec4(0);
				for (int i = -KERNEL_RADIUS; i <= KERNEL_RADIUS; ++i) {
					ivec2 c = ivec2((screenCoord + vec2(0.0, i * filterRadius)) * viewResolution);
					c = clamp(c, ivec2(0), ivec2(viewResolution - 1));

					vec4 temp0 = texelFetch(colortex0, c, 0);
					vec4 temp1 = texelFetch(colortex1, c, 0);

					vec4 tempRe0 = vec4(Unpack2x8(temp0.x), Unpack2x8(temp0.y)); tempRe0.rgb = tempRe0.rgb * 2.0 - 1.0;
					vec4 tempIm0 = vec4(Unpack2x8(temp0.z), Unpack2x8(temp0.w)); tempIm0.rgb = tempIm0.rgb * 2.0 - 1.0;
					vec4 tempRe1 = vec4(Unpack2x8(temp1.x), Unpack2x8(temp1.y)); tempRe1.rgb = tempRe1.rgb * 2.0 - 1.0;
					vec4 tempIm1 = vec4(Unpack2x8(temp1.z), Unpack2x8(temp1.w)); tempIm1.rgb = tempIm1.rgb * 2.0 - 1.0;
					vec3 texelRe0 = DecodeRGBE8(tempRe0);
					vec3 texelIm0 = DecodeRGBE8(tempIm0);
					vec3 texelRe1 = DecodeRGBE8(tempRe1);
					vec3 texelIm1 = DecodeRGBE8(tempIm1);

					vec4 texelR = vec4(texelRe0.r, texelIm0.r, texelRe1.r, texelIm1.r);
					vec4 texelG = vec4(texelRe0.g, texelIm0.g, texelRe1.g, texelIm1.g);
					vec4 texelB = vec4(texelRe0.b, texelIm0.b, texelRe1.b, texelIm1.b);

					vec4 c0_c1 = GetC0C1(i);
					//vec4 c0_c1 = GetC0C1(i * 1.25 / KERNEL_RADIUS);

					valR += vec4(texelR.xz * c0_c1.xz - texelR.yw * c0_c1.yw, texelR.yw * c0_c1.xz + texelR.xz * c0_c1.yw);
					valG += vec4(texelG.xz * c0_c1.xz - texelG.yw * c0_c1.yw, texelG.yw * c0_c1.xz + texelG.xz * c0_c1.yw);
					valB += vec4(texelB.xz * c0_c1.xz - texelB.yw * c0_c1.yw, texelB.yw * c0_c1.xz + texelB.xz * c0_c1.yw);
				}

				//*
				color.rgb = vec3(
					dot(valR.xz, Kernel0Weights_RealX_ImY) + dot(valR.yw, Kernel1Weights_RealX_ImY),
					dot(valG.xz, Kernel0Weights_RealX_ImY) + dot(valG.yw, Kernel1Weights_RealX_ImY),
					dot(valB.xz, Kernel0Weights_RealX_ImY) + dot(valB.yw, Kernel1Weights_RealX_ImY)
				);
				//*/ color.rgb = vec3(valR.x + valR.y, valG.x + valG.y, valB.x + valB.y) / KERNEL_RADIUS;

				/*
				if (gl_FragCoord.x < 256.0 && gl_FragCoord.y < 256.0) {
					vec2 c  = (gl_FragCoord.xy / 256.0) * 2.0 - 1.0;
					     c *= 1.25;
					     c *= 1.5;

					vec4 C0C1_X = GetC0C1(c.x);
					vec4 C0C1_Y = GetC0C1(c.y);
					vec4 C0C1_R = GetC0C1(length(c));

					vec2 C0_XY = vec2(C0C1_X.x * C0C1_Y.x - C0C1_X.y * C0C1_Y.y, C0C1_X.x * C0C1_Y.y + C0C1_X.y * C0C1_Y.x);
					vec2 C1_XY = vec2(C0C1_X.z * C0C1_Y.z - C0C1_X.w * C0C1_Y.w, C0C1_X.z * C0C1_Y.w + C0C1_X.w * C0C1_Y.z);
					float shape = C0_XY.x + C1_XY.x;

					if (shape >= 0.0) {
						color.rgb = vec3(shape);
					} else {
						color.rgb = vec3(-shape, 0.0, -shape);
					}
				}
				//*/
			#endif

			#ifndef DOF_SIMPLE
				float lodSample = log2(2.0 * MaxOf(cocPixels) * inversesqrt(DOF_SAMPLES));
				float lodBokeh  = log2(viewResolution.y * inversesqrt(DOF_SAMPLES));

				vec3 result = vec3(0.0), weight = vec3(0.0);
				vec2 dir = vec2(1.0, 0.0);
				for (int i = 0; i < DOF_SAMPLES; ++i) {
					vec2 offset = dir * sqrt((i + 0.5) / DOF_SAMPLES);
					dir *= rotateGoldenAngle;

					vec2 bokehCoord = (offset * 0.5 + 0.5) / vec2(aspectRatio, 1.0);
					vec3 bokeh = textureLod(colortex0, bokehCoord, lodBokeh).rgb;

					vec2 sampleCoord = screenCoord + offset * cocSensor;
					result += textureLod(colortex3, sampleCoord, lodSample).rgb * bokeh;
					weight += bokeh;
				} result /= weight;

				color.rgb = result;
			#endif

			color.a = texture(colortex3, screenCoord).a;
		#else
			color = texture(colortex3, screenCoord);
		#endif
	}
#endif
