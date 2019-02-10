/*\
 * Program Description:
\*/

//--// Settings

#include "/settings.glsl"

#define REFRACTION_OFF 0
#define REFRACTION_WATER_ONLY 1
#define REFRACTION_FULL 2
#define REFRACTION_MODE REFRACTION_WATER_ONLY // [REFRACTION_OFF REFRACTION_WATER_ONLY REFRACTION_FULL]
//#define REFRACTION_RAYTRACED

//--// Uniforms

//
uniform float sunAngle;

uniform float wetness;

uniform int isEyeInWater;
uniform ivec2 eyeBrightness;
uniform vec3 cameraPosition;

uniform float fogDensity = 0.1;

uniform float eyeAltitude;

uniform float far;

// Time
uniform int frameCounter;
uniform float frameTimeCounter;

uniform int worldDay;
uniform int worldTime;

// Gbuffer Uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

// Shadow Uniforms
uniform mat4 shadowModelView;
#if defined VL_AIR || defined VL_WATER
	uniform mat4 shadowProjection;

	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;
	uniform sampler2D shadowcolor0;
	#ifdef SHADOW_COLORED
		uniform sampler2D shadowcolor1;
	#endif
#endif

//
uniform sampler2D colortex0; // Gbuffer0
uniform sampler2D colortex1; // Gbuffer1
uniform sampler2D colortex2; // Shadows
uniform sampler2D colortex3; // Transparent color
uniform sampler2D colortex4; // Main color
uniform sampler2D colortex6; // Sky Scattering Image
uniform sampler2D colortex7; // Sky Transmittance LUT
uniform sampler2D noisetex;

// Custom Uniforms
uniform vec2 viewResolution;
uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 sunVector;

uniform vec3 shadowLightVector;

//--// Shared Libraries

#include "/lib/utility.glsl"
#include "/lib/utility/colorspace.glsl"
#include "/lib/utility/encoding.glsl"
#include "/lib/utility/sampling.glsl"

#include "/lib/shared/celestialConstants.glsl"
#include "/lib/shared/skyProjection.glsl"

#include "/lib/shared/atmosphere/constants.glsl"
#include "/lib/shared/atmosphere/lookup.glsl"
#include "/lib/shared/atmosphere/transmittance.glsl"

//--// Shared Functions

#if STAGE == STAGE_VERTEX
	//--// Vertex Outputs

	out vec2 screenCoord;

	out vec3 luminanceShadowlight;
	out vec3 illuminanceShadowlight;

	out vec3 illuminanceSky;

	//--// Vertex Libraries

	//--// Vertex Functions

	void main() {
		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);

		const ivec2 samples = ivec2(16, 8);

		illuminanceSky = vec3(0.0);
		for (int x = 0; x < samples.x; ++x) {
			for (int y = 0; y < samples.y; ++y) {
				vec3 dir = GenerateUnitVector((vec2(x, y) + 0.5) / samples);

				vec3 skySample = texture(colortex6, ProjectSky(dir, SKY_IMAGE_LOD)).rgb;
				illuminanceSky += skySample * step(0.0, dir.y);
			}
		}

		const float sampleWeight = 4.0 * pi / (samples.x * samples.y);
		illuminanceSky *= sampleWeight;

		vec3 shadowlightTransmittance  = AtmosphereTransmittance(colortex7, vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector);
		     shadowlightTransmittance *= smoothstep(0.0, 0.01, abs(shadowLightVector.y));
		luminanceShadowlight   = (sunAngle < 0.5 ? sunLuminance   : moonLuminance)   * shadowlightTransmittance;
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * shadowlightTransmittance;
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	in vec3 luminanceShadowlight;
	in vec3 illuminanceShadowlight;

	in vec3 illuminanceSky;

	//--// Fragment Outputs

	/* DRAWBUFFERS:6 */

	layout (location = 0) out vec3 color;

	//--// Fragment Libraries

	#include "/lib/utility/complex.glsl"
	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/math.glsl"
	#include "/lib/utility/noise.glsl"
	#include "/lib/utility/packing.glsl"
	#include "/lib/utility/rotation.glsl"
	#include "/lib/utility/spaceConversion.glsl"

	#include "/lib/fragment/clouds3D.fsh"

	#if defined VL_AIR || defined VL_WATER
		#include "/lib/shared/shadowDistortion.glsl"

		#ifdef SHADOW_COLORED
			vec3 ReadShadowMaps(vec3 shadowCoord) {
				float shadow0 = textureLod(shadowtex0, shadowCoord.st, 0.0).r;
				      shadow0 = shadow0 < 1.0 ? step(shadowCoord.z, shadow0) : 1.0;
				float shadow1 = textureLod(shadowtex1, shadowCoord.st, 0.0).r;
				      shadow1 = shadow1 < 1.0 ? step(shadowCoord.z, shadow1) : 1.0;
				vec4  shadowC = textureLod(shadowcolor1, shadowCoord.st, 0.0);
				      shadowC.rgb = SrgbToLinear(shadowC.rgb);

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

	#include "/lib/shared/atmosphere/density.glsl"
	#include "/lib/shared/atmosphere/phase.glsl"

	vec3 CalculateAirFog(vec3 background, vec3 startPosition, vec3 endPosition, vec3 viewVector, float LoV, float startSkylight, float endSkylight, float dither, bool sky) {
		float skylight = startSkylight * (1.0 - endSkylight) + endSkylight;

		vec2 phaseSun = AtmospherePhases(LoV, atmosphere_mieg);
		const vec2 phaseSky = vec2(0.25 / pi);

		const vec3 baseAttenuationCoefficient = atmosphere_coefficientsAttenuation[0] + atmosphere_coefficientsAttenuation[1] + atmosphere_coefficientsAttenuation[2];

		#ifdef VL_AIR
			const int steps = 6;

			if (sky) {
				endPosition = startPosition + viewVector * far;
			}

			//--//

			vec3 incrementWorld = (endPosition - startPosition) / steps;
			vec3 worldPosition  = startPosition + incrementWorld * dither;

			vec3 incrementShadow    = mat3(shadowModelView) * incrementWorld;
			     incrementShadow   *= Diagonal(shadowProjection).xyz;
			     incrementShadow.z /= SHADOW_DEPTH_SCALE;
			vec3 shadowPosition     = mat3(shadowModelView) * startPosition + shadowModelView[3].xyz;
			     shadowPosition     = Diagonal(shadowProjection).xyz * shadowPosition + shadowProjection[3].xyz;
			     shadowPosition.z  /= SHADOW_DEPTH_SCALE;
			     shadowPosition    += dither * incrementShadow;

			float stepSize = length(incrementWorld);

			//--//

			vec3 scatteringSun = vec3(0.0);
			vec3 scatteringSky = vec3(0.0);
			vec3 transmittance = vec3(1.0);
			for (int i = 0; i < steps; ++i, worldPosition += incrementWorld, shadowPosition += incrementShadow) {
				vec3 density      = FOG_AIR_DENSITY * AtmosphereDensity(worldPosition.y + cameraPosition.y + atmosphere_planetRadius);
				vec3 stepAirmass  = density * stepSize;
				vec3 opticalDepth = atmosphere_coefficientsAttenuation * stepAirmass;

				vec3 stepTransmittance       = exp(-opticalDepth);
				vec3 stepTransmittedFraction = Clamp01((stepTransmittance - 1.0) / -opticalDepth);
				vec3 stepVisibleFraction     = transmittance * stepTransmittedFraction;

				//--//

				#ifdef SHADOW_INFINITE_RENDER_DISTANCE
					vec3 lightingSun = vec3(ReadShadowMaps(DistortShadowSpace(shadowPosition) * 0.5 + 0.5));
				#else
					vec3 lightingSun;
					if (dot(shadowPosition.xy, shadowPosition.xy) < 1.0) {
						lightingSun = vec3(ReadShadowMaps(DistortShadowSpace(shadowPosition) * 0.5 + 0.5));
					} else {
						lightingSun = vec3(1.0);
					}
				#endif

				#ifdef CLOUDS3D
					lightingSun *= GetCloudShadows(worldPosition);
				#endif

				//--//

				scatteringSun += atmosphere_coefficientsScattering * (stepAirmass.xy * phaseSun) * stepVisibleFraction * lightingSun;
				scatteringSky += atmosphere_coefficientsScattering * (stepAirmass.xy * phaseSky) * stepVisibleFraction;
				transmittance *= stepTransmittance;
			}

			scatteringSun *= illuminanceShadowlight;
			scatteringSky *= illuminanceSky * skylight;

			vec3 scattering = scatteringSun + scatteringSky;
		#else
			phaseSun.y *= endSkylight;

			vec3 lightingSky = illuminanceSky * startSkylight;
			vec3 lightingSun = illuminanceShadowlight * startSkylight * GetCloudShadows(startPosition);

			float depth = FOG_AIR_DENSITY * (sky ? far : distance(startPosition, endPosition));
			vec3 opticalDepth = baseAttenuationCoefficient * depth;

			vec3 transmittance   = exp(-opticalDepth);
			vec3 visibleFraction = (transmittance - 1.0) / -opticalDepth;

			vec3 scattering  = atmosphere_coefficientsScattering * (depth * phaseSun) * lightingSun;
			     scattering += atmosphere_coefficientsScattering * (depth * phaseSky) * lightingSky;
			     scattering *= visibleFraction;
		#endif

		return background * transmittance + scattering;
	}

	float PhaseHenyeyGreenstein(float cosTheta, float g) {
		const float norm = 0.25 / pi;

		float gg = g * g;
		return (norm - norm * gg) * pow(1.0 + gg - 2.0 * g * cosTheta, -1.5);
	}

	float FournierForandPhase(float phi, float n, float mu) {
		// Not sure if this is correct.
		float v = (3.0 - mu) / 2.0;
		float delta = (4.0 / (3.0 * Pow2(n - 1))) * Pow2(sin(phi / 2.0));
		float delta180 = (4.0 / (3.0 * Pow2(n - 1))) * Pow2(sin(pi / 2.0));

		float p1 = 1.0 / (4.0 * pi * Pow2(1.0 - delta) * pow(delta, v));
		float p2 = v * (1.0 - delta) - (1.0 - pow(delta, v)) + (delta * (1.0 - pow(delta, v)) - v * (1.0 - delta)) * pow(sin(phi / 2.0), -2.0);
		float p3 = ((1.0 - pow(delta180, v)) / (16.0 * pi * (delta180 - 1.0) * pow(delta180, v))) * (3.0 * Pow2(cos(phi)) - 1.0);
		return p1 * p2 + p3;
	}

	#ifdef VL_WATER_CAUSTICS
		#include "/lib/fragment/waterCaustics.fsh"
	#endif

	vec3 CalculateWaterFog(vec3 background, vec3 startPosition, vec3 endPosition, vec3 viewVector, float LoV, float skylight, float dither, bool sky) {
		vec3 waterScatteringAlbedo = SrgbToLinear(vec3(WATER_SCATTERING_R, WATER_SCATTERING_G, WATER_SCATTERING_B) / 255.0);
		vec3 baseAttenuationCoefficient = -log(SrgbToLinear(vec3(WATER_TRANSMISSION_R, WATER_TRANSMISSION_G, WATER_TRANSMISSION_B) / 255.0)) / WATER_REFERENCE_DEPTH;

		const float isotropicPhase = 0.25 / pi;

		//#define sunlightPhase isotropicPhase
		float sunlightPhase = PhaseHenyeyGreenstein(LoV, 0.5);
		//float sunlightPhase = FournierForandPhase(acos(LoV), 1.1, 3.5835); // Accurate-ish for water

		#ifdef UNDERWATER_ADAPTATION
			float fogDensity = isEyeInWater == 1 ? fogDensity : 0.1;
		#else
			const float fogDensity = 0.1;
		#endif

		#ifdef VL_WATER
			const int steps = 6;

			//--//

			vec3 incrementWorld = (endPosition - startPosition) / steps;
			vec3 worldPosition  = startPosition + incrementWorld * dither;

			vec3 incrementShadow    = mat3(shadowModelView) * incrementWorld;
			     incrementShadow   *= Diagonal(shadowProjection).xyz;
			     incrementShadow.z /= SHADOW_DEPTH_SCALE;
			vec3 shadowPosition     = mat3(shadowModelView) * startPosition + shadowModelView[3].xyz;
			     shadowPosition     = Diagonal(shadowProjection).xyz * shadowPosition + shadowProjection[3].xyz;
			     shadowPosition.z  /= SHADOW_DEPTH_SCALE;
			     shadowPosition    += incrementShadow * dither;

			float stepSize = length(incrementWorld);

			//--//

			vec3 stepOpticalDepth  = baseAttenuationCoefficient * fogDensity * stepSize;
			vec3 stepTransmittance = exp(-stepOpticalDepth);

			vec3 scatteringSun = vec3(0.0);
			vec3 scatteringSky = vec3(0.0);
			vec3 transmittance = vec3(1.0);
			for (int i = 0; i < steps; ++i, worldPosition += incrementWorld, shadowPosition += incrementShadow) {
				vec3 shadowCoord = DistortShadowSpace(shadowPosition) * 0.5 + 0.5;

				#ifdef SHADOW_INFINITE_RENDER_DISTANCE
					vec3 lightingSun = vec3(ReadShadowMaps(shadowCoord));
				#else
					vec3 lightingSun;
					if (dot(shadowPosition.xy, shadowPosition.xy) < 1.0) {
						lightingSun = vec3(ReadShadowMaps(shadowCoord));
					} else {
						lightingSun = vec3(1.0);
					}
				#endif

				#ifdef CLOUDS3D
					lightingSun *= GetCloudShadows(worldPosition);
				#endif

				if (texture(shadowcolor0, shadowCoord.xy).a > 0.5) {
					float waterDepth = SHADOW_DEPTH_RADIUS * Max0(shadowCoord.z - textureLod(shadowtex0, shadowCoord.xy, 0.0).r);

					if (waterDepth > 0.0) {
						lightingSun *= exp(-baseAttenuationCoefficient * fogDensity * waterDepth);

						#if defined VL_WATER_CAUSTICS && defined CAUSTICS
							lightingSun *= CalculateCaustics(worldPosition, waterDepth, 0.5, 1.0);
						#endif
					}
				}

				//--//

				scatteringSun += transmittance * lightingSun;
				scatteringSky += transmittance;
				transmittance *= stepTransmittance;
			}

			//--//

			vec3 stepTransmittedFraction = Clamp01((stepTransmittance - 1.0) / -stepOpticalDepth);

			vec3 scattering  = scatteringSun * sunlightPhase * illuminanceShadowlight;
			     scattering += scatteringSky * isotropicPhase * illuminanceSky * skylight;
			     scattering *= waterScatteringAlbedo * stepOpticalDepth * stepTransmittedFraction;

			//--//

			if (sky) {
				vec3 lighting = illuminanceShadowlight * sunlightPhase;
				#ifdef CLOUDS3D
					if (isEyeInWater == 1) {
						lighting *= GetCloudShadows(gbufferModelViewInverse[3].xyz);
					}
				#endif
				lighting += illuminanceSky * isotropicPhase * skylight;

				scattering += lighting * waterScatteringAlbedo * transmittance;
				transmittance = vec3(0.0);
			}
		#else
			vec3 lighting = illuminanceSky * isotropicPhase * skylight;
			if (isEyeInWater == 1) {
				lighting += illuminanceShadowlight * sunlightPhase * skylight * GetCloudShadows(startPosition);
			} else {
				lighting += illuminanceShadowlight * sunlightPhase * SrgbToLinear(texture(colortex2, screenCoord).rgb);
			}

			if (sky) {
				return lighting * waterScatteringAlbedo;
			}

			float waterDepth   = distance(startPosition, endPosition);
			vec3  opticalDepth = baseAttenuationCoefficient * fogDensity * waterDepth;

			vec3 transmittance   = exp(-opticalDepth);
			vec3 unlitScattering = waterScatteringAlbedo - waterScatteringAlbedo * transmittance;
			vec3 scattering      = lighting * unlitScattering;
		#endif

		return background * transmittance + scattering;
	}

	#include "/lib/fragment/brdf.fsh"
	#include "/lib/fragment/material.fsh"
	#include "/lib/fragment/raytracer.fsh"
	#include "/lib/fragment/specularLighting.fsh"

	//--// Fragment Functions

	vec3 refract2(vec3 I, vec3 N, vec3 NF, float eta) {
		float NoI = dot(N, I);
		float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
		if (k < 0.0) {
			return vec3(0.0); // Total Internal Reflection
		} else {
			float sqrtk = sqrt(k);
			vec3 R = (eta * dot(NF, I) + sqrtk) * NF - (eta * NoI + sqrtk) * N;
			#ifdef REFRACTION_RAYTRACED
				R *= sqrt(abs(NoI));
			#endif
			return normalize(R + eta * I);
		}
	}

	void CalculateRefraction(
		mat3 frontPosition,
		mat3 backPosition,
		vec3 viewDirection,
		vec3 normal,
		vec3 flatNormal,
		int  blockId,
		float eta,
		out mat3 refractedPosition,
		out vec3 refractedDirectionClamped
	) {
		// Init
		refractedPosition         = backPosition;
		refractedDirectionClamped = viewDirection;

		#if REFRACTION_MODE == REFRACTION_WATER_ONLY
			// Only refract through water
			if (blockId != 8 && blockId != 9) { return; }
		#endif

		// Refraction vector
		vec3 refractedDirection = viewDirection;

		float NoI = dot(normal, viewDirection);
		float k = 1.0 - eta * eta * (1.0 - NoI * NoI);
		if (k < 0.0) {
			return; // Total Internal Reflection
		} else {
			float sqrtk = sqrt(k);
			refractedDirection = (eta * dot(flatNormal, viewDirection) + sqrtk) * flatNormal - (eta * NoI + sqrtk) * normal;
			refractedDirection = normalize(refractedDirection * sqrt(abs(NoI)) + eta * viewDirection);
		}

		//--// Calculate refracted position

		#ifdef REFRACTION_RAYTRACED
			vec3 hitPosition = frontPosition[0];
			if (RaytraceIntersection(hitPosition, frontPosition[1], mat3(gbufferModelView) * refractedDirection, 16, 4)) {
				refractedPosition[0] = hitPosition;
				refractedPosition[1] = ScreenSpaceToViewSpace(refractedPosition[0], gbufferProjectionInverse);
				refractedPosition[2] = mat3(gbufferModelViewInverse) * refractedPosition[1] + gbufferModelViewInverse[3].xyz;

				refractedDirectionClamped = normalize(refractedPosition[2] - frontPosition[2]);
			}
		#else
			float refractedDistance = distance(frontPosition[2], backPosition[2]);
			refractedPosition[2] = refractedDirection * refractedDistance + frontPosition[2];
			refractedPosition[1] = mat3(gbufferModelView) * refractedPosition[2] + gbufferModelView[3].xyz;
			refractedPosition[0] = ViewSpaceToScreenSpace(refractedPosition[1], gbufferProjection);

			// Edge clamping
			vec2 rv = refractedPosition[0].xy - frontPosition[0].xy;
			refractedPosition[0].xy = rv * Clamp01(MinOf((step(0.0, rv) - frontPosition[0].xy) / rv) * 0.5) + frontPosition[0].xy;

			// Depth at refracted position
			refractedPosition[0].z = texture(depthtex1, refractedPosition[0].xy).r;

			// Don't refract if there was nothing that could be refracted
			if (refractedPosition[0].z < frontPosition[0].z) {
				refractedPosition = backPosition;

				return;
			}

			refractedPosition[1] = ScreenSpaceToViewSpace(refractedPosition[0], gbufferProjectionInverse);
			refractedPosition[2] = mat3(gbufferModelViewInverse) * refractedPosition[1] + gbufferModelViewInverse[3].xyz;

			refractedDirectionClamped = normalize(refractedPosition[2] - frontPosition[2]);
		#endif
	}

	void main() {
		mat3 frontPosition;
		frontPosition[0] = vec3(screenCoord, texture(depthtex0, screenCoord).r);
		frontPosition[1] = ScreenSpaceToViewSpace(frontPosition[0], gbufferProjectionInverse);
		frontPosition[2] = mat3(gbufferModelViewInverse) * frontPosition[1] + gbufferModelViewInverse[3].xyz;
		mat3 backPosition;
		backPosition[0] = vec3(screenCoord, texture(depthtex1, screenCoord).r);
		backPosition[1] = ScreenSpaceToViewSpace(backPosition[0], gbufferProjectionInverse);
		backPosition[2] = mat3(gbufferModelViewInverse) * backPosition[1] + gbufferModelViewInverse[3].xyz;
		vec3 viewVector = normalize(frontPosition[2] - gbufferModelViewInverse[3].xyz);
		vec3 backDirection = viewVector;

		float LoV = dot(shadowLightVector, -viewVector);

		float eyeSkylight = eyeBrightness.y / 240.0;
		      eyeSkylight = eyeSkylight * exp(eyeSkylight * 6.0 - 6.0);

		// Dither pattern
		const float ditherSize = 32.0 * 32.0;
		float dither = Bayer32(gl_FragCoord.st);
		#ifdef TAA
		      dither = fract(dither + LinearBayer16(frameCounter));
		#endif

		vec3 transparentFlatNormal = normalize(cross(dFdx(frontPosition[2]), dFdy(frontPosition[2])));

		if (frontPosition[0].z < 1.0) {
			// Gbuffer data
			vec4 colortex0Sample = texture(colortex0, screenCoord);
			vec4 colortex1Sample = texture(colortex1, screenCoord);

			vec3 baseTex;
			baseTex.rg = Unpack2x8(colortex0Sample.r);
			baseTex.b = Unpack2x8X(colortex0Sample.g);
			vec4 specTex;
			specTex.rg = Unpack2x8(colortex1Sample.r);
			specTex.ba = Unpack2x8(colortex1Sample.g);

			int blockId = int(floor(Unpack2x8Y(colortex0Sample.g) * 255.0 + 0.5));

			Material material = MaterialFromTex(baseTex, specTex, blockId);

			vec2 lightmap = Unpack2x8(colortex0Sample.b);
			vec3 normal   = DecodeNormal(Unpack2x8(colortex1Sample.b) * 2.0 - 1.0);

			vec3 eyeN = isEyeInWater == 1 ? waterMaterial.n : airMaterial.n;
			#if REFRACTION_MODE != REFRACTION_OFF
				if (frontPosition[0].z != backPosition[0].z) {
					// Refract
					CalculateRefraction(
						frontPosition,
						backPosition,
						viewVector,
						normal,
						transparentFlatNormal,
						blockId,
						eyeN.x / (isEyeInWater == 1 ? airMaterial.n.x : material.n.x),
						backPosition,
						backDirection
					);
				}
			#endif

			color = DecodeRGBE8(texture(colortex4, backPosition[0].xy));

			float skylightFade = lightmap.y * exp(lightmap.y * 6.0 - 6.0);

			if (backPosition[0].z != frontPosition[0].z) {
				// Front to back fog
				bool backIsSky = backPosition[0].z >= 1.0;
				if (isEyeInWater != 1 && (blockId == 8 || blockId == 9)) { // Water fog
					color = CalculateWaterFog(color, frontPosition[2], backPosition[2], viewVector, -LoV, skylightFade, dither, backIsSky);
				} else { // Air fog
					color = CalculateAirFog(color, frontPosition[2], backPosition[2], viewVector, -LoV, skylightFade, skylightFade, dither, backIsSky);
				}

				// Apply transparents
				vec4 transparentSurfaceCol = texture(colortex3, screenCoord);
				color = color * (1.0 - transparentSurfaceCol.a) + transparentSurfaceCol.rgb;
			}

			// Specular
			if (material.n != eyeN) {
				float NoV = dot(normal, -viewVector);

				color += CalculateSsr(colortex4, frontPosition, normal, NoV, material.roughness, material.n, material.k, skylightFade, blockId == 8, dither, ditherSize);

				if (backPosition[0].z != frontPosition[0].z) {
					float NoL = dot(normal, shadowLightVector);
					float rcpLen_LV = inversesqrt(2.0 * LoV + 2.0);
					float NoH = (NoL + NoV) * rcpLen_LV;
					float VoH = LoV * rcpLen_LV + rcpLen_LV;

					float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;
					color += CalculateSpecularHighlight(NoL, NoV, LoV, VoH, material.roughness, material.n, material.k, lightAngularRadius) * illuminanceShadowlight * SrgbToLinear(texture(colortex2, screenCoord).rgb);
				}
			}

			// Eye to front fog
			if (isEyeInWater == 1) { // Water fog
				color = CalculateWaterFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight * (1.0 - skylightFade) + skylightFade, dither, false);
			} else if (isEyeInWater == 2) { // Lava fog
				// TODO
			} else { // Air fog
				color = CalculateAirFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, skylightFade, dither, false);
			}
		} else { // Sky
			color = DecodeRGBE8(texture(colortex4, screenCoord));

			if (isEyeInWater == 1) { // Water fog
				color = CalculateWaterFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, dither, true);
			} else if (isEyeInWater == 2) { // Lava fog
				// TODO
			} else { // Air fog
				color = CalculateAirFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, 1.0, dither, true);
			}
		}

		color = sqrt(Max0(color)); // Max0 as a temp workaround for the very occasional nan that is coming from seemingly nowhere
	}
#endif
