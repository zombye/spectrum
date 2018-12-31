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
#ifdef SHADOW_COLORED
	uniform sampler2D shadowcolor0;
#endif
uniform sampler2D shadowcolor1;

// Misc samplers
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3; // RSM, Clouds Transmittance
uniform sampler2D colortex4; // Sky Encode
uniform sampler2D colortex5; // Sky Scattering LUT
uniform sampler2D colortex6; // Sky Scattering Image
uniform sampler2D colortex7; // Sky Transmittance LUT

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

#if STAGE == STAGE_VERTEX
	//--// Vertex Outputs

	out vec2 screenCoord;

	flat out vec3 skylightPosX;
	flat out vec3 skylightPosY;
	flat out vec3 skylightPosZ;
	flat out vec3 skylightNegX;
	flat out vec3 skylightNegY;
	flat out vec3 skylightNegZ;

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
				vec3 dir = GenUnitVector((vec2(x, y) + 0.5) / samples);

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

		vec3 shadowlightTransmittance = AtmosphereTransmittance(colortex7, vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector);
		luminanceShadowlight   = (sunAngle < 0.5 ? sunLuminance   : moonLuminance)   * shadowlightTransmittance;
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * shadowlightTransmittance;
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	flat in vec3 skylightPosX;
	flat in vec3 skylightPosY;
	flat in vec3 skylightPosZ;
	flat in vec3 skylightNegX;
	flat in vec3 skylightNegY;
	flat in vec3 skylightNegZ;

	flat in vec3 luminanceShadowlight;
	flat in vec3 illuminanceShadowlight;

	//--// Fragment Outputs

	/* DRAWBUFFERS:46 */

	layout (location = 0) out vec4 colortex4Write;
	layout (location = 1) out vec3 colortex6Write;

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

	vec3 CalculateBaseHorizonVector(
		vec3 Po,  // Point on the plane
		vec3 Td,  // Direction to get tangent vector for
		vec3 L,   // Vector in the direction of the line
		vec3 N,   // Normal vector to the plane
		float LdotN // Dot product of L and N
	) {
		/*\
		 * Line-Plane Intersection:
		 *
		 * Lo = Point on the line
		 * D  = Distance to plane, in multiples of L
		 * I  = Point of intersection
		 *
		 * D = dot(Po - Lo, N) / dot(L, N)
		 * I = D * L + Lo
		 *
		 * Extended to getting a tangent vector the way I do it currently:
		 * Ld = Line position vector for getting tangent vector
		 * T  = Tangent vector
		 *
		 * Ld = Lo + Td
		 * D = dot(Po - Ld, N) / dot(L, N)
		 * T = (D * L + Ld) - Po
		 *
		 * This method seems to work perfectly.
		 *
		 * Another method that I used before added an offset to L, rather than Lo.
		 * That method breaks at shallow angles, but aside from that appears to be
		 * identical to this method.
		\*/

		vec3 negPoLd = Td - Po;
		float D = -dot(negPoLd, N) / LdotN;
		return normalize(D * L + negPoLd);
	}

	/*
	#define SSAO_SAMPLES 16
	vec4 CalculateSSAO(vec3 position, vec3 viewVector, vec3 normal, float dither, const int ditherSize) {
		dither = dither * ditherSize + 0.5;

		vec2 perspectiveMult = Diagonal(gbufferProjection).xy * (-0.5 * AO_RADIUS / position.z);

		float ao = 0.0;
		for (int i = 0; i < SSAO_SAMPLES; ++i) {
			vec2 sampleOffset2D = CircleMap(i * ditherSize + dither, SSAO_SAMPLES * ditherSize);
			vec3 sampleOffset   = AO_RADIUS * Rotate(vec3(sampleOffset2D, 0.0), vec3(0, 0, 1), viewVector);

			vec3 samplePosition = position + sampleOffset;
			vec2 sampleCoord = ViewSpaceToScreenSpace(samplePosition, gbufferProjection).xy;
			if (Clamp01(sampleCoord) != sampleCoord) { continue; }

			samplePosition.z = GetLinearDepth(depthtex1, sampleCoord);

			vec3 sampleVector = samplePosition - position;

			float sampleInvDistXY = inversesqrt(dot(sampleVector.xy, sampleVector.xy));

			sampleVector.z = min(sampleVector.z, CalculateBaseHorizonVector2(position, sampleOffset, viewVector, normal, dot(viewVector, normal)).z + position.z);

			ao += atan(sampleVector.z * sampleInvDistXY) * sampleInvDistXY * AO_RADIUS;
		}
		ao = Clamp01(1.0 - ao / SSAO_SAMPLES);

		return vec4(normal, ao);
	}
	//*/

	float CalculateCosBaseHorizonAngle(
		vec3 Po,  // Point on the plane
		vec3 Td,  // Direction to get tangent vector for
		vec3 L,   // (Normalized) Vector in the direction of the line
		vec3 N,   // Normal vector to the plane
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
			vec2 sampleCoord = ViewSpaceToScreenSpace(position + horizonDirection * sampleRadius * AO_RADIUS, gbufferProjection).xy;

			if (Clamp01(sampleCoord) != sampleCoord) { break; }

			//vec3 samplePosition = vec3(sampleCoord, texture(depthtex1, sampleCoord).r);
			//     samplePosition = ScreenSpaceToViewSpace(samplePosition, gbufferProjectionInverse);
			vec3 samplePosition = vec3(sampleCoord * 2.0 - 1.0, GetLinearDepth(depthtex1, sampleCoord));
			#ifdef TAA
				samplePosition.xy -= taaOffset;
			#endif
			samplePosition.xy *= Diagonal(gbufferProjectionInverse).xy * -samplePosition.z;
			samplePosition.z += samplePosition.z * 2e-4; // done to prevent overocclusion in some cases

			vec3  sampleVector          = samplePosition - position;
			float sampleDistanceSquared = dot(sampleVector, sampleVector);

			if (sampleDistanceSquared > AO_RADIUS * AO_RADIUS) { continue; }

			float cosSampleAngle = dot(viewVector, sampleVector) * inversesqrt(sampleDistanceSquared);

			cosHorizonAngle = max(cosHorizonAngle, cosSampleAngle);
		}

		return cosHorizonAngle;
	}
	vec4 CalculateHBAO(vec3 position, vec3 viewVector, vec3 normal, float dither, const int ditherSize) {
		dither += 0.5 / ditherSize;

		float NoV = dot(normal, viewVector);

		vec3 normal2 = Rotate(normal, viewVector, vec3(0,0,1));
		float phiN = atan(normal2.x, normal2.y), thetaN = acos(normal2.z);
		float sinThetaN = sin(thetaN);
		float cosThetaN = normal2.z;

		vec4 result = vec4(0.0); // xyz = direction, w = angle
		for (int i = 0; i < HBAO_DIRECTIONS; ++i) {
			float idx = i + dither;
			float phi = idx * pi / HBAO_DIRECTIONS;
			vec2 xy = SinCos(phi);
			vec3 horizonDirection = Rotate(vec3(xy, 0.0), vec3(0,0,1), viewVector);

			//--// Get cosine horizon angles

			float sampleOffset = fract(idx * ditherSize * phi) / HBAO_ANGLE_SAMPLES;

			float cosTheta1 = CalculateCosHorizonAngle( horizonDirection, position, viewVector, normal, NoV, sampleOffset);
			float cosTheta2 = CalculateCosHorizonAngle(-horizonDirection, position, viewVector, normal, NoV, sampleOffset);

			//--// Integrate over theta

			// Parts that are reused
			float theta1 = acos(clamp(cosTheta1, -1.0, 1.0));
			float theta2 = acos(clamp(cosTheta2, -1.0, 1.0));
			float sinTheta1 = sin(theta1);
			float sinTheta2 = sin(theta2);
			float sinThetaSq1 = sinTheta1 * sinTheta1;
			float sinThetaSq2 = sinTheta2 * sinTheta2;
			float cu1MinusCu2 = sinThetaSq1 * sinTheta1 - sinThetaSq2 * sinTheta2;

			float temp = cos(phiN - phi) * sinThetaN;

			// Average non-occluded direction
			float xym = cos(3.0 * theta1) + cos(3.0 * theta2) - 9.0 * (cosTheta1 + cosTheta2);
			      xym = temp * (0.25 * xym + 4.0) + cosThetaN * cu1MinusCu2;

			result.xy += xy * xym;
			result.z  += temp * cu1MinusCu2 + cosThetaN * (2.0 - Pow3(cosTheta1) - Pow3(cosTheta2));

			// AO
			result.w += temp * (theta1 + 0.5 * (sin(2.0 * theta2) - sin(2.0 * theta1)) - theta2);
			result.w += cosThetaN * (sinThetaSq1 + sinThetaSq2);
		}

		result.xyz = Rotate(result.xyz, vec3(0, 0, 1), viewVector);

		float coneLength = length(result.xyz);
		result.xyz = coneLength <= 0.0 ? normal : result.xyz / coneLength;
		result.w /= 2.0 * HBAO_DIRECTIONS;

		return result;
	}

	float RTAO(mat3 position, vec3 normal, float dither, out vec3 lightdir) {
		const int rays = RTAO_RAYS;
		normal = mat3(gbufferModelView) * normal;

		lightdir = vec3(0.0);
		float ao = 0.0;
		for (int i = 0; i < rays; ++i) {
			vec3 dir = GenUnitVector(Hash2(vec2(dither, i / float(rays))));
			float NoL = dot(dir, normal);
			if (NoL < 0.0) {
				dir = -dir;
				NoL = -NoL;
			}

			vec3 hitPos = position[0];
			if (!RaytraceIntersection(hitPos, position[1], dir, dither, AO_RADIUS, RTAO_RAY_STEPS, 4)) {
				lightdir += dir * NoL;
				ao += NoL;
			}
		}
		float ldl = dot(lightdir, lightdir);
		lightdir = ldl == 0.0 ? normal : lightdir * inversesqrt(ldl);
		lightdir = mat3(gbufferModelViewInverse) * lightdir;

		return ao * 2.0 / rays;
	}

	// --

	vec3 CalculateFakeBouncedLight(vec3 normal, vec3 lightVector) {
		const vec3 groundAlbedo = vec3(0.1, 0.1, 0.1);
		const vec3 weight = vec3(0.2, 0.6, 0.2); // Fraction of light bounced off the x, y, and z planes. Should sum to 1.0 or less.

		// Divide by pi^2 for energy conservation.
		float bounceIntensity = dot(abs(lightVector) * (-sign(lightVector) * normal * 0.5 + 0.5), weight / (pi * pi));

		return groundAlbedo * bounceIntensity;
	}

	vec3 FilterRSM(vec3 normalFlat, float linearDepth) {
		ivec2 fragCoord = ivec2(gl_FragCoord.st) / 2;
		ivec2 shift     = ivec2(gl_FragCoord.st) % 2;

		vec3 result = texelFetch(colortex3, fragCoord, 0).rgb;
		float weightAccum = 1.0;

		for (int x = -4; x < 4; ++x) {
			for (int y = -4; y < 4; ++y) {
				ivec2 offset = ivec2(x, y) + shift;
				if (offset.x == 0 && offset.y == 0) { continue; }

				vec3 sampleNormal = DecodeNormal(Unpack2x8(texelFetch(colortex1, (fragCoord + offset) * 2, 0).a) * 2.0 - 1.0);
				float weight = pow(Clamp01(dot(sampleNormal, normalFlat)), 4.0);

				result += weight * texelFetch(colortex3, fragCoord + offset, 0).rgb;
				weightAccum += weight;
			}
		}

		return result / weightAccum;
	}

	// --

	vec3 CalculateStars(vec3 background, vec3 viewVector) {
		const float scale = 256.0;
		const float coverage = 0.01;
		const float maxLuminance = 0.3;
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
				colortex6Write = skylightPosX;
			} else if (gl_FragCoord.x < 2.0) {
				colortex6Write = skylightPosY;
			} else if (gl_FragCoord.x < 3.0) {
				colortex6Write = skylightPosZ;
			} else if (gl_FragCoord.x < 4.0) {
				colortex6Write = skylightNegX;
			} else if (gl_FragCoord.x < 5.0) {
				colortex6Write = skylightNegY;
			} else {
				colortex6Write = skylightNegZ;
			}
		} else {
			colortex6Write = vec3(0.0);
		}

		mat3 position;
		position[0] = vec3(screenCoord, texture(depthtex1, screenCoord).r);
		position[1] = ScreenSpaceToViewSpace(position[0], gbufferProjectionInverse);
		position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;
		vec3 viewVector = normalize(position[2] - gbufferModelViewInverse[3].xyz);

		#ifdef TAA
			const int ditherSize = 8 * 8 * 16;
			float dither = Bayer8(gl_FragCoord.st) + float(frameCounter % 16) / ditherSize; // should use like a Nx1 bayer matrix for the temporal part
			//float dither = Bayer8(gl_FragCoord.st) + LinearBayer16(frameCounter % 16) * 16 / ditherSize;
		#else
			const int ditherSize = 8 * 8;
			float dither = Bayer8(gl_FragCoord.st);
		#endif

		vec3 color = vec3(0.0);
		if (position[0].z < 1.0) {
			// Gbuffer data
			vec4 colortex0Sample = texture(colortex0, screenCoord);
			vec4 colortex1Sample = texture(colortex1, screenCoord);

			vec3 baseTex;
			baseTex.rg = Unpack2x8(colortex0Sample.r);
			baseTex.b = Unpack2x8X(colortex0Sample.g);
			vec4 specTex;
			specTex.rg = Unpack2x8(colortex1Sample.r);
			specTex.ba = Unpack2x8(colortex1Sample.g);

			int id = int(floor(Unpack2x8Y(colortex0Sample.g) * 255.0 + 0.5));

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
			#if AO_METHOD == AO_SSAO
				vec4 ssao = CalculateSSAO(position[1], -normalize(position[1]), mat3(gbufferModelView) * normal, dither, ditherSize);
				vec3 skyConeVector = ssao.xyz;
				float ao = ssao.a;
			#elif AO_METHOD == AO_HBAO
				vec4 hbao = CalculateHBAO(position[1], -normalize(position[1]), mat3(gbufferModelView) * normal, dither, ditherSize);
				vec3 skyConeVector = mat3(gbufferModelViewInverse) * hbao.xyz;
				float ao = hbao.a;
			#elif AO_METHOD == AO_RTAO
				vec3 skyConeVector;
				float ao = RTAO(position, normal, dither, skyConeVector);
			#else // AO_METHOD == AO_VERTEX
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
					float cloudShadow = Calculate3DCloudShadows(position[2] + cameraPosition);
					bool translucent = material.translucency.r + material.translucency.g + material.translucency.b > 0.0;
					shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
					if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
						shadows *= CalculateShadows(position, normalFlat, translucent, dither, ditherSize);
					}

					#ifdef RSM
						bounce = FilterRSM(normalFlat, position[1].z) * RSM_BRIGHTNESS;
					#else
						bounce  = CalculateFakeBouncedLight(skyConeVector, shadowLightVector);
						bounce *= lightmap.y * lightmap.y * lightmap.y;
					#endif

					bounce *= cloudShadow * ao;
				}
			#else
				float cloudShadow = Calculate3DCloudShadows(position[2] + cameraPosition);
				bool translucent = material.translucency.r + material.translucency.g + material.translucency.b > 0.0;
				shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
				if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
					shadows *= CalculateShadows(position, normalFlat, translucent, dither, ditherSize);
				}

				#ifdef RSM
					bounce = FilterRSM(normalFlat, position[1].z) * RSM_BRIGHTNESS;
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
		} else {
			color  = CalculateStars(vec3(0.0), viewVector);
			color  = CalculateSun(color, viewVector, sunVector);
			color  = CalculateMoon(color, viewVector, moonVector);
			color *= AtmosphereTransmittance(colortex7, vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0), viewVector);

			vec4 sky;
			sky.rgb = DecodeRGBE8(texelFetch(colortex4, ivec2(screenCoord * exp2(-SKY_RENDER_LOD) * viewResolution), 0));
			sky.a   = texelFetch(colortex3, ivec2(screenCoord * exp2(-SKY_RENDER_LOD) * viewResolution), 0).a;
			color = color * sky.a + sky.rgb;

			#ifdef CLOUDS2D
				vec3 viewPosition = vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0);

				float clouds2DDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_planetRadius + CLOUDS2D_ALTITUDE).y;

				vec3 transmittance = AtmosphereTransmittance(colortex7, viewPosition, viewVector, clouds2DDistance) * sky.a;

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
