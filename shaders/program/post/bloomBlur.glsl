//--// Settings

#include "/settings.glsl"

//--// Uniforms

uniform sampler2D colortex6;

// Custom uniforms
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
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);

		screenCoord = gl_Vertex.xy;
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	//--// Fragment Outputs

	/* DRAWBUFFERS:5 */

	layout (location = 0) out vec3 blur;

	//--// Fragment Libraries

	#include "/lib/utility.glsl"

	//--// Fragment Functions

	//*
	float gaussian(float x, float sigma) {
		return exp(-(x * x) / (2.0 * sigma * sigma)) * inversesqrt(tau * sigma * sigma);
	}

	float calcFastBlurOffset(float o1, float o2, float w1, float w2) {
		return (o1 * w1 + o2 * w2) / (w1 + w2);
	}
	float calcFastBlurWeight(float w1, float w2) {
		return w1 + w2;
	}
	//*/

	void main() {
		//* sigma = 2
		const float[5] weights = float[5](0.199471140, 0.297018026, 0.091754281, 0.010980074, 0.000503256);
		const float[5] offsets = float[5](0.000000000, 1.407333400, 3.294214972, 5.201813222, 7.132964240);
		//*/
		/* sigma = 2.5
		const float[5] weights = float[5](0.159576912, 0.263184677, 0.122042756, 0.030554199, 0.004119816);
		const float[5] offsets = float[5](0.000000000, 1.440286351, 3.363547460, 5.293177779, 7.231475216);
		//*/
		/*
		#define SIGMA 2.0
		float[5] weights = float[5](
			gaussian(0, SIGMA),
			calcFastBlurWeight(gaussian(1, SIGMA), gaussian(2, SIGMA)),
			calcFastBlurWeight(gaussian(3, SIGMA), gaussian(4, SIGMA)),
			calcFastBlurWeight(gaussian(5, SIGMA), gaussian(6, SIGMA)),
			calcFastBlurWeight(gaussian(7, SIGMA), gaussian(8, SIGMA))
		);
		float[5] offsets = float[5](
			0.0,
			calcFastBlurOffset(1, 2, gaussian(1, SIGMA), gaussian(2, SIGMA)),
			calcFastBlurOffset(3, 4, gaussian(3, SIGMA), gaussian(4, SIGMA)),
			calcFastBlurOffset(5, 6, gaussian(5, SIGMA), gaussian(6, SIGMA)),
			calcFastBlurOffset(7, 8, gaussian(7, SIGMA), gaussian(8, SIGMA))
		);
		//*/

		blur = texture(colortex6, screenCoord).rgb * weights[0];
		for (int i = 1; i < 5; i++) {
			#if defined VERTICAL
				vec2 offset = vec2(0.0, offsets[i] * viewPixelSize.y);
			#else
				vec2 offset = vec2(offsets[i] * viewPixelSize.x, 0.0);
			#endif
			blur += texture(colortex6, screenCoord + offset).rgb * weights[i];
			blur += texture(colortex6, screenCoord - offset).rgb * weights[i];
		}
	}
#endif
