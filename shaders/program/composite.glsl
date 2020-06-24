//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

#define REFRACTION_OFF 0
#define REFRACTION_WATER_ONLY 1
#define REFRACTION_FULL 2
#define REFRACTION_MODE REFRACTION_WATER_ONLY // [REFRACTION_OFF REFRACTION_WATER_ONLY REFRACTION_FULL]
//#define REFRACTION_RAYTRACED

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

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);

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

		vec3 shadowlightTransmittance = texelFetch(colortex5, ivec2(0, 1), 0).rgb;
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

	/* DRAWBUFFERS:6 */

	layout (location = 0) out vec3 color;

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

	#include "/include/fragment/material.fsh"
	#include "/include/fragment/brdf.fsh"
	#include "/include/fragment/raytracer.fsh"
	#include "/include/fragment/specularLighting.fsh"

	//--// Fragment Functions //----------------------------------------------//

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
			} else {
				refractedPosition[0] = vec3(ViewSpaceToScreenSpace(mat3(gbufferModelView) * refractedDirection, gbufferProjection).xy, 1.0);
				refractedPosition[1] = ScreenSpaceToViewSpace(refractedPosition[0], gbufferProjectionInverse);
				refractedPosition[2] = mat3(gbufferModelViewInverse) * refractedPosition[1] + gbufferModelViewInverse[3].xyz;
				refractedDirectionClamped = refractedDirection;
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
			refractedPosition[0].z = texture(depthtex1, refractedPosition[0].xy + taaOffset * 0.5).r;

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
		#ifdef TAA
		frontPosition[0].xy -= taaOffset * 0.5;
		#endif
		frontPosition[1] = ScreenSpaceToViewSpace(frontPosition[0], gbufferProjectionInverse);
		frontPosition[2] = mat3(gbufferModelViewInverse) * frontPosition[1] + gbufferModelViewInverse[3].xyz;
		mat3 backPosition;
		backPosition[0] = vec3(screenCoord, texture(depthtex1, screenCoord).r);
		#ifdef TAA
		backPosition[0].xy -= taaOffset * 0.5;
		#endif
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
		      dither = fract(dither + frameR1);
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

			#ifdef TOTAL_INTERNAL_REFLECTION
			vec3 eyeN = isEyeInWater == 1 ? waterMaterial.n : airMaterial.n;
			#else
			vec3 eyeN = airMaterial.n;
			#endif
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

			color = DecodeRGBE8(texture(colortex4, backPosition[0].xy + taaOffset * 0.5));

			float skylightFade = lightmap.y * exp(lightmap.y * 6.0 - 6.0);

			if (backPosition[0].z != frontPosition[0].z) {
				// Front to back fog
				bool backIsSky = backPosition[0].z >= 1.0;
				if (isEyeInWater != 1 && (blockId == 8 || blockId == 9)) { // Water fog
					#ifdef VL_WATER
					color = CalculateWaterFogVL(color, frontPosition[2], backPosition[2], viewVector, -LoV, skylightFade, dither, backIsSky);
					#else
					color = CalculateWaterFog(color, frontPosition[2], backPosition[2], viewVector, -LoV, skylightFade, dither, backIsSky);
					#endif
				} else { // Air fog
					#ifdef VL_AIR
					color = CalculateAirFogVL(color, frontPosition[2], backPosition[2], viewVector, -LoV, skylightFade, skylightFade, dither, backIsSky);
					#else
					color = CalculateAirFog(color, frontPosition[2], backPosition[2], viewVector, -LoV, skylightFade, skylightFade, dither, backIsSky);
					#endif
				}

				// Apply transparents
				vec4 transparentSurfaceCol = texture(colortex3, screenCoord);
				color = color * (1.0 - transparentSurfaceCol.a) + transparentSurfaceCol.rgb;
			} else if (wetness > 0.01) {
				// rain puddles, idk where to do these tbh but here works
				vec3 flatNormal = DecodeNormal(Unpack2x8(colortex1Sample.a) * 2.0 - 1.0);;

				float rainMask  = 1.0 - Pow2(LinearStep(1.0, 0.01, wetness));
				      rainMask *= Clamp01(lightmap.y * 15.0 - 13.5);
				      rainMask *= LinearStep(0.5, 0.9, normal.y);

				float noise  = TextureBicubic(noisetex, fract(0.5 * (backPosition[2].xz + cameraPosition.xz) / 256.0)).x;
				      noise += TextureBicubic(noisetex, fract(1.0 * (backPosition[2].xz + cameraPosition.xz) / 256.0)).x * 0.5;
				      noise /= 1.5;

				float wetMask = Clamp01(Clamp01(noise * 1.7) + rainMask - 1.0);
				float puddleMask = LinearStep(0.9, 0.95, Clamp01(noise * 1.5) - 0.1 + LinearStep(0.5, 1.0, rainMask)*0.1);

				material.n += 0.3 * LinearStep(0.3, 0.9, wetMask);
				material.roughness *= (1.0 - puddleMask) * pow(1.0 - wetMask * 0.75, 2.0) + puddleMask * 0.01;
				normal = normalize(mix(normal, flatNormal, puddleMask));
			}

			// Specular
			if (material.n != eyeN) {
				color *= 1.0 - material.metalness;
				color += material.emission * material.metalness; // as emissive is done before this it needs to be readded here for metals

				float NoV = dot(normal, -viewVector);

				float NoL = dot(normal, shadowLightVector);
				float rcpLen_LV = inversesqrt(2.0 * LoV + 2.0);
				float NoH = (NoL + NoV) * rcpLen_LV;
				float VoH = LoV * rcpLen_LV + rcpLen_LV;

				float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;
				color += CalculateSpecularHighlight(NoL, NoV, LoV, VoH, material, lightAngularRadius) * illuminanceShadowlight * LinearFromSrgb(texture(colortex7, screenCoord).rgb);

				#ifdef SSR_MULTILAYER
					if (backPosition[0].z == frontPosition[0].z) {
						color += CalculateEnvironmentReflections(colortex4, frontPosition, normal, NoV, material, skylightFade, blockId == 8, dither, ditherSize);
					}
				#else
					color += CalculateEnvironmentReflections(colortex4, frontPosition, normal, NoV, material, skylightFade, blockId == 8, dither, ditherSize);
				#endif
			}

			// Eye to front fog
			if (isEyeInWater == 1) { // Water fog
				#ifdef VL_WATER
				color = CalculateWaterFogVL(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight * (1.0 - skylightFade) + skylightFade, dither, false);
				#else
				color = CalculateWaterFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight * (1.0 - skylightFade) + skylightFade, dither, false);
				#endif
			} else if (isEyeInWater == 2) { // Lava fog
				// TODO
			} else { // Air fog
				#ifdef VL_AIR
				color = CalculateAirFogVL(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, skylightFade, dither, false);
				#else
				color = CalculateAirFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, skylightFade, dither, false);
				#endif
			}
		} else { // Sky
			color = DecodeRGBE8(texture(colortex4, screenCoord));

			if (isEyeInWater == 1) { // Water fog
				#ifdef VL_WATER
				color = CalculateWaterFogVL(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, dither, true);
				#else
				color = CalculateWaterFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, dither, true);
				#endif
			} else if (isEyeInWater == 2) { // Lava fog
				// TODO
			} else { // Air fog
				#ifdef VL_AIR
				color = CalculateAirFogVL(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, 1.0, dither, true);
				#else
				color = CalculateAirFog(color, gbufferModelViewInverse[3].xyz, frontPosition[2], viewVector, -LoV, eyeSkylight, 1.0, dither, true);
				#endif
			}
		}

		color = sqrt(Max0(color)); // Max0 as a temp workaround for the very occasional nan that is coming from seemingly nowhere
	}
#endif
