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
uniform vec3 previousCameraPosition;

// Time
uniform int   frameCounter;
uniform float frameTimeCounter;

uniform int worldDay;
uniform int worldTime;

// Gbuffer Uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform sampler2D depthtex1;

// Shadow uniforms
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

// Misc samplers
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex5; // Sky Scattering LUT
uniform sampler2D colortex7; // Previous frame data
uniform sampler2D noisetex;

uniform sampler2D depthtex0; // Sky Transmittance LUT
#define transmittanceLut depthtex0

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
#define moonIlluminance (moonIlluminance * NIGHT_SKY_BRIGHTNESS)

#include "/lib/shared/atmosphere/constants.glsl"
#include "/lib/shared/atmosphere/lookup.glsl"
#include "/lib/shared/atmosphere/transmittance.glsl"
#include "/lib/shared/atmosphere/phase.glsl"
#include "/lib/shared/atmosphere/scattering.glsl"

#include "/lib/shared/skyProjection.glsl"

//--// Shared Functions

#if defined STAGE_VERTEX
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
				vec3 dir = GenerateUnitVector((vec2(x, y) + 0.5) / samples);

				vec3 skySample  = AtmosphereScattering(colortex5, vec3(0.0, atmosphere_planetRadius, 0.0), dir, sunVector ) * sunIlluminance;
				     skySample += AtmosphereScattering(colortex5, vec3(0.0, atmosphere_planetRadius, 0.0), dir, moonVector) * moonIlluminance;

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

		averageCloudTransmittance = CalculateAverageCloudTransmittance(GetCloudCoverage());
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	in vec3 skyAmbient;
	in vec3 skyAmbientUp;
	in vec3 illuminanceShadowlight;

	in float averageCloudTransmittance;

	//--// Fragment Outputs

	#if AO_METHOD != AO_VERTEX || defined RSM
		/* DRAWBUFFERS:3467 */

		layout (location = 3) out vec4 halfres;
	#else
		/* DRAWBUFFERS:346 */
	#endif

	layout (location = 0) out float cloudTransmittance;
	layout (location = 1) out vec4  scatteringEncode;
	layout (location = 2) out vec4  skyImage_cloudShadow;

	//--// Fragment Libraries

	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/packing.glsl"
	#include "/lib/utility/rotation.glsl"
	#include "/lib/utility/spaceConversion.glsl"

	#include "/lib/shared/shadowDistortion.glsl"

	#include "/lib/shared/atmosphere/density.glsl"

	#include "/lib/fragment/clouds2D.fsh"
	#include "/lib/fragment/clouds3D.fsh"

	//--// Fragment Functions

	#if AO_METHOD == AO_HBAO || defined RSM
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

		vec3 GetVelocity(vec3 position) {
			//if (position.z >= 1.0) { // Sky doesn't write to the velocity buffer
				vec3 currentPosition = position;

				position = ScreenSpaceToViewSpace(position, gbufferProjectionInverse);
				position = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
				position = position + cameraPosition - previousCameraPosition;
				position = mat3(gbufferPreviousModelView) * position + gbufferPreviousModelView[3].xyz;
				position = ViewSpaceToScreenSpace(position, gbufferPreviousProjection);

				return currentPosition - position;
			//}

			//return texture(colortex5, position.xy).rgb;
		}
	#endif

	#if AO_METHOD == AO_HBAO
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
		vec4 CalculateHBAO(vec3 position, vec3 viewVector, vec3 normal, float dither, const float ditherSize) {
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
	#elif AO_METHOD == AO_RTAO
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
	#endif

	#ifdef RSM
		vec3 ReflectiveShadowMaps(vec3 position, vec3 normal, float skylight, float dither, const float ditherSize) {
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

				vec3 shadowcolor0Sample = textureLod(shadowcolor0, sampleCoord, 0.0).rgb;
				vec3 sampleNormal = DecodeNormal(shadowcolor0Sample.rg * 2.0 - 1.0);

				// Calculate BRDF (lambertian)
				//float sampleIn  = 1.0; // We're sampling the lights projected area so this is just 1.
				float sampleOut = Clamp01(dot(sampleNormal, -sampleVector)) / pi; // Divide by pi for energy conservation.
				float bounceIn  = Clamp01(dot(shadowNormal,  sampleVector));
				float bounceOut = 1.0 / pi; // Divide by pi for energy conservation.

				float brdf = sampleOut * bounceIn * bounceOut;

				#ifdef RSM_LEAK_FIX
					float sampleSkylight = shadowcolor0Sample.b;
					brdf *= Clamp01(1.0 - 5.0 * abs(sampleSkylight - skylight));
				#endif

				vec4 sampleAlbedo = textureLod(shadowcolor1, sampleCoord, 0.0);
				rsm += SrgbToLinear(sampleAlbedo.rgb) * sampleAlbedo.a * brdf / (sampleDistanceSquared + sampleDistanceAdd);
			}

			return rsm * perSampleArea;
		}
	#endif

	#ifdef DISTANT_VL
		mat2x3 CloudShadowedAtmosphere(vec3 startPosition, vec3 viewVector, float endDistance, float cloudCoverage, float dither) {
			const int steps = DISTANT_VL_STEPS;
			//int steps = int(ceil(endDistance / 1000.0));

			float stepSize = abs(endDistance / steps);
			vec3 increment = viewVector * stepSize;
			vec3 position  = startPosition + increment * dither;

			vec3 scattering = vec3(0.0);
			vec3 transmittance = vec3(1.0);

			scattering += AtmosphereScatteringMulti(colortex5, position, viewVector, sunVector ) * sunIlluminance;
			scattering += AtmosphereScatteringMulti(colortex5, position, viewVector, moonVector) * moonIlluminance;
			scattering *= averageCloudTransmittance;

			vec3 sun  = AtmosphereScatteringSingle(colortex5, position, viewVector, sunVector ) * sunIlluminance;
			vec3 moon = AtmosphereScatteringSingle(colortex5, position, viewVector, moonVector) * moonIlluminance;
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

				sun  = Max0(AtmosphereScatteringSingle(colortex5, position, viewVector, sunVector )) * sunIlluminance;
				moon = Max0(AtmosphereScatteringSingle(colortex5, position, viewVector, moonVector)) * moonIlluminance;
				if (sunAngle < 0.5) {
					scattering -= (sun * cloudShadow + moon) * transmittance;
				} else {
					scattering -= (sun + moon * cloudShadow) * transmittance;
				}
			}

			return mat2x3(scattering, transmittance);
		}
	#endif

	#ifdef CLOUDS3D
		float CalculateCloudShadowMap(float cloudCoverage) {
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

			float cloudShadow = 1.0;

			cloudShadow *= Calculate3DCloudShadows(pos, cloudCoverage, 20);

			return cloudShadow;
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

	void main() {
		ivec2 fragCoord = ivec2(gl_FragCoord.xy);

		//--// AO & RSM //----------------------------------------------------//

		#if AO_METHOD != AO_VERTEX || defined RSM
			halfres = vec4(0.0);
		#endif

		#ifdef RSM
			if (screenCoord.x > 0.5 && screenCoord.y < 0.5) {
				ivec2 tile, tileFragCoord; vec2 tileScreenCoord;
				DitherTiles(fragCoord, 4, 2.0, tile, tileFragCoord, tileScreenCoord);
				//tile = fragCoord % 8; tileFragCoord = fragCoord % ivec2(viewResolution / 2); tileScreenCoord = screenCoord * 2.0;

				mat3 position;
				position[0].xy = tileScreenCoord;
				position[1]    = GetViewDirection(position[0].xy, gbufferProjectionInverse);
				position[1]   *= GetLinearDepth(depthtex1, position[0].xy) / position[1].z;
				position[0].z  = ViewSpaceToScreenSpace(position[1].z, gbufferProjection);

				if (position[0].z < 1.0) {
					position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;

					vec3 normal = DecodeNormal(Unpack2x8(texelFetch(colortex1, tileFragCoord * 2, 0).a) * 2.0 - 1.0);
					float skylight = Unpack2x8Y(texelFetch(colortex0, tileFragCoord * 2, 0).b);

					const float ditherSize = 4.0 * 4.0;
					float dither = Bayer4(tile);
					dither = fract(dither + LinearBayer8(frameCounter));

					vec3 velocity = GetVelocity(position[0]);
					vec3 reprojPos = position[0] - velocity;
					bool reprojValid = clamp(reprojPos.xy, viewPixelSize, 1.0 - viewPixelSize) == reprojPos.xy;

					vec3 rsmCurr = ReflectiveShadowMaps(position[2], normal, skylight, dither, ditherSize);
					vec3 rsmPrev = textureLod(colortex7, reprojPos.xy * 0.5 + vec2(0.5, 0.0), 0.0).rgb;

					halfres.rgb = mix(rsmCurr, rsmPrev, reprojValid ? 0.8 : 0.0);
					halfres.a = 1.0;
				} else {
					halfres = vec4(0.0, 0.0, 0.0, 1.0);
				}
			}
		#endif

		#if AO_METHOD != AO_VERTEX
			if (screenCoord.x < 0.5 && screenCoord.y < 0.5) {
				mat3 position;
				position[0].xy = screenCoord * 2.0;
				position[1]    = GetViewDirection(position[0].xy, gbufferProjectionInverse);
				position[1]   *= GetLinearDepth(depthtex1, position[0].xy) / position[1].z;
				position[0].z  = ViewSpaceToScreenSpace(position[1].z, gbufferProjection);

				if (position[0].z < 1.0) {
					position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;

					vec3 normal = DecodeNormal(Unpack2x8(texelFetch(colortex1, fragCoord * 2, 0).a) * 2.0 - 1.0);
					float skylight = Unpack2x8Y(texelFetch(colortex0, fragCoord * 2, 0).b);

					const float ditherSize = 4.0 * 4.0;
					float dither = Bayer4(fragCoord);
					dither = fract(dither + LinearBayer8(frameCounter));

					#if AO_METHOD == AO_HBAO
						vec3 velocity = GetVelocity(position[0]);
						vec3 reprojPos = position[0] - velocity;
						bool reprojValid = clamp(reprojPos.xy, viewPixelSize, 1.0 - viewPixelSize) == reprojPos.xy;

						vec4 hbaoCurr = CalculateHBAO(position[1], -normalize(position[1]), mat3(gbufferModelView) * normal, dither, ditherSize);
						hbaoCurr.xyz = mat3(gbufferModelViewInverse) * hbaoCurr.xyz;
						vec4 hbaoPrev = textureLod(colortex7, reprojPos.xy * 0.5, 0.0);
						if (hbaoPrev.xyz == vec3(0.0)) {
							hbaoPrev = vec4(normal, 1.0);
						} else {
							hbaoPrev.xyz = hbaoPrev.xyz * 2.0 - 1.0;
						}

						halfres = mix(hbaoCurr, hbaoPrev, reprojValid ? 0.8 : 0.0);
						halfres.xyz = normalize(halfres.xyz) * 0.5 + 0.5;
					#endif
				} else {
					halfres = vec4(0.5, 0.5, 0.5, 1.0);
				}
			}
		#endif

		//--// Sky //---------------------------------------------------------//

		const float ditherSize = 16.0 * 16.0;
		float dither = Bayer16(gl_FragCoord.st);
		#ifdef TAA
		      dither = fract(dither + LinearBayer16(frameCounter));
		#endif

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
							transmittance *= AtmosphereTransmittance(transmittanceLut, vlEndPosition, viewVector, Max0(clouds3DDistance - vlEndDistance));
						#else
							scattering *= averageCloudTransmittance;
							float clouds3DDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_planetRadius + CLOUDS3D_ALTITUDE_MIN).y;

							vec3 transmittance = AtmosphereTransmittance(transmittanceLut, viewPosition, viewVector, clouds3DDistance);
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
						vec3 transmittance = AtmosphereTransmittance(transmittanceLut, viewPosition, viewVector, vlEndDistance);

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
		vec3 skyImage;
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

						vec3 transmittance = AtmosphereTransmittance(transmittanceLut, viewPosition, viewVector, clouds3DDistance);
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
							transmittance *= AtmosphereTransmittance(transmittanceLut, clouds3DPosition, viewVector, clouds2DDistance - clouds3DDistance);
						#else
							vec3 transmittance = AtmosphereTransmittance(transmittanceLut, viewPosition, viewVector, clouds2DDistance);
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

		skyImage_cloudShadow.rgb = skyImage;

		#ifdef CLOUDS3D
			skyImage_cloudShadow.a = CalculateCloudShadowMap(cloudCoverage);
		#else
			skyImage_cloudShadow.a = 1.0;
		#endif
	}
#endif
