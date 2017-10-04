#include "/settings.glsl"

#define REFLECTION_SAMPLES 1 // [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64]
#define REFLECTION_QUALITY 8.0
//#define VOLUMETRICCLOUDS_REFLECTED // Can have a very high performance impact!

const bool colortex2MipmapEnabled = true;

//----------------------------------------------------------------------------//

uniform ivec2 eyeBrightness;

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
uniform sampler2D colortex7;

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

#include "/lib/fragment/volumetricClouds.fsh"

//--//

float f0ToIOR(float f0) {
	f0 = sqrt(f0);
	f0 *= 0.99999; // Prevents divide by 0
	return (1.0 + f0) / (1.0 - f0);
}

float d_GGX(float NoH, float alpha2) {
	float p = (NoH * alpha2 - NoH) * NoH + 1.0;
	return alpha2 / (pi * p * p);
}
float f_dielectric(float NoV, float n1, float n2) {
	float p = 1.0 - (pow2(n1 / n2) * (1.0 - NoV * NoV));
	if (p <= 0.0) return 1.0; p = sqrt(p);

	float Rs = pow2((n1 * NoV - n2 * p  ) / (n1 * NoV + n2 * p  ));
	float Rp = pow2((n1 * p   - n2 * NoV) / (n1 * p   + n2 * NoV));

	return 0.5 * (Rs + Rp);
}
float v_smithGGXCorrelated(float NoV, float NoL, float alpha2) {
	vec2 delta = vec2(NoV, NoL);
	delta *= sqrt((-delta * alpha2 + delta) * delta + alpha2);
	return 0.5 / max(delta.x + delta.y, 1e-9);
}

float brdf(vec3 view, vec3 normal, vec3 light, float reflectance, float alpha2) {
	vec3 halfVec = normalize(view + light);
	float NoV = max0(dot(normal, view));
	float NoH = max0(dot(normal, halfVec));
	float NoL = max0(dot(normal, light));

	float d = d_GGX(NoH, alpha2);
	float f = f_dielectric(NoV, 1.0, f0ToIOR(reflectance));
	float v = v_smithGGXCorrelated(NoV, NoL, alpha2);

	return d * f * v * NoL;
}

#include "/lib/fragment/raytracer.fsh"

float calculateReflectionMipGGX(vec3 view, vec3 normal, vec3 light, float zDistance, float alpha2) {
	float NoH = dot(normal, normalize(view + light));

	float p = (NoH * alpha2 - NoH) * NoH + 1.0;
	return max0(0.25 * log2(4.0 * projection[1].y * viewHeight * viewHeight * zDistance * dot(view, normalize(view + light)) * p * p / (REFLECTION_SAMPLES * alpha2 * NoH)));
}

vec3 calculateReflections(mat3 position, material mat, vec3 normal, float skyLight) {
	if (mat.reflectance == 0.0) return vec3(0.0);

	vec3 viewDir = normalize(position[1]);
	float dither = bayer8(gl_FragCoord.st);

	float ior    = f0ToIOR(mat.reflectance);
	float alpha2 = mat.roughness * mat.roughness;

	vec3 reflection = vec3(0.0);
	for (float i = 0.0; i < REFLECTION_SAMPLES; i++) {
		#if REFLECTION_SAMPLES > 1
		vec3 facetNormal = is_GGX(normal, hash42(vec2(i, dither)), alpha2);
		if (dot(viewDir, facetNormal) > 0.0) facetNormal = -facetNormal;
		#else
		vec3 facetNormal = normal; // Leave roughness to mipmaps when only doing one sample.
		#endif
		vec3 rayDir = reflect(viewDir, facetNormal);

		float fresnel = f_dielectric(max0(dot(facetNormal, -viewDir)), 1.0, ior);

		vec3 hitPos;
		bool intersected = raytraceIntersection(position[0], rayDir, hitPos, dither, REFLECTION_QUALITY);

		vec3 reflectionSample = vec3(0.0);

		if (intersected) reflectionSample = texture2DLod(colortex2, hitPos.st, calculateReflectionMipGGX(-viewDir, normal, rayDir, linearizeDepth(hitPos.z, projectionInverse) - position[1].z, alpha2)).rgb;
		else if (skyLight > 0.1) reflectionSample = sky_atmosphere(vec3(0.0), rayDir) * smoothstep(0.1, 0.9, skyLight);

		#if defined VOLUMETRICCLOUDS && defined VOLUMETRICCLOUDS_REFLECTED
		if (skyLight > 0.1) {
			vec4 clouds = volumetricClouds_calculate(position[1], screenSpaceToViewSpace(hitPos, projectionInverse), rayDir, !intersected);
			reflectionSample = reflectionSample * clouds.a + clouds.rgb;
		}
		#endif

		reflection += reflectionSample * fresnel;
	}
	reflection /= REFLECTION_SAMPLES;

	// Sun specular
	reflection += texture2D(colortex4, screenCoord).rgb * shadowLightColor * brdf(-viewDir, normal, shadowLightVector, mat.reflectance, alpha2);

	return reflection;
}

//--//

#ifdef VOLUMETRIC_FOG

vec3 volumetricFog(vec3 background, mat3 position, vec2 lightmap) {
	vec3 skylightBrightness = skyLightColor * max(eyeBrightness.y / 240.0, lightmap.y);

	const float steps = 16.0;

	vec3 phase = vec3(dot(normalize(position[1]), shadowLightVector));
	phase = vec3(sky_rayleighPhase(phase.x), sky_miePhase(phase.x, 0.8), 0.25 / pi);

	float stepSize = length(position[1]) / steps;

	vec3 worldPos = modelViewInverse[3].xyz + cameraPosition;
	vec3 worldIncrement = mat3(modelViewInverse) * normalize(position[1]) * stepSize;
	vec3 shadowPos = mat3(projectionShadow) * (mat3(modelViewShadow) * modelViewInverse[3].xyz + modelViewShadow[3].xyz) + projectionShadow[3].xyz;
	vec3 shadowIncrement = mat3(projectionShadow) * mat3(modelViewShadow) * worldIncrement;

	worldPos += worldIncrement * bayer8(gl_FragCoord.st);
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
		transmittance *= exp(-(transmittanceCoefficients[0] + transmittanceCoefficients[1]) * stepSize);
	}

	return background * transmittance + scattering * 10.0;
}

#else

#ifdef FAKE_CREPUSCULAR_RAYS
vec3 fakeCrepuscularRays(vec3 viewVector) {
	const float steps = 6.0;

	vec4 lightPosition = projection * vec4(shadowLightVector, 1.0);
	lightPosition = (lightPosition / lightPosition.w) * 0.5 + 0.5;

	vec2 increment = (lightPosition.xy - screenCoord) / steps;
	vec2 sampleCoord = increment * bayer8(gl_FragCoord.st) + screenCoord;

	float result = 0.0;
	for (float i = 0.0; i < steps && floor(sampleCoord) == vec2(0.0); i++, sampleCoord += increment) {
		float fakeCloudShadow = texture2D(colortex3, sampleCoord).a;
		result += step(1.0, texture2D(depthtex1, sampleCoord).r) * fakeCloudShadow;
	}

	float directionalMult = max0(dot(viewVector, shadowLightVector)); directionalMult *= directionalMult;

	return result * directionalMult * 0.01 * shadowLightColor / steps;
}
#endif

#ifdef SIMPLE_FOG
vec3 fog(vec3 background, vec3 position, vec2 lightmap) {
	float opticalDepth = length(position);
	vec3 viewVector = position / opticalDepth;
	
	float phase = sky_rayleighPhase(dot(viewVector, shadowLightVector));

	vec3
	lighting = (shadowLightColor + skyLightColor) * max(eyeBrightness.y / 240.0, lightmap.y) * 10.0;

	background *= exp(-transmittanceCoefficients[0] * opticalDepth);
	background += lighting * scatteringCoefficients[0] * phase * transmittedScatteringIntegral(opticalDepth, transmittanceCoefficients[0]);
	#ifdef FAKE_CREPUSCULAR_RAYS
	background += fakeCrepuscularRays(viewVector);
	#endif

	return background;
}
#endif

#endif

//--//

void main() {
	vec3 tex0 = textureRaw(colortex0, screenCoord).rgb;
	vec3 tex1 = textureRaw(colortex1, screenCoord).rgb;

	vec4 diff_id = vec4(unpack2x8(tex0.r), unpack2x8(tex0.g));

	masks mask = calculateMasks(diff_id.a * 255.0);
	material mat = calculateMaterial(diff_id.rgb, unpack2x8(tex1.b), mask);

	mat3 position;
	position[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	position[1] = screenSpaceToViewSpace(position[0], projectionInverse);
	position[2] = viewSpaceToSceneSpace(position[1], modelViewInverse);

	vec3 normal   = unpackNormal(tex1.rg);
	vec2 lightmap = unpack2x8(tex0.b);

	//--//

	vec3 composite = texture2D(colortex2, screenCoord).rgb;

	if (mask.sky) {
		composite = sky_render(composite, normalize(position[1]));
	} else {
		vec3 specular = calculateReflections(position, mat, normal, lightmap.y);

		composite = blendMaterial(composite, specular, mat);
	}

	composite = mix(composite, texture2D(colortex5, screenCoord).rgb, texture2D(colortex5, screenCoord).a);

	#ifdef VOLUMETRICCLOUDS
	vec4 clouds = texture2D(colortex3, screenCoord);
	composite = composite * clouds.a + clouds.rgb;
	#endif

	#ifdef VOLUMETRIC_FOG
	composite = volumetricFog(composite, position, lightmap);
	#elif defined SIMPLE_FOG
	composite = fog(composite, position[1], lightmap);
	#elif defined FAKE_CREPUSCULAR_RAYS
	composite += fakeCrepuscularRays(normalize(position[1]));
	#endif

	// Apply exposure - it needs to be done here for the sun to work properly.
	float prevLuminance = texture2D(colortex7, screenCoord).r;
	if (prevLuminance == 0.0) prevLuminance = 0.35;
	composite *= 0.35 / prevLuminance;

/* DRAWBUFFERS:2 */

	gl_FragData[0] = vec4(composite, 1.0);
}
