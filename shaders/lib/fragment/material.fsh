#if !defined INCLUDE_FRAGMENT_MATERIAL
#define INCLUDE_FRAGMENT_MATERIAL

#define RESOURCE_FORMAT_GREYSCALE 0
#define RESOURCE_FORMAT_OPBR      1
#define RESOURCE_FORMAT_NPBR      3
#define RESOURCE_FORMAT_WIP       4
#define RESOURCE_FORMAT RESOURCE_FORMAT_NPBR // [RESOURCE_FORMAT_GREYSCALE RESOURCE_FORMAT_OPBR RESOURCE_FORMAT_NPBR RESOURCE_FORMAT_WIP]

float F0ToIor(float f0) {
	f0 = sqrt(f0) * 0.99999; // *0.99999 to prevent divide by 0 errors
	return (1.0 + f0) / (1.0 - f0);
}
vec3 F0ToIor(vec3 f0) {
	f0 = sqrt(f0) * 0.99999; // *0.99999 to prevent divide by 0 errors
	return (1.0 + f0) / (1.0 - f0);
}

struct Material {
	vec3  albedo;       // Scattering albedo, currently only affects diffuse
	float roughness;    // GGX roughness
	float porosity;     // Currently unused
	vec3  n;            // Index of refraction
	vec3  k;            // Extinction coefficient (for complex index of refraction, needed for metals)
	vec3  emission;     // Emitted light at surface
	vec3  translucency; // Currently unused
};

Material airMaterial   = Material(vec3(0.0), 0.002, 0.0, vec3(1.000275), vec3(0.0), vec3(0.0), vec3(1.0));
Material waterMaterial = Material(vec3(0.0), 0.002, 0.0, vec3(1.333000), vec3(0.0), vec3(0.0), vec3(1.0));

Material MaterialFromTex(vec3 baseTex, vec4 specTex, int id) {
	baseTex = SrgbToLinear(baseTex);

	#ifndef USE_WATER_TEXTURE
		if (id == 8 || id == 9) { return isEyeInWater == 1 ? airMaterial : waterMaterial; }
	#endif

	Material material;

	#if   RESOURCE_FORMAT == RESOURCE_FORMAT_GREYSCALE
		material.albedo       = baseTex;
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = 0.0;
		material.n            = airMaterial.n * F0ToIor(Pow4(specTex.r));
		material.k            = vec3(0.0);
		material.emission     = vec3(0.0);
		material.translucency = vec3(id == 18 || id == 31 || id == 38 || id == 78 || id == 175);
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_OPBR
		material.albedo       = baseTex - baseTex * specTex.g;
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = 0.0;
		material.n            = F0ToIor(mix(vec3(specTex.r), baseTex, specTex.g)) * airMaterial.n;
		material.k            = vec3(0.0);
		material.emission     = baseTex * specTex.b * ARTIFICIAL_LIGHT_LUMINANCE;
		material.translucency = vec3(id == 18 || id == 31 || id == 38 || id == 78 || id == 175);
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_NPBR
		float metalness = smoothstep(0.25, 0.45, specTex.r);

		material.albedo    = baseTex - baseTex * metalness;
		material.roughness = Pow2(1.0 - specTex.b);
		material.porosity  = specTex.g;
		material.n         = F0ToIor(mix(vec3(specTex.r), baseTex, metalness)) * airMaterial.n;
		material.k         = vec3(0.0);

		if (id == 18 || id == 30 || id == 31 || id == 38 || id == 78 || id == 175) {
			material.emission     = vec3(0.0);
			material.translucency = vec3(specTex.a > 0.0 ? 1.0 - specTex.a : 1.0);
		} else {
			material.emission     = baseTex * (1.0 - specTex.a) * float(specTex.a > 0.0) * ARTIFICIAL_LIGHT_LUMINANCE;
			material.translucency = vec3(0.0);
		}
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_WIP
		float sqrtReflectance = specTex.r; // Stored sqrt'd to have more of the smaller values.
		float metalness       = specTex.g; // Linear
		float sqrtRoughness   = specTex.b; // Stored sqrt'd
		float porosity        = specTex.a; // Probably going to be hard-coded by ID or something until _s alpha is properly defaulted by OptiFine.

		material.albedo       = baseTex - baseTex * metalness;
		material.roughness    = Pow2(sqrtRoughness);
		material.porosity     = porosity;
		material.emission     = vec3(0.0); //emisTex.rgb * emisTex.a * ARTIFICIAL_LIGHT_LUMINANCE;
		material.translucency = vec3(0.0);

		if (metalness < 1.0) {
			material.n = F0ToIor(mix(vec3(Pow2(sqrtReflectance)), baseTex, metalness)) * airMaterial.n;
			material.k = vec3(0.0);
		} else { // metalness == 1
			// If specTex.r is 0, calculate n with f0 = baseTex and set k to 0.
			// Otherwise, index into a list of materials based on specTex.r and set n & k based on that.
			// If there's no material for the value specTex.r has, fall back to the same as if it was 0.
			// This gives up to 255 special materials that can have N that doesn't come from baseTex or and/or non-0 K.
			switch (int(specTex.r * 255.0 + 0.5)) {
				default: {
					material.n = F0ToIor(baseTex) * airMaterial.n;
					material.k = vec3(0.0);
					break;
				}
			}
		}
	#endif

	return material;
}

#endif
