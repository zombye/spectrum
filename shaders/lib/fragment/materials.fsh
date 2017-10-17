struct material {
	vec3  albedo;
	float occlusion;
	float reflectance;
	float roughness;
	float metallicBlend;
	vec3  emittance;
	float subsurface;
};

material material_calculateSEUS(vec3 diff, vec2 spec, masks mask) {
	material mat;

	bool isMetal = (mask.id == 41.0 || mask.id == 42.0) && spec.r > 0.0;
	bool isEmissive = false; // TODO

	mat.albedo        = sRGBToLinear(diff);
	mat.occlusion     = 1.0;
	mat.reflectance   = isMetal ? 1.0 : spec.r * spec.r * spec.r;
	mat.roughness     = 1.0 - pow(spec.g, 0.2);
	mat.metallicBlend = float(isMetal);
	mat.emittance     = isEmissive ? diff : vec3(0.0);
	mat.subsurface    = float(mask.plant);

	return mat;
}

material calculateMaterial(vec3 diffuse, vec2 specular, masks mask) {
	return material_calculateSEUS(diffuse, specular, mask);
}

vec3 blendMaterial(vec3 diffuse, vec3 specular, material mat) {
	vec3 dielectric = diffuse + specular;
	vec3 metallic   = mat.albedo * specular;

	return mat.emittance * 1e3 + mix(dielectric, metallic, mat.metallicBlend);
}
