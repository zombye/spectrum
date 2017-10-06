#include "/settings.glsl"

#define DIFFUSE_MODEL 1 // [0 1]

#define SHADOW_SPACE_QUANTIZATION 0 // Currently causes flickering! [0 1 2 4 8 16]

//#define HAND_LIGHT_SHADOWS // Allows held light sources to cast shadows. Broken!

//----------------------------------------------------------------------------//

// Time
uniform float frameTimeCounter;

// Viewport
uniform float viewWidth, viewHeight;

// Positions
uniform vec3 cameraPosition;

// Hand light
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

// Samplers
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;

uniform sampler2D depthtex1;

uniform sampler2D shadowtex1;

uniform sampler2D noisetex;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
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

#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/masks.fsh"
#include "/lib/fragment/materials.fsh"
#include "/lib/fragment/raytracer.fsh"

//--//

float diffuse_lambertian(vec3 normal, vec3 light) {
	return max0(dot(normal, light)) / pi;
}
float diffuse_burley(vec3 view, vec3 normal, vec3 light, float roughness) {
	return diffuse_lambertian(normal, light);
	const vec2 efc = vec2(-51.0 / 151.0, 1.0) / pi;

	float NoV = max0(dot(normal, view));
	float NoL = max0(dot(normal, light));
	float VoH = max0(dot(view, normalize(light + view)));

	float fd90 = 2.0 * roughness * (VoH * VoH + 0.25) - 1.0;
	vec2  rs   = fd90 * pow5(1.0 - vec2(NoL, NoV)) + 1.0;
	return NoL * rs.x * rs.y * (efc.x * roughness + efc.y);
}

#if DIFFUSE_MODEL == 1
#define diffuse(v, n, l, r) diffuse_burley(v, n, l, r)
#else
#define diffuse(v, n, l, r) diffuse_lambertian(n, l)
#endif

float calculateAntiAcneOffset(float sampleRadius, vec3 normal, float distortFactor) {
	normal.xy = abs(normalize(normal.xy));
	normal    = clamp01(normal);

	float projectionScale = projectionShadow[2].z * 2.0 / projectionShadow[0].x;

	float baseOffset = sampleRadius * projectionScale / (textureSize2D(shadowtex1, 0).x * distortFactor * distortFactor);
	float normalScaling = (normal.x + normal.y) * tan(acos(normal.z));

	return baseOffset * min(normalScaling, 9.0);
}

vec3 shadows(vec3 position) {
	vec3 normal = normalize(cross(dFdx(position), dFdy(position)));

	#if SHADOW_SPACE_QUANTIZATION > 0
		position += cameraPosition;
		position  = (floor(position * SHADOW_SPACE_QUANTIZATION) + 0.5) / SHADOW_SPACE_QUANTIZATION;
		position -= cameraPosition;
	#endif

	normal = mat3(modelViewShadow) * normal;

	position = mat3(modelViewShadow) * position + modelViewShadow[3].xyz;
	position = vec3(projectionShadow[0].x, projectionShadow[1].y, projectionShadow[2].z) * position + projectionShadow[3].xyz;

	float distortFactor = shadows_calculateDistortionCoeff(position.xy);

	position.xy *= distortFactor;
	position = position * 0.5 + 0.5;

	position.z += calculateAntiAcneOffset(0.5, normal, distortFactor);
	position.z -= 0.0001 * distortFactor;

	float result = textureShadow(shadowtex1, position);

	return vec3(result * result * (-2.0 * result + 3.0));
}

float blockLight(float lightmap) {
	return lightmap / (pow2(-16.0 * lightmap + 16.0) + 1.0);
}
#if DIRECTIONAL_SKY_DIFFUSE == OFF
float skyLight(float lightmap, vec3 normal) {
	return (dot(normal, upVector) * 0.2 + 0.8) * lightmap / (pow2(-4.0 * lightmap + 4.0) + 1.0);
}
#endif

float handLight(mat3 position, vec3 normal) {
	// TODO: Make this accurate to standard block lighting

	const mat2x3 handPosition = mat2x3(
		vec3( 1.4, -0.6, -1.0) * MC_HAND_DEPTH,
		vec3(-1.4, -0.6, -1.0) * MC_HAND_DEPTH
	);

	mat2x3 lightVector = handPosition - mat2x3(position[1], position[1]);

	vec2 dist = (15.0 - vec2(heldBlockLightValue, heldBlockLightValue2)) + vec2(length(lightVector[0]), length(lightVector[1]));
	vec2 lm   = clamp01(-0.0625 * dist + 1.0) / (dist * dist + 1.0);

	#ifdef HAND_LIGHT_SHADOWS
	vec3 temp;
	if (heldBlockLightValue  > 0) lm.x *= float(!raytraceIntersection(position[0], normalize(lightVector[0]), temp, bayer8(gl_FragCoord.st), 32.0));
	if (heldBlockLightValue2 > 0) lm.y *= float(!raytraceIntersection(position[0], normalize(lightVector[1]), temp, bayer8(gl_FragCoord.st), 32.0));
	#endif

	lm *= vec2(
		diffuse(normalize(position[1]), normal, normalize(lightVector[0]), 0.0),
		diffuse(normalize(position[1]), normal, normalize(lightVector[1]), 0.0)
	);

	return lm.x + lm.y;
}

//--//

#include "/lib/fragment/volumetricClouds.fsh"

//--//

vec4 bilateralResample(vec3 normal, float depth) {
	const float range = 3.0;
	vec2 px = 1.0 / (COMPOSITE0_SCALE * vec2(viewWidth, viewHeight));

	vec4 filtered = vec4(0.0);
	vec2 totalWeight = vec2(0.0);
	for (float i = -range; i <= range; i++) {
		for (float j = -range; j <= range; j++) {
			vec2 offset = vec2(i, j) * px;
			vec2 coord = clamp01(screenCoord + offset);

			vec3 normalSample = unpackNormal(texture2D(colortex1, coord).rg);
			float depthSample = linearizeDepth(texture2D(depthtex1, coord).r, projectionInverse);

			vec2 weight = vec2(max0(dot(normal, normalSample)), float(i == 0.0 && j == 0.0));
			weight.x *= 1.0 - clamp(abs(depth - depthSample), 0.0, 1.0);

			filtered += texture2D(colortex3, coord * COMPOSITE0_SCALE) * weight.xxxy;
			totalWeight += weight;
		}
	}

	if (totalWeight.x == 0.0) return vec4(0.0);

	filtered /= totalWeight.xxxy;
	return filtered;
}

//--//

void main() {
	vec3 tex0 = textureRaw(colortex0, screenCoord).rgb;

	vec4 diff_id = vec4(unpack2x8(tex0.r), unpack2x8(tex0.g));

	masks mask = calculateMasks(diff_id.a * 255.0);

	mat3 position;
	position[0] = vec3(screenCoord, texture2D(depthtex1, screenCoord).r);
	position[1] = screenSpaceToViewSpace(position[0], projectionInverse);

	#ifdef VOLUMETRICCLOUDS
	gl_FragData[1] = volumetricClouds_calculate(vec3(0.0), position[1], normalize(position[1]), mask.sky);
	#else
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif

	if (mask.id == 0.0) {
		gl_FragData[0] = vec4(0.0);
		gl_FragData[2] = vec4(0.0);
		return;
	}

	position[2]  = viewSpaceToSceneSpace(position[1], modelViewInverse);

	vec3 tex1 = textureRaw(colortex1, screenCoord).rgb;

	material mat = calculateMaterial(diff_id.rgb, unpack2x8(tex1.b), mask);
	vec3 normal   = unpackNormal(tex1.rg);
	vec2 lightmap = unpack2x8(tex0.b);

	//--// Main calculations

	#if defined CAUSTICS || defined RSM || DIRECTIONAL_SKY_DIFFUSE != OFF
	vec4 filtered = bilateralResample(normal, position[1].z);
	#endif

	vec3 sunVisibility = shadows(position[2]);

	vec3
	composite  = shadowLightColor;
	composite *= lightmap.y * lightmap.y;
	composite *= sunVisibility;
	composite *= mix(diffuse_burley(normalize(position[1]), normal, shadowLightVector, mat.roughness), 1.0 / pi, mat.subsurface);
	#ifdef CAUSTICS
	composite *= filtered.a;
	#endif
	#if defined RSM || DIRECTIONAL_SKY_DIFFUSE != OFF
	composite += filtered.rgb;
	#endif
	#if DIRECTIONAL_SKY_DIFFUSE == OFF
	composite += skyLightColor * skyLight(lightmap.y, normal);
	#endif
	composite += blockLightColor * blockLight(lightmap.x);
	composite += blockLightColor * handLight(position, normal);

	composite *= mat.albedo;

/* DRAWBUFFERS:234 */

	gl_FragData[0] = vec4(composite, 1.0);
	gl_FragData[2] = vec4(sunVisibility, 1.0);
}
