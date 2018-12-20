//--// Settings

#include "/settings.glsl"

const bool colortex6MipmapEnabled = true;

//--// Uniforms

uniform float frameTime;

//
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform sampler2D depthtex0;

// Custom Uniforms
uniform vec2 viewResolution;
uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 shadowLightVector;

//--// Shared Libraries

#include "/lib/utility.glsl"
#include "/lib/utility/colorspace.glsl"

//--// Shared Functions

vec3 ReadColorLod(vec2 coord, float lod) {
	vec3 color = textureLod(colortex6, coord, lod).rgb;
	return color * color;
}

#if STAGE == STAGE_VERTEX
	//--// Vertex Outputs

	out vec2 screenCoord;
	out float exposure, previousExposure;

	//--// Vertex Libraries

	#include "/lib/shared/celestialConstants.glsl"

	//--// Vertex Functions

	void CalculateExposure(out float exposure, out float previousExposure) {
		const float K = 14.0;
		const float calibration = exp2(CAMERA_EXPOSURE_BIAS) * K / 100.0;

		// 18% albedo is common as reference
		const float minExposure = calibration / (dot(lumacoeff_rec709, sunIlluminance ) * (0.18 / pi));
		const float maxExposure = calibration / (dot(lumacoeff_rec709, moonIlluminance) * (0.18 / pi));

		#ifdef CAMERA_AUTOEXPOSURE
			// Figure out the target exposure
			float averageLuminance = dot(ReadColorLod(vec2(0.5), 10.0), lumacoeff_rec709);
			float targetExposure   = clamp(calibration / averageLuminance, minExposure, maxExposure);

			// Get previous exposure
			previousExposure = texture(colortex3, vec2(0.5)).a;
			previousExposure = previousExposure > 0.0 ? previousExposure : targetExposure; // Set to target exposure if 0 since that only happens if it's a new frame
			previousExposure = clamp(previousExposure, minExposure, maxExposure);

			// Determine how quickly to adjust
			float exposureRate = targetExposure < previousExposure ? CAMERA_EXPOSURE_SPEED_BRIGHT : CAMERA_EXPOSURE_SPEED_DARK;

			// Calculate final exposure
			exposure = mix(targetExposure, previousExposure, exp(-exposureRate * frameTime));
		#else
			exposure = CAMERA_ISO / (78.0 * CAMERA_SHUTTER_SPEED * CAMERA_FSTOP * CAMERA_FSTOP);
			previousExposure = exposure;
		#endif
	}

	void main() {
		CalculateExposure(exposure, previousExposure);

		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;
	in float exposure, previousExposure;

	//--// Fragment Outputs

	/* DRAWBUFFERS:3 */

	layout (location = 0) out vec4 temporal;

	//--// Fragment Libraries

	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/math.glsl"
	#include "/lib/utility/spaceConversion.glsl"
	#include "/lib/utility/textRendering.fsh"

	//--// Fragment Functions

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

			return texture(colortex5, position.xy).rgb;
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
			vec3 current = ReadColor(screenCoord);
			vec3 history = SampleTextureCatmullRom(colortex3, reprojectedPosition.xy, viewResolution).rgb;
			     history = max(history / historyExposure, 0.0);

			#ifdef TAA_YCoCg
				// Convert current & history to YCoCg
				current = RgbToYcocg(current);
				history = RgbToYcocg(history);
			#endif

			// Don't blend if reprojecting an off-screen position
			float blendWeight = clamp(reprojectedPosition.xy, 0.0, 1.0) == reprojectedPosition.xy ? 0.97 : 0.0;

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
				#ifdef TAA_YCoCg
					tl = RgbToYcocg(tl);
					tc = RgbToYcocg(tc);
					tr = RgbToYcocg(tr);
					ml = RgbToYcocg(ml);
					mr = RgbToYcocg(mr);
					bl = RgbToYcocg(bl);
					bm = RgbToYcocg(bm);
					br = RgbToYcocg(br);
				#endif

				// Min/Avg/Max of nearest 5 + nearest 9
				vec3 min5  = min(min(min(min(tc, ml),  mc),  mr), bm);
				vec3 min9  = min(min(min(min(tl, tr), min5), bl), br);
				vec3 avg5  =  tc + ml +  mc  + mr + bm;
				vec3 avg9  = (tl + tr + avg5 + bl + br) / 9.0;
				     avg5 *= 0.2;
				vec3 max5  = max(max(max(max(tc, ml),  mc),  mr), bm);
				vec3 max9  = max(max(max(max(tl, tr), min5), bl), br);

				// "Rounded" min/avg/max (avg of values for nearest 5 + nearest 9)
				vec3 minRounded = (min5 + min9) * 0.5;
				vec3 avgRounded = (avg5 + avg9) * 0.5;
				vec3 maxRounded = (max5 + max9) * 0.5;

				// Clip history
				history = ClipAABB(history, minRounded, avgRounded, maxRounded);

				// Reduce blend weight when variance is low, helps reduce ghosting
				// This doesn't work well for lower-resolution effects
				if (closestFragment.z < 1.0) {
					vec3 variance = avgRounded.x == 0.0 ? vec3(0.0) : abs((maxRounded - minRounded) / avgRounded.x);
					blendWeight *= 1.0 - exp(-3.0 * variance.x - 0.5 * (variance.y + variance.z));
				}
			#endif

			// Blend with history
			vec3 blended = mix(current, history, blendWeight);

			#ifdef TAA_YCoCg
				// Convert blended result from YCoCg to RGB
				blended = YcocgToRgb(blended);
			#endif

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
	}
#endif
