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

	/* RENDERTARGETS: 4 */

	out vec4 fragData;

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

	void main() {
		mat3 frontPosition;
		frontPosition[0] = vec3(screenCoord, texture(depthtex0, screenCoord).r);
		#ifdef TAA
		frontPosition[0].xy -= taaOffset * 0.5;
		#endif
		frontPosition[1] = ScreenSpaceToViewSpace(frontPosition[0], gbufferProjectionInverse);
		frontPosition[2] = mat3(gbufferModelViewInverse) * frontPosition[1] + gbufferModelViewInverse[3].xyz;

		vec3 transparentFlatNormal = normalize(cross(dFdx(frontPosition[2]), dFdy(frontPosition[2])));

		vec3 color = DecodeRGBE8(texture(colortex4, screenCoord));
		if (frontPosition[0].z < 1.0) {
			vec3 viewVector = normalize(frontPosition[2] - gbufferModelViewInverse[3].xyz);

			mat3 backPosition;
			backPosition[0] = vec3(screenCoord, texture(depthtex1, screenCoord).r);
			#ifdef TAA
			backPosition[0].xy -= taaOffset * 0.5;
			#endif
			backPosition[1] = ScreenSpaceToViewSpace(backPosition[0], gbufferProjectionInverse);
			backPosition[2] = mat3(gbufferModelViewInverse) * backPosition[1] + gbufferModelViewInverse[3].xyz;

			float LoV = dot(shadowLightVector, -viewVector);

			float eyeSkylight = eyeBrightness.y / 240.0;
			      eyeSkylight = eyeSkylight * exp(eyeSkylight * 6.0 - 6.0);

			// Dither pattern
			const float ditherSize = 32.0 * 32.0;
			float dither = Bayer32(gl_FragCoord.st);
			#ifdef TAA
			      dither = fract(dither + frameR1);
			#endif

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

			float skylightFade = lightmap.y * exp(lightmap.y * 6.0 - 6.0);

			if (wetness > 0.01 && (backPosition[0].z == frontPosition[0].z)) {
				// rain puddles, idk where to do these tbh but here works
				vec3 flatNormal = DecodeNormal(Unpack2x8(colortex1Sample.a) * 2.0 - 1.0);;

				float rainMask  = 1.0 - Pow2(LinearStep(1.0, 0.01, wetness));
				      rainMask *= Clamp01(lightmap.y * 15.0 - 13.5);
				      rainMask *= LinearStep(0.5, 0.9, normal.y);

				float noise  = TextureCubic(noisetex, fract(0.5 * (frontPosition[2].xz + cameraPosition.xz) / 256.0)).x;
				      noise += TextureCubic(noisetex, fract(1.0 * (frontPosition[2].xz + cameraPosition.xz) / 256.0)).x * 0.5;
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
		}

		fragData = EncodeRGBE8(color);
	}
#endif
