/*\
 * Program Description:
 * Performs Motion Blur
\*/

//--// Settings

#include "/settings.glsl"

//--// Uniforms

// Gbuffer Uniforms
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform sampler2D depthtex1;

// Misc Samplers
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

// Custom Uniforms
uniform vec2 viewResolution;

uniform vec2 taaOffset;

//--// Shared Libraries

//--// Shared Functions

#if STAGE == STAGE_VERTEX
	//--// Vertex Outputs

	out vec2 screenCoord;

	//--// Vertex Libraries

	//--// Vertex Functions

	void main() {
		screenCoord    = gl_Vertex.xy;
		gl_Position.xy = gl_Vertex.xy * 2.0 - 1.0;
		gl_Position.zw = vec2(1.0);
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	in vec2 screenCoord;

	//--// Fragment Outputs

	/* DRAWBUFFERS:3 */

	layout (location = 0) out vec4 color;

	//--// Fragment Libraries

	#include "/lib/utility/spaceConversion.glsl"

	//--// Fragment Functions

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

	void main() {
		color.rgb = texture(colortex6, screenCoord).rgb;
		color.a = texture(colortex3, screenCoord).a;

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
				color.rgb += texture(colortex6, c).rgb;
			}
			color.rgb /= MOTION_BLUR_SAMPLES;
		#endif
	}
#endif
