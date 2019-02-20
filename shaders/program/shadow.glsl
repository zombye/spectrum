/*\
 * Program Description:
 * Used to render the shadow maps.
\*/

//--// Settings

#include "/settings.glsl"

#define SHADOW_BACKFACE_CULLING // This causes light to pass through terrain as side faces on chunks aren't rendered even if the neighboring chunk on that side isn't rendered either.
//#define BEACON_BEAM_SHADOWS

//--// Uniforms

#ifndef BEACON_BEAM_SHADOWS
	uniform int blockEntityId;
#endif

uniform vec3 cameraPosition;

// Time
uniform float frameTimeCounter;

// Shadow uniforms
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

// Misc samplers
uniform sampler2D tex;

uniform sampler2D noisetex;

// Custom uniforms
uniform vec3 shadowLightVector;

//--// Shared Libraries

//--// Shared Functions

#if defined STAGE_VERTEX
	//--// Vertex Inputs

	attribute vec2 mc_Entity;
	attribute vec2 mc_midTexCoord;

	//--// Vertex Outputs

	// Interpolated
	out vec3 normal;
	#ifdef CAUSTICS
		out vec3 scenePosition;
	#endif
	out vec2 textureCoordinates;
	out vec2 lightmapCoordinates;

	// Flat
	flat out vec3 tint;
	flat out int blockId;

	//--// Vertex Libraries

	#include "/lib/utility.glsl"

	#include "/lib/shared/shadowDistortion.glsl"

	#include "/lib/vertex/animation.vsh"

	//--// Vertex Functions

	void main() {
		normal = gl_NormalMatrix * gl_Normal;
		#ifdef SHADOW_BACKFACE_CULLING
			if (normal.z < 0.0) {
				gl_Position = vec4(-1.0);
				return;
			}
		#endif

		#ifndef BEACON_BEAM_SHADOWS
			if (blockEntityId == 138) {
				gl_Position = vec4(-1.0);
				return;
			}
		#endif

		tint                = gl_Color.rgb;
		textureCoordinates  = gl_MultiTexCoord0.st;
		lightmapCoordinates = gl_MultiTexCoord1.st / 240.0;
		blockId             = int(mc_Entity.x);

		gl_Position.xyz = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
		#ifdef CAUSTICS
			scenePosition = mat3(shadowModelViewInverse) * gl_Position.xyz + shadowModelViewInverse[3].xyz;
		#elif defined VERTEX_ANIMATION
			vec3 scenePosition = mat3(shadowModelViewInverse) * gl_Position.xyz + shadowModelViewInverse[3].xyz;
		#endif
		#if defined VERTEX_ANIMATION
			scenePosition += AnimateVertex(scenePosition, scenePosition + cameraPosition, int(mc_Entity.x), frameTimeCounter);
			gl_Position.xyz = mat3(shadowModelView) * scenePosition + shadowModelView[3].xyz;
		#endif
		gl_Position.xyz = vec3(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y, gl_ProjectionMatrix[2].z) * gl_Position.xyz + gl_ProjectionMatrix[3].xyz;
		gl_Position.xy  = DistortShadowSpace(gl_Position.xy);
		gl_Position.z  /= SHADOW_DEPTH_SCALE;
		gl_Position.w   = 1.0;
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs

	// Interpolated
	in vec3 normal;
	#ifdef CAUSTICS
		in vec3 scenePosition;
	#endif
	in vec2 textureCoordinates;
	in vec2 lightmapCoordinates;

	// Flat
	flat in vec3 tint;
	flat in int blockId;

	//--// Fragment Outputs

	layout (location = 0) out vec4 shadowcolor0Write;
	layout (location = 1) out vec4 shadowcolor1Write;

	//--// Fragment Libraries

	#include "/lib/utility.glsl"
	#include "/lib/utility/encoding.glsl"
	#include "/lib/utility/math.glsl"

	#include "/lib/fragment/waterNormal.fsh"

	//--// Fragment Functions

	void main() {
		#ifndef CAUSTICS
			shadowcolor0Write.xy = EncodeNormal(normal) * 0.5 + 0.5;
		#endif
		shadowcolor0Write.z = lightmapCoordinates.y;

		if (blockId == 8 || blockId == 9) {
			shadowcolor1Write.rgb = vec3(1.0);
			shadowcolor1Write.a   = 0.0;

			#ifdef CAUSTICS
				shadowcolor0Write.xy = EncodeNormal(CalculateWaterNormal(scenePosition)) * 0.5 + 0.5;
			#endif
			shadowcolor0Write.w = 1.0;
		} else {
			shadowcolor1Write = texture(tex, textureCoordinates);
			if (shadowcolor1Write.a < 0.102) { discard; }
			shadowcolor1Write.rgb *= tint;

			#ifdef CAUSTICS
				shadowcolor0Write.xy = EncodeNormal(normal) * 0.5 + 0.5;
			#endif
			shadowcolor0Write.w = 0.0;
		}
	}
#endif
