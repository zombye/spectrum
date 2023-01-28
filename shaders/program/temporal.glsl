//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

#define FILTER_NEAREST 0
#define FILTER_BILINEAR 1
#define FILTER_BICUBIC 2
#define TAA_FILTER_CURRENT FILTER_BICUBIC // [FILTER_NEAREST FILTER_BILINEAR FILTER_BICUBIC]
#define TAA_FILTER_HISTORY FILTER_BICUBIC // [FILTER_BILINEAR FILTER_BICUBIC]

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D depthtex0;

uniform usampler2D colortex2;

uniform sampler2D colortex3;
uniform sampler2D colortex8;
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

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

	out vec2 screenCoord;
	out float exposure, previousExposure;

	//--// Vertex Includes //-------------------------------------------------//

	#include "/include/shared/celestialConstants.glsl"

	//--// Vertex Functions //------------------------------------------------//

	const float K = 14.0;
	const float calibration = exp2(CAMERA_AUTOEXPOSURE_BIAS) * K / 100.0;

	const float minExposure = exp2(CAMERA_AUTOEXPOSURE_BIAS) * pi /  dot(sunIlluminance, RgbToXyz[1]);
	const float maxExposure = 0.03 * exp2(CAMERA_AUTOEXPOSURE_BIAS) * pi / (dot(moonIlluminance, RgbToXyz[1]) * NIGHT_SKY_BRIGHTNESS);

	void CalculateExposure(out float exposure, out float previousExposure) {
		#if CAMERA_AUTOEXPOSURE != CAMERA_AUTOEXPOSURE_OFF
			float targetExposure = uintBitsToFloat(texelFetch(colortex2, ivec2(HISTOGRAM_BIN_COUNT, 0), 0).x);

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

	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:3 */

	layout (location = 0) out vec4 temporal;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/dithering.glsl"
	#include "/include/utility/fastMath.glsl"
	#include "/include/utility/spaceConversion.glsl"
	#include "/include/utility/textRendering.fsh"

	//--// Fragment Functions //----------------------------------------------//


	#ifdef TAA
		// Bicubic Catmull-Rom texture filter
		// Implementation directly based on Vulkan spec, albeit optimized
		vec4 CatRom(float x) {
			vec4 vec = vec4(1.0, x, x * x, x * x * x);
			const mat4 matrix = mat4(
				 0, 2, 0, 0,
				-1, 0, 1, 0,
				 2,-5, 4,-1,
				-1, 3,-3, 1
			);
			return (1.0/2.0) * matrix * vec;
		}
		vec4 TextureCubicCatRom(sampler2D sampler, vec2 uv) {
			uv = viewResolution * uv - 0.5;
			/*
			vec2 i = floor(uv);
			vec2 f = fract(uv);
			//*/ vec2 i, f = modf(uv, i);

			uv = viewPixelSize * i;

			vec4 weightsX = CatRom(f.x);
			vec4 weightsY = CatRom(f.y);
			vec2 w12 = vec2(weightsX[1] + weightsX[2], weightsY[1] + weightsY[2]);

			float cx = weightsX[2] / w12.x;
			float cy = weightsY[2] / w12.y;
			vec2 uv12 = uv + viewPixelSize * (0.5 + vec2(cx, cy));

			vec2 uv0 = uv - 0.5 * viewPixelSize;
			vec2 uv3 = uv + 2.5 * viewPixelSize;

			vec4
			result  = (weightsX[0] * weightsY[0]) * texture(sampler, uv0);
			result += (w12.x       * weightsY[0]) * texture(sampler, vec2(uv12.x, uv0.y));
			result += (weightsX[3] * weightsY[0]) * texture(sampler, vec2(uv3.x,  uv0.y));

			result += (weightsX[0] * w12.y      ) * texture(sampler, vec2(uv0.x,  uv12.y));
			result += (w12.x       * w12.y      ) * texture(sampler, uv12);
			result += (weightsX[3] * w12.y      ) * texture(sampler, vec2(uv3.x,  uv12.y));

			result += (weightsX[0] * weightsY[3]) * texture(sampler, vec2(uv0.x,  uv3.y));
			result += (w12.x       * weightsY[3]) * texture(sampler, vec2(uv12.x, uv3.y));
			result += (weightsX[3] * weightsY[3]) * texture(sampler, uv3);

			return result;
		}

		vec3 GetClosestFragment(vec3 position, vec2 pixelSize) {
			vec3 closestFragment = position;

			vec3 currentFragment;
			currentFragment.xy = vec2(-1,-1) * pixelSize + position.xy;
			currentFragment.z  = texelFetch(depthtex0, ivec2(gl_FragCoord.xy) + ivec2(-1,-1), 0).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2(-1, 0) * pixelSize + position.xy;
			currentFragment.z  = texelFetch(depthtex0, ivec2(gl_FragCoord.xy) + ivec2(-1, 0), 0).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2(-1, 1) * pixelSize + position.xy;
			currentFragment.z  = texelFetch(depthtex0, ivec2(gl_FragCoord.xy) + ivec2(-1, 1), 0).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 0,-1) * pixelSize + position.xy;
			currentFragment.z  = texelFetch(depthtex0, ivec2(gl_FragCoord.xy) + ivec2( 0,-1), 0).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 0, 1) * pixelSize + position.xy;
			currentFragment.z  = texelFetch(depthtex0, ivec2(gl_FragCoord.xy) + ivec2( 0, 1), 0).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 1,-1) * pixelSize + position.xy;
			currentFragment.z  = texelFetch(depthtex0, ivec2(gl_FragCoord.xy) + ivec2( 1,-1), 0).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 1, 0) * pixelSize + position.xy;
			currentFragment.z  = texelFetch(depthtex0, ivec2(gl_FragCoord.xy) + ivec2( 1, 0), 0).r;
			closestFragment = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;

			currentFragment.xy = vec2( 1, 1) * pixelSize + position.xy;
			currentFragment.z  = texelFetch(depthtex0, ivec2(gl_FragCoord.xy) + ivec2( 1, 1), 0).r;
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

			return texture(colortex8, position.xy).rgb;
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
			vec2 currentUv = viewPixelSize * gl_FragCoord.xy;
			vec3 position = vec3(currentUv + 0.5 * taaOffset, texture(depthtex0, currentUv).r);

			// Get velocity of closest fragment and set reprojected position based on that
			vec3 currentFragment = vec3(currentUv, position.z);
			vec3 closestFragment = GetClosestFragment(currentFragment, viewPixelSize);
			vec3 velocity = GetVelocity(closestFragment);
			vec3 reprojectedPosition = currentFragment - velocity;

			// Read needed current and previous frame color values
			#if TAA_FILTER_CURRENT == FILTER_BICUBIC
			vec3 current = TextureCubicCatRom(colortex6, position.xy).rgb;
			#elif TAA_FILTER_CURRENT == FILTER_BILINEAR
			vec3 current = texture(colortex6, position.xy).rgb;
			#else //TAA_FILTER_CURRENT == FILTER_NEAREST
			vec3 current = texelFetch(colortex6, ivec2(viewResolution * position.xy), 0).rgb;
			#endif

			#if TAA_FILTER_HISTORY == FILTER_BICUBIC
			vec3 history = TextureCubicCatRom(colortex3, reprojectedPosition.xy).rgb;
			#elif TAA_FILTER_HISTORY == FILTER_BILINEAR
			vec3 history = texture(colortex3, reprojectedPosition.xy).rgb;
			#endif
			     history = max(history / historyExposure, 0.0);

			// Don't blend if reprojecting an off-screen position
			vec3 blendWeight = vec3(clamp(reprojectedPosition.xy, 0.0, 1.0) == reprojectedPosition.xy ? 0.97 : 0.0);

			// Reduce blend weight when not in the pixel center to reduce blurring
			vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(reprojectedPosition.xy * viewResolution) - 1.0);
			blendWeight *= sqrt(pixelCenterDist.x * pixelCenterDist.y) * TAA_OFFCENTER_REJECTION + (1.0 - TAA_OFFCENTER_REJECTION);

			#ifdef TAA_CLIP
				// Gather nearby samples
				vec3 mc = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2( 0, 0), 0).rgb;
				vec3 tl = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2(-1,-1), 0).rgb;
				vec3 tc = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2( 0,-1), 0).rgb;
				vec3 tr = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2( 1,-1), 0).rgb;
				vec3 ml = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2(-1, 0), 0).rgb;
				vec3 mr = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2( 1, 0), 0).rgb;
				vec3 bl = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2(-1, 1), 0).rgb;
				vec3 bm = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2( 0, 1), 0).rgb;
				vec3 br = texelFetch(colortex6, ivec2(gl_FragCoord.xy) + ivec2( 1, 1), 0).rgb;

				// Min/Avg/Max of nearest 5 + nearest 9
				vec3 min5  = min(min(min(min(tc, ml),  mc),  mr), bm);
				vec3 min9  = min(min(min(min(tl, tr), min5), bl), br);
				vec3 avg5  =  2 * tc      + 2 * ml      + 2 * mc      + 2 * mr      + 2 * bm;
				vec3 asq5  =  4 * tc * tc + 4 * ml * ml + 4 * mc * mc + 4 * mr * mr + 4 * bm * bm;
				vec3 avg9  = (tl      + tr      + avg5 + bl      + br     ) / 14.0;
				vec3 asq9  = (tl * tl + tr * tr + asq5 + bl * bl + br * br) / 14.0;
				vec3 max5  = max(max(max(max(tc, ml),  mc),  mr), bm);
				vec3 max9  = max(max(max(max(tl, tr), max5), bl), br);

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
					//blendWeight *= 1.0 - Clamp01(exp(-2.0 * variance / (avgRounded * avgRounded)));
				}

				// Increase blend weight if current is very different from history
				// Reduces flickering
				//blendWeight  = 1.0 - blendWeight;
				//blendWeight *= Clamp01(exp(-Pow2(current - history) * variance));
				//blendWeight  = 1.0 - blendWeight;
			#endif

			// Blend with history
			vec3 blended = Max0(mix(current, history, blendWeight));

			// Return final anti-aliased fragment
			return blended;
		}
	#endif

	void main() {
		#ifdef TAA
			vec3 color = CalculateTaa(previousExposure);
		#else
			vec3 color = texture(colortex6, screenCoord).rgb;
		#endif

		temporal = vec4(color * exposure, exposure);
	}
#endif
