#if !defined INCLUDE_FRAGMENT_MATERIAL
#define INCLUDE_FRAGMENT_MATERIAL

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

	bool isFoliage = id == 18 || id == 30 || id == 31 || id == 38 || id == 78 || id == 175;

	Material material;

	#if   RESOURCE_FORMAT == RESOURCE_FORMAT_GREYSCALE
		bool isMetal = (id == 41 || id == 42) && specTex.r > 0.5;
		material.albedo       = isMetal ? vec3(0.0) : baseTex;
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = 0.0;
		material.n            = (isMetal ? F0ToIor(baseTex) : vec3(F0ToIor(Pow4(specTex.r)))) * airMaterial.n;
		material.k            = vec3(0.0);
		material.emission     = vec3(0.0);
		material.translucency = vec3(isFoliage);
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_OPBR
		material.albedo       = baseTex - baseTex * specTex.g;
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = 0.0;
		material.n            = F0ToIor(mix(vec3(specTex.r), baseTex, specTex.g)) * airMaterial.n;
		material.k            = vec3(0.0);
		material.emission     = baseTex * specTex.b * BLOCK_LIGHT_LUMINANCE;
		material.translucency = vec3(isFoliage);
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_CONTINUUM2
		float metalness = smoothstep(0.25, 0.45, specTex.r);

		material.albedo    = baseTex - baseTex * metalness;
		material.roughness = Pow2(1.0 - specTex.b);
		material.porosity  = specTex.g;
		material.n         = F0ToIor(mix(vec3(specTex.r), baseTex, metalness)) * airMaterial.n;
		material.k         = vec3(0.0);

		if (isFoliage) {
			material.emission     = vec3(0.0);
			material.translucency = vec3(specTex.a > 0.0 ? 1.0 - specTex.a : 1.0);
		} else {
			material.emission     = baseTex * (1.0 - specTex.a) * float(specTex.a > 0.0) * BLOCK_LIGHT_LUMINANCE;
			material.translucency = vec3(0.0);
		}
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_LAB
		bool isMetal = specTex.g > (229.5 / 255.0);
		bool isPorous = specTex.b < (64.5 / 255.0);

		material.albedo       = isMetal ? vec3(0.0) : baseTex.rgb;
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = !isMetal && isPorous ? specTex.b * (255.0 / 64.0) : 0.0;
		material.n            = F0ToIor(isMetal ? baseTex.rgb : vec3(specTex.g * specTex.g)) * airMaterial.n;
		material.k            = vec3(0.0);
		material.translucency = vec3(!isMetal && !isPorous ? specTex.b * (255.0 / 190.0) - (65.0 / 190.0) : float(isFoliage));
		material.emission     = specTex.a < (254.5 / 255.0) ? baseTex * specTex.a * (255.0 / 254.0) * BLOCK_LIGHT_LUMINANCE : vec3(0.0);
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_WIP
		bool isMetal = specTex.g > (254.5 / 255.0);

		material.albedo       = isMetal ? vec3(0.0) : baseTex;
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = 1.0;
		material.n            = F0ToIor(isMetal ? baseTex : vec3(SrgbToLinear(specTex.g))) * airMaterial.n;
		material.k            = vec3(0.0);
		material.emission     = vec3(0.0); //emisTex.rgb * BLOCK_LIGHT_LUMINANCE;
		material.translucency = vec3(0.0);
	#endif

	return material;
}

#endif
