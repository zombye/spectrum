/*\
 * Program Description:
 * Renders the sky
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform float sunAngle;

uniform float wetness;

uniform float screenBrightness;

uniform sampler2D depthtex1;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex8; // Velocity buffer
uniform sampler2D colortex5; // Previous frame data
uniform sampler3D colortex7; // 3D noise
uniform sampler2D colortex9; // Cloud patch noise
uniform sampler2D colortex10; // 3D clouds scattering, transmittance
uniform sampler2D colortex11; // 3D clouds distance
uniform sampler2D colortex12; // 2D clouds scattering, transmittance
uniform sampler2D noisetex;

uniform sampler2D depthtex0; // Sky Transmittance LUT
uniform sampler3D depthtex2; // Sky Scattering LUT
#define transmittanceLut depthtex0
#define scatteringLut depthtex2

//--// Time uniforms

uniform int   frameCounter;
uniform float frameTimeCounter;

uniform int worldDay;
uniform int worldTime;

//--// Camera uniforms

uniform int isEyeInWater;
uniform float eyeAltitude;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float far;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

//--// Custom uniforms

uniform vec2 viewResolution;
uniform vec2 viewPixelSize;

uniform float frameR1;

uniform vec2 taaOffset;

uniform vec3 sunVector;

uniform vec3 moonVector;

uniform vec3 shadowLightVector;

//--// Shared Includes //-----------------------------------------------------//

#include "/include/utility.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/noise.glsl"
#include "/include/utility/sampling.glsl"

#include "/include/shared/celestialConstants.glsl"
#define moonIlluminance (moonIlluminance * NIGHT_SKY_BRIGHTNESS)
#include "/include/shared/phaseFunctions.glsl"

#include "/include/shared/atmosphere/constants.glsl"
#include "/include/shared/atmosphere/lookup.glsl"
#include "/include/shared/atmosphere/transmittance.glsl"
#include "/include/shared/atmosphere/phase.glsl"
#include "/include/shared/atmosphere/scattering.glsl"

#include "/include/shared/skyProjection.glsl"

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

	out vec2 screenCoord;

	out vec3 skyAmbient;
	out vec3 skyAmbientUp;
	out vec3 illuminanceShadowlight;

	out float averageCloudTransmittance;

	//--// Vertex Includes //-------------------------------------------------//

	#include "/include/fragment/clouds3D.fsh"

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);

		const ivec2 samples = ivec2(16, 8);

		skyAmbient = vec3(0.0);
		skyAmbientUp = vec3(0.0);
		for (int x = 0; x < samples.x; ++x) {
			for (int y = 0; y < samples.y; ++y) {
				vec3 dir = SampleSphere((vec2(x, y) + 0.5) / samples);

				vec3 skySample  = AtmosphereScattering(scatteringLut, vec3(0.0, atmosphere_planetRadius, 0.0), dir, sunVector ) * sunIlluminance;
				     skySample += AtmosphereScattering(scatteringLut, vec3(0.0, atmosphere_planetRadius, 0.0), dir, moonVector) * moonIlluminance;

				skyAmbient += skySample;
				skyAmbientUp += skySample * Clamp01(dir.y);
			}
		}

		const float sampleWeight = 4.0 * pi / (samples.x * samples.y);
		skyAmbient *= sampleWeight;
		skyAmbientUp *= sampleWeight;

		vec3 shadowlightTransmittance  = AtmosphereTransmittance(transmittanceLut, vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector);
		     shadowlightTransmittance *= smoothstep(0.0, 0.01, abs(shadowLightVector.y));
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : (moonIlluminance / NIGHT_SKY_BRIGHTNESS)) * shadowlightTransmittance;

		averageCloudTransmittance = Calculate3DCloudsAverageTransmittance();
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

	in vec2 screenCoord;

	in vec3 skyAmbient;
	in vec3 skyAmbientUp;
	in vec3 illuminanceShadowlight;

	in float averageCloudTransmittance;

	//--// Fragment Outputs //------------------------------------------------//

	/* RENDERTARGETS: 6 */

	out vec4 skyImage_cloudShadow;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/complex.glsl"
	#include "/include/utility/dithering.glsl"
	#include "/include/utility/packing.glsl"
	#include "/include/utility/rotation.glsl"
	#include "/include/utility/spaceConversion.glsl"

	#include "/include/shared/atmosphere/density.glsl"

	#include "/include/fragment/clouds2D.fsh"
	#include "/include/fragment/clouds3D.fsh"

	#include "/include/fragment/material.fsh"
	#include "/include/fragment/brdf.fsh"
	#include "/include/fragment/diffuseLighting.fsh"
	#include "/include/fragment/specularLighting.fsh"

	//--// Fragment Functions //----------------------------------------------//

	#ifdef DISTANT_VL
		mat2x3 CloudShadowedAtmosphere(vec3 startPosition, vec3 viewVector, float endDistance, float dither) {
			const int steps = DISTANT_VL_STEPS;

			float raymarchDistance = min(endDistance, 1e3 * DISTANT_VL_RANGE);
			float stepSize = abs(raymarchDistance / steps);
			vec3 increment = viewVector * stepSize;
			vec3 position  = startPosition + increment * dither;

			vec3 scattering = vec3(0.0);
			vec3 transmittance = vec3(1.0);

			scattering += AtmosphereScatteringMulti(scatteringLut, position, viewVector, sunVector ) * sunIlluminance;
			scattering += AtmosphereScatteringMulti(scatteringLut, position, viewVector, moonVector) * moonIlluminance;
			scattering *= averageCloudTransmittance;

			vec3 sun  = AtmosphereScatteringSingle(scatteringLut, position, viewVector, sunVector ) * sunIlluminance;
			vec3 moon = AtmosphereScatteringSingle(scatteringLut, position, viewVector, moonVector) * moonIlluminance;
			for (int i = 0; i < steps; ++i) {
				float cloudShadow = exp(-Calculate3DCloudsOpticalDepth(position + vec3(cameraPosition.x, -atmosphere_planetRadius, cameraPosition.z), shadowLightVector, 0.5, 3));
				if (sunAngle < 0.5) {
					sun *= cloudShadow;
				} else {
					moon *= cloudShadow;
				}

				scattering += (sun + moon) * transmittance;

				vec3 density = AtmosphereDensity(length(position));
				if (density.y > 1e15) { break; }
				vec3 airmass = stepSize * density;
				vec3 opticalDepth = atmosphere_coefficientsAttenuation * airmass;
				transmittance *= exp(-opticalDepth);

				position += increment;

				sun  = Max0(AtmosphereScatteringSingle(scatteringLut, position, viewVector, sunVector )) * sunIlluminance;
				moon = Max0(AtmosphereScatteringSingle(scatteringLut, position, viewVector, moonVector)) * moonIlluminance;
				if (sunAngle < 0.5) {
					scattering -= (sun * cloudShadow + moon) * transmittance;
				} else {
					scattering -= (sun + moon * cloudShadow) * transmittance;
				}
			}

			if (raymarchDistance < endDistance) {
				vec3 endPos = startPosition + viewVector * endDistance;

				vec3 scatteringFromRme  = AtmosphereScattering(scatteringLut, position, viewVector, sunVector)  * sunIlluminance;
				     scatteringFromRme += AtmosphereScattering(scatteringLut, position, viewVector, moonVector) * moonIlluminance;
				vec3 scatteringFromEnd  = AtmosphereScattering(scatteringLut, endPos, viewVector, sunVector)  * sunIlluminance;
				     scatteringFromEnd += AtmosphereScattering(scatteringLut, endPos, viewVector, moonVector) * moonIlluminance;

				vec3 transmittanceViewToEnd = AtmosphereTransmittance(transmittanceLut, startPosition, viewVector, endDistance);
				vec3 scatteringRmeToEnd = Max0(scatteringFromRme * transmittance - Max0(scatteringFromEnd * transmittanceViewToEnd));

				scattering += scatteringRmeToEnd * averageCloudTransmittance;
				transmittance = transmittanceViewToEnd;
			}

			return mat2x3(scattering, transmittance);
		}
	#endif

	#ifdef CLOUDS3D
		float CalculateCloudShadowMap() {
			vec3 pos = vec3(screenCoord, 0.0);
			pos.xy /= CLOUD_SHADOW_MAP_RESOLUTION * viewPixelSize;
			if (Clamp01(pos.xy) != pos.xy) { return 1.0; }
			pos.xy  = pos.xy * 2.0 - 1.0;
			pos.xy /= 1.0 - length(pos.xy);
			pos.xy *= 200.0;
			pos     = mat3(shadowModelViewInverse) * pos;

			pos += cameraPosition;
			pos += shadowLightVector * (256.0 - pos.y) / shadowLightVector.y;

			//--//

			return exp(-Calculate3DCloudsOpticalDepth(pos, shadowLightVector, 0.5, 50));
		}
	#endif

	//------------------------------------------------------------------------//

	// Doens't handle stars or the sun/moon so not really the entire sky but I couldn't think of a better name for this function
	void RenderSky(
		vec3 viewPosition, vec3 viewVector, float dither,
		out vec3 scattering, out vec3 transmittance
	) {
		transmittance = AtmosphereTransmittance(transmittanceLut, viewPosition, viewVector);
		#if !defined CLOUDS3D || !defined DISTANT_VL
		scattering  = AtmosphereScattering(scatteringLut, viewPosition, viewVector, sunVector)  * sunIlluminance;
		scattering += AtmosphereScattering(scatteringLut, viewPosition, viewVector, moonVector) * moonIlluminance;
		#endif

		#if defined CLOUDS2D || defined CLOUDS3D
		float lowerLimitDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_lowerLimitRadius).x;
		if (lowerLimitDistance <= 0.0 || eyeAltitude >= CLOUDS3D_ALTITUDE_MIN) {
			#ifdef CLOUDS3D
			float clouds3DDistance = texelFetch(colortex11, ivec2(gl_FragCoord.xy), 0).x;
			vec4 clouds3D = texelFetch(colortex10, ivec2(gl_FragCoord.xy), 0);

			if (clouds3DDistance > 0.0) {
				vec3 cloudsPosition = viewPosition + viewVector * clouds3DDistance;

				// remove atmosphere occluded by clouds
				vec3 transmittanceFromClouds = AtmosphereTransmittance(transmittanceLut, cloudsPosition, viewVector);
				vec3 transmittanceToClouds = AtmosphereTransmittance(transmittanceLut, viewPosition, viewVector, clouds3DDistance);//transmittance / transmittanceFromClouds;
				vec3 scatteringFromClouds  = AtmosphereScattering(scatteringLut, cloudsPosition, viewVector, sunVector)  * sunIlluminance;
				     scatteringFromClouds += AtmosphereScattering(scatteringLut, cloudsPosition, viewVector, moonVector) * moonIlluminance;

				#ifdef DISTANT_VL
				if (eyeAltitude < CLOUDS3D_ALTITUDE_MIN) {
					scattering += CloudShadowedAtmosphere(viewPosition, viewVector, clouds3DDistance, dither)[0];
					scattering += scatteringFromClouds * transmittanceToClouds * clouds3D.a;
				} else {
					// TODO: Do distant VL here as well
					scattering += scatteringFromClouds * transmittanceToClouds * (clouds3D.a * averageCloudTransmittance - 1.0);
				}
				#else
				if (eyeAltitude < CLOUDS3D_ALTITUDE_MIN) {
					scattering -= scatteringFromClouds * transmittanceToClouds;
					scattering *= averageCloudTransmittance;
					scattering += scatteringFromClouds * transmittanceToClouds * clouds3D.a;
				} else {
					scattering += scatteringFromClouds * transmittanceToClouds * (clouds3D.a * averageCloudTransmittance - 1.0);
				}
				#endif

				// apply clouds
				scattering += clouds3D.rgb * transmittanceToClouds;
				transmittance *= clouds3D.a;
			}
			#endif

			#ifdef CLOUDS2D
			float clouds2DDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_planetRadius + CLOUDS2D_ALTITUDE).y;

			if (clouds2DDistance > 0.0) {
				vec4 clouds2D = texelFetch(colortex12, ivec2(gl_FragCoord.xy), 0);
				vec3 cloudsPosition = viewPosition + viewVector * clouds2DDistance;

				// remove atmosphere occluded by clouds
				vec3 transmittanceFromClouds = AtmosphereTransmittance(transmittanceLut, cloudsPosition, viewVector);
				vec3 transmittanceToClouds = transmittance / transmittanceFromClouds;
				vec3 scatteringFromClouds  = AtmosphereScattering(scatteringLut, cloudsPosition, viewVector, sunVector)  * sunIlluminance;
				     scatteringFromClouds += AtmosphereScattering(scatteringLut, cloudsPosition, viewVector, moonVector) * moonIlluminance;

				scattering += scatteringFromClouds * transmittanceToClouds * (clouds2D.a - 1.0);

				// apply clouds
				scattering += clouds2D.rgb * transmittanceToClouds;
				transmittance *= clouds2D.a;
			}
			#endif
		} else {
			#ifdef CLOUDS3D
			#ifdef DISTANT_VL
			scattering = CloudShadowedAtmosphere(viewPosition, viewVector, lowerLimitDistance, dither)[0];
			#else
			scattering *= averageCloudTransmittance;
			#endif
			#endif
		}
		#endif
	}

	//------------------------------------------------------------------------//

	void main() {
		ivec2 fragCoord = ivec2(gl_FragCoord.xy);

		const float ditherSize = 16.0 * 16.0;
		float dither = Bayer16(gl_FragCoord.st);
		#ifdef TAA
		      dither = fract(dither + frameR1);
		#endif

		vec3 viewPosition = vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0);

		float tileSize = min(floor(viewResolution.x * 0.5) / 1.5, floor(viewResolution.y * 0.5)) * exp2(-SKY_IMAGE_LOD);
		vec2 cmp = tileSize * vec2(3.0, 2.0);
		vec3 skyImage;
		if (gl_FragCoord.x < cmp.x && gl_FragCoord.y < cmp.y) {
			vec3 viewVector = UnprojectSky(screenCoord, SKY_IMAGE_LOD);

			vec3 tmp;
			RenderSky(viewPosition, viewVector, 0.5, skyImage, tmp);
		} else {
			skyImage = vec3(0.0);
		}

		skyImage_cloudShadow.rgb = skyImage;

		#ifdef CLOUDS3D
			skyImage_cloudShadow.a = CalculateCloudShadowMap();
		#else
			skyImage_cloudShadow.a = 1.0;
		#endif
	}
#endif
