/*\
 * Program Description:
 * Renders clouds
\*/

//--// Settings

#include "/settings.glsl"

//--// Uniforms

uniform float far;

uniform float sunAngle;

uniform float wetness;

uniform float eyeAltitude;
uniform vec3 cameraPosition;

// Time
uniform int   frameCounter;
uniform float frameTimeCounter;

uniform int worldDay;
uniform int worldTime;

// Gbuffer Uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D depthtex1;

// Shadow uniforms
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

// Misc samplers
uniform sampler2D colortex1;
uniform sampler2D colortex5; // Sky Scattering LUT
uniform sampler2D colortex7; // Sky Transmittance LUT
uniform sampler2D noisetex;

// Custom Uniforms
uniform vec2 viewResolution;
uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 sunVector;

uniform vec3 moonVector;

uniform vec3 shadowLightVector;

//--// Shared Libraries

#include "/lib/utility.glsl"
#include "/lib/utility/colorspace.glsl"
#include "/lib/utility/encoding.glsl"
#include "/lib/utility/math.glsl"
#include "/lib/utility/noise.glsl"
#include "/lib/utility/sampling.glsl"

#include "/lib/shared/celestialConstants.glsl"

#include "/lib/shared/atmosphere/constants.glsl"
#include "/lib/shared/atmosphere/lookup.glsl"
#include "/lib/shared/atmosphere/transmittance.glsl"
#include "/lib/shared/atmosphere/phase.glsl"
#include "/lib/shared/atmosphere/scattering.glsl"

#include "/lib/shared/skyProjection.glsl"

//--// Shared Functions

#if STAGE == STAGE_VERTEX
	//--// Vertex Outputs

	out vec2 screenCoord;

	out vec3 skyAmbient;
	out vec3 skyAmbientUp;
	out vec3 illuminanceShadowlight;

	out float averageCloudTransmittance;

	//--// Vertex Libraries

	#include "/lib/fragment/clouds3D.fsh"

	//--// Vertex Functions

	void main() {
		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);

		const ivec2 samples = ivec2(16, 8);

		skyAmbient = vec3(0.0);
		skyAmbientUp = vec3(0.0);
		for (int x = 0; x < samples.x; ++x) {
			for (int y = 0; y < samples.y; ++y) {
				vec3 dir = GenUnitVector((vec2(x, y) + 0.5) / samples);

				vec3 skySample  = AtmosphereScattering(colortex5, vec3(0.0, atmosphere_planetRadius, 0.0), dir, sunVector ) * sunIlluminance;
				     skySample += AtmosphereScattering(colortex5, vec3(0.0, atmosphere_planetRadius, 0.0), dir, moonVector) * moonIlluminance;

				skyAmbient += skySample;
				skyAmbientUp += skySample * Clamp01(dir.y);
			}
		}

		const float sampleWeight = 4.0 * pi / (samples.x * samples.y);
		skyAmbient *= sampleWeight;
		skyAmbientUp *= sampleWeight;

		vec3 shadowlightTransmittance = AtmosphereTransmittance(colortex7, vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector);
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * shadowlightTransmittance;

		averageCloudTransmittance = CalculateAverageCloudTransmittance(GetCloudCoverage());
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	in vec3 skyAmbient;
	in vec3 skyAmbientUp;
	in vec3 illuminanceShadowlight;

	in float averageCloudTransmittance;

	//--// Fragment Outputs

	#ifdef RSM
		/* DRAWBUFFERS:3462 */

		layout (location = 3) out vec4 rsmEncode;
	#else
		/* DRAWBUFFERS:3462 */
	#endif

	layout (location = 0) out float cloudTransmittance;
	layout (location = 1) out vec4  scatteringEncode;
	layout (location = 2) out vec3  skyImage;

	//--// Fragment Libraries

	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/packing.glsl"
	#include "/lib/utility/spaceConversion.glsl"

	#include "/lib/shared/shadowDistortion.glsl"

	#include "/lib/shared/atmosphere/raymarch/transmittance.glsl"

	#include "/lib/fragment/clouds2D.fsh"
	#include "/lib/fragment/clouds3D.fsh"

	//--// Fragment Functions

	vec3 ReflectiveShadowMaps(vec3 position, vec3 normal, float dither, const float ditherSize) {
		dither = dither * ditherSize + 0.5;
		float dither2 = dither / ditherSize;

		const float radiusSquared     = RSM_RADIUS * RSM_RADIUS;
		const float perSampleArea     = pi * radiusSquared / RSM_SAMPLES;
		const float sampleDistanceAdd = sqrt(perSampleArea / pi); // Added to sampleDistanceSquared to prevent fireflies

		vec3 projectionScale        = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z / SHADOW_DEPTH_SCALE);
		vec3 projectionInverseScale = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z * SHADOW_DEPTH_SCALE);
		vec2 offsetScale            = RSM_RADIUS * projectionScale.xy;

		vec3 shadowPosition = mat3(shadowModelView) * position + shadowModelView[3].xyz;
		vec3 shadowClip     = projectionScale * shadowPosition + shadowProjection[3].xyz;
		vec3 shadowNormal   = mat3(shadowModelView) * normal;

		vec3 rsm = vec3(0.0);
		vec2 dir = SinCos(dither * goldenAngle);
		for (int i = 0; i < RSM_SAMPLES; ++i) {
			vec2 sampleOffset = dir * offsetScale * sqrt((i + dither2) / RSM_SAMPLES);
			dir *= rotateGoldenAngle;

			vec3 sampleClip     = shadowClip;
			     sampleClip.xy += sampleOffset;

			float distortionFactor = CalculateDistortionFactor(sampleClip.xy);
			vec2 sampleCoord    = (sampleClip.xy * distortionFactor) * 0.5 + 0.5;
			     sampleClip.z   = textureLod(shadowtex0, sampleCoord, 0.0).r * 2.0 - 1.0;
			vec3 samplePosition = projectionInverseScale * sampleClip + shadowProjectionInverse[3].xyz;

			vec3  sampleVector          = samplePosition - shadowPosition;
			float sampleDistanceSquared = dot(sampleVector, sampleVector);

			if (sampleDistanceSquared > radiusSquared) { continue; } // Discard samples that are too far away

			sampleVector *= inversesqrt(sampleDistanceSquared);

			vec3 sampleNormal = DecodeNormal(textureLod(shadowcolor1, sampleCoord, 0.0).rg * 2.0 - 1.0);

			// Calculate BRDF (lambertian)
			//float sampleIn  = 1.0; // We're sampling the lights projected area so this is just 1.
			float sampleOut = Clamp01(dot(sampleNormal, -sampleVector)) / pi; // Divide by pi for energy conservation.
			float bounceIn  = Clamp01(dot(shadowNormal,  sampleVector));
			float bounceOut = 1.0 / pi; // Divide by pi for energy conservation.

			float brdf = sampleOut * bounceIn * bounceOut;

			vec4 sampleAlbedo = textureLod(shadowcolor0, sampleCoord, 0.0);
			rsm += SrgbToLinear(sampleAlbedo.rgb) * sampleAlbedo.a * brdf / (sampleDistanceSquared + sampleDistanceAdd);
		}

		return rsm * perSampleArea;
	}

	mat2x3 CloudShadowedAtmosphere(vec3 startPosition, vec3 viewVector, float endDistance, float cloudCoverage, float dither) {
		const int steps = 15;
		//int steps = int(ceil(endDistance / 1000.0));

		float stepSize = abs(endDistance / steps);
		vec3 increment = viewVector * stepSize;
		vec3 position  = startPosition + increment * dither;

		vec3 scattering = vec3(0.0);
		vec3 transmittance = vec3(1.0);

		vec3 sun  = AtmosphereScattering(colortex5, position, viewVector, sunVector ) * sunIlluminance;
		vec3 moon = AtmosphereScattering(colortex5, position, viewVector, moonVector) * moonIlluminance;
		for (int i = 0; i < steps; ++i) {
			float cloudShadow = Calculate3DCloudShadows(position + vec3(cameraPosition.x, -atmosphere_planetRadius, cameraPosition.z), cloudCoverage, 3);
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

			sun  = Max0(AtmosphereScattering(colortex5, position, viewVector, sunVector )) * sunIlluminance;
			moon = Max0(AtmosphereScattering(colortex5, position, viewVector, moonVector)) * moonIlluminance;
			if (sunAngle < 0.5) {
				scattering -= (sun * cloudShadow + moon) * transmittance;
			} else {
				scattering -= (sun + moon * cloudShadow) * transmittance;
			}
		}

		return mat2x3(scattering, transmittance);
	}

	void main() {
		#ifdef TAA
			const float ditherSize = 16.0 * 16.0 * 16.0;
			float dither = Bayer16(gl_FragCoord.st) + (frameCounter % 16) / ditherSize; // should use like a Nx1 bayer matrix for the temporal part
		#else
			const float ditherSize = 16.0 * 16.0;
			float dither = Bayer16(gl_FragCoord.st);
		#endif

		//--// RSM //---------------------------------------------------------//

		#ifdef RSM
			if (screenCoord.x < 0.5 && screenCoord.y < 0.5) {
				mat3 position;
				position[0] = vec3(screenCoord * 2.0, texture(depthtex1, screenCoord * 2.0).r);
				position[1] = ScreenSpaceToViewSpace(position[0], gbufferProjectionInverse);
				position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;

				vec3 normal = DecodeNormal(Unpack2x8(texelFetch(colortex1, ivec2(gl_FragCoord.st * 2.0), 0).a) * 2.0 - 1.0);

				const float ditherSize = 8.0 * 8.0;
				float dither = Bayer8(gl_FragCoord.st);

				vec3 rsm = ReflectiveShadowMaps(position[2], normal, dither, ditherSize);
				rsmEncode = EncodeRGBE8(rsm);
			} else {
				rsmEncode = vec4(0.0);
			}
		#endif

		//--// Sky //---------------------------------------------------------//

		vec3 viewPosition  = vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0);
		float cloudCoverage = GetCloudCoverage();

		vec4 depths = textureGather(depthtex1, screenCoord * exp2(SKY_RENDER_LOD));
		if (screenCoord.x <= exp2(-SKY_RENDER_LOD) && screenCoord.y <= exp2(-SKY_RENDER_LOD) && (depths.x >= 1.0 || depths.y >= 1.0 || depths.z >= 1.0 || depths.w >= 1.0)) {
			mat3 position;
			position[0] = vec3(screenCoord * exp2(SKY_RENDER_LOD), 1.0);
			position[1] = ScreenSpaceToViewSpace(position[0], gbufferProjectionInverse);
			position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;
			vec3 viewVector = normalize(position[2] - gbufferModelViewInverse[3].xyz);

			cloudTransmittance = 1.0;
			#ifdef CLOUDS3D
				vec3 scattering = vec3(0.0);

				float lowerLimitDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_lowerLimitRadius).x;
				if (lowerLimitDistance < 0.0) {
					#ifdef DISTANT_VL
						float clouds3DDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN).y;
						#if DISTANT_VL_RANGE <= 0
							float vlEndDistance = clouds3DDistance;
						#else
							float vlEndDistance = min(clouds3DDistance, DISTANT_VL_RANGE * 1e3);
						#endif

						mat2x3 distantVl = CloudShadowedAtmosphere(viewPosition, viewVector, vlEndDistance, cloudCoverage, dither);
						scattering = distantVl[0];
						vec3 transmittance = distantVl[1];

						vec3 vlEndPosition = vlEndDistance * viewVector + viewPosition;
						vec3 atmosphereScattering  = AtmosphereScattering(colortex5, vlEndPosition, viewVector, sunVector ) * sunIlluminance;
						     atmosphereScattering += AtmosphereScattering(colortex5, vlEndPosition, viewVector, moonVector) * moonIlluminance;
						scattering += atmosphereScattering * transmittance * averageCloudTransmittance;
					#else
						scattering  = AtmosphereScattering(colortex5, viewPosition, viewVector, sunVector ) * sunIlluminance;
						scattering += AtmosphereScattering(colortex5, viewPosition, viewVector, moonVector) * moonIlluminance;
					#endif

					#ifdef CLOUDS3D
						#ifdef DISTANT_VL
							transmittance *= AtmosphereTransmittance(colortex7, vlEndPosition, viewVector, Max0(clouds3DDistance - vlEndDistance));
						#else
							scattering *= averageCloudTransmittance;
							float clouds3DDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN).y;

							vec3 transmittance = AtmosphereTransmittance(colortex7, viewPosition, viewVector, clouds3DDistance);
							vec3 atmosphereScattering;
						#endif

						vec3 clouds3DPosition = clouds3DDistance * viewVector + viewPosition;
						atmosphereScattering  = AtmosphereScattering(colortex5, clouds3DPosition, viewVector, sunVector ) * sunIlluminance;
						atmosphereScattering += AtmosphereScattering(colortex5, clouds3DPosition, viewVector, moonVector) * moonIlluminance;
						scattering -= atmosphereScattering * transmittance * averageCloudTransmittance;

						vec4 clouds3D = Calculate3DClouds(viewVector, dither);
						scattering += clouds3D.rgb * transmittance; transmittance *= clouds3D.a;
						cloudTransmittance *= clouds3D.a;

						scattering += atmosphereScattering * transmittance;
					#endif
				} else {
					#ifdef DISTANT_VL
						#if DISTANT_VL_RANGE <= 0
							float vlEndDistance = lowerLimitDistance;
						#else
							float vlEndDistance = min(lowerLimitDistance, DISTANT_VL_RANGE * 1e3);
						#endif

						mat2x3 distantVl = CloudShadowedAtmosphere(viewPosition, viewVector, vlEndDistance, cloudCoverage, dither);
						scattering = distantVl[0];
						vec3 transmittance = AtmosphereTransmittance(colortex7, viewPosition, viewVector, vlEndDistance);

						vec3 vlEndPosition = vlEndDistance * viewVector + viewPosition;
						vec3 atmosphereScattering  = AtmosphereScattering(colortex5, vlEndPosition, viewVector, sunVector ) * sunIlluminance;
						     atmosphereScattering += AtmosphereScattering(colortex5, vlEndPosition, viewVector, moonVector) * moonIlluminance;
						scattering += atmosphereScattering * transmittance * averageCloudTransmittance;
					#else
						scattering  = AtmosphereScattering(colortex5, viewPosition, viewVector, sunVector ) * sunIlluminance;
						scattering += AtmosphereScattering(colortex5, viewPosition, viewVector, moonVector) * moonIlluminance;

						scattering *= averageCloudTransmittance;
					#endif
				}
			#else
				// Atmosphere
				vec3 scattering  = AtmosphereScattering(colortex5, viewPosition, viewVector, sunVector ) * sunIlluminance;
				     scattering += AtmosphereScattering(colortex5, viewPosition, viewVector, moonVector) * moonIlluminance;
			#endif

			scatteringEncode = EncodeRGBE8(scattering);
		} else {
			cloudTransmittance = 1.0;
			scatteringEncode = vec4(0.0);
		}

		float tileSize = min(floor(viewResolution.x * 0.5) / 1.5, floor(viewResolution.y * 0.5)) * exp2(-SKY_IMAGE_LOD);
		vec2 cmp = tileSize * vec2(3.0, 2.0);
		if (gl_FragCoord.x < cmp.x && gl_FragCoord.y < cmp.y) {
			vec3 viewVector = UnprojectSky(screenCoord, SKY_IMAGE_LOD);

			#if defined CLOUDS2D || defined CLOUDS3D
				float lowerLimitDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_lowerLimitRadius).x;
				if (lowerLimitDistance < 0.0) {
					skyImage  = AtmosphereScattering(colortex5, viewPosition, viewVector, sunVector ) * sunIlluminance;
					skyImage += AtmosphereScattering(colortex5, viewPosition, viewVector, moonVector) * moonIlluminance;

					#ifdef CLOUDS3D
						skyImage *= averageCloudTransmittance;

						float clouds3DDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN).y;
						vec3  clouds3DPosition = clouds3DDistance * viewVector + viewPosition;

						vec3 transmittance = AtmosphereTransmittance(colortex7, viewPosition, viewVector, clouds3DDistance);
						vec3 atmosphereScattering;

						atmosphereScattering  = AtmosphereScattering(colortex5, clouds3DPosition, viewVector, sunVector ) * sunIlluminance;
						atmosphereScattering += AtmosphereScattering(colortex5, clouds3DPosition, viewVector, moonVector) * moonIlluminance;
						skyImage -= atmosphereScattering * transmittance * averageCloudTransmittance;

						vec4 clouds3D = Calculate3DClouds(viewVector, 0.5);
						skyImage += clouds3D.rgb * transmittance; transmittance *= clouds3D.a;

						skyImage += atmosphereScattering * transmittance;
					#endif

					#ifdef CLOUDS2D
						float clouds2DDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_planetRadius + CLOUDS2D_ALTITUDE).y;
						vec3  clouds2DPosition = clouds2DDistance * viewVector + viewPosition;

						#ifdef CLOUDS3D
							transmittance *= AtmosphereTransmittance(colortex7, clouds3DPosition, viewVector, clouds2DDistance - clouds3DDistance);
						#else
							vec3 transmittance = AtmosphereTransmittance(colortex7, viewPosition, viewVector, clouds2DDistance);
							vec3 atmosphereScattering;
						#endif

						atmosphereScattering  = AtmosphereScattering(colortex5, clouds2DPosition, viewVector, sunVector ) * sunIlluminance;
						atmosphereScattering += AtmosphereScattering(colortex5, clouds2DPosition, viewVector, moonVector) * moonIlluminance;
						skyImage -= atmosphereScattering * transmittance;

						vec4 clouds2D = Calculate2DClouds(viewVector, 0.5);
						skyImage += clouds2D.rgb * transmittance; transmittance *= clouds2D.a;

						skyImage += atmosphereScattering * transmittance;
					#endif
				} else {
					skyImage  = AtmosphereScattering(colortex5, viewPosition, viewVector, sunVector ) * sunIlluminance;
					skyImage += AtmosphereScattering(colortex5, viewPosition, viewVector, moonVector) * moonIlluminance;

					#ifdef CLOUDS3D
						skyImage *= averageCloudTransmittance;
					#endif
				}
			#else
				skyImage  = AtmosphereScattering(colortex5, viewPosition, viewVector, sunVector ) * sunIlluminance;
				skyImage += AtmosphereScattering(colortex5, viewPosition, viewVector, moonVector) * moonIlluminance;
			#endif
		} else {
			skyImage = vec3(0.0);
		}
	}
#endif
