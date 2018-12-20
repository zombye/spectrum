#if !defined INCLUDE_FRAGMENT_SPECULARLIGHTING
#define INCLUDE_FRAGMENT_SPECULARLIGHTING

//#define SPECULAR_EXACT_FRESNEL

// From https://www.guerrilla-games.com/read/decima-engine-advances-in-lighting-and-aa
// Made radiusCos and RoL inputs but otherwise essentially copy-pasted.
float GetNoHSquared(float radiusCos, float radiusTan, float NoL, float NoV, float VoL, float RoL) {
	// Early out if R falls within the disc
	if (RoL >= radiusCos) { return 1.0; }

	float rOverLengthT = radiusCos * radiusTan * inversesqrt(1.0 - RoL * RoL);
	float NoTr = rOverLengthT * (NoV - RoL * NoL);
	float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);

	// Calculate dot(cross(N, L), V). This could already be calculated and available.
	float triple = sqrt(clamp(1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL, 0.0, 1.0));

	// Do one Newton iteration to improve the bent light vector
	float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
	float NoLVTr = NoL * radiusCos + NoV + NoTr, VoLVTr = VoL * radiusCos + 1.0 + VoTr;
	float p = NoBr * VoLVTr, q = NoLVTr * VoLVTr, s = VoBr * NoLVTr;
	float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
	float xDenom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr + q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
	float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
	float sinTheta = twoX1 * xDenom;
	float cosTheta = 1.0 - twoX1 * xNum;
	NoTr = cosTheta * NoTr + sinTheta * NoBr; // use new T to update NoTr
	VoTr = cosTheta * VoTr + sinTheta * VoBr; // use new T to update VoTr

	// Calculate (N.H)^2 based on the bent light vector
	float newNoL = NoL * radiusCos + NoTr;
	float newVoL = VoL * radiusCos + VoTr;
	float NoH = NoV + newNoL;
	float HoH = 2.0 * newVoL + 2.0;
	return Clamp01(NoH * NoH / HoH);
}

vec3 CalculateSpecularBRDFPoint(float NoL, float NoH, float NoV, float VoH, float alpha2, vec3 n, vec3 k) {
	// A point is used in place of a really, really small light source for simplicity.
	// Small enough that it can be assumed to be invisible unless reflected by a rough surface (which can have facets pointing in the right direction)
	if (alpha2 == 0.0) {
		return vec3(0.0);
	}

	vec3  f  = FresnelDielectric(VoH, 1.000275 / n);
	float d  = DistributionGGX(NoH, alpha2);
	float g2 = G2SmithGGX(NoL, NoV, alpha2);

	return f * d * g2;
}
vec3 CalculateSpecularBRDFSphere(float NoL, float NoV, float LoV, float VoH, float alpha2, vec3 n, vec3 k, float angularRadius) {
	// Specular fraction (fresnel)
	vec3 f = FresnelDielectric(VoH, 1.000275 / n);

	// Reflection direction
	float RoL = 2.0 * NoV * NoL - LoV; // == dot(reflect(-V, N), L)
	if (alpha2 < 0.25/65025) {
		// No roughness, use mirror specular
		return step(cos(angularRadius), RoL) * f / ConeAngleToSolidAngle(angularRadius);
	}

	float NoH = sqrt(GetNoHSquared(cos(angularRadius), tan(angularRadius), NoL, NoV, LoV, RoL));

	// Geometry part
	float d  = DistributionGGX(NoH, alpha2);
	float g2 = G2SmithGGX(NoL, NoV, alpha2);

	return f * d * g2;
}

vec3 CalculateSpecularHighlight(float NoL, float NoV, float LoV, float VoH, float roughness, vec3 n, vec3 k, float angularRadius) {
	float alpha2 = roughness * roughness;

	vec3 brdf = CalculateSpecularBRDFSphere(NoL, NoV, LoV, VoH, alpha2, n, k, angularRadius);

	// NoL modified to fade to 0 only when the light is fully occluded (rather than only when light is halfway occluded)
	float sinLightRadius = sin(angularRadius);
	return brdf * Clamp01((NoL + sinLightRadius) / (1.0 + sinLightRadius)) / abs(NoV);
}

//--//

#if PROGRAM == PROGRAM_COMPOSITE1
	#define SSR_RAY_COUNT       1   // [1 2 3 4 5 6 7 8]
	#define SSR_RAY_STEPS       12  // [4 6 8 12 16 24 32]
	#define SSR_RAY_REFINEMENTS 4   // [0 1 2 3 4 5 6 7 8]
	//#define SSR_TAIL_CLAMP      0.1 // [0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2]

	// From https://hal.archives-ouvertes.fr/hal-01509746/document
	// Had some minor tweaks to fit in spectrum (M_PI -> pi) but otherwise essentially copy-pasted
	// Will probably create my own impmenentation at some point that lets me do tail clamping.
	vec3 sampleGGXVNDF(vec3 V_, float alpha_x, float alpha_y, float U1, float U2)
	{
		// stretch view
		vec3 V = normalize(vec3(alpha_x * V_.x, alpha_y * V_.y, V_.z));

		// orthonormal basis
		vec3 T1 = (V.z < 0.9999) ? normalize(cross(V, vec3(0,0,1))) : vec3(1,0,0);
		vec3 T2 = cross(T1, V);

		// sample point with polar coordinates (r, phi)
		float a = 1.0 / (1.0 + V.z);
		float r = sqrt(U1);
		float phi = (U2<a) ? U2/a * pi : pi + (U2-a)/(1.0-a) * pi;
		float P1 = r*cos(phi);
		float P2 = r*sin(phi)*((U2<a) ? 1.0 : V.z);

		// compute normal
		vec3 N = P1*T1 + P2*T2 + sqrt(max(0.0, 1.0 - P1*P1 - P2*P2))*V;

		// unstretch
		N = normalize(vec3(alpha_x*N.x, alpha_y*N.y, max(0.0, N.z)));
		return N;
	}

	vec3 GenerateSsrFacet(vec3 tangentView, vec3 normal, float roughness, float alpha2, float index, const float ditherSize) {
		vec2 hash = vec2(fract(index * ditherSize * phi), index / SSR_RAY_COUNT); // forms a lattice
		vec3 facet = sampleGGXVNDF(-tangentView, roughness, roughness, hash.x, hash.y);

		vec2 axis = normalize(vec2(-normal.y, normal.x));
		vec3 p1 = normal.z * facet;
		vec3 p2 = sqrt(1.0 - normal.z * normal.z) * cross(vec3(axis, 0.0), facet);
		vec2 p3 = (1.0 - normal.z) * dot(axis.xy, facet.xy) * axis;
		return p1 + p2 + vec3(p3, 0.0);
	}

	float CalculateReflectionMip(vec3 position, vec3 hitPosition, float roughness) {
		// Simple mip level calculation for SSR.
		float positionalScale = distance(position, hitPosition) / -hitPosition.z; // ray length and perspective divide
		float projectionScale = gbufferProjection[1].y;                           // field of view
		float sampleScale     = viewResolution.y * inversesqrt(SSR_RAY_COUNT);    // resolution and sample count

		// This part should really be specific to the distribution, but just "roughness" works well enough most of the time.
		// If it's gonna be accurate it needs to be a little more complicated though.
		float roughnessScale = roughness;

		return log2(positionalScale * projectionScale * sampleScale * roughnessScale);
	}

	vec3 TraceSsrRay(sampler2D sampler, mat3 position, vec3 rayDirection, float NoL, float roughness, float skyFade, float dither) {
		vec3 hitPosition       = position[0];
		vec3 hitPositionView   = position[1];
		vec3 hitPositionScene  = position[2];
		vec3 rayDirectionWorld = mat3(gbufferModelViewInverse) * rayDirection;
		bool intersected       = true;

		if (NoL > 0.0) { // Raytrace if not self-intersecting
			intersected      = RaytraceIntersection(hitPosition, position[1], rayDirection, SSR_RAY_STEPS, SSR_RAY_REFINEMENTS);
			hitPositionView  = intersected ? ScreenSpaceToViewSpace(hitPosition, gbufferProjectionInverse) : rayDirection * 100.0;
			hitPositionScene = mat3(gbufferModelViewInverse) * hitPositionView + gbufferModelViewInverse[3].xyz;
		}

		vec3 result = vec3(0.0);
		if (intersected) {
			//float lod = CalculateReflectionMip(position[1], hitPositionView, roughness);
			result = DecodeRGBE8(textureLod(sampler, hitPosition.xy, 0.0));
		} else if (isEyeInWater == 0) {
			result = texture(colortex6, ProjectSky(rayDirectionWorld)).rgb * skyFade;
		}

		float LoV = dot(rayDirection, shadowLightVector);
		if (isEyeInWater == 1) {
			result = CalculateWaterFog(result, position[2], hitPositionScene, rayDirectionWorld, LoV, skyFade, dither, !intersected);
		} else {
			result = CalculateAirFog(result, position[2], hitPositionScene, rayDirectionWorld, LoV, skyFade, dither, !intersected);
		}

		return result;
	}

	vec3 CalculateSsr(sampler2D sampler, mat3 position, vec3 normal, float NoV, float roughness, vec3 n, vec3 k, float skyFade, float dither, const float ditherSize) {
		float roughnessSquared = roughness * roughness;
		vec3 viewDirection = normalize(position[1]);
		normal = mat3(gbufferModelView) * normal;

		vec3 tangentView = Rotate(viewDirection, normal, vec3(0, 0, 1));

		vec3 reflection = vec3(0.0);
		float averageG2 = 0.0;
		int samples = SSR_RAY_COUNT;
		for (int i = 0; i < SSR_RAY_COUNT; ++i) {
			vec3 facetNormal = GenerateSsrFacet(tangentView, normal, roughness, roughnessSquared, i + dither, ditherSize);

			float MoV /* = MoL */ = abs(dot(facetNormal, -viewDirection));
			#define MoL MoV // MoL and MoV are identical for specular

			vec3 rayDirection = reflect(viewDirection, facetNormal);
			float NoL = abs(dot(normal, rayDirection));

			vec3 reflectionSample = TraceSsrRay(sampler, position, rayDirection, NoL, roughness, skyFade, dither);

			reflectionSample *= FresnelDielectric(MoV, (isEyeInWater == 1 ? 1.333 : 1.0002275) / n);

			vec2 G1G2 = G1G2SmithGGX(NoV, NoL, roughnessSquared);
			reflectionSample *= G1G2.y / G1G2.x;

			reflection += reflectionSample;
		}
		reflection /= samples != 0 ? SSR_RAY_COUNT : 1;

		return reflection;
	}
#endif

#endif
