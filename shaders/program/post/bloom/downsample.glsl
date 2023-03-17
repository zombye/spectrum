//--// Settings //------------------------------------------------------------//

#if DOWNSAMPLE_LOD == 0
#define SOURCE_SAMPLER colortex5
#else
#define SOURCE_SAMPLER colortex6
#endif

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D SOURCE_SAMPLER;

//--// Custom uniforms

uniform vec2 viewPixelSize;

#if defined STAGE_VERTEX
	//--// Vertex Functions //------------------------------------------------//

	void main() {
		// based on downsample iteration, place quad in different locations
		#if DOWNSAMPLE_LOD == 0 || DOWNSAMPLE_LOD == 1
		// first 2 passes need to clear buffers
		vec2 vertPos = gl_Vertex.xy;
		#else
		vec2 vertPos = gl_Vertex.xy * exp2(-DOWNSAMPLE_LOD) / 2.0;
		     vertPos = vertPos + 1.0 - exp2(-DOWNSAMPLE_LOD);
		#endif
		gl_Position = vec4(vertPos * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:6 */

	out vec3 fragColor;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"

	//--// Fragment Functions //----------------------------------------------//

	void main() {
		vec2 uv = viewPixelSize * gl_FragCoord.xy;

		#if DOWNSAMPLE_LOD == 0
			vec2 srcUv = uv * 2.0;
			if (srcUv.x > 1.0 || srcUv.y > 1.0) {
				fragColor = vec3(0.0);
				return;
			}
		#else
			vec2 srcUv = uv * 2.0 - 1.0;
			#if DOWNSAMPLE_LOD == 1
			if (srcUv.x > 0.5 || srcUv.y > 0.5 || srcUv.x < 0.0 || srcUv.y < 0.0) {
				fragColor = vec3(0.0);
				return;
			}
			#endif
		#endif

		/* Basic 2x2 box filter, i.e. standard mipmapping
		// Results in pulsating artifacts. Not recommended.
		fragColor = texture(SOURCE_SAMPLER, srcUv).rgb;
		//*/

		/* Basic 4x4 box filter
		// Mitigates pulsating artifacts
		fragColor  = texture(SOURCE_SAMPLER, vec2(-1.0,-1.0) * viewPixelSize + srcUv).rgb;
		fragColor += texture(SOURCE_SAMPLER, vec2( 1.0,-1.0) * viewPixelSize + srcUv).rgb;
		fragColor += texture(SOURCE_SAMPLER, vec2(-1.0, 1.0) * viewPixelSize + srcUv).rgb;
		fragColor += texture(SOURCE_SAMPLER, vec2( 1.0, 1.0) * viewPixelSize + srcUv).rgb;
		fragColor *= 0.25;
		//*/

		/* 6x6 filter constructed with 4x4 box filters
		// Pretty much fixes the pulsating artifacts
		// As used by Sledgehammer Games in Call of Duty Advanced Warfare
		fragColor  = (0.5   * 0.25) * texture(SOURCE_SAMPLER, vec2(-1.0,-1.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.5   * 0.25) * texture(SOURCE_SAMPLER, vec2( 1.0,-1.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.5   * 0.25) * texture(SOURCE_SAMPLER, vec2(-1.0, 1.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.5   * 0.25) * texture(SOURCE_SAMPLER, vec2( 1.0, 1.0) * viewPixelSize + srcUv).rgb;

		fragColor += (0.125 * 0.25) * texture(SOURCE_SAMPLER, vec2(-2.0,-2.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.25  * 0.25) * texture(SOURCE_SAMPLER, vec2( 0.0,-2.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.125 * 0.25) * texture(SOURCE_SAMPLER, vec2( 2.0,-2.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.25  * 0.25) * texture(SOURCE_SAMPLER, vec2(-2.0, 0.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.5   * 0.25) * texture(SOURCE_SAMPLER, vec2( 0.0, 0.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.25  * 0.25) * texture(SOURCE_SAMPLER, vec2( 2.0, 0.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.125 * 0.25) * texture(SOURCE_SAMPLER, vec2(-2.0, 2.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.25  * 0.25) * texture(SOURCE_SAMPLER, vec2( 0.0, 2.0) * viewPixelSize + srcUv).rgb;
		fragColor += (0.125 * 0.25) * texture(SOURCE_SAMPLER, vec2( 2.0, 2.0) * viewPixelSize + srcUv).rgb;
		//*/

		//* 6x6 filter using 9 bilinear taps, with sampling locations shifted towards the center slightly.
		// 4 fewer texture samples compared with the above, but produces a *very* similar kernel.
		fragColor  =       textureLod(SOURCE_SAMPLER, vec2(-1.75,-1.75) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor += 2.0 * textureLod(SOURCE_SAMPLER, vec2( 0.00,-1.75) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor +=       textureLod(SOURCE_SAMPLER, vec2( 1.75,-1.75) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor += 2.0 * textureLod(SOURCE_SAMPLER, vec2(-1.75, 0.00) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor += 4.0 * textureLod(SOURCE_SAMPLER, vec2( 0.00, 0.00) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor += 2.0 * textureLod(SOURCE_SAMPLER, vec2( 1.75, 0.00) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor +=       textureLod(SOURCE_SAMPLER, vec2(-1.75, 1.75) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor += 2.0 * textureLod(SOURCE_SAMPLER, vec2( 0.00, 1.75) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor +=       textureLod(SOURCE_SAMPLER, vec2( 1.75, 1.75) * viewPixelSize + srcUv, 0.0).rgb;
		fragColor *= 1.0 / 16.0;
		//*/

		#if DOWNSAMPLE_LOD == 0
		fragColor -= fragColor * inversesqrt(1.0 + fragColor * fragColor);
		#endif
	}
#endif
