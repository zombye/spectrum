/*\
 * Program Description:
 * Deferred lighting pass for opaque objects.
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"
#include "/internalSettings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform float sunAngle;

uniform float wetness;

uniform float fogDensity = 0.1;

uniform float screenBrightness;

uniform sampler2D depthtex1;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4; // Sky Encode
uniform sampler2D colortex6; // Sky Scattering Image
uniform sampler2D colortex5; // Misc encoded stuff

uniform sampler2D depthtex0; // Sky Transmittance LUT
uniform sampler3D depthtex2; // Sky Scattering LUT
#define transmittanceLut depthtex0
#define scatteringLut depthtex2

uniform sampler2D noisetex;

//--// Time uniforms

uniform int   frameCounter;
uniform float frameTimeCounter;

uniform int worldDay;
uniform int worldTime;

//--// Camera uniforms

uniform int isEyeInWater;
uniform float eyeAltitude;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

//--// Shadow uniforms

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

//--// Custom uniforms

uniform vec2 viewResolution;
uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 sunVector;

uniform vec3 moonVector;
uniform vec3 shadowLightVectorView;
uniform vec3 shadowLightVector;

//--// Shared Includes //-----------------------------------------------------//

#include "/include/utility.glsl"
#include "/include/utility/colorspace.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/sampling.glsl"

#include "/include/shared/celestialConstants.glsl"
#include "/include/shared/phaseFunctions.glsl"
#include "/include/shared/skyProjection.glsl"

#include "/include/shared/atmosphere/constants.glsl"
#include "/include/shared/atmosphere/lookup.glsl"
#include "/include/shared/atmosphere/transmittance.glsl"
#include "/include/shared/atmosphere/phase.glsl"
#include "/include/shared/atmosphere/scattering.glsl"

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

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

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);

		const ivec2 samples = ivec2(64, 32);

		skylightPosX = vec3(0.0);
		skylightPosY = vec3(0.0);
		skylightPosZ = vec3(0.0);
		skylightNegX = vec3(0.0);
		skylightNegY = vec3(0.0);
		skylightNegZ = vec3(0.0);

		for (int x = 0; x < samples.x; ++x) {
			for (int y = 0; y < samples.y; ++y) {
				vec3 dir = GenerateUnitVector((vec2(x, y) + 0.5) / samples);
				if (dir.y < 0.0) { dir.y = -dir.y; }

				vec3 skySample = texture(colortex6, ProjectSky(dir)).rgb;

				skylightPosX += skySample * Clamp01( dir.x);
				skylightPosY += skySample * Clamp01( dir.y);
				skylightPosZ += skySample * Clamp01( dir.z);
				skylightNegX += skySample * Clamp01(-dir.x);
				skylightNegZ += skySample * Clamp01(-dir.z);
			}
		}

		const float sampleWeight = 2.0 / (samples.x * samples.y);
		skylightPosX *= sampleWeight;
		skylightPosY *= sampleWeight;
		skylightPosZ *= sampleWeight;
		skylightNegX *= sampleWeight;
		skylightNegZ *= sampleWeight;

		// super simple fake skylight bounce
		const float fakeBounceAlbedo = 0.2;
		skylightPosX += skylightPosY * fakeBounceAlbedo * 0.5;
		skylightPosZ += skylightPosY * fakeBounceAlbedo * 0.5;
		skylightNegX += skylightPosY * fakeBounceAlbedo * 0.5;
		skylightNegY += skylightPosY * fakeBounceAlbedo;
		skylightNegZ += skylightPosY * fakeBounceAlbedo * 0.5;

		shadowlightTransmittance  = AtmosphereTransmittance(transmittanceLut, vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector);
		shadowlightTransmittance *= smoothstep(0.0, 0.01, abs(shadowLightVector.y));
		luminanceShadowlight   = (sunAngle < 0.5 ? sunLuminance   : moonLuminance)   * shadowlightTransmittance;
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * shadowlightTransmittance;
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

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

	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:457 */

	layout (location = 0) out vec4 colortex4Write;
	layout (location = 1) out vec4 colortex5Write;
	layout (location = 2) out vec4 shadowsOut; // shadows

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/complex.glsl"
	#include "/include/utility/dithering.glsl"
	#include "/include/utility/geometry.glsl"
	#include "/include/utility/noise.glsl"
	#include "/include/utility/packing.glsl"
	#include "/include/utility/rotation.glsl"
	#include "/include/utility/spaceConversion.glsl"

	#include "/include/shared/shadowDistortion.glsl"

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
	#include "/include/fragment/raytracer.fsh"

	#include "/include/fragment/material.fsh"
	#include "/include/fragment/brdf.fsh"
	#include "/include/fragment/diffuseLighting.fsh"
	#include "/include/fragment/specularLighting.fsh"
	#if CAUSTICS != CAUSTICS_OFF
		#include "/include/fragment/waterCaustics.fsh"
	#endif
	#include "/include/fragment/shadows.fsh"

	#include "/include/fragment/clouds3D.fsh"


	//--// Fragment Functions //----------------------------------------------//

	float CalculateSampleWeight(vec3 centerNormal, vec3 sampleNormal, vec3 sampleVector) {
		float planeDist = abs(dot(centerNormal, sampleVector));
		return Clamp01(dot(centerNormal, sampleNormal)) * LinearStep(0.05, 0.0, planeDist);
	}

	void Filter(vec3 flatNormal, vec3 position, out vec4 hbao, out vec3 rsm) {
		ivec2 res       = ivec2(viewResolution) / 2;
		ivec2 fragCoord = ivec2(gl_FragCoord.st) / 2;
		ivec2 shift     = ivec2(gl_FragCoord.st) % 2;

		#ifdef HBAO
		hbao = texelFetch(colortex5, fragCoord, 0);
		#endif

		#ifdef RSM
		rsm = texelFetch(colortex5, fragCoord + ivec2(res.x, 0), 0).rgb;
		#endif

		float weightSum = 1.0;
		for (int x = -4; x < 4; ++x) {
			for (int y = -4; y < 4; ++y) {
				ivec2 offset = ivec2(x, y) + shift;
				if (offset.x == 0 && offset.y == 0) { continue; }

				ivec2 sampleFragCoord = fragCoord + offset;

				if(sampleFragCoord.x < 0
				|| sampleFragCoord.y < 0
				|| sampleFragCoord.x >= res.x
				|| sampleFragCoord.y >= res.y
				) { continue; }

				vec2 sampleCoord = vec2(sampleFragCoord) * viewPixelSize * 2.0;

				vec3 sampleNormal = DecodeNormal(Unpack2x8(texelFetch(colortex1, sampleFragCoord * 2, 0).a) * 2.0 - 1.0);
				vec3 samplePosition  = GetViewDirection(sampleCoord, gbufferProjectionInverse);
				     samplePosition *= GetLinearDepth(depthtex1, sampleCoord) / samplePosition.z;

				float weight  = CalculateSampleWeight(flatNormal, sampleNormal, mat3(gbufferModelViewInverse) * (samplePosition - position));
				      weight *= (1.0 - 0.2 * abs(offset.x)) * (1.0 - 0.2 * abs(offset.y));

				#ifdef HBAO
				hbao += texelFetch(colortex5, sampleFragCoord, 0) * weight;
				#endif

				#ifdef RSM
				rsm += texelFetch(colortex5, sampleFragCoord + ivec2(res.x, 0), 0).rgb * weight;
				#endif

				weightSum += weight;
			}
		}

		hbao.xyz = normalize(hbao.xyz);
		hbao.w /= weightSum;
		rsm /= weightSum;
	}

	vec3 CalculateFakeBouncedLight(vec3 normal, vec3 lightVector) {
		const vec3 groundAlbedo = vec3(0.1, 0.1, 0.1);
		const vec3 weight = vec3(0.2, 0.6, 0.2); // Fraction of light bounced off the x, y, and z planes. Should sum to 1.0 or less.

		// Divide by pi^2 for energy conservation.
		float bounceIntensity = dot(abs(lightVector) * (-sign(lightVector) * normal * 0.5 + 0.5), weight / (pi * pi));

		return groundAlbedo * bounceIntensity;
	}

	void main() {
		if (gl_FragCoord.x < 6.0 && gl_FragCoord.y < 1.0) {
			if (gl_FragCoord.x < 1.0) {
				colortex5Write.rgb = skylightPosX;
			} else if (gl_FragCoord.x < 2.0) {
				colortex5Write.rgb = skylightPosY;
			} else if (gl_FragCoord.x < 3.0) {
				colortex5Write.rgb = skylightPosZ;
			} else if (gl_FragCoord.x < 4.0) {
				colortex5Write.rgb = skylightNegX;
			} else if (gl_FragCoord.x < 5.0) {
				colortex5Write.rgb = skylightNegY;
			} else {
				colortex5Write.rgb = skylightNegZ;
			}
		} else if (gl_FragCoord.x < 1.0 && gl_FragCoord.y < 2.0) {
			colortex5Write.rgb = shadowlightTransmittance;
		} else {
			colortex5Write.rgb = vec3(0.0);
		}
		colortex5Write.a = 1.0;

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

			// Lighting
			#if defined HBAO || defined RSM
			vec4 hbao; vec3 rsm;
			Filter(normalFlat, position[1], hbao, rsm);
			#endif

			#ifdef HBAO
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

			vec3 shadows = vec3(0.0), bounce = vec3(0.0); float sssDepth = 0.0;
			#ifdef GLOBAL_LIGHT_FADE_WITH_SKYLIGHT
				if (lightmap.y > 0.0) {
					float cloudShadow = GetCloudShadows(position[2]);
					bool translucent = material.translucency.r + material.translucency.g + material.translucency.b > 0.0;
					shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
					if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
						shadows *= CalculateShadows(position, normalFlat, translucent, dither, ditherSize, sssDepth);
					}

					#ifdef RSM
						bounce = rsm * RSM_BRIGHTNESS;
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
					shadows *= CalculateShadows(position, normalFlat, translucent, dither, ditherSize, sssDepth);
				}

				#ifdef RSM
					bounce = rsm * RSM_BRIGHTNESS;
				#else
					bounce  = CalculateFakeBouncedLight(skyConeVector, shadowLightVector);
					bounce *= lightmap.y * lightmap.y * lightmap.y;
				#endif

				bounce *= cloudShadow * ao;
			#endif

			color = CalculateDiffuseLighting(NoL, NoH, NoV, LoV, material, shadows, bounce, sssDepth, skylight, lightmap, blocklightShading, ao);

			shadowsOut = vec4(LinearToSrgb(shadows), 1.0);
			#endif
		} else {
			shadowsOut = vec4(0.0);

			color = DecodeRGBE8(texelFetch(colortex4, ivec2(screenCoord * viewResolution), 0));
		}

		colortex4Write = EncodeRGBE8(color);
	}
#endif
