#include "/settings.glsl"

#define CREPUSCULAR_RAYS 2 // [0 1 2]
//#define CREPUSCULAR_RAYS_CAUSTICS

const bool gaux1MipmapEnabled = true;

//----------------------------------------------------------------------------//

uniform float wetness;

uniform ivec2 eyeBrightness;

uniform int isEyeInWater;

// Viewport
uniform float viewWidth, viewHeight;

// Time
uniform float frameTimeCounter;

// Positions
uniform vec3 cameraPosition;

// Samplers
uniform sampler2D colortex0; // gbuffer0 | Albedo
uniform sampler2D colortex1; // gbuffer1 | ID, lightmap
uniform sampler2D colortex2; // gbuffer2 | Normal, Specular
uniform sampler2D colortex3; // temporal
uniform sampler2D gaux1;     // composite
uniform sampler2D colortex5; // aux0 | Sunlight visibility
uniform sampler2D colortex6; // aux1 | Transparent composite
uniform sampler2D colortex7; // aux2 | Transparent normal, id, skylight

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/debug.glsl"

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/texture.glsl"

#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"
#include "/lib/uniform/vectors.glsl"

#include "/lib/misc/get3DNoise.glsl"
#include "/lib/misc/importanceSampling.glsl"
#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/masks.fsh"
#include "/lib/fragment/materials.fsh"
//--//

#include "/lib/fragment/sky.fsh"

#include "/lib/fragment/flatClouds.fsh"
#include "/lib/fragment/volumetricClouds.fsh"

#include "/lib/fragment/raytracer.fsh"
#include "/lib/fragment/specularBRDF.fsh"
#include "/lib/fragment/reflections.fsh"

//--//

vec3 fog(vec3 background, vec3 startPosition, vec3 endPosition, vec2 lightmap) {
	vec3 direction = endPosition - startPosition;
	float stepSize = length(direction);
	if (stepSize == 0.0) return background; // Prevent divide by 0
	direction /= stepSize;

	#if CREPUSCULAR_RAYS == 2
	vec3 skylightBrightness = skyLightColor * max(eyeBrightness.y / 240.0, lightmap.y);

	const float steps = 6.0;

	stepSize /= steps;

	vec4 phase = vec4(dot(direction, shadowLightVector));
	     phase = vec4(sky_rayleighPhase(phase.x), sky_miePhase(phase.x, 0.8), sky_miePhase(phase.x, 0.3), 0.5);

	vec3 worldPos = transformPosition(startPosition, gbufferModelViewInverse) + cameraPosition;
	vec3 worldIncrement = mat3(gbufferModelViewInverse) * direction * stepSize;
	vec3 shadowPos = transformPosition(transformPosition(worldPos - cameraPosition, shadowModelView), projectionShadow);
	vec3 shadowIncrement = mat3(projectionShadow) * mat3(shadowModelView) * worldIncrement;

	worldPos  += worldIncrement  * bayer8(gl_FragCoord.st);
	shadowPos += shadowIncrement * bayer8(gl_FragCoord.st);

	float mistFactor = pow5(dot(sunVector, gbufferModelView[0].xyz) * 0.5 + 0.5);
	float mistScaleHeight = mix(200.0, 8.0, mistFactor);
	float mistDensity = 0.02 / mistScaleHeight;
	vec3 ish = vec3(inverseScaleHeights, 1.0 / mistScaleHeight);
	mat3 transmittanceMatrix = mat3(transmittanceCoefficients[0], transmittanceCoefficients[1], vec3(1.0));

	vec3 transmittance = vec3(1.0);
	vec3 scattering    = vec3(0.0);

	for (float i = 0.0; i < steps; i++, worldPos += worldIncrement, shadowPos += shadowIncrement) {
		vec3 opticalDepth = exp(-ish * (worldPos.y - 63.0)) * stepSize;
		opticalDepth.z *= mistDensity;

		mat3 scatterCoeffs = mat3(
			scatteringCoefficients[0] * transmittedScatteringIntegral(opticalDepth.x, transmittanceCoefficients[0]),
			scatteringCoefficients[1] * transmittedScatteringIntegral(opticalDepth.y, transmittanceCoefficients[1]),
			vec3(1.0) * transmittedScatteringIntegral(opticalDepth.z, vec3(1.0))
		);

		vec3 shadowCoord = shadows_distortShadowSpace(shadowPos) * 0.5 + 0.5;
		vec3 sunlight  = (scatterCoeffs * phase.xyz) * shadowLightColor * textureShadow(shadowtex0, shadowCoord);
		     sunlight *= texture2D(colortex5, shadowCoord.st).a;
		vec3 skylight  = (scatterCoeffs * phase.www) * skylightBrightness;

		scattering += (sunlight + skylight) * transmittance;
		transmittance *= exp(-transmittanceMatrix * opticalDepth);
	}
	#else
	float phase = sky_rayleighPhase(dot(direction, shadowLightVector));

	vec3 lighting = (shadowLightColor + skyLightColor) * max(eyeBrightness.y / 240.0, lightmap.y);

	vec3 transmittance = exp(-transmittanceCoefficients[0] * stepSize);
	vec3 scattering    = lighting * scatteringCoefficients[0] * phase * transmittedScatteringIntegral(stepSize, transmittanceCoefficients[0]);
	#endif

	return background * transmittance + scattering;
}

vec3 fakeCrepuscularRays(vec3 viewVector) {
	#if CREPUSCULAR_RAYS != 1
	return vec3(0.0);
	#endif

	float mistFactor = pow5(dot(sunVector, gbufferModelView[0].xyz) * 0.5 + 0.5);
	float mistScaleHeight = mix(200.0, 8.0, mistFactor);
	float mistDensity = 0.02 / mistScaleHeight;

	const float steps = 6.0;

	vec4 lightPosition = projection * vec4(shadowLightVector, 1.0);
	lightPosition = (lightPosition / lightPosition.w) * 0.5 + 0.5;

	vec2 increment = (lightPosition.xy - screenCoord) / steps;
	vec2 sampleCoord = increment * bayer8(gl_FragCoord.st) + screenCoord;

	float result = 0.0;
	for (float i = 0.0; i < steps && floor(sampleCoord) == vec2(0.0); i++, sampleCoord += increment) {
		result += step(1.0, texture2D(depthtex1, sampleCoord).r);
	}

	float directionalMult = clamp01(dot(viewVector, shadowLightVector)); directionalMult *= directionalMult;

	return result * directionalMult * 10.0 * mistDensity * shadowLightColor / steps;
}

//--//

#include "/lib/fragment/water/waves.fsh"
#include "/lib/fragment/water/normal.fsh"
#include "/lib/fragment/water/caustics.fsh"

vec3 waterFog(vec3 background, vec3 startPosition, vec3 endPosition, float skylight) {
	const vec3 scatterCoeff = vec3(0.3e-2, 1.8e-2, 2.0e-2) * 0.4;
	const vec3 absorbCoeff  = vec3(0.8, 0.45, 0.11);
	const vec3 attenCoeff   = scatterCoeff + absorbCoeff;

	#if CREPUSCULAR_RAYS == 2
	const float steps = 6.0;

	vec3 increment = (endPosition - startPosition) / steps;

	float stepSize = length(increment);
	vec3 stepIntegral = transmittedScatteringIntegral(stepSize, attenCoeff);

	increment = mat3(projectionShadow) * mat3(shadowModelView) * mat3(gbufferModelViewInverse) * increment;
	vec3 position = transformPosition(transformPosition(transformPosition(startPosition, gbufferModelViewInverse), shadowModelView), projectionShadow);

	position += increment * bayer8(gl_FragCoord.st);

	vec3 transmittance = vec3(1.0);
	vec3 scattering    = vec3(0.0);

	for (float i = 0.0; i < steps; i++, position += increment) {
		vec3 shadowCoord = shadows_distortShadowSpace(position) * 0.5 + 0.5;
		vec3 sunlight  = scatterCoeff * (0.25/pi) * shadowLightColor * textureShadow(shadowtex1, shadowCoord);
		     sunlight *= texture2D(colortex5, shadowCoord.st).a;
		#ifdef CREPUSCULAR_RAYS_CAUSTICS
		#if CAUSTICS_SAMPLES > 0
		if (sunlight != vec3(0.0)) {
			vec3 shadowPosition = transformPosition(position, projectionShadowInverse);
			sunlight *= waterCaustics(transformPosition(shadowPosition, shadowModelViewInverse), shadowPosition, shadowCoord);
		}
		#endif
		#endif
		vec3 skylight  = scatterCoeff * 0.5 * skyLightColor * skylight;

		scattering    += (sunlight + skylight) * stepIntegral * transmittance;
		transmittance *= exp(-attenCoeff * stepSize);
	}
	#else
	float waterDepth = distance(startPosition, endPosition);

	vec3 transmittance = exp(-attenCoeff * waterDepth);
	vec3 scattering    = ((shadowLightColor * 0.25 / pi) + (skyLightColor * 0.5)) * skylight * scatterCoeff * (1.0 - transmittance) / attenCoeff;
	#endif

	return background * transmittance + scattering;
}

//--//

void main() {
	vec3 composite = texture2D(gaux1, screenCoord).rgb;

	vec4 tex0 = texture2D(colortex0, screenCoord);
	vec2 tex7 = texture2D(colortex7, screenCoord).rg;
	masks mask = calculateMasks(round(tex0.a * 255.0), round(unpack2x8(tex7.r).r * 255.0));

	mat2x3 backPosition;
	backPosition[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	backPosition[1] = screenSpaceToViewSpace(backPosition[0], projectionInverse);
	vec3 direction = normalize(backPosition[1]);

	if (mask.sky) {
		composite = sky_render(composite, direction);
		#ifdef FLATCLOUDS
		vec4 clouds = flatClouds_calculate(direction);
		composite = composite * clouds.a + clouds.rgb;
		#endif
	}

	vec4 tex2 = texture2D(colortex2, screenCoord);
	vec3 normal   = unpackNormal(tex2.rg);
	vec2 lightmap = tex2.ba;

	if (mask.opaque) {
		#ifdef MC_SPECULAR_MAP
		material mat = calculateMaterial(tex0.rgb, texture2D(colortex1, screenCoord), mask);

		vec3 specular = calculateReflections(backPosition, direction, normal, mat.reflectance, mat.roughness, lightmap.y, texture2D(colortex5, screenCoord).rgb);
		composite = blendMaterial(composite, specular, mat);
		#endif
	}

	vec4 clouds = volumetricClouds_calculate(vec3(0.0), backPosition[1], direction, mask.sky);
	composite = composite * clouds.a + clouds.rgb;

	mat3 frontPosition;
	frontPosition[0] = vec3(screenCoord, texture2D(depthtex0, screenCoord).r);
	frontPosition[1] = screenSpaceToViewSpace(frontPosition[0], projectionInverse);
	frontPosition[2] = viewSpaceToSceneSpace(frontPosition[1], gbufferModelViewInverse);
	float frontSkylight = tex7.g;

	if (mask.water) {
		if (isEyeInWater != 1) {
			composite = waterFog(composite, frontPosition[1], backPosition[1], frontSkylight);
		} else {
			composite = fog(composite, frontPosition[1], backPosition[1], lightmap);
			// TODO: Fake crepuscular rays here as well
		}
	}

	vec4 transparent = texture2D(colortex6, screenCoord);
	composite = composite * (1.0 - transparent.a) + transparent.rgb;

	if (isEyeInWater == 1) {
		composite = waterFog(composite, vec3(0.0), frontPosition[1], mask.water ? frontSkylight : lightmap.y);
	} else {
		composite  = fog(composite, vec3(0.0), frontPosition[1], lightmap);
		composite += fakeCrepuscularRays(direction);
	}

	float prevLuminance = texture2D(colortex3, screenCoord).a;
	if (prevLuminance == 0.0) prevLuminance = 100.0;
	composite *= EXPOSURE / prevLuminance;

/* DRAWBUFFERS:4 */

	gl_FragData[0] = vec4(composite, 1.0);

	exit();
}
