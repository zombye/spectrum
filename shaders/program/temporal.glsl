//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

#if CAMERA_AUTOEXPOSURE == CAMERA_AUTOEXPOSURE_HISTOGRAM
	#define HISTOGRAM_BINS           64
	#define HISTOGRAM_PERCENT_DIM    60
	#define HISTOGRAM_PERCENT_BRIGHT  2

	//#define DEBUG_HISTOGRAM
#endif

const bool colortex6MipmapEnabled = true;

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D depthtex0;

uniform sampler2D colortex3;
uniform sampler2D colortex2;
uniform sampler2D colortex6;

//--// Time uniforms

uniform float frameTime;

//--// Camera uniforms

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

//--// Custom uniforms

uniform vec2 viewResolution;
uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 shadowLightVector;

//--// Shared Includes //-----------------------------------------------------//

#include "/include/utility.glsl"
#include "/include/utility/color.glsl"

//--// Shared Functions //----------------------------------------------------//

vec3 ReadColorLod(vec2 coord, float lod) {
	vec3 color = textureLod(colortex6, coord, lod).rgb;
	return color * color;
}

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

	out vec2 screenCoord;
	out float exposure, previousExposure;

	#ifdef DEBUG_HISTOGRAM
		out vec4[16] histogram;
	#endif

	//--// Vertex Includes //-------------------------------------------------//

	#include "/include/shared/celestialConstants.glsl"

	//--// Vertex Functions //------------------------------------------------//

	const float K = 14.0;
	const float calibration = exp2(CAMERA_AUTOEXPOSURE_BIAS) * K / 100.0;

	const float minExposure = exp2(CAMERA_AUTOEXPOSURE_BIAS) * pi /  dot(sunIlluminance, RgbToXyz[1]);
	const float maxExposure = 0.03 * exp2(CAMERA_AUTOEXPOSURE_BIAS) * pi / (dot(moonIlluminance, RgbToXyz[1]) * NIGHT_SKY_BRIGHTNESS);

	#if CAMERA_AUTOEXPOSURE == CAMERA_AUTOEXPOSURE_HISTOGRAM
		float CalculateHistogramExposure() {
			float maxLod = MaxOf(ceil(log2(viewResolution)));
			vec3 averageColor = ReadColorLod(vec2(0.5), maxLod);
			float averageLuminance = dot(averageColor, RgbToXyz[1]);

			return clamp(1.0 / averageLuminance, minExposure / calibration, maxExposure / calibration);
		}
		float HistogramLuminanceFromBin(float bin) {
			return exp2((bin - (HISTOGRAM_BINS / 2 - 1)) / 4.0);
		}
		float HistogramBinFromLuminance(float luminance) {
			luminance = clamp(luminance, HistogramLuminanceFromBin(0), HistogramLuminanceFromBin(HISTOGRAM_BINS - 1));
			return log2(luminance) * 4.0 + (HISTOGRAM_BINS / 2 - 1);
		}
		float[HISTOGRAM_BINS] CalculateHistogram(float histogramExposure) {
			// create empty histogram
			float[HISTOGRAM_BINS] histogram;
			for (int i = 0; i < HISTOGRAM_BINS; ++i) { histogram[i] = 0.0; }

			const ivec2 samples = ivec2(64, 36);
			float sampleLod = MaxOf(viewResolution / samples);
			      sampleLod = ceil(log2(sampleLod));

			// sample into histogram
			for (int x = 0; x < samples.x; ++x) {
				for (int y = 0; y < samples.y; ++y) {
					vec2 samplePos = (vec2(x, y) + 0.5) / samples;
					vec3 colorSample = ReadColorLod(samplePos, sampleLod);
					float luminanceSample = dot(colorSample, RgbToXyz[1]) * histogramExposure;

					float bin = HistogramBinFromLuminance(luminanceSample);
					      bin = clamp(bin, 0, HISTOGRAM_BINS - 1);

					int bin0 = int(bin);
					int bin1 = bin0 + 1;

					float weight1 = fract(bin);
					float weight0 = 1.0 - weight1;

					// Pixels around the center of the screen are more important, so give them a higher weight in the histogram.
					samplePos = samplePos * 2.0 - 1.0;
					float sampleWeight  = (1.0 - samplePos.x * samplePos.x) * (1.0 - samplePos.y * samplePos.y);
					      sampleWeight *= sampleWeight;

					if (bin0 >= 0) histogram[bin0] += sampleWeight * weight0;
					if (bin1 <= HISTOGRAM_BINS - 1) histogram[bin1] += sampleWeight * weight1;
				}
			}

			return histogram;
		}

		float CalculateTargetExposure(float[HISTOGRAM_BINS] histogram, float histogramExposure) {
			const float brightFraction = 0.01 * HISTOGRAM_PERCENT_BRIGHT;
			const float dimFraction    = 0.01 * HISTOGRAM_PERCENT_DIM;

			float sum = 0.0;
			for (int i = 0; i < HISTOGRAM_BINS; ++i) { sum += histogram[i]; }

			float dimSum = sum * dimFraction;
			float brightSum = sum * (1.0 - brightFraction);

			float l = 0.0, n = 0.0;
			for (int bin = 0; bin < HISTOGRAM_BINS; ++bin) {
				float binValue = histogram[bin];

				// remove dim range
				float dimSub = min(binValue, dimSum);
				binValue  -= dimSub;
				dimSum    -= dimSub;
				brightSum -= dimSub;

				// remove bright range
				binValue = min(binValue, brightSum);
				brightSum -= binValue;

				float binLuminance = HistogramLuminanceFromBin(bin);
				l += binValue * binLuminance / histogramExposure;
				n += binValue;
			}

			l /= n > 0.0 ? n : 1.0;

			const float a =     calibration / minExposure;
			const float b = a - calibration / maxExposure;
			return calibration / (a - b * exp(-l / b));
		}
	#endif

	#if CAMERA_AUTOEXPOSURE == CAMERA_AUTOEXPOSURE_SIMPLE
		float CalculateTargetExposureSimple() {
			float maxLod = MaxOf(ceil(log2(viewResolution)));
			vec3 averageColor = ReadColorLod(vec2(0.5), maxLod);
			float averageLuminance = dot(averageColor, RgbToXyz[1]);

			const float a =     calibration / minExposure;
			const float b = a - calibration / maxExposure;
			return calibration / (a - b * exp(-averageLuminance / b));
		}
	#endif

	void CalculateExposure(out float exposure, out float previousExposure) {
		#if CAMERA_AUTOEXPOSURE != CAMERA_AUTOEXPOSURE_OFF
			#if CAMERA_AUTOEXPOSURE == CAMERA_AUTOEXPOSURE_HISTOGRAM
				float histogramExposure = CalculateHistogramExposure();
				float[HISTOGRAM_BINS] histogram = CalculateHistogram(histogramExposure);
				float targetExposure = CalculateTargetExposure(histogram, histogramExposure);

				#ifdef DEBUG_HISTOGRAM
					float histogramMax = 0.0;
					for (int i = 0; i < 64; ++i) {
						histogramMax = max(histogramMax, histogram[i]);
					}

					for (int i = 0; i < 16; ++i) {
						::histogram[i] = vec4(
							histogram[4*i],
							histogram[4*i+1],
							histogram[4*i+2],
							histogram[4*i+3]
						) / histogramMax;
					}
				#endif
			#else
				float targetExposure = CalculateTargetExposureSimple();
			#endif

			// Get previous exposure
			previousExposure = texture(colortex3, vec2(0.5)).a;
			previousExposure = previousExposure > 0.0 ? previousExposure : targetExposure; // Set to target exposure if 0 since that only happens if it's a new frame
			previousExposure = clamp(previousExposure, minExposure, maxExposure);

			// Determine how quickly to adjust
			float exposureRate = targetExposure < previousExposure ? CAMERA_AUTOEXPOSURE_SPEED_BRIGHT : CAMERA_AUTOEXPOSURE_SPEED_DARK;

			// Calculate final exposure
			exposure = mix(targetExposure, previousExposure, exp(-exposureRate * frameTime));
		#else
			exposure = CAMERA_ISO / (78.0 * CAMERA_SHUTTER_SPEED * CAMERA_FSTOP * CAMERA_FSTOP);
			previousExposure = exposure;
		#endif
	}

	void main() {
		CalculateExposure(exposure, previousExposure);

		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

	in vec2 screenCoord;
	in float exposure, previousExposure;

	#ifdef DEBUG_HISTOGRAM
		in vec4[16] histogram;
	#endif

	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:3 */

	layout (location = 0) out vec4 temporal;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/dithering.glsl"
	#include "/include/utility/fastMath.glsl"
	#include "/include/utility/spaceConversion.glsl"
	#include "/include/utility/textRendering.fsh"

	//--// Fragment Functions //----------------------------------------------//

	// Original from: https://gist.github.com/TheRealMJP/c83b8c0f46b63f3a88a5986f4fa982b1
	vec4 SampleTextureCatmullRom(sampler2D tex, vec2 uv, vec2 texSize) {
		// We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
		// down the sample location to get the exact center of our "starting" texel. The starting texel will be at
		// location [1, 1] in the grid, where [0, 0] is the top left corner.
		vec2 samplePos = uv * texSize;
		vec2 texPos1 = floor(samplePos - 0.5) + 0.5;

		// Compute the fractional offset from our starting texel to our original sample location, which we'll
		// feed into the Catmull-Rom spline function to get our filter weights.
		vec2 f = samplePos - texPos1;

		// Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
		// These equations are pre-expanded based on our knowledge of where the texels will be located,
		// which lets us avoid having to evaluate a piece-wise function.
		vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
		vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
		vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
		vec2 w3 = f * f * (-0.5 + 0.5 * f);

		// Work out weighting factors and sampling offsets that will let us use bilinear filtering to
		// simultaneously evaluate the middle 2 samples from the 4x4 grid.
		vec2 w12 = w1 + w2;
		vec2 offset12 = w2 / (w1 + w2);

		// Compute the final UV coordinates we'll use for sampling the texture
		vec2 texPos0 = texPos1 - 1;
		vec2 texPos3 = texPos1 + 2;
		vec2 texPos12 = texPos1 + offset12;

		texPos0 /= texSize;
		texPos3 /= texSize;
		texPos12 /= texSize;

		vec4
		result  = textureLod(tex, vec2(texPos0.x,  texPos0.y),  0.0) * w0.x  * w0.y;
		result += textureLod(tex, vec2(texPos12.x, texPos0.y),  0.0) * w12.x * w0.y;
		result += textureLod(tex, vec2(texPos3.x,  texPos0.y),  0.0) * w3.x  * w0.y;

		result += textureLod(tex, vec2(texPos0.x,  texPos12.y), 0.0) * w0.x  * w12.y;
		result += textureLod(tex, vec2(texPos12.x, texPos12.y), 0.0) * w12.x * w12.y;
		result += textureLod(tex, vec2(texPos3.x,  texPos12.y), 0.0) * w3.x  * w12.y;

		result += textureLod(tex, vec2(texPos0.x,  texPos3.y),  0.0) * w0.x  * w3.y;
		result += textureLod(tex, vec2(texPos12.x, texPos3.y),  0.0) * w12.x * w3.y;
		result += textureLod(tex, vec2(texPos3.x,  texPos3.y),  0.0) * w3.x  * w3.y;

		return result;
	}

	vec3 ReadColor(vec2 coord) {
		return ReadColorLod(coord, 0.0);
	}

	#ifdef TAA
		vec3 GetClosestFragment(vec3 position, vec2 pixelSize) {
			vec3 closestFragment = position;

			vec3 currentFragment;
			currentFragment.xy = vec2(-1,-1) * pixelSize + position.xy;
			currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2(-1, 0) * pixelSize + position.xy;
			currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2(-1, 1) * pixelSize + position.xy;
			currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 0,-1) * pixelSize + position.xy;
			currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 0, 1) * pixelSize + position.xy;
			currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 1,-1) * pixelSize + position.xy;
			currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 1, 0) * pixelSize + position.xy;
			currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 1, 1) * pixelSize + position.xy;
			currentFragment.z  = texture(depthtex0, currentFragment.xy).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			return closestFragment;
		}

		vec3 GetVelocity(vec3 position) {
			if (position.z >= 1.0) { // Sky doesn't write to the velocity buffer
				vec3 currentPosition = position;

				position = ScreenSpaceToViewSpace(position, gbufferProjectionInverse);
				position = mat3(gbufferPreviousModelView) * mat3(gbufferModelViewInverse) * position;
				position = ViewSpaceToScreenSpace(position, gbufferPreviousProjection);

				return currentPosition - position;
			}

			return texture(colortex2, position.xy).rgb;
		}

		vec3 ClipAABB(vec3 col, vec3 minCol, vec3 avgCol, vec3 maxCol) {
			vec3 clampedCol = clamp(col, minCol, maxCol);

			if (clampedCol != col) {
				vec3 cvec = avgCol - col;

				vec3 dists = mix(maxCol - col, minCol - col, step(0.0, cvec));
				     dists = Clamp01(dists / cvec);

				if (clampedCol.x == col.x) { // ignore x
					if (clampedCol.y == col.y) { // ignore x+y
						col += cvec * dists.z;
					} else if (clampedCol.z == col.z) { // ignore x+z
						col += cvec * dists.y;
					} else { // ignore x
						col += cvec * MaxOf(dists.yz);
					}
				} else if (clampedCol.y == col.y) { // ignore y
					if (clampedCol.z == col.z) { // ignore y+z
						col += cvec * dists.x;
					} else { // ignore y
						col += cvec * MaxOf(dists.xz);
					}
				} else { // ignore z
					col += cvec * MaxOf(dists.xy);
				}
			}

			return col;
		}

		vec3 CalculateTaa(float historyExposure) {
			vec3 position = vec3(screenCoord, texture(depthtex0, screenCoord).r);

			vec3 closestFragment = GetClosestFragment(position, viewPixelSize);

			// Get velocity of closest fragment and set reprojected position based on that
			vec3 velocity = GetVelocity(closestFragment);
			vec3 reprojectedPosition = position - velocity;

			// Read needed current and previous frame color values
			#ifdef TAA_SOFT
			vec3 current = ReadColor(screenCoord + taaOffset * 0.5);
			#else
			vec3 current = ReadColor(screenCoord);
			#endif
			vec3 history = SampleTextureCatmullRom(colortex3, reprojectedPosition.xy, viewResolution).rgb;
			     history = max(history / historyExposure, 0.0);

			// Don't blend if reprojecting an off-screen position
			vec3 blendWeight = vec3(clamp(reprojectedPosition.xy, 0.0, 1.0) == reprojectedPosition.xy ? 0.97 : 0.0);

			// Reduce blend weight when not in the pixel center to reduce blurring
			vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(reprojectedPosition.xy * viewResolution) - 1.0);
			blendWeight *= sqrt(pixelCenterDist.x * pixelCenterDist.y) * TAA_MOTION_REJECTION + (1.0 - TAA_MOTION_REJECTION);

			#ifdef TAA_CLIP
				// Gather nearby samples
				vec3 mc = current;
				vec3 tl = ReadColor(viewPixelSize * vec2(-1,-1) + screenCoord);
				vec3 tc = ReadColor(viewPixelSize * vec2( 0,-1) + screenCoord);
				vec3 tr = ReadColor(viewPixelSize * vec2( 1,-1) + screenCoord);
				vec3 ml = ReadColor(viewPixelSize * vec2(-1, 0) + screenCoord);
				vec3 mr = ReadColor(viewPixelSize * vec2( 1, 0) + screenCoord);
				vec3 bl = ReadColor(viewPixelSize * vec2(-1, 1) + screenCoord);
				vec3 bm = ReadColor(viewPixelSize * vec2( 0, 1) + screenCoord);
				vec3 br = ReadColor(viewPixelSize * vec2( 1, 1) + screenCoord);

				// Min/Avg/Max of nearest 5 + nearest 9
				vec3 min5  = min(min(min(min(tc, ml),  mc),  mr), bm);
				vec3 min9  = min(min(min(min(tl, tr), min5), bl), br);
				vec3 avg5  =  2 * tc      + 2 * ml      + 2 * mc      + 2 * mr      + 2 * bm;
				vec3 asq5  =  4 * tc * tc + 4 * ml * ml + 4 * mc * mc + 4 * mr * mr + 4 * bm * bm;
				vec3 avg9  = (tl      + tr      + avg5 + bl      + br     ) / 14.0;
				vec3 asq9  = (tl * tl + tr * tr + asq5 + bl * bl + br * br) / 14.0;
				vec3 max5  = max(max(max(max(tc, ml),  mc),  mr), bm);
				vec3 max9  = max(max(max(max(tl, tr), min5), bl), br);

				// "Rounded" min/avg/max (avg of values for nearest 5 + nearest 9)
				vec3 minRounded = (min5 + min9) * 0.5;
				vec3 avgRounded = avg9;
				vec3 asqRounded = asq9;
				vec3 maxRounded = (max5 + max9) * 0.5;

				// Clip history
				history = ClipAABB(history, minRounded, avgRounded, maxRounded);

				vec3 variance = asqRounded - avgRounded * avgRounded;
				// Reduce blend weight when (normalized) variance is low, helps reduce ghosting
				// This doesn't work well for lower-resolution effects
				if (closestFragment.z < 1.0) {
					blendWeight *= 1.0 - Clamp01(exp(-2.0 * variance / (avgRounded * avgRounded)));
				}

				// Increase blend weight if current is very different from history
				// Reduces flickering
				//blendWeight  = 1.0 - blendWeight;
				//blendWeight *= Clamp01(exp(-Pow2(current - history) * variance));
				//blendWeight  = 1.0 - blendWeight;
			#endif

			// Blend with history
			vec3 blended = mix(current, history, blendWeight);

			// Return final anti-aliased fragment
			return blended;
		}
	#endif

	void main() {
		#ifdef TAA
			vec3 color = CalculateTaa(previousExposure);
		#else
			vec3 color = ReadColor(screenCoord);
		#endif

		temporal = vec4(color * exposure, exposure);

		#ifdef DEBUG_HISTOGRAM
			{
				const ivec2 pos  = ivec2(4, 3);
				const ivec2 size = ivec2(512, 128);

				vec2 coord = gl_FragCoord.xy - pos;

				if (clamp(coord, vec2(0.0), size) == coord) {
					int idx = int(coord.x / 8.0);
					float barMask = 129.0 * histogram[idx/4][idx%4];
					      barMask = LinearStep(coord.y, coord.y + 1.0, barMask);

					temporal.rgb = mix(temporal.rgb * 0.2, vec3(1.0), barMask);
				}
			}
		#endif
	}
#endif
