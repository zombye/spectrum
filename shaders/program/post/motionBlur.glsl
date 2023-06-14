/*\
 * Program Description:
 * Performs Motion Blur
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D depthtex1;

uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex8;

#ifdef DOF
#define colorSampler colortex5
#else
#define colorSampler colortex3
#endif

//--// Camera uniforms

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

//--// Custom uniforms

uniform vec2 viewResolution;

uniform vec2 taaOffset;

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

	out vec2 screenCoord;

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

	in vec2 screenCoord;

	//--// Fragment Outputs //------------------------------------------------//

	/* RENDERTARGETS: 5 */

	layout (location = 0) out vec3 color;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/spaceConversion.glsl"

	//--// Fragment Functions //----------------------------------------------//

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

	void main() {
		color = texture(colorSampler, screenCoord).rgb;

		#ifdef MOTION_BLUR
			vec2 velocity = GetVelocity(vec3(screenCoord, texture(depthtex1, screenCoord).r)).xy * MOTION_BLUR_INTENSITY;
			vec2 increment = velocity / MOTION_BLUR_SAMPLES;

			for (int i = 1; i < MOTION_BLUR_SAMPLES; ++i) {
				vec2 c = i * increment + screenCoord;
				/*
				if (clamp(c, 0.0, 1.0) != c) {
					// read previous frame instead
					c -= velocity;
					color.rgb += texelFetch(colortex3, ivec2(clamp(c, 0.0, 1.0) * viewResolution - 0.5), 0).rgb;
				} else
				//*/
				color += texture(colorSampler, c).rgb;
			}
			color /= MOTION_BLUR_SAMPLES;
		#endif
	}
#endif
