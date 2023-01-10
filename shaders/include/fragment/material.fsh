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
	vec3  albedo;       // Diffuse albedo
	float metalness;    // Only used to scale down diffuse light before adding specular (so metals don't have to just be black in the reflections)
	float roughness;    // GGX roughness
	float porosity;     // Currently unused
	bool  albedoTintsMetalReflections; // For lab, mainly
	vec3  n;            // Index of refraction
	vec3  k;            // Extinction coefficient (for complex index of refraction, needed for metals)
	vec3  emission;     // Emitted light at surface
	vec3  translucency; // Currently unused
};

Material airMaterial   = Material(vec3(0.0), 0.0, 0.002, 0.0, false, vec3(1.000275), vec3(0.0), vec3(0.0), vec3(1.0));
Material waterMaterial = Material(vec3(0.0), 0.0, 0.002, 0.0, false, vec3(1.333000), vec3(0.0), vec3(0.0), vec3(1.0));

Material MaterialFromTex(vec3 baseTex, vec4 specTex, int id) {
	baseTex = LinearFromSrgb(baseTex);

	#ifdef PROCEDURAL_WATER
		if (id == 8 || id == 9) {
			#ifdef TOTAL_INTERNAL_REFLECTION
			return isEyeInWater == 1 ? airMaterial : waterMaterial;
			#else
			return waterMaterial;
			#endif
		}
	#endif

	bool isTranslucent = id == 18 || id == 30 || id == 31 || id == 38 || id == 78 || id == 175 || id == 176;

	Material material;

	#if   RESOURCE_FORMAT == RESOURCE_FORMAT_GREYSCALE
		bool isMetal = (id == 41 || id == 42) && specTex.r > 0.5;
		material.albedo       = baseTex;
		material.metalness    = float(isMetal);
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = 0.0;
		material.albedoTintsMetalReflections = false;
		material.n            = (isMetal ? F0ToIor(baseTex) : vec3(F0ToIor(Pow4(specTex.r)))) * airMaterial.n;
		material.k            = vec3(0.0);
		material.emission     = vec3(0.0);
		material.translucency = vec3(isTranslucent);
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_OPBR
		material.albedo       = baseTex;
		material.metalness    = specTex.g;
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = 0.0;
		material.albedoTintsMetalReflections = false;
		material.n            = F0ToIor(mix(vec3(0.04), baseTex, specTex.g)) * airMaterial.n;
		material.k            = vec3(0.0);
		material.emission     = baseTex * specTex.b * BLOCK_LIGHT_LUMINANCE;
		material.translucency = vec3(isTranslucent);
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_CONTINUUM2
		material.albedo    = baseTex;
		material.metalness = smoothstep(0.25, 0.45, specTex.r);
		material.roughness = Pow2(1.0 - specTex.b);
		material.porosity  = specTex.g;
		material.albedoTintsMetalReflections = true;
		material.n         = F0ToIor(mix(vec3(specTex.r), baseTex, material.metalness)) * airMaterial.n;
		material.k         = vec3(0.0);

		if (isTranslucent) {
			material.emission     = vec3(0.0);
			material.translucency = vec3(specTex.a > 0.0 ? 1.0 - specTex.a : 1.0);
		} else {
			material.emission     = baseTex * (1.0 - specTex.a) * float(specTex.a > 0.0) * BLOCK_LIGHT_LUMINANCE;
			material.translucency = vec3(0.0);
		}
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_LAB_1_1 || RESOURCE_FORMAT == RESOURCE_FORMAT_LAB_1_2 || RESOURCE_FORMAT == RESOURCE_FORMAT_LAB_1_3
		bool isMetal = specTex.g > (229.5 / 255.0);
		bool isPorous = specTex.b < (64.5 / 255.0);

		material.albedo       = baseTex.rgb;
		material.metalness    = float(isMetal);
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = !isMetal && isPorous ? specTex.b * (255.0 / 64.0) : 0.0;
		material.translucency = vec3(!isMetal && !isPorous ? specTex.b * (255.0 / 190.0) - (65.0 / 190.0) : float(isTranslucent));
		material.emission     = specTex.a < (254.5 / 255.0) ? baseTex * specTex.a * (255.0 / 254.0) * BLOCK_LIGHT_LUMINANCE : vec3(0.0);

		if (isMetal) {
			int index = int(specTex.g * 255.0 + 0.5) - 230;
			material.albedoTintsMetalReflections = index < 8;
			if (material.albedoTintsMetalReflections) {
				vec3[8] metalN = vec3[8](
					vec3(2.91140, 2.94970, 2.58450), // Iron
					vec3(0.18299, 0.42108, 1.37340), // Gold
					vec3(1.34560, 0.96521, 0.61722), // Aluminium
					vec3(3.10710, 3.18120, 2.32300), // Chrome
					vec3(0.27105, 0.67693, 1.31640), // Copper
					vec3(1.91000, 1.83000, 1.44000), // Lead
					vec3(2.37570, 2.08470, 1.84530), // Platinum
					vec3(0.15943, 0.14512, 0.13547)  // Silver
				);
				vec3[8] metalK = vec3[8](
					vec3(3.0893, 2.9318, 2.7670), // Iron
					vec3(3.4242, 2.3459, 1.7704), // Gold
					vec3(7.4746, 6.3995, 5.3031), // Aluminium
					vec3(3.3314, 3.3291, 3.1350), // Chrome
					vec3(3.6092, 2.6248, 2.2921), // Copper
					vec3(3.5100, 3.4000, 3.1800), // Lead
					vec3(4.2655, 3.7153, 3.1365), // Platinum
					vec3(3.9291, 3.1900, 2.3808)  // Silver
				);

				material.n = metalN[index];
				material.k = metalK[index];
			} else {
				material.n = F0ToIor(baseTex.rgb) * airMaterial.n;
				material.k = vec3(0.0);
			}
		} else {
			material.albedoTintsMetalReflections = false;
			#if RESOURCE_FORMAT == RESOURCE_FORMAT_LAB_1_3
			material.n = F0ToIor(specTex.g) * airMaterial.n;
			#else
			material.n = F0ToIor(specTex.g * specTex.g) * airMaterial.n;
			#endif
			material.k = vec3(0.0);
		}
	#elif RESOURCE_FORMAT == RESOURCE_FORMAT_WIP
		bool isMetal = specTex.g > (254.5 / 255.0);

		material.albedo       = baseTex;
		material.metalness    = float(isMetal);
		material.roughness    = Pow2(1.0 - specTex.r);
		material.porosity     = 1.0;
		material.n            = F0ToIor(isMetal ? baseTex : vec3(LinearFromSrgb(specTex.g))) * airMaterial.n;
		material.k            = vec3(0.0);
		material.emission     = vec3(0.0); //emisTex.rgb * BLOCK_LIGHT_LUMINANCE;
		material.translucency = vec3(isTranslucent);
	#endif

	return material;
}

#endif
