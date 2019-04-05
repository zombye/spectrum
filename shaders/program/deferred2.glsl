/*\
 * Program Description:
 * Deferred lighting pass for opaque objects.
\*/

//--// Settings

#include "/settings.glsl"
#include "/internalSettings.glsl"

//--// Uniforms

//
uniform float sunAngle;

uniform float wetness;

uniform int isEyeInWater;
uniform float eyeAltitude;
uniform vec3 cameraPosition;

uniform float fogDensity = 0.1;

uniform float screenBrightness;

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
#ifdef SHADOW_COLORED
	uniform sampler2D shadowcolor1;
#endif

// Misc samplers
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3; // Clouds Transmittance
uniform sampler2D colortex4; // Sky Encode
uniform sampler2D colortex5; // Sky Scattering LUT
uniform sampler2D colortex6; // Sky Scattering Image
uniform sampler2D colortex7; // Misc encoded stuff

uniform sampler2D depthtex0; // Sky Transmittance LUT
#define transmittanceLut depthtex0

uniform sampler2D noisetex;

// Custom Uniforms
uniform vec2 viewResolution;
uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 sunVector;

uniform vec3 moonVector;
uniform vec3 shadowLightVectorView;
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
#include "/lib/shared/atmosphere/phase.glsl"
#include "/lib/shared/atmosphere/scattering.glsl"

//--// Shared Functions

#if defined STAGE_VERTEX
	//--// Vertex Outputs

	out vec2 screenCoord;

	flat out vec3 skylightPosX;
	flat out vec3 skylightPosY;
	flat out vec3 skylightPosZ;
	flat out vec3 skylightNegX;
	flat out vec3 skylightNegY;
	flat out vec3 skylightNegZ;

	flat out vec3 shadowlightTransmittance;
	flat out vec3 luminanceShadowlight;
	flat out vec3 illuminanceShadowlight;

	//--// Vertex Functions

	void main() {
		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);

		const ivec2 samples = ivec2(16, 8);

		skylightPosX = vec3(0.0);
		skylightPosY = vec3(0.0);
		skylightPosZ = vec3(0.0);
		skylightNegX = vec3(0.0);
		skylightNegY = vec3(0.0);
		skylightNegZ = vec3(0.0);

		for (int x = 0; x < samples.x; ++x) {
			for (int y = 0; y < samples.y; ++y) {
				vec3 dir = GenerateUnitVector((vec2(x, y) + 0.5) / samples);

				vec3 skySample = texture(colortex6, ProjectSky(dir)).rgb;

				skylightPosX += skySample * Clamp01( dir.x);
				skylightPosY += skySample * Clamp01( dir.y);
				skylightPosZ += skySample * Clamp01( dir.z);
				skylightNegX += skySample * Clamp01(-dir.x);
				skylightNegY += skySample * Clamp01(-dir.y);
				skylightNegZ += skySample * Clamp01(-dir.z);
			}
		}

		const float sampleWeight = 4.0 / (samples.x * samples.y);
		skylightPosX *= sampleWeight;
		skylightPosY *= sampleWeight;
		skylightPosZ *= sampleWeight;
		skylightNegX *= sampleWeight;
		skylightNegY *= sampleWeight;
		skylightNegZ *= sampleWeight;

		shadowlightTransmittance  = AtmosphereTransmittance(transmittanceLut, vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector);
		shadowlightTransmittance *= smoothstep(0.0, 0.01, abs(shadowLightVector.y));
		luminanceShadowlight   = (sunAngle < 0.5 ? sunLuminance   : moonLuminance)   * shadowlightTransmittance;
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * shadowlightTransmittance;
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	flat in vec3 skylightPosX;
	flat in vec3 skylightPosY;
	flat in vec3 skylightPosZ;
	flat in vec3 skylightNegX;
	flat in vec3 skylightNegY;
	flat in vec3 skylightNegZ;

	flat in vec3 shadowlightTransmittance;
	flat in vec3 luminanceShadowlight;
	flat in vec3 illuminanceShadowlight;

	//--// Fragment Outputs

	/* DRAWBUFFERS:47 */

	layout (location = 0) out vec4 colortex4Write;
	layout (location = 1) out vec4 colortex7Write;

	//--// Fragment Libraries

	#include "/lib/utility/complex.glsl"
	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/math.glsl"
	#include "/lib/utility/noise.glsl"
	#include "/lib/utility/packing.glsl"
	#include "/lib/utility/rotation.glsl"
	#include "/lib/utility/spaceConversion.glsl"

	#include "/lib/shared/shadowDistortion.glsl"

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

	#include "/lib/fragment/material.fsh"
	#include "/lib/fragment/brdf.fsh"
	#include "/lib/fragment/diffuseLighting.fsh"
	#include "/lib/fragment/specularLighting.fsh"
	#ifdef CAUSTICS
		#include "/lib/fragment/waterCaustics.fsh"
	#endif
	#include "/lib/fragment/shadows.fsh"

	#include "/lib/fragment/clouds2D.fsh"
	#include "/lib/fragment/clouds3D.fsh"

	#include "/lib/fragment/raytracer.fsh"

	//--// Fragment Functions

	float CalculateSampleWeight(vec3 centerNormal, vec3 sampleNormal, vec3 sampleVector) {
		float planeDist = abs(dot(centerNormal, sampleVector));
		return Clamp01(dot(centerNormal, sampleNormal)) * LinearStep(0.05, 0.0, planeDist);
	}

	vec4 FilterAo(vec3 flatNormal, vec3 position) {
		ivec2 res       = ivec2(viewResolution) / 2;
		ivec2 fragCoord = ivec2(gl_FragCoord.st) / 2;
		ivec2 shift     = ivec2(gl_FragCoord.st) % 2;

		vec4 hbao = texelFetch(colortex7, fragCoord, 0);
		hbao.xyz = hbao.xyz * 2.0 - 1.0;

		float weightSum = 1.0;
		for (int x = -2; x < 2; ++x) {
			for (int y = -2; y < 2; ++y) {
				ivec2 offset = ivec2(x, y) + shift;
				if (offset.x == 0 && offset.y == 0) { continue; }

				ivec2 sampleFragCoord = fragCoord + offset;

				if (sampleFragCoord.x < 0 || sampleFragCoord.y < 0) { continue; }
				if (sampleFragCoord.x >= res.x || sampleFragCoord.y >= res.y) { continue; }

				vec2 sampleCoord = vec2(fragCoord + offset) * viewPixelSize * 2.0;

				vec3 sampleNormal = DecodeNormal(Unpack2x8(texelFetch(colortex1, sampleFragCoord * 2, 0).a) * 2.0 - 1.0);
				vec3 samplePosition  = GetViewDirection(sampleCoord, gbufferProjectionInverse);
				     samplePosition *= GetLinearDepth(depthtex1, sampleCoord) / samplePosition.z;

				float weight = CalculateSampleWeight(flatNormal, sampleNormal, mat3(gbufferModelViewInverse) * (samplePosition - position));

				vec4 hbaoSample = texelFetch(colortex7, sampleFragCoord, 0);
				hbaoSample.xyz = hbaoSample.xyz * 2.0 - 1.0;

				hbao += hbaoSample * weight;
				weightSum += weight;
			}
		}

		hbao.xyz = normalize(hbao.xyz);
		hbao.w /= weightSum;

		return hbao;
	}

	// --

	vec3 CalculateFakeBouncedLight(vec3 normal, vec3 lightVector) {
		const vec3 groundAlbedo = vec3(0.1, 0.1, 0.1);
		const vec3 weight = vec3(0.2, 0.6, 0.2); // Fraction of light bounced off the x, y, and z planes. Should sum to 1.0 or less.

		// Divide by pi^2 for energy conservation.
		float bounceIntensity = dot(abs(lightVector) * (-sign(lightVector) * normal * 0.5 + 0.5), weight / (pi * pi));

		return groundAlbedo * bounceIntensity;
	}

	vec3 FilterRSM(vec3 normalFlat, vec3 position) {
		ivec2 res       = ivec2(viewResolution / 2);
		ivec2 fragCoord = ivec2(gl_FragCoord.st) / 2;
		ivec2 shift     = ivec2(gl_FragCoord.st) % 2;

		vec3 result = texelFetch(colortex7, fragCoord + ivec2(res.x, 0), 0).rgb;
		float weightSum = 1.0;

		for (int x = -2; x < 2; ++x) {
			for (int y = -2; y < 2; ++y) {
				ivec2 offset = ivec2(x, y) + shift;
				if (offset.x == 0 && offset.y == 0) { continue; }

				ivec2 sampleFragCoord = fragCoord + offset;

				if (sampleFragCoord.x < 0 || sampleFragCoord.y < 0) { continue; }
				if (sampleFragCoord.x >= res.x || sampleFragCoord.y >= res.y) { continue; }

				vec2 sampleCoord = vec2(fragCoord + offset) * viewPixelSize * 2.0;

				vec3 sampleNormal = DecodeNormal(Unpack2x8(texelFetch(colortex1, sampleFragCoord * 2, 0).a) * 2.0 - 1.0);
				vec3 samplePosition  = GetViewDirection(sampleCoord, gbufferProjectionInverse);
				     samplePosition *= GetLinearDepth(depthtex1, sampleCoord) / samplePosition.z;

				float weight = CalculateSampleWeight(normalFlat, sampleNormal, mat3(gbufferModelViewInverse) * (samplePosition - position));

				vec3 rsmSample = texelFetch(colortex7, sampleFragCoord + ivec2(res.x, 0), 0).rgb;

				result += rsmSample * weight;
				weightSum += weight;
			}
		}

		return result / weightSum;
	}

	// --

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

		// Caluculate diffuse
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

	void main() {
		if (gl_FragCoord.x < 6.0 && gl_FragCoord.y < 1.0) {
			if (gl_FragCoord.x < 1.0) {
				colortex7Write.rgb = skylightPosX;
			} else if (gl_FragCoord.x < 2.0) {
				colortex7Write.rgb = skylightPosY;
			} else if (gl_FragCoord.x < 3.0) {
				colortex7Write.rgb = skylightPosZ;
			} else if (gl_FragCoord.x < 4.0) {
				colortex7Write.rgb = skylightNegX;
			} else if (gl_FragCoord.x < 5.0) {
				colortex7Write.rgb = skylightNegY;
			} else {
				colortex7Write.rgb = skylightNegZ;
			}
		} else if (gl_FragCoord.x < 1.0 && gl_FragCoord.y < 2.0) {
			colortex7Write.rgb = shadowlightTransmittance;
		} else {
			colortex7Write.rgb = vec3(0.0);
		}
		colortex7Write.a = 1.0;

		mat3 position;
		position[0] = vec3(screenCoord, texture(depthtex1, screenCoord).r);
		position[1] = ScreenSpaceToViewSpace(position[0], gbufferProjectionInverse);
		position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;
		vec3 viewVector = normalize(position[2] - gbufferModelViewInverse[3].xyz);

		const float ditherSize = 8.0 * 8.0;
		float dither = Bayer8(gl_FragCoord.st);
		#ifdef TAA
		      dither = fract(dither + LinearBayer16(frameCounter));
		#endif

		vec4 colortex0Sample = texture(colortex0, screenCoord);
		int id = int(floor(Unpack2x8Y(colortex0Sample.g) * 255.0 + 0.5));

		vec3 color = vec3(0.0);
		if (position[0].z < 1.0 || id != 0) {
			#ifndef BLACK_TERRAIN
			// Gbuffer data
			vec4 colortex1Sample = texture(colortex1, screenCoord);

			vec3 baseTex;
			baseTex.rg = Unpack2x8(colortex0Sample.r);
			baseTex.b = Unpack2x8X(colortex0Sample.g);
			vec4 specTex;
			specTex.rg = Unpack2x8(colortex1Sample.r);
			specTex.ba = Unpack2x8(colortex1Sample.g);

			Material material = MaterialFromTex(baseTex, specTex, id);

			vec2 lightmap   = Unpack2x8(colortex0Sample.b);
			vec3 normal     = DecodeNormal(Unpack2x8(colortex1Sample.b) * 2.0 - 1.0);
			vec3 normalFlat = DecodeNormal(Unpack2x8(colortex1Sample.a) * 2.0 - 1.0);

			vec3 unpack = UnpackUnormArbitrary(uint(colortex0Sample.a * 65535.0 + 0.5), uvec4(8, 1, 7, 0)).xyz;
			float vertexAo = unpack.x, parallaxShadow = unpack.y, blocklightShading = unpack.z;

			// Lighting dots
			float NoL = dot(normal, shadowLightVector);
			float NoV = dot(normal, -viewVector);
			float LoV = dot(shadowLightVector, -viewVector);
			float rcpLen_LV = inversesqrt(2.0 * LoV + 2.0);
			float NoH = (NoL + NoV) * rcpLen_LV;
			float VoH = LoV * rcpLen_LV + rcpLen_LV;

			// Lighting
			#ifdef HBAO
				vec4 hbao = FilterAo(normalFlat, position[1]);
				vec3 skyConeVector = hbao.xyz;
				float ao = hbao.w;
			#else
				vec3 skyConeVector = normal;
				float ao = unpack.x;
			#endif

			vec3 skylight = vec3(0.0);
			if (lightmap.y > 0.0) {
				vec3 octahedronPoint = skyConeVector / (abs(skyConeVector.x) + abs(skyConeVector.y) + abs(skyConeVector.z));
				vec3 wPos = Clamp01( octahedronPoint);
				vec3 wNeg = Clamp01(-octahedronPoint);

				skylight = skylightPosX * wPos.x + skylightPosY * wPos.y + skylightPosZ * wPos.z
				         + skylightNegX * wNeg.x + skylightNegY * wNeg.y + skylightNegZ * wNeg.z;
			}

			vec3 shadows = vec3(0.0), bounce = vec3(0.0);
			#ifdef GLOBAL_LIGHT_FADE_WITH_SKYLIGHT
				if (lightmap.y > 0.0) {
					float cloudShadow = GetCloudShadows(position[2]);
					bool translucent = material.translucency.r + material.translucency.g + material.translucency.b > 0.0;
					shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
					if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
						shadows *= CalculateShadows(position, normalFlat, translucent, dither, ditherSize);
					}

					#ifdef RSM
						bounce = FilterRSM(normalFlat, position[1]) * RSM_BRIGHTNESS;
					#else
						bounce  = CalculateFakeBouncedLight(skyConeVector, shadowLightVector);
						bounce *= lightmap.y * lightmap.y * lightmap.y;
					#endif

					bounce *= cloudShadow * ao;
				}
			#else
				float cloudShadow = GetCloudShadows(position[2]);
				bool translucent = material.translucency.r + material.translucency.g + material.translucency.b > 0.0;
				shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
				if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
					shadows *= CalculateShadows(position, normalFlat, translucent, dither, ditherSize);
				}

				#ifdef RSM
					bounce = FilterRSM(normalFlat, position[1]) * RSM_BRIGHTNESS;
				#else
					bounce  = CalculateFakeBouncedLight(skyConeVector, shadowLightVector);
					bounce *= lightmap.y * lightmap.y * lightmap.y;
				#endif

				bounce *= cloudShadow * ao;
			#endif

			float lightAngularRadius = sunAngle < 0.5 ? sunAngularRadius : moonAngularRadius;

			color  = CalculateDiffuseLighting(NoL, NoH, NoV, LoV, material, shadows, bounce, skylight, lightmap, blocklightShading, ao);
			color += CalculateSpecularHighlight(NoL, NoV, LoV, VoH, material.roughness, material.n, material.k, lightAngularRadius) * illuminanceShadowlight * shadows;
			color += material.emission;
			//color = skylight * ao;
			//color = bounce * illuminanceShadowlight;
			#else
			color = vec3(0.0);
			#endif
		} else {
			color  = CalculateStars(vec3(0.0), viewVector);
			color  = CalculateSun(color, viewVector, sunVector);
			color  = CalculateMoon(color, viewVector, moonVector);
			color *= AtmosphereTransmittance(transmittanceLut, vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0), viewVector);

			vec4 sky;
			sky.rgb = DecodeRGBE8(texelFetch(colortex4, ivec2(screenCoord * exp2(-SKY_RENDER_LOD) * viewResolution), 0));
			sky.a   = texelFetch(colortex3, ivec2(screenCoord * exp2(-SKY_RENDER_LOD) * viewResolution), 0).r;
			color = color * sky.a + sky.rgb;

			#ifdef CLOUDS2D
				vec3 viewPosition = vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0);

				float clouds2DDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_planetRadius + CLOUDS2D_ALTITUDE).y;

				vec3 transmittance = AtmosphereTransmittance(transmittanceLut, viewPosition, viewVector, clouds2DDistance) * sky.a;

				vec3 clouds2DPosition = clouds2DDistance * viewVector + viewPosition;
				vec3 atmosphereScattering  = AtmosphereScattering(colortex5, clouds2DPosition, viewVector, sunVector ) * sunIlluminance;
				     atmosphereScattering += AtmosphereScattering(colortex5, clouds2DPosition, viewVector, moonVector) * moonIlluminance;
				color -= atmosphereScattering * transmittance;

				vec4 clouds2D = Calculate2DClouds(viewVector, dither);
				color += clouds2D.rgb * transmittance; transmittance *= clouds2D.a;

				color += atmosphereScattering * transmittance;
			#endif
		}

		colortex4Write = EncodeRGBE8(color);
	}
#endif
