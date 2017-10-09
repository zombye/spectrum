#include "/settings.glsl"

//#define DIFFRACTION_SPIKES // Diffraction spikes. Quite slow. Not finished.

//----------------------------------------------------------------------------//

// Viewport
uniform float viewWidth, viewHeight;
uniform float aspectRatio;

// Samplers
uniform sampler2D colortex2;
uniform sampler2D colortex3;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/texture.glsl"

vec3 weighAndSumGlareTiles() {
	if (GLARE_AMOUNT == 0.0) return vec3(0.0); // can't throw floats at the preprocessor :(

	vec2 px = 1.0 / vec2(viewWidth, viewHeight);

	vec3
	glare  = textureBicubic(colortex3, (screenCoord / exp2(1)) + vec2(0.0000, 0.00000) + vec2(0, 0) * px).rgb * 0.625;
	glare += textureBicubic(colortex3, (screenCoord / exp2(2)) + vec2(0.0000, 0.50000) + vec2(0, 8) * px).rgb * 0.750;
	glare += textureBicubic(colortex3, (screenCoord / exp2(3)) + vec2(0.2500, 0.50000) + vec2(2, 8) * px).rgb * 0.850;
	glare += textureBicubic(colortex3, (screenCoord / exp2(4)) + vec2(0.2500, 0.62500) + vec2(2,16) * px).rgb * 0.925;
	glare += textureBicubic(colortex3, (screenCoord / exp2(5)) + vec2(0.3125, 0.62500) + vec2(4,16) * px).rgb * 0.975;
	glare += textureBicubic(colortex3, (screenCoord / exp2(6)) + vec2(0.3125, 0.65625) + vec2(4,24) * px).rgb * 1.000;
	glare /= 5.125;

	return glare;
}

vec3 diffractionSpikes(vec3 color) {
	const float spikeCount   = APERTURE_BLADE_COUNT;
	const float spikeSamples = 32.0;
	const float spikeFalloff = 32.0;
	const float spikeSize    = 0.1 / spikeSamples;
	const float rotation     = radians(APERTURE_BLADE_ROTATION + 180.0);

	float totalWeight = 1.0;
	for (float i = 0.0; i < APERTURE_BLADE_COUNT; i++) {
		float angle = tau * (i / APERTURE_BLADE_COUNT) + rotation;
		vec2 direction = vec2(sin(angle), cos(angle)) * spikeSize / vec2(aspectRatio, 1.0);

		for (float j = 1.0; j < spikeSamples; j++) {
			float weight = j / spikeSamples;
			weight = (1.0 - weight) / (spikeFalloff * weight * weight);
			color += texture2D(colortex2, direction * j + screenCoord).rgb * weight;
			totalWeight += weight;
		}
	}
	color /= totalWeight;

	return color;
}

vec3 tonemap(vec3 color) {
	const vec3 a = vec3(0.46, 0.46, 0.46);
	const vec3 b = vec3(0.60, 0.60, 0.60);

	vec3 cr = mix(vec3(dot(color, lumacoeff_rec709)), color, 0.5) + 1.0;

	color = pow(color / (1.0 + color), a);
	return pow(color * color * (-2.0 * color + 3.0), cr / b);
}

void main() {
	vec3 color = texture2D(colortex2, screenCoord).rgb;

	color = mix(color, weighAndSumGlareTiles(), GLARE_AMOUNT / (1.0 + GLARE_AMOUNT));

	#ifdef DIFFRACTION_SPIKES
	color = mix(color, diffractionSpikes(color), 0.2);
	#endif

	color = tonemap(color);

	color = linearTosRGB(color);
	color += (bayer4(gl_FragCoord.st) / 255.0) + (0.5 / 255.0);

	gl_FragColor = vec4(color, 1.0);
}
