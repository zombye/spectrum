//--// Settings

#include "/settings.glsl"

//--// Uniforms

uniform sampler2D DS_SAMPLER;

// Custom Uniforms
uniform vec2 viewPixelSize;

//--// Shared Libraries

//--// Shared Functions

#if defined STAGE_VERTEX
	//--// Vertex Inputs

	//--// Vertex Outputs

	out vec2 screenCoord;

	//--// Vertex Libraries

	//--// Vertex Functions

	void main() {
		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	//--// Fragment Outputs

	/* DRAWBUFFERS:5 */

	layout (location = 0) out vec3 downsample;

	//--// Fragment Libraries

	#include "/lib/utility.glsl"
	#include "/lib/shared/blurTileOffset.glsl"

	//--// Fragment Functions

	void main() {
		#if DS_PASS == 0
			vec2 tc = screenCoord * 2.0;
		#else
			const int id = DS_PASS;
			vec2 tc = (screenCoord - CalculateTileOffset(id)) * exp2(id + 1);
		#endif

		if (Clamp01(tc) != tc) {
			#if DS_PASS == 0
				downsample = vec3(0.0);
			#else
				downsample = texture(DS_SAMPLER, screenCoord).rgb;
			#endif

			return;
		}

		#if DS_PASS > 0
			tc = tc * exp2(-id) + CalculateTileOffset(id - 1);
		#endif

		vec2[13] fetchC = vec2[13](
			vec2(-2,-2), vec2( 0,-2), vec2( 2,-2),
			      vec2(-1,-1), vec2( 1,-1),
			vec2(-2, 0), vec2( 0, 0), vec2( 2, 0),
			      vec2(-1, 1), vec2( 1, 1),
			vec2(-2, 2), vec2( 0, 2), vec2( 2, 2)
		);
		float[13] fetchW = float[13](
			0.03125, 0.06250, 0.03125,
			    0.12500, 0.12500,
			0.06250, 0.12500, 0.06250,
			    0.12500, 0.12500,
			0.03125, 0.06250, 0.03125
		);

		downsample = vec3(0.0);
		for (int i = 0; i < 13; ++i) {
			downsample += textureLod(DS_SAMPLER, fetchC[i] * viewPixelSize + tc, 0.0).rgb * fetchW[i];
		}
	}
#endif
