#include "/settings.glsl"

#define REFLECTION_SAMPLES 1 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
#define REFLECTION_QUALITY 8.0
#define REFLECTION_REFINEMENTS 4 // The max number needed depends on your resolution and reflection quality setting.
#define VOLUMETRICCLOUDS_REFLECTED // Can have a very high performance impact!

#define REFRACTIONS

#define FAKE_CREPUSCULAR_RAYS // Automatically disabled when volumetric fog is enabled.
#define SIMPLE_FOG            // Automatically disabled when volumetric fog is enabled.

#define VOLUMETRIC_FOG

const bool colortex2MipmapEnabled = true;

//----------------------------------------------------------------------------//

uniform ivec2 eyeBrightness;

uniform int isEyeInWater;

// Viewport
uniform float viewWidth, viewHeight;

// Time
uniform float frameTimeCounter;

// Positions
uniform vec3 cameraPosition;

// Samplers
uniform sampler2D colortex0; // Albedo, ID, Lightmap
uniform sampler2D colortex1; // Normal, Specular
uniform sampler2D colortex2; // Composite
uniform sampler2D colortex3; // Volumetric clouds
uniform sampler2D colortex4; // Sunlight visibility
uniform sampler2D colortex5; // Transparent composite
uniform sampler2D colortex6; // Transparent normal, id, skylight
uniform sampler2D colortex7;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;

uniform sampler2D noisetex;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/texture.glsl"

float get3DNoise(vec3 pos) {
	float flr = floor(pos.z);
	vec2 coord = (pos.xy * 0.015625) + (flr * 0.265625); // 1/64 | 17/64
	vec2 noise = texture2D(noisetex, coord).xy;
	return mix(noise.x, noise.y, pos.z - flr);
}

#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/importanceSampling.glsl"
#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/masks.fsh"
#include "/lib/fragment/materials.fsh"
//--//

#include "/lib/fragment/sky.fsh"

#include "/lib/fragment/flatClouds.fsh"
#include "/lib/fragment/volumetricClouds.fsh"

//--//

#ifdef VOLUMETRIC_FOG

vec3 volumetricFog(vec3 background, vec3 startPosition, vec3 endPosition, vec2 lightmap) {
	vec3 skylightBrightness = skyLightColor * max(eyeBrightness.y / 240.0, lightmap.y);

	const float steps = 16.0;

	vec3 direction = normalize(endPosition - startPosition);

	vec3 phase = vec3(dot(direction, shadowLightVector));
	phase = vec3(sky_rayleighPhase(phase.x), sky_miePhase(phase.x, 0.8), 0.5);

	float stepSize = distance(startPosition, endPosition) / steps;

	vec3 worldPos = mat3(modelViewInverse) * startPosition + modelViewInverse[3].xyz + cameraPosition;
	vec3 worldIncrement = mat3(modelViewInverse) * direction * stepSize;
	vec3 shadowPos = mat3(projectionShadow) * (mat3(modelViewShadow) * (worldPos - cameraPosition) + modelViewShadow[3].xyz) + projectionShadow[3].xyz;
	vec3 shadowIncrement = mat3(projectionShadow) * mat3(modelViewShadow) * worldIncrement;

	worldPos  += worldIncrement * bayer8(gl_FragCoord.st);
	shadowPos += shadowIncrement * bayer8(gl_FragCoord.st);

	vec3 transmittance = vec3(1.0);
	vec3 scattering = vec3(0.0);

	for (float i = 0.0; i < steps; i++, worldPos += worldIncrement, shadowPos += shadowIncrement) {
		vec2 opticalDepth = exp(-inverseScaleHeights * worldPos.y) * stepSize;

		mat2x3 scatterCoeffs = mat2x3(
			scatteringCoefficients[0] * transmittedScatteringIntegral(opticalDepth.x, transmittanceCoefficients[0]),
			scatteringCoefficients[1] * transmittedScatteringIntegral(opticalDepth.y, transmittanceCoefficients[1])
		);

		vec3 sunlight = (scatterCoeffs * phase.xy) * shadowLightColor * textureShadow(shadowtex0, shadows_distortShadowSpace(shadowPos) * 0.5 + 0.5);
		vec3 skylight = (scatterCoeffs * phase.zz) * skylightBrightness;

		scattering += (sunlight + skylight) * transmittance;
		transmittance *= exp(-transmittanceCoefficients * opticalDepth);
	}

	return background * transmittance + scattering;
}

#else

vec3 fog(vec3 background, vec3 startPosition, vec3 endPosition, vec2 lightmap) {
	#ifndef SIMPLE_FOG
	return background;
	#endif

	float opticalDepth = distance(startPosition, endPosition);
	vec3 viewVector = (endPosition - startPosition) / opticalDepth;

	float phase = sky_rayleighPhase(dot(viewVector, shadowLightVector));

	vec3
	lighting = (shadowLightColor + skyLightColor) * max(eyeBrightness.y / 240.0, lightmap.y);

	background *= exp(-transmittanceCoefficients[0] * opticalDepth);
	background += lighting * scatteringCoefficients[0] * phase * transmittedScatteringIntegral(opticalDepth, transmittanceCoefficients[0]);

	return background;
}

vec3 fakeCrepuscularRays(vec3 viewVector) {
	#ifndef FAKE_CREPUSCULAR_RAYS
	return vec3(0.0);
	#endif

	const float steps = 6.0;

	vec4 lightPosition = projection * vec4(shadowLightVector, 1.0);
	lightPosition = (lightPosition / lightPosition.w) * 0.5 + 0.5;

	vec2 increment = (lightPosition.xy - screenCoord) / steps;
	vec2 sampleCoord = increment * bayer8(gl_FragCoord.st) + screenCoord;

	float result = 0.0;
	for (float i = 0.0; i < steps && floor(sampleCoord) == vec2(0.0); i++, sampleCoord += increment) {
		result += step(1.0, texture2D(depthtex1, sampleCoord).r);
	}

	float directionalMult = max0(dot(viewVector, shadowLightVector)); directionalMult *= directionalMult;

	return result * directionalMult * 0.01 * shadowLightColor / steps;
}

#endif

vec3 waterFog(vec3 background, vec3 startPosition, vec3 endPosition, float skylight) {
	const vec3 scatterCoeff = vec3(0.3e-2, 1.8e-2, 2.0e-2);
	const vec3 absorbCoeff  = vec3(0.8, 0.45, 0.11);
	const vec3 attenCoeff   = scatterCoeff + absorbCoeff;

	float waterDepth = distance(startPosition, endPosition);

	vec3 transmittance = exp(-attenCoeff * waterDepth);
	vec3 scattered  = skyLightColor * skylight * scatterCoeff * (1.0 - transmittance) / attenCoeff;

	return background * transmittance + scattered;
}

//--//

#include "/lib/fragment/specularBRDF.fsh"

#include "/lib/fragment/raytracer.fsh"

float calculateReflectionMipGGX(vec3 view, vec3 normal, vec3 light, float zDistance, float alpha2) {
	float NoH = dot(normal, normalize(view + light));

	float p = (NoH * alpha2 - NoH) * NoH + 1.0;
	return max0(0.25 * log2(4.0 * projection[1].y * viewHeight * viewHeight * zDistance * dot(view, normalize(view + light)) * p * p / (REFLECTION_SAMPLES * alpha2 * NoH)));
}

vec3 calculateReflections(mat3 position, vec3 viewDirection, vec3 normal, float reflectance, float roughness, float skyLight) {
	float dither = bayer8(gl_FragCoord.st);

	float ior    = f0ToIOR(reflectance);
	float alpha2 = roughness * roughness;

	vec3 reflection = vec3(0.0);
	for (float i = 0.0; i < REFLECTION_SAMPLES; i++) {
		vec3 facetNormal = is_GGX(normal, hash42(vec2(i, dither)), alpha2);
		if (dot(viewDirection, facetNormal) > 0.0) facetNormal = -facetNormal;
		vec3 rayDir = reflect(viewDirection, facetNormal);

		vec3 hitPos;
		bool intersected = raytraceIntersection(position[0], rayDir, hitPos, dither, REFLECTION_QUALITY, REFLECTION_REFINEMENTS);

		vec3 reflectionSample = vec3(0.0);

		if (intersected) {
			reflectionSample = texture2DLod(colortex2, hitPos.st, calculateReflectionMipGGX(-viewDirection, normal, rayDir, linearizeDepth(hitPos.z, projectionInverse) - position[1].z, alpha2)).rgb;
		} else if (skyLight > 0.1) {
			reflectionSample = sky_atmosphere(vec3(0.0), rayDir);
			#ifdef FLATCLOUDS
			vec4 clouds = flatClouds_calculate(rayDir);
			reflectionSample = reflectionSample * clouds.a + clouds.rgb;
			#endif
			reflectionSample *= smoothstep(0.1, 0.9, skyLight);
		}

		#ifdef VOLUMETRICCLOUDS_REFLECTED
		if (skyLight > 0.1) {
			vec4 clouds = volumetricClouds_calculate(position[1], screenSpaceToViewSpace(hitPos, projectionInverse), rayDir, !intersected);
			clouds = mix(vec4(0.0, 0.0, 0.0, 1.0), clouds, smoothstep(0.1, 0.9, skyLight));
			reflectionSample = reflectionSample * clouds.a + clouds.rgb;
		}
		#endif

		reflectionSample *= f_dielectric(max0(dot(facetNormal, -viewDirection)), 1.0, ior);

		reflection += reflectionSample;
	} reflection /= REFLECTION_SAMPLES;

	return reflection;
}

//--//

vec3 calculateRefractions(vec3 frontPosition, vec3 backPosition, vec3 direction, vec3 normal, masks mask, out vec3 hitPosition) {
	float refractionDepth = distance(frontPosition, backPosition);
	hitPosition = backPosition;

	#ifdef REFRACTIONS
	if (refractionDepth == 0.0)
	#endif
		return texture2D(colortex2, screenCoord).rgb;

	hitPosition = refract(direction, normal, 0.75) * clamp01(refractionDepth) + frontPosition;
	vec3 hitCoord = viewSpaceToScreenSpace(hitPosition, projection);
	hitCoord.z = texture2D(depthtex1, hitCoord.st).r;
	hitPosition = screenSpaceToViewSpace(hitCoord, projectionInverse);

	return texture2D(colortex2, hitCoord.xy).rgb;
}

//--//

void main() {
	// TODO: Only do these first bits if and when needed
	vec3 tex0 = textureRaw(colortex0, screenCoord).rgb;
	vec3 tex1 = textureRaw(colortex1, screenCoord).rgb;
	vec4 tex5 = texture2D(colortex5, screenCoord);
	vec3 tex6 = textureRaw(colortex6, screenCoord).rgb;

	vec4 diff_id = vec4(unpack2x8(tex0.r), unpack2x8(tex0.g));

	masks mask = calculateMasks(diff_id.a * 255.0, unpack2x8(tex6.b).r * 255.0);
	material mat = calculateMaterial(diff_id.rgb, unpack2x8(tex1.b), mask);

	mat3 frontPosition;
	frontPosition[0] = vec3(screenCoord, texture2D(depthtex0, screenCoord).r);
	frontPosition[1] = screenSpaceToViewSpace(frontPosition[0], projectionInverse);
	frontPosition[2] = viewSpaceToSceneSpace(frontPosition[1], modelViewInverse);
	mat3 backPosition;
	backPosition[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	backPosition[1] = screenSpaceToViewSpace(backPosition[0], projectionInverse);
	backPosition[2] = viewSpaceToSceneSpace(backPosition[1], modelViewInverse);
	mat2x3 direction;
	direction[0] = normalize(frontPosition[1]);
	direction[1] = mat3(modelViewInverse) * direction[0];

	vec3 frontNormal = unpackNormal(tex6.rg);
	vec3 backNormal  = unpackNormal(tex1.rg);
	vec2 lightmap = unpack2x8(tex0.b);
	float frontSkylight = unpack2x8(tex6.b).g;

	bool transparentMask = tex5.a > 0.0;

	//--//

	vec3 refractedPosition;
	vec3 composite = calculateRefractions(frontPosition[1], backPosition[1], direction[0], frontNormal, mask, refractedPosition);

	// TODO: Need to figure out how to deal with refractions for the sky
	if (mask.sky) {
		composite = sky_render(composite, direction[0]);
		#ifdef FLATCLOUDS
		vec4 clouds = flatClouds_calculate(direction[0]);
		composite = composite * clouds.a + clouds.rgb;
		#endif
	}
	#ifdef MC_SPECULAR_MAP
	else if (mat.reflectance > 0.0) {
		vec3 specular = calculateReflections(backPosition, direction[0], backNormal, mat.reflectance, mat.roughness, lightmap.y);

		// Sun specular
		specular += texture2D(colortex4, screenCoord).rgb * shadowLightColor * specularBRDF(-direction[0], backNormal, mrp_sphere(reflect(direction[0], backNormal), shadowLightVector, sunAngularRadius), mat.reflectance, mat.roughness * mat.roughness);

		composite = blendMaterial(composite, specular, mat);
	}
	#endif

	vec4 clouds = volumetricClouds_calculate(vec3(0.0), backPosition[1], direction[0], mask.sky);
	composite = composite * clouds.a + clouds.rgb;

	if (mask.water) {
		if (isEyeInWater != 1) {
			composite = waterFog(composite, frontPosition[1], refractedPosition, frontSkylight);
		} else {
			#ifdef VOLUMETRIC_FOG
			composite = volumetricFog(composite, frontPosition[1], refractedPosition, lightmap);
			#else
			composite = fog(composite, frontPosition[1], refractedPosition, lightmap);
			// TODO: Fake crepuscular rays here as well
			#endif
		}
	}

	composite = composite * (1.0 - tex5.a) + tex5.rgb;
	if (mask.water) { composite += calculateReflections(frontPosition, direction[0], frontNormal, 0.02, 0.0, frontSkylight); }

	if (isEyeInWater == 1) {
		composite = waterFog(composite, vec3(0.0), frontPosition[1], mask.water ? frontSkylight : lightmap.y);
	} else {
		#ifdef VOLUMETRIC_FOG
		composite = volumetricFog(composite, vec3(0.0), frontPosition[1], lightmap);
		#else
		composite  = fog(composite, vec3(0.0), frontPosition[1], lightmap);
		composite += fakeCrepuscularRays(direction[0]);
		#endif
	}

	// Exposure - it needs to be done here for the sun to look right
	float prevLuminance = texture2D(colortex7, screenCoord).r;
	if (prevLuminance == 0.0) prevLuminance = 0.35;
	composite *= 0.35 / prevLuminance;

/* DRAWBUFFERS:2 */

	gl_FragData[0] = vec4(composite, 1.0);
}
