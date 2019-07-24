/*\
 * Program Description:
 * Used to render the shadow maps.
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

#define SHADOW_BACKFACE_CULLING // This causes light to pass through terrain as side faces on chunks aren't rendered even if the neighboring chunk on that side isn't rendered either.
//#define BEACON_BEAM_SHADOWS

//--// Uniforms //------------------------------------------------------------//

#ifndef BEACON_BEAM_SHADOWS
	uniform int blockEntityId;
#endif

uniform sampler2D tex;

uniform sampler2D noisetex;

//--// Time uniforms

uniform float frameTimeCounter;

//--// Camera uniforms

uniform vec3 cameraPosition;

//--// Shadow uniforms

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

//--// Custom uniforms

uniform vec3 shadowLightVector;

#if defined STAGE_VERTEX
	//--// Vertex Inputs //---------------------------------------------------//

	attribute vec2 mc_Entity;
	attribute vec2 mc_midTexCoord;

	//--// Vertex Outputs //--------------------------------------------------//

	// Interpolated
	out vec3 normal;
	#if CAUSTICS != CAUSTICS_OFF
		out vec3 scenePosition;
	#endif
	out vec2 textureCoordinates;
	out vec2 lightmapCoordinates;

	// Flat
	flat out vec3 tint;
	flat out int blockId;

	//--// Vertex Includes //-------------------------------------------------//

	#include "/include/utility.glsl"

	#include "/include/shared/shadowDistortion.glsl"

	#include "/include/vertex/animation.vsh"

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		#ifndef BEACON_BEAM_SHADOWS
			if (blockEntityId == 138) {
				gl_Position = vec4(-1.0);
				return;
			}
		#endif

		normal = gl_NormalMatrix * gl_Normal;
		#ifdef SHADOW_BACKFACE_CULLING
			if (normal.z < 0.0) {
				gl_Position = vec4(-1.0);
				return;
			}
		#endif

		tint                = gl_Color.rgb;
		textureCoordinates  = gl_MultiTexCoord0.st;
		lightmapCoordinates = gl_MultiTexCoord1.st / 240.0;
		blockId             = int(mc_Entity.x);

		gl_Position.xyz = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
		#if CAUSTICS != CAUSTICS_OFF
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
	//--// Fragment Inputs //-------------------------------------------------//

	// Interpolated
	in vec3 normal;
	#if CAUSTICS != CAUSTICS_OFF
		in vec3 scenePosition;
	#endif
	in vec2 textureCoordinates;
	in vec2 lightmapCoordinates;

	// Flat
	flat in vec3 tint;
	flat in int blockId;

	//--// Fragment Outputs //------------------------------------------------//

	layout (location = 0) out vec4 shadowcolor0Write;
	layout (location = 1) out vec4 shadowcolor1Write;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"
	#include "/include/utility/encoding.glsl"
	#include "/include/utility/math.glsl"

	#include "/include/fragment/waterNormal.fsh"

	//--// Fragment Functions //----------------------------------------------//

	#if CAUSTICS != CAUSTICS_OFF
	float CalculateProjectedCaustics(vec3 position, vec3 normal) {
		// calculate (squared) original area
		vec3 dpdx = dFdx(position), dpdy = dFdy(position);
		float oldAreaSquared = dot(dpdx, dpdx) * dot(dpdy, dpdy);

		// refract
		vec3 refractedLightVector = refract(-shadowLightVector, normal, 0.75);
		position += 2.0 * refractedLightVector;

		// calculate (squared) new area
		dpdx = dFdx(position), dpdy = dFdy(position);
		float newAreaSquared = dot(dpdx, dpdx) * dot(dpdy, dpdy);

		// calculate relative density from old and new area
		return sqrt(oldAreaSquared / newAreaSquared);
	}
	#endif

	void main() {
		if (blockId == 8 || blockId == 9) {
			shadowcolor1Write.rgb = vec3(1.0);
			shadowcolor1Write.a   = 0.0;

			#if CAUSTICS != CAUSTICS_OFF
				vec3 waterNormal = CalculateWaterNormal(scenePosition);
				float projectedCaustics = CalculateProjectedCaustics(scenePosition, waterNormal);
				shadowcolor0Write.w = sqrt(0.5 * projectedCaustics) * (254.0 / 255.0) + (1.0 / 255.0);
			#else
				shadowcolor0Write.w = 1.0;
			#endif
			#if CAUSTICS == CAUSTICS_HIGH
				shadowcolor0Write.xy = EncodeNormal(waterNormal) * 0.5 + 0.5;
			#endif
		} else {
			shadowcolor1Write = texture(tex, textureCoordinates);
			if (shadowcolor1Write.a < 0.102) { discard; }
			shadowcolor1Write.rgb *= tint;

			shadowcolor0Write.w = 0.0;
			#if CAUSTICS == CAUSTICS_HIGH
				shadowcolor0Write.xy = EncodeNormal(normal) * 0.5 + 0.5;
			#endif
		}

		#if CAUSTICS != CAUSTICS_HIGH
			shadowcolor0Write.xy = EncodeNormal(normal) * 0.5 + 0.5;
		#endif
		shadowcolor0Write.z = lightmapCoordinates.y;
	}
#endif
