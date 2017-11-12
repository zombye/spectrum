#define RESOURCE_PACK_TYPE 0 // [0 1]

struct material {
	vec3  albedo;
	float occlusion;
	float reflectance;
	float roughness;
	float porosity;
	float metallicBlend;
	vec3  emittance;
	float subsurface;
};

vec3 material_masklessEmissive(int id, vec3 diff) {
	vec3 emittance = vec3(0.0);

	if (id == 10 || id == 11 || id == 51 || id == 90) emittance = diff; // Lava, Fire, Nether Portal
	if (id == 89 || id == 124 || id == 169) emittance = diff * diff.r;  // Glowstone, Redstone Lamp, Sea Lantern

	return emittance;
}

material material_calculateSEUS(vec3 diff, vec4 spec, masks mask) {
	diff = sRGBToLinear(diff);

	material mat;

	bool isMetal = (mask.id == 41.0 || mask.id == 42.0) && spec.r > 0.0;

	mat.albedo        = diff;
	mat.occlusion     = 1.0;
	mat.reflectance   = isMetal ? 1.0 : spec.r * spec.r * spec.r;
	mat.roughness     = 1.0 - pow(spec.b, 0.2);
	mat.porosity      = 1.0 - spec.g;
	mat.metallicBlend = float(isMetal);
	mat.emittance     = material_masklessEmissive(int(mask.id), diff);
	mat.subsurface    = float(mask.plant);

	return mat;
}
material material_calculateContinuumPBR(vec3 diff, vec4 spec, masks mask) {
	diff = sRGBToLinear(diff);

	material mat;

	mat.albedo        = diff;
	mat.occlusion     = 1.0;
	mat.reflectance   = spec.r;
	mat.roughness     = pow2(1.0 - spec.b);
	mat.porosity      = spec.g;
	mat.metallicBlend = smoothstep(0.25, 0.45, spec.r);
	if (spec.a == 0.0) spec.a = 1.0;
	if (mask.plant) {
		mat.emittance  = vec3(0.0);
		mat.subsurface = 1.0 - spec.a;
	} else {
		mat.emittance  = (1.0 - spec.a) * diff;
		mat.subsurface = 0.0;
	}

	return mat;
}

material calculateMaterial(vec3 diffuse, vec4 specular, masks mask) {
	#if RESOURCE_PACK_TYPE == 1
	return material_calculateContinuumPBR(diffuse, specular, mask);
	#else
	return material_calculateSEUS(diffuse, specular, mask);
	#endif
}

vec3 blendMaterial(vec3 diffuse, vec3 specular, material mat) {
	vec3 dielectric = diffuse + specular;
	vec3 metallic   = mat.albedo * specular;

	return mix(dielectric, metallic, mat.metallicBlend);
}
