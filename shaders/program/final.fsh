#include "/settings.glsl"

//#define DIFFRACTION_SPIKES // Diffraction spikes. Quite slow. Not finished.

#define TONEMAP 1 // [1 2]

//----------------------------------------------------------------------------//

// Viewport
uniform float viewWidth, viewHeight;
uniform float aspectRatio;

// Samplers
uniform sampler2D colortex4; // composite
uniform sampler2D colortex5; // aux0


//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/debug.glsl"

#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/texture.glsl"

vec3 weighAndSumBloomTiles() {
	vec2 px = 1.0 / vec2(viewWidth, viewHeight);

	vec3
	glare  = textureBicubic(colortex5, (screenCoord / exp2(1)) + vec2(0.0000, 0.00000) + vec2(0, 0) * px).rgb * 0.625;
	glare += textureBicubic(colortex5, (screenCoord / exp2(2)) + vec2(0.0000, 0.50000) + vec2(0, 9) * px).rgb * 0.750;
	glare += textureBicubic(colortex5, (screenCoord / exp2(3)) + vec2(0.2500, 0.50000) + vec2(2, 9) * px).rgb * 0.850;
	glare += textureBicubic(colortex5, (screenCoord / exp2(4)) + vec2(0.2500, 0.62500) + vec2(2,18) * px).rgb * 0.925;
	glare += textureBicubic(colortex5, (screenCoord / exp2(5)) + vec2(0.3125, 0.62500) + vec2(4,18) * px).rgb * 0.975;
	glare += textureBicubic(colortex5, (screenCoord / exp2(6)) + vec2(0.3125, 0.65625) + vec2(4,27) * px).rgb * 1.000;
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
			color += texture2D(colortex4, direction * j + screenCoord).rgb * weight;
			totalWeight += weight;
		}
	}
	color /= totalWeight;

	return color;
}

vec3 tonemap_natural(vec3 color) {
	const vec3 p = vec3(2.0, 2.0, 2.0);

	color = pow(color, p);
	return pow(color / (1.0 + color), 1.0 / p);
}

vec3 tonemap_filmic(vec3 color) {
	// a mainly controls the height of the shoulder
	// b and c mainly control toe & overall contrast
	// d controls how much it tends to desaturate (or oversaturate)

	const vec3 a = vec3(1.44, 1.44, 1.44);
	const vec3 b = vec3(0.52, 0.52, 0.52);
	const vec3 c = vec3(0.72, 0.72, 0.72);
	const vec3 d = vec3(0.70, 0.70, 0.70);

	vec3 cr = mix(vec3(dot(color, lumacoeff_rec709)), color, d) + 1.0;

	color = pow(color, a);
	color = pow(color / (1.0 + color), b / a);
	return pow(color * color * (-2.0 * color + 3.0), cr / c);
}

vec3 tonemap(vec3 color) {
	#if   TONEMAP == 1
	return tonemap_natural(color);
	#elif TONEMAP == 2
	return tonemap_filmic(color);
	#endif

	return color; // Reference. This should always look acceptable.
}

void main() {
	vec3 color = texture2D(colortex4, screenCoord).rgb;

	if (BLOOM_AMOUNT != 0.0) color = mix(color, weighAndSumBloomTiles(), BLOOM_AMOUNT / (1.0 + BLOOM_AMOUNT));

	#ifdef DIFFRACTION_SPIKES
	color = mix(color, diffractionSpikes(color), 0.2);
	#endif

	color = tonemap(color);

	color = linearTosRGB(color);
	color += (bayer4(gl_FragCoord.st) / 255.0) + (0.03125 / 255.0);

	gl_FragData[0] = vec4(color, 1.0);

	exit();
}
