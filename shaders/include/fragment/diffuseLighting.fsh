#if !defined INCLUDE_FRAGMENT_DIFFUSELIGHTING
#define INCLUDE_FRAGMENT_DIFFUSELIGHTING

vec3 DiffuseHammon(float NoL, float NoH, float NoV, float LoV, vec3 diffuseAlbedo, float roughness) {
	// Diffuse approximation for GGX + Smith microsurfaces.
	// Uses Schlick fresnel; will not match specular as well if specular is not using Schlick.
	// From what I can tell, the albedo input should be multiplied by `1.0 - f0`.
	// I am not entirely sure of this though, it's possible that the multiply should happen to the output instead.
	// For more details see http://gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
	// ~ Zombye

	if (NoL <= 0.0) { return vec3(0.0); }

	float facing = 0.5 * LoV + 0.5;

	// If NoH is <= 0, the surface either isn't visible or isn't lit
	float single_rough  = NoH <= 0.0 ? 0.0 : facing * (-0.2 * facing + 0.45) * ((1.0 / NoH) + 2.0);
	float single_smooth = 1.05 * (1.0 - Pow5(1.0 - NoL)) * (1.0 - Pow5(1.0 - NoV));

	float single = mix(single_smooth, single_rough, roughness) / pi;
	float multi  = 0.1159 * roughness;

	return Clamp01(NoL * (diffuseAlbedo * multi + single));
}
vec3 DiffuseHammonAmbient(float NoV, vec3 diffuseAlbedo, float roughness) {
	// Diffuse approximation for GGX + Smith microsurfaces.
	// Uses Schlick fresnel; will not match specular as well if specular is not using Schlick.
	// From what I can tell, the albedo input should be multiplied by `1.0 - f0`.
	// I am not entirely sure of this though, it's possible that the multiply should happen to the output instead.
	// For more details see http://gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
	// This is a version I made for when light comes uniformly from every direction
	// ~ Zombye

	NoV = abs(NoV);

	const float single_rough = 0.8; // TODO, this is just roughly the value it usually gets.
	float single_smooth = 1.0 - Pow5(1.0 - NoV);

	float single = mix(single_smooth, single_rough, roughness);
	float multi  = 0.1159 * pi * roughness;

	return multi * diffuseAlbedo + single;
}

vec3 SubsurfaceApprox(float NoL, float LoV, vec3 albedo, vec3 translucency) {
	return (1.0 - albedo) * translucency * abs(NoL) / tau;
}

float CalculateBlocklightFalloff(float blocklight) {
	const float lightmapRange = 15.0;
	const float lightSize     = BLOCK_LIGHT_SIZE;
	const float lightmapScale = lightmapRange / lightSize;

	const float cmp   = lightmapScale * 0.5 - 0.5;
	const float sqMul = 4.0 / ((lightmapScale + 1.0) * (lightmapScale + 1.0));
	const float sqAdd = -sqMul * lightmapScale;

	float falloff = lightmapScale - lightmapScale * blocklight;
	      falloff = falloff < cmp ? 1.0 / (falloff + 1.0) : sqMul * falloff + sqAdd;
	return falloff * falloff;
}

vec3 CalculateDiffuseLighting(
	// Lighting dots
	float NoL,
	float NoH,
	float NoV,
	float LoV,
	// Surface properties
	Material material,
	// Lighting information from before this function is calculated
	vec3 shadows,
	vec3 bounced, // Only from the shadow light
	vec3 skylight,
	vec2 lightmap,
	float blocklightShading,
	float ao
) {
	vec3 diffuseLighting = vec3(0.0);

	#ifdef LIGHTING_ONLY
		material.albedo = vec3(1.0);
	#endif

	vec3 hemisphereDiffuse = DiffuseHammonAmbient(NoV, material.albedo, material.roughness);

	#ifdef GLOBAL_LIGHT_FADE_WITH_SKYLIGHT
		if (lightmap.y > 0.0) {
			float falloff = lightmap.y * exp(6.0 * (lightmap.y - 1.0));

			vec3 diffuse    = DiffuseHammon(NoL, NoH, NoV, LoV, material.albedo, material.roughness);
			vec3 subsurface = SubsurfaceApprox(NoL, -LoV, material.albedo, material.translucency);

			diffuseLighting += ((diffuse + subsurface) * shadows + bounced) * illuminanceShadowlight * falloff;

			#ifdef GLOBAL_LIGHT_USE_AO
				diffuseLighting += falloff * hemisphereDiffuse * skylight;
				diffuseLighting *= ao;
			#else
				diffuseLighting += skylight * hemisphereDiffuse * ao * falloff;
			#endif
		}
	#else
		// Sunlight
		vec3 diffuse    = DiffuseHammon(NoL, NoH, NoV, LoV, material.albedo, material.roughness);
		vec3 subsurface = SubsurfaceApprox(NoL, -LoV, material.albedo, material.translucency);

		#ifdef GLOBAL_LIGHT_USE_AO
			diffuseLighting += illuminanceShadowlight * ((diffuse * ao + subsurface) * shadows + bounced);
		#else
			diffuseLighting += illuminanceShadowlight * ((diffuse + subsurface) * shadows + bounced);
		#endif

		// Skylight
		if (lightmap.y > 0.0) {
			float falloff = lightmap.y * exp(6.0 * (lightmap.y - 1.0));

			diffuseLighting += skylight * hemisphereDiffuse * ao * falloff;
		}
	#endif

	// Block light
	if (lightmap.x > 0.0) {
		float falloff = CalculateBlocklightFalloff(lightmap.x);
		vec3  color   = mix(Blackbody(BLOCK_LIGHT_TEMPERATURE), vec3(1.0), falloff);

		#ifdef BLOCK_LIGHT_USE_AO
			falloff *= ao;
		#endif

		diffuseLighting += BLOCK_LIGHT_LUMINANCE * color * falloff * hemisphereDiffuse * blocklightShading / pi;
	}

	// Ambient light (so you can see anything at all in unlit caves caves)
	diffuseLighting += hemisphereDiffuse * ao * mix(0.002, 0.005, screenBrightness) * NIGHT_SKY_BRIGHTNESS;

	// Done outside all the functions, common small optimization
	diffuseLighting *= material.albedo;

	return diffuseLighting;
}

#endif
