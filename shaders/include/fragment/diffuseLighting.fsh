#if !defined INCLUDE_FRAGMENT_DIFFUSELIGHTING
#define INCLUDE_FRAGMENT_DIFFUSELIGHTING

vec3 BRDFDiffuseHammon(float NoL, float NoH, float NoV, float LoV, vec3 diffuseAlbedo, float roughness) {
	// Diffuse approximation for GGX + Smith microsurfaces.
	// Uses Schlick fresnel; will not match specular as well if specular is not using Schlick.
	// From what I can tell, the albedo input should be multiplied by `1.0 - f0`.
	// I am not entirely sure of this though, it's possible that the multiply should happen to the output instead.
	// For more details see http://gdcvault.com/play/1024478/PBR-Diffuse-Lighting-for-GGX
	// ~ Zombye

	float facing = 0.5 * LoV + 0.5;

	float single_rough  = facing * (0.45 - 0.2 * facing) * (inversesqrt(NoH * NoH + 0.01) + 2.0);
	float single_smooth = 1.05 * (1.0 - Pow5(1.0 - NoL)) * (1.0 - Pow5(1.0 - abs(NoV)));

	float single = mix(single_smooth, single_rough, roughness) / pi;
	float multi  = 0.1159 * roughness;

	return diffuseAlbedo * multi + single;
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

vec3 SubsurfaceApprox(float NoL, float LoV, vec3 albedo, vec3 translucency, float sssDepth) {
	sssDepth = max(sssDepth, 0.0);
	float phase = 0.25 / pi; // Should use like a HG phase function here and adjust g same way I do for clouds
	return Clamp01(exp((albedo * 0.5 - 1.0) * sssDepth / translucency)) * phase;
}

float CalculateBlocklightFalloff(float blocklight) {
	if (blocklight >= 1.0) { return 1.0; } // Return 1 for "emissive" stuff as I currently don't handle emission from lightmap properly

	// Light falloff calculation for block light sources.
	// Uses a realistic falloff where the light is the surface of a sphere, then remaps it to hit 0 at the end.
	// Would really like if Minecraft's lightmaps extended further though. Would look so much better.

	const float lightmapRange = 15.0;
	const float lightDiameter = BLOCK_LIGHT_SIZE;
	const float lightRadius = lightDiameter / 2.0;

	// Illuminance integral, assuming NdotL = 1 since we don't know the actual direction of the light.
	// Leaves out luminance multiplier, that should be done outside of this function
	float lightDistance = lightmapRange * (1.0 - blocklight);
	float illuminance = (pi * lightRadius * lightRadius) / Pow2(lightDistance + lightRadius);

	// subtract illuminance at end so it reaches 0 and scale to keep illuminance at start same as before
	const float minIlluminance = (pi * lightRadius * lightRadius) / pow(lightmapRange + lightRadius, 2.0);
	const float maxIlluminance = pi;
	const float scale = maxIlluminance / (maxIlluminance - minIlluminance);
	illuminance = illuminance * scale - (minIlluminance * scale);

	return illuminance;
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
	float cloudShadows,
	vec3 bounced, // Only from the shadow light
	float sssDepth, // Depth to use for subsurface scattering
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

			vec3 brdf       = BRDFDiffuseHammon(NoL, NoH, NoV, LoV, material.albedo, material.roughness);
			vec3 subsurface = SubsurfaceApprox(NoL, -LoV, material.albedo, material.translucency, sssDepth);

			diffuseLighting += (brdf * max(NoL, 0.0) * shadows + subsurface * cloudShadows + bounced) * illuminanceShadowlight * falloff;

			#ifdef GLOBAL_LIGHT_USE_AO
				diffuseLighting += falloff * hemisphereDiffuse * skylight;
				diffuseLighting *= ao;
			#else
				diffuseLighting += skylight * hemisphereDiffuse * ao * falloff;
			#endif
		}
	#else
		// Sunlight
		vec3 brdf       = BRDFDiffuseHammon(NoL, NoH, NoV, LoV, material.albedo, material.roughness);
		vec3 subsurface = SubsurfaceApprox(NoL, -LoV, material.albedo, material.translucency, sssDepth);

		#ifdef GLOBAL_LIGHT_USE_AO
			diffuseLighting += illuminanceShadowlight * (brdf * max(NoL, 0.0) * ao * shadows + subsurface * cloudShadows + bounced);
		#else
			diffuseLighting += illuminanceShadowlight * (brdf * max(NoL, 0.0) * shadows + subsurface * cloudShadows + bounced);
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
		vec3  color   = mix(Blackbody(BLOCK_LIGHT_TEMPERATURE), vec3(1.0), falloff / pi);

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
