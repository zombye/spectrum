/*\
 * Program Description:
 * Renders HBAO, RSM, and the sky
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
uniform sampler2D colortex2; // Velocity buffer
uniform sampler2D colortex5; // Previous frame data
uniform sampler3D colortex7; // 3D noise
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

#ifdef RSM
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowcolor1;
#endif

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
				vec3 dir = GenerateUnitVector((vec2(x, y) + 0.5) / samples);

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

	#if defined HBAO || defined RSM
		/* DRAWBUFFERS:465 */

		layout (location = 2) out vec4 halfres;
	#else
		/* DRAWBUFFERS:46 */
	#endif

	layout (location = 0) out vec4 skyEncode;
	layout (location = 1) out vec4 skyImage_cloudShadow;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/complex.glsl"
	#include "/include/utility/dithering.glsl"
	#include "/include/utility/packing.glsl"
	#include "/include/utility/rotation.glsl"
	#include "/include/utility/spaceConversion.glsl"

	#include "/include/shared/shadowDistortion.glsl"

	#include "/include/shared/atmosphere/density.glsl"

	#include "/include/fragment/clouds2D.fsh"
	#include "/include/fragment/clouds3D.fsh"

	#include "/include/fragment/material.fsh"
	#include "/include/fragment/brdf.fsh"
	#include "/include/fragment/diffuseLighting.fsh"
	#include "/include/fragment/specularLighting.fsh"

	//--// Fragment Functions //----------------------------------------------//

	#if defined HBAO || defined RSM
		float GetLinearDepth(sampler2D depthSampler, vec2 coord) {
			//float depth = texelFetch(depthSampler, ivec2(coord * viewResolution), 0).r + gbufferProjectionInverse[1].y*exp2(-3.0);
			//return ScreenSpaceToViewSpace(depth, gbufferProjectionInverse);

			// Interpolates after linearizing, significantly reduces a lot of issues for screen-space shadows
			coord = coord * viewResolution + 0.5;

			vec2  f = fract(coord);
			ivec2 i = ivec2(coord - f);

			vec4 s = textureGather(depthSampler, i / viewResolution) * 2.0 - 1.0;
			     s = 1.0 / (gbufferProjectionInverse[2].w * s + gbufferProjectionInverse[3].w);

			s.xy = mix(s.wx, s.zy, f.x);
			return mix(s.x,  s.y,  f.y) * gbufferProjectionInverse[3].z;
		}
	#endif

	#ifdef HBAO
		float CalculateCosBaseHorizonAngle(
			vec3  Po,   // Point on the plane
			vec3  Td,   // Direction to get tangent vector for
			vec3  L,    // (Normalized) Vector in the direction of the line
			vec3  N,    // Normal vector to the plane
			float LdotN // Dot product of L and N
		) {
			vec3 negPoLd = Td - Po;

			float D = -dot(negPoLd, N) / LdotN;
			float Mu = dot(negPoLd, L);

			return (Mu + D) * inversesqrt(D * D + 2.0 * Mu * D + dot(negPoLd, negPoLd));
		}
		float CalculateCosHorizonAngle(vec3 horizonDirection, vec3 position, vec3 viewVector, vec3 normal, float NoV, float sampleOffset) {
			float cosHorizonAngle = CalculateCosBaseHorizonAngle(position, horizonDirection, viewVector, normal, NoV);

			for (int i = 0; i < HBAO_ANGLE_SAMPLES; ++i) {
				float sampleRadius = Pow2(float(i) / float(HBAO_ANGLE_SAMPLES) + sampleOffset);
				vec2 sampleCoord = ViewSpaceToScreenSpace(position + horizonDirection * sampleRadius * HBAO_RADIUS, gbufferProjection).xy;

				if (Clamp01(sampleCoord) != sampleCoord) { break; }

				//vec3 samplePosition = vec3(sampleCoord, texture(depthtex1, sampleCoord).r);
				//     samplePosition = ScreenSpaceToViewSpace(samplePosition, gbufferProjectionInverse);
				vec3 samplePosition = vec3(sampleCoord * 2.0 - 1.0, GetLinearDepth(depthtex1, sampleCoord + 0.5 * taaOffset));
				samplePosition.xy *= Diagonal(gbufferProjectionInverse).xy * -samplePosition.z;
				samplePosition.z += samplePosition.z * 2e-4; // done to prevent overocclusion in some cases

				vec3  sampleVector          = samplePosition - position;
				float sampleDistanceSquared = dot(sampleVector, sampleVector);

				if (sampleDistanceSquared > HBAO_RADIUS * HBAO_RADIUS) { continue; }

				float cosSampleAngle = dot(viewVector, sampleVector) * inversesqrt(sampleDistanceSquared);

				cosHorizonAngle = max(cosHorizonAngle, cosSampleAngle);
			}

			return cosHorizonAngle;
		}
		vec4 CalculateHBAO(vec3 position, vec3 viewVector, vec3 normal, float dither, const float ditherSize) {
			dither += 0.5 / ditherSize;

			float NoV = dot(normal, viewVector);

			mat3 rot = GetRotationMatrix(vec3(0, 0, 1), viewVector);

			vec3 normal2 = normal * rot;
			float phiN = atan(normal2.y, normal2.x);
			float sinThetaN = sqrt(Clamp01(1.0 - normal2.z * normal2.z));
			float cosThetaN = normal2.z;

			vec4 result = vec4(0.0); // xyz = direction, w = angle
			for (int i = 0; i < HBAO_DIRECTIONS; ++i) {
				float idx = i + dither;
				float phi = idx * pi / HBAO_DIRECTIONS;
				vec2 xy = vec2(cos(phi), sin(phi));
				vec3 horizonDirection = rot * vec3(xy, 0.0);

				//--// Get cosine horizon angles

				float sampleOffset = fract(idx * ditherSize * phi) / HBAO_ANGLE_SAMPLES;

				float cosTheta1 = CalculateCosHorizonAngle( horizonDirection, position, viewVector, normal, NoV, sampleOffset);
				float cosTheta2 = CalculateCosHorizonAngle(-horizonDirection, position, viewVector, normal, NoV, sampleOffset);

				//--// Integral over theta

				// Parts that are reused
				float theta1 = acos(clamp(cosTheta1, -1.0, 1.0));
				float theta2 = acos(clamp(cosTheta2, -1.0, 1.0));
				float sinThetaSq1 = 1.0 - cosTheta1 * cosTheta1;
				float sinThetaSq2 = 1.0 - cosTheta2 * cosTheta2;
				float sinTheta1 = sin(theta1);
				float sinTheta2 = sin(theta2);
				float cu1MinusCu2 = sinThetaSq1 * sinTheta1 - sinThetaSq2 * sinTheta2;

				float temp = cos(phiN - phi) * sinThetaN;

				// Average non-occluded direction
				float xym = 4.0 - cosTheta1 * (2.0 + sinThetaSq1) - cosTheta2 * (2.0 + sinThetaSq2);
				      xym = temp * xym + cosThetaN * cu1MinusCu2;

				result.xy += xy * xym;
				result.z  += temp * cu1MinusCu2 + cosThetaN * (2.0 - Pow3(cosTheta1) - Pow3(cosTheta2));

				// AO
				result.w += temp * ((theta1 - cosTheta1 * sinTheta1) - (theta2 - cosTheta2 * sinTheta2));
				result.w += cosThetaN * (sinThetaSq1 + sinThetaSq2);
			}

			float coneLength = length(result.xyz);
			result.xyz = coneLength <= 0.0 ? normal : rot * result.xyz / coneLength;
			result.w /= 2.0 * HBAO_DIRECTIONS;

			return result;
		}

		/*
		float RTAO(mat3 position, vec3 normal, float dither, out vec3 lightdir) {
			const int rays = RTAO_RAYS;
			normal = mat3(gbufferModelView) * normal;

			lightdir = vec3(0.0);
			float ao = 0.0;
			for (int i = 0; i < rays; ++i) {
				vec3 dir = GenerateUnitVector(Hash2(vec2(dither, i / float(rays))));
				float NoL = dot(dir, normal);
				if (NoL < 0.0) {
					dir = -dir;
					NoL = -NoL;
				}

				vec3 hitPos = position[0];
				if (!RaytraceIntersection(hitPos, position[1], dir, dither, HBAO_RADIUS, RTAO_RAY_STEPS, 4)) {
					lightdir += dir * NoL;
					ao += NoL;
				}
			}
			float ldl = dot(lightdir, lightdir);
			lightdir = ldl == 0.0 ? normal : lightdir * inversesqrt(ldl);
			lightdir = mat3(gbufferModelViewInverse) * lightdir;

			return ao * 2.0 / rays;
		}
		*/
	#endif

	#ifdef RSM
		vec3 ReflectiveShadowMaps(vec3 position, vec3 normal, float skylight, float dither, const float ditherSize) {
			dither = dither * ditherSize + 0.5;
			float dither2 = dither / ditherSize;

			const float radiusSquared     = RSM_RADIUS * RSM_RADIUS;
			const float perSampleArea     = pi * radiusSquared / RSM_SAMPLES;
			const float sampleDistanceAdd = sqrt((perSampleArea / RSM_SAMPLES) / pi); // Added to sampleDistanceSquared to prevent fireflies

			vec3 projectionScale        = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z / SHADOW_DEPTH_SCALE);
			vec3 projectionInverseScale = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z * SHADOW_DEPTH_SCALE);
			vec2 offsetScale            = RSM_RADIUS * projectionScale.xy;

			vec3 shadowPosition = mat3(shadowModelView) * position + shadowModelView[3].xyz;
			vec3 shadowClip     = projectionScale * shadowPosition + shadowProjection[3].xyz;
			vec3 shadowNormal   = mat3(shadowModelView) * normal;

			mat2 rot = GetRotationMatrix(ditherSize * goldenAngle);

			vec3 rsm = vec3(0.0);
			vec2 dir = SinCos(dither * goldenAngle);
			for (int i = 0; i < RSM_SAMPLES; ++i) {
				float r = (i + dither2) / RSM_SAMPLES;
				vec2 sampleOffset = dir * offsetScale * r;
				dir *= rot;

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

				vec3 shadowcolor0Sample = textureLod(shadowcolor0, sampleCoord, 0.0).rgb;
				vec3 sampleNormal = DecodeNormal(shadowcolor0Sample.rg * 2.0 - 1.0);

				// Calculate BRDF (lambertian)
				float sampleIn  = 2.0 * r; // Light's projected area for each sample
				float sampleOut = Clamp01(dot(sampleNormal, -sampleVector)) / pi; // Divide by pi for energy conservation.
				float bounceIn  = Clamp01(dot(shadowNormal,  sampleVector));
				const float bounceOut = 1.0 / pi; // Divide by pi for energy conservation.

				float brdf = sampleIn * sampleOut * bounceIn * bounceOut;

				#ifdef RSM_LEAK_PREVENTION
					float sampleSkylight = shadowcolor0Sample.b;
					brdf *= Clamp01(1.0 - 5.0 * abs(sampleSkylight - skylight));
				#endif

				vec4 sampleAlbedo = textureLod(shadowcolor1, sampleCoord, 0.0);
				rsm += LinearFromSrgb(sampleAlbedo.rgb) * sampleAlbedo.a * brdf / (sampleDistanceSquared + sampleDistanceAdd);
			}

			return rsm * perSampleArea;
		}
	#endif

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

	void DitherTiles(ivec2 fragCoord, int patternSize, float scale, out ivec2 tile, out ivec2 tileFragCoord, out vec2 tileScreenCoord) {
		ivec2 quadResolution      = ivec2(ceil(viewResolution / scale));
		ivec2 floorTileResolution = ivec2(floor(vec2(quadResolution) / float(patternSize)));
		ivec2 ceilTileResolution  = ivec2( ceil(vec2(quadResolution) / float(patternSize)));

		fragCoord = fragCoord % quadResolution;

		ivec2 ceilTiles         = quadResolution % patternSize;
		ivec2 tileSizeThreshold = ceilTileResolution * ceilTiles;
		bvec2 belowThreshold;
		belowThreshold.x = fragCoord.x < tileSizeThreshold.x;
		belowThreshold.y = fragCoord.y < tileSizeThreshold.y;

		ivec2 tileResolution;
		tileResolution.x = belowThreshold.x ? ceilTileResolution.x : floorTileResolution.x;
		tileResolution.y = belowThreshold.y ? ceilTileResolution.y : floorTileResolution.y;

		tileFragCoord.x = belowThreshold.x ? fragCoord.x : fragCoord.x - tileSizeThreshold.x;
		tileFragCoord.y = belowThreshold.y ? fragCoord.y : fragCoord.y - tileSizeThreshold.y;

		tile = tileFragCoord / tileResolution;
		tile.x += belowThreshold.x ? 0 : ceilTiles.x;
		tile.y += belowThreshold.y ? 0 : ceilTiles.y;
		tileFragCoord = tileFragCoord % tileResolution;

		tileFragCoord = tileFragCoord * patternSize + tile;
		tileScreenCoord = (tileFragCoord + 0.5) * scale / viewResolution;
	}

	//------------------------------------------------------------------------//

	vec3 CalculateStars(vec3 background, vec3 viewVector) {
		const float scale = 256.0;
		const float coverage = 0.01;
		const float maxLuminance = 0.7 * NIGHT_SKY_BRIGHTNESS;
		const float minTemperature = 1500.0;
		const float maxTemperature = 9000.0;

		viewVector = Rotate(viewVector, sunVector, vec3(0, 0, 1));

		// TODO: Calculate for surrounding cells as well to allow uniform apparent size

		vec3  p = viewVector * scale;
		ivec3 i = ivec3(floor(p));
		vec3  f = p - i;
		float r = dot(f - 0.5, f - 0.5);

		vec2 hash = Hash2(i);
		hash.y = 2.0 * hash.y - 4.0 * hash.y * hash.y + 3.0 * hash.y * hash.y * hash.y;

		vec3 luminance = Pow2(LinearStep(1.0 - coverage, 1.0, hash.x)) * Blackbody(mix(minTemperature, maxTemperature, hash.y));
		return background + maxLuminance * LinearStep(0.25, 0.0, r) * Pow2(LinearStep(1.0 - coverage, 1.0, hash.x)) * Blackbody(mix(minTemperature, maxTemperature, hash.y));
	}

	vec3 CalculateSun(vec3 background, vec3 viewVector, vec3 sunVector) {
		float cosTheta = dot(viewVector, sunVector);

		if (cosTheta < cos(sunAngularRadius)) { return background; }

		// limb darkening approximation
		const vec3 a = vec3(0.397, 0.503, 0.652);
		const vec3 halfa = a * 0.5;
		const vec3 normalizationConst = vec3(0.83438, 0.79904, 0.75415); // changes with `a` and `sunAngularRadius`

		float x = Clamp01(acos(cosTheta) / sunAngularRadius);
		vec3 sunDisk = exp2(log2(1.0 - x * x) * halfa) / normalizationConst;

		return sunLuminance * sunDisk;
	}

	vec3 CalculateMoon(vec3 background, vec3 viewVector, vec3 moonVector) {
		const float roughness = 0.4;
		const float roughnessSquared = roughness * roughness;

		// -- Find normal and calculate dot products for lighting

		vec2 dists = RaySphereIntersection(-moonVector, viewVector, sin(moonAngularRadius));
		if (dists.y < 0.0) { return background; }

		vec3 normal = normalize(viewVector * dists.x - moonVector);

		float NoL = dot(normal, sunVector);
		float LoV = dot(sunVector, -viewVector);
		float NoV = dot(normal, -viewVector);
		float rcpLen_LV = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * rcpLen_LV;
		float VoH = LoV * rcpLen_LV + rcpLen_LV;

		vec3 diffuse = DiffuseHammon(NoL, NoH, NoV, LoV, moonAlbedo, roughness);

		// Specular
		float f  = FresnelDielectric(VoH, 1.0 / 1.45);
		float d  = DistributionGGX(NoH, roughnessSquared);
		float g2 = G2SmithGGX(NoL, NoV, roughnessSquared);

		float specular = f * d * g2 // BRDF
		               * NoL / NoV; // incoming spread / outgoing gather

		// Return result
		return sunIlluminance * (diffuse + specular);
	}

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
			float clouds3DDistance = 0.0;
			vec4 clouds3D = Render3DClouds(viewVector, dither, clouds3DDistance);

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
				vec4 clouds2D = Calculate2DClouds(viewVector, dither);
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

		//--// AO & RSM //----------------------------------------------------//

		#if defined HBAO || defined RSM
			halfres = vec4(0.0);
		#endif

		#ifdef RSM
			if (screenCoord.x > 0.5 && screenCoord.y < 0.5) {
				ivec2 tile, tileFragCoord; vec2 tileScreenCoord;
				DitherTiles(fragCoord, 16, 2.0, tile, tileFragCoord, tileScreenCoord);
				//tile = fragCoord % 8; tileFragCoord = fragCoord % ivec2(viewResolution / 2); tileScreenCoord = screenCoord * 2.0;

				mat3 position;
				position[0].xy = tileScreenCoord;
				#ifdef TAA
				position[0].xy -= taaOffset * 0.5;
				#endif
				position[1]    = GetViewDirection(position[0].xy, gbufferProjectionInverse);
				position[1]   *= GetLinearDepth(depthtex1, tileScreenCoord) / position[1].z;
				position[0].z  = ViewSpaceToScreenSpace(position[1].z, gbufferProjection);

				if (position[0].z < 1.0) {
					position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;

					vec3 normal = DecodeNormal(Unpack2x8(texelFetch(colortex1, tileFragCoord * 2, 0).a) * 2.0 - 1.0);
					float skylight = Unpack2x8Y(texelFetch(colortex0, tileFragCoord * 2, 0).b);

					const float ditherSize = 16.0 * 16.0;
					float dither = Bayer16(tile);

					halfres.rgb = ReflectiveShadowMaps(position[2], normal, skylight, dither, ditherSize);
					halfres.a = 1.0;
				} else {
					halfres = vec4(0.0, 0.0, 0.0, 1.0);
				}
			}
		#endif

		#ifdef HBAO
			if (screenCoord.x < 0.5 && screenCoord.y < 0.5) {
				mat3 position;
				position[0].xy = screenCoord * 2.0;
				#ifdef TAA
				position[0].xy -= taaOffset * 0.5;
				#endif
				position[1]    = GetViewDirection(position[0].xy, gbufferProjectionInverse);
				position[1]   *= GetLinearDepth(depthtex1, screenCoord * 2.0) / position[1].z;
				position[0].z  = ViewSpaceToScreenSpace(position[1].z, gbufferProjection);

				if (position[0].z < 1.0) {
					position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;

					vec3 normal = DecodeNormal(Unpack2x8(texelFetch(colortex1, fragCoord * 2, 0).a) * 2.0 - 1.0);
					float skylight = Unpack2x8Y(texelFetch(colortex0, fragCoord * 2, 0).b);

					const float ditherSize = 4.0 * 4.0;
					float dither = Bayer4(fragCoord);

					halfres = CalculateHBAO(position[1], -normalize(position[1]), mat3(gbufferModelView) * normal, dither, ditherSize);
					halfres.xyz = mat3(gbufferModelViewInverse) * halfres.xyz;

					halfres.xyz = normalize(halfres.xyz);
				} else {
					halfres = vec4(0.0, 0.0, 0.0, 1.0);
				}
			}
		#endif

		//--// Sky //---------------------------------------------------------//

		const float ditherSize = 16.0 * 16.0;
		float dither = Bayer16(gl_FragCoord.st);
		#ifdef TAA
		      dither = fract(dither + frameR1);
		#endif

		vec3 viewPosition = vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0);

		float depth = texture(depthtex1, screenCoord).x;
		if (depth >= 1.0) {
			vec3 positionScreen = vec3(screenCoord, depth);
			#ifdef TAA
			positionScreen.xy -= 0.5 * taaOffset;
			#endif
			vec3 viewVector = mat3(gbufferModelViewInverse) * GetViewDirection(positionScreen.xy, gbufferProjectionInverse);

			vec3 color = vec3(0.0);
			color = CalculateStars(color, viewVector);
			color = CalculateSun(color, viewVector, sunVector);
			color = CalculateMoon(color, viewVector, moonVector);

			vec3 scattering, transmittance;
			RenderSky(viewPosition, viewVector, dither, scattering, transmittance);
			color = color * transmittance + scattering;

			skyEncode = EncodeRGBE8(color);
		} else {
			skyEncode = vec4(0.0);
		}

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
