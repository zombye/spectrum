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

uniform sampler2D shadowtex1;

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
#include "/lib/fragment/water/normal.fsh"

#include "/lib/fragment/specularBRDF.fsh"
#include "/lib/fragment/lighting.fsh"

//--//

void main() {
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

	masks mask = calculateMasks(metadata.x);

	if (mask.water) {
		base = vec4(0.02, 0.03, 0.06, 0.15);
		norm.xyz = water_calculateNormal(position[2] + cameraPosition, tbn, normalize(position[1]));
		spec = vec4(pow(0.02, 1.0 / 3.0), 0.0, 0.99, 0.0);
	}

	material mat = calculateMaterial(base.rgb, spec.rb, mask);
	vec3 normal = norm.xyz;

	vec3 sunVisibility;
	vec3
	composite  = calculateLighting(position, normal, lightmap, mat, sunVisibility);
	composite *= mat.albedo;
	composite += sunVisibility * shadowLightColor * specularBRDF(-normalize(position[1]), normal, mrp_sphere(reflect(normalize(position[1]), normal), shadowLightVector, sunAngularRadius), mat.reflectance, mat.roughness * mat.roughness) / base.a;

/* DRAWBUFFERS:56 */

	gl_FragData[0] = vec4(composite, base.a);
	gl_FragData[1] = vec4(packNormal(norm.xyz), pack2x8(vec2(metadata.x / 255.0, lightmap.y)), 1.0);
}
