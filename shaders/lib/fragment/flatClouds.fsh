#define FLATCLOUDS
#define FLATCLOUDS_ALTITUDE 10000.0
#define FLATCLOUDS_COVERAGE 0.45

float flatClouds_phase(float cosTheta) {
	const vec2 g    = vec2(0.25, -0.15);
	const vec2 gm2  = 2.0 * g;
	const vec2 gg   = g * g;
	const vec2 gga1 = 1.0 + gg;
	const vec2 p1   = (0.75 * (1.0 - gg)) / (tau * (2.0 + gg));

	vec2 res = p1 * (cosTheta * cosTheta + 1.0) * pow(gga1 - gm2 * cosTheta, vec2(-1.5));

	return dot(res, vec2(0.4)) + 0.2;
}

vec4 flatClouds_calculate(vec3 viewDirection) {
	vec3 direction = mat3(modelViewInverse) * viewDirection;

	float planeDistance = FLATCLOUDS_ALTITUDE / direction.y;
	if (planeDistance < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

	vec2 cloudPosition = direction.xz * planeDistance + cameraPosition.xz;

	float
	density  = texture2D(noisetex, cloudPosition * 0.000001 + 0.00005 * frameTimeCounter).r * 1.0000 / 1.624;
	density += texture2D(noisetex, cloudPosition * 0.000003 + 0.00025 * frameTimeCounter).r * 0.4000 / 1.624;
	density += texture2D(noisetex, cloudPosition * 0.000009 + 0.00125 * frameTimeCounter).r * 0.1600 / 1.624;
	density += texture2D(noisetex, cloudPosition * 0.000027 + 0.00625 * frameTimeCounter).r * 0.0640 / 1.624;

	const float densityFactor  = 1.0 / FLATCLOUDS_COVERAGE;
	const float coverageFactor = FLATCLOUDS_COVERAGE * densityFactor - densityFactor;
	density  = clamp01(density * densityFactor + coverageFactor);
	density *= density * (-2.0 * density + 3.0) * 0.2;

	vec4 clouds;
	clouds.rgb = shadowLightColor * flatClouds_phase(dot(viewDirection, shadowLightVector)) * transmittedScatteringIntegral(density, 0.5);
	clouds.a = exp(-0.5 * density);
	clouds.rgb *= clouds.a;

	return mix(vec4(0.0, 0.0, 0.0, 1.0), clouds, smoothstep(0.0, 0.1, dot(viewDirection, upVector)));
}
