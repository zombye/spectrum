#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Time
uniform float frameTimeCounter;

// Positions
uniform vec3 cameraPosition;

// Hand light
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

// Samplers
uniform sampler2D tex;
#ifdef MC_NORMAL_MAP
uniform sampler2D normals;
#endif
#ifdef MC_SPECULAR_MAP
uniform sampler2D specular;
#endif

uniform sampler2D shadowtex0;

uniform sampler2D noisetex;

//----------------------------------------------------------------------------//

varying vec4 tint;

varying vec2 baseUV;
varying vec2 lightmap;

varying mat3 tbn;

varying vec2 metadata;

varying mat3 position;

//----------------------------------------------------------------------------//

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/texture.glsl"

#include "/lib/uniform/vectors.glsl"
#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/shadowMatrices.glsl"

#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/masks.fsh"
#include "/lib/fragment/materials.fsh"

#include "/lib/fragment/water/waves.fsh"
#include "/lib/fragment/water/parallax.fsh"
#include "/lib/fragment/water/normal.fsh"

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

	float baseOffset = sampleRadius * projectionScale / (textureSize2D(shadowtex0, 0).x * distortFactor * distortFactor);
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

	float result = textureShadow(shadowtex0, position);

	return vec3(result * result * (-2.0 * result + 3.0));
}

float blockLight(float lightmap) {
	return lightmap / (pow2(-16.0 * lightmap + 16.0) + 1.0);
}
float skyLight(float lightmap, vec3 normal) {
	return (dot(normal, upVector) * 0.2 + 0.8) * lightmap / (pow2(-2.0 * lightmap + 2.0) + 1.0);
}

float handLight(vec3 position, vec3 normal) {
	// TODO: Make this accurate to standard block lighting

	const mat2x3 handPosition = mat2x3(
		vec3( 1.4, -0.6, -1.0) * MC_HAND_DEPTH,
		vec3(-1.4, -0.6, -1.0) * MC_HAND_DEPTH
	);

	mat2x3 lightVector = handPosition - mat2x3(position, position);

	vec2 dist = (15.0 - vec2(heldBlockLightValue, heldBlockLightValue2)) + vec2(length(lightVector[0]), length(lightVector[1]));
	vec2 lm   = clamp01(-0.0625 * dist + 1.0) / (dist * dist + 1.0);

	lm *= vec2(
		diffuse(normalize(position), normal, normalize(lightVector[0]), 0.0),
		diffuse(normalize(position), normal, normalize(lightVector[1]), 0.0)
	);

	return lm.x + lm.y;
}

//--//

void main() {
	bool waterMask = metadata.x > 7.9 && metadata.x < 9.1;

	vec4 base = texture2D(tex,      baseUV) * tint; if (base.a < 0.102) discard;
	#ifdef MC_NORMAL_MAP
	vec4 norm = texture2D(normals,  baseUV) * 2.0 - 1.0; norm.w = length(norm.xyz); norm.xyz = tbn * norm.xyz / norm.w;
	#else
	vec4 norm = vec4(tbn[2], 1.0);
	#endif
	#ifdef MC_SPECULAR_MAP
	vec4 spec = texture2D(specular, baseUV);
	#else
	vec4 spec = vec4(0.0, 0.0, 0.0, 0.0);
	#endif
	
	if (waterMask) {
		base = vec4(0.1, 0.2, 0.4, 0.15);
		norm.xyz = water_calculateNormal(position[2] + cameraPosition, tbn, normalize(position[1]));
		spec = vec4(0.02, 0.0, 0.9, 0.0);
	}

	masks mask = calculateMasks(metadata.x);
	material mat = calculateMaterial(base.rgb, spec.rb, mask);
	vec3 normal = norm.xyz;

	vec3 sunVisibility = shadows(position[2]);

	vec3
	composite  = shadowLightColor;
	composite *= sunVisibility;
	composite *= mix(diffuse_burley(normalize(position[1]), normal, shadowLightVector, mat.roughness), 1.0 / pi, mat.subsurface);
	composite += skyLightColor * skyLight(lightmap.y, normal);
	composite += blockLightColor * blockLight(lightmap.x);
	composite += blockLightColor * handLight(position[1], normal);

	composite *= mat.albedo;

/* DRAWBUFFERS:56 */

	gl_FragData[0] = vec4(composite, base.a);
	gl_FragData[1] = vec4(packNormal(norm.xyz), pack2x8(vec2(metadata.x / 255.0, lightmap.y)), 1.0);
}
