//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform float sunAngle;

uniform float rainStrength;
uniform float wetness;

uniform float fogDensity = 0.1;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D colortex0; // Gbuffer0
uniform sampler2D colortex1; // Gbuffer1

uniform sampler2D colortex3; // Transparent color
uniform sampler2D colortex4; // Main color
uniform sampler2D colortex5; // Image storing some stuff that would ideally be uniforms but currently can't be
uniform sampler2D colortex6; // Sky Scattering Image
uniform sampler2D colortex7; // Shadows

uniform sampler2D noisetex;

//--// Time uniforms

uniform int frameCounter;
uniform float frameTimeCounter;

uniform int worldDay;
uniform int worldTime;

//--// Camera uniforms

uniform int isEyeInWater;
uniform ivec2 eyeBrightness;
uniform float eyeAltitude;

uniform vec3 cameraPosition;

uniform float far;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
#if defined VL_AIR || defined VL_WATER
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
#ifdef SHADOW_COLORED
uniform sampler2D shadowcolor1;
#endif
#endif

//-// Custom uniforms

uniform vec2 viewResolution;
uniform vec2 viewPixelSize;

uniform float frameR1;

uniform vec2 taaOffset;

uniform vec3 sunVector;

uniform vec3 shadowLightVector;

//--// Shared Includes //-----------------------------------------------------//

#include "/include/utility.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/sampling.glsl"

#include "/include/shared/celestialConstants.glsl"
#include "/include/shared/skyProjection.glsl"

#include "/include/shared/atmosphere/constants.glsl"
#include "/include/shared/atmosphere/lookup.glsl"
#include "/include/shared/atmosphere/transmittance.glsl"

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

	out vec2 screenCoord;

	out vec3 luminanceShadowlight;
	out vec3 illuminanceShadowlight;

	out vec3 illuminanceSky;

	//--// Vertex Includes //-------------------------------------------------//

	#include "/include/spherical_harmonics/core.glsl"
	#include "/include/spherical_harmonics/expansion.glsl"

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);

		vec3[9] skylight_sh_coeffs = vec3[9](
			texelFetch(colortex5, ivec2(0, viewResolution.y - 1), 0).rgb,
			texelFetch(colortex5, ivec2(1, viewResolution.y - 1), 0).rgb,
			texelFetch(colortex5, ivec2(2, viewResolution.y - 1), 0).rgb,
			texelFetch(colortex5, ivec2(3, viewResolution.y - 1), 0).rgb,
			texelFetch(colortex5, ivec2(4, viewResolution.y - 1), 0).rgb,
			texelFetch(colortex5, ivec2(5, viewResolution.y - 1), 0).rgb,
			texelFetch(colortex5, ivec2(6, viewResolution.y - 1), 0).rgb,
			texelFetch(colortex5, ivec2(7, viewResolution.y - 1), 0).rgb,
			texelFetch(colortex5, ivec2(8, viewResolution.y - 1), 0).rgb
		);
		illuminanceSky = sh_integrate_product(skylight_sh_coeffs, sh_expansion_hemisphere_order3(vec3(0.0, 1.0, 0.0)));

		vec3 shadowlightTransmittance = texelFetch(colortex5, ivec2(0, viewResolution.y - 2), 0).rgb;
		luminanceShadowlight   = (sunAngle < 0.5 ? sunLuminance   : moonLuminance)   * shadowlightTransmittance;
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * shadowlightTransmittance;
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

	in vec2 screenCoord;

	in vec3 luminanceShadowlight;
	in vec3 illuminanceShadowlight;

	in vec3 illuminanceSky;

	//--// Fragment Outputs //------------------------------------------------//

	/* RENDERTARGETS: 6 */

	out vec4 fragData;
	#define color (fragData.rgb)
	#define luminance (fragData.a)

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/complex.glsl"
	#include "/include/utility/dithering.glsl"
	#include "/include/utility/fastMath.glsl"
	#include "/include/utility/geometry.glsl"
	#include "/include/utility/noise.glsl"
	#include "/include/utility/packing.glsl"
	#include "/include/utility/rotation.glsl"
	#include "/include/utility/sequence.glsl"
	#include "/include/utility/spaceConversion.glsl"

	#include "/include/fragment/clouds3D.fsh"

	#if defined VL_AIR || defined VL_WATER
		#include "/include/shared/shadowDistortion.glsl"

		#ifdef SHADOW_COLORED
			vec3 ReadShadowMaps(vec3 shadowCoord) {
				float shadow0 = textureLod(shadowtex0, shadowCoord.st, 0.0).r;
				      shadow0 = shadow0 < 1.0 ? step(shadowCoord.z, shadow0) : 1.0;
				float shadow1 = textureLod(shadowtex1, shadowCoord.st, 0.0).r;
				      shadow1 = shadow1 < 1.0 ? step(shadowCoord.z, shadow1) : 1.0;
				vec4  shadowC = textureLod(shadowcolor1, shadowCoord.st, 0.0);
				      shadowC.rgb = LinearFromSrgb(shadowC.rgb);

				// Best looking method I've found so far.
				return (shadowC.rgb * shadowC.a - shadowC.a) * (-shadow1 * shadow0 + shadow1) + shadow1;
			}
		#else
			float ReadShadowMaps(vec3 shadowCoord) {
				float shadowSample = textureLod(shadowtex1, shadowCoord.st, 0.0).r;
				return shadowSample < 1.0 ? step(shadowCoord.z, shadowSample) : 1.0;
			}
		#endif
	#endif

	#include "/include/shared/phaseFunctions.glsl"

	#include "/include/shared/atmosphere/density.glsl"
	#include "/include/shared/atmosphere/phase.glsl"

	#if defined VL_WATER && CAUSTICS != CAUSTICS_OFF
		#include "/include/fragment/waterCaustics.fsh"
	#endif
	#include "/include/fragment/fog.fsh"

	//--// Fragment Functions //----------------------------------------------//

	void main() {
		mat3 frontPosition;
		frontPosition[0] = vec3(screenCoord, texture(depthtex0, screenCoord).r);
		#ifdef TAA
		frontPosition[0].xy -= taaOffset * 0.5;
		#endif
		frontPosition[1] = ScreenSpaceToViewSpace(frontPosition[0], gbufferProjectionInverse);
		frontPosition[2] = mat3(gbufferModelViewInverse) * frontPosition[1] + gbufferModelViewInverse[3].xyz;
		vec3 viewVector = normalize(frontPosition[2] - gbufferModelViewInverse[3].xyz);

		float LoV = dot(shadowLightVector, -viewVector);

		float eyeSkylight = eyeBrightness.y / 240.0;
		      eyeSkylight = eyeSkylight * exp(eyeSkylight * 6.0 - 6.0);

		// Dither pattern
		const float ditherSize = 32.0 * 32.0;
		float dither = Bayer32(gl_FragCoord.st);
		#ifdef TAA
		      dither = fract(dither + frameR1);
		#endif

		bool isSky = frontPosition[0].z >= 1.0;
		float skylightFade;
		if (!isSky) {
			// Gbuffer data
			vec4 colortex0Sample = texture(colortex0, screenCoord);

			vec2 lightmap = Unpack2x8(colortex0Sample.b);
			skylightFade = lightmap.y * exp(lightmap.y * 6.0 - 6.0);
		} else { // Sky
			skylightFade = 1.0;
		}

		color = DecodeRGBE8(texture(colortex4, screenCoord));

		// Eye to front fog
		if (isEyeInWater == 1) { // Water fog
			#ifdef VL_WATER
			color = CalculateWaterFogVL(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, skylightFade, dither, isSky);
			#else
			color = CalculateWaterFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, skylightFade, dither, isSky);
			#endif
		} else if (isEyeInWater == 2) { // Lava fog
			// TODO
		} else { // Air fog
			#ifdef VL_AIR
			color = CalculateAirFogVL(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, skylightFade, dither, isSky);
			#else
			color = CalculateAirFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, skylightFade, dither, isSky);
			#endif
		}

		color = Max0(color); // Max0 as a temp workaround for the very occasional nan that is coming from seemingly nowhere
		luminance = sqrt(dot(color, RgbToXyz[1]));
	}
#endif
