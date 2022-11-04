/*\
 * Program Description:
 * Used to render the shadow maps.
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//#define SHADOW_DISABLE_ALPHA_MIPMAP
#define SHADOW_BACKFACE_CULLING // This causes light to pass through terrain as side faces on chunks aren't rendered even if the neighboring chunk on that side isn't rendered either.
//#define BEACON_BEAM_SHADOWS

//--// Uniforms //------------------------------------------------------------//

#ifndef BEACON_BEAM_SHADOWS
	uniform int blockEntityId;
#endif

uniform sampler2D tex;

uniform sampler3D gaux4;

uniform sampler2D noisetex;

uniform sampler2D shadowtex1;

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
	#include "/include/utility/fastMath.glsl"
	#include "/include/utility/noise.glsl"

	#include "/include/fragment/waterNormal.fsh"

	//--// Fragment Functions //----------------------------------------------//

	#if defined PROCEDURAL_WATER && CAUSTICS != CAUSTICS_OFF
	float CalculateProjectedCaustics(vec3 position, vec3 normal) {
		float waterDepth  = texelFetch(shadowtex1, ivec2(gl_FragCoord.xy), 0).x - gl_FragCoord.z;
		      waterDepth *= 2.0 * SHADOW_DEPTH_RADIUS;

		// calculate (squared) original area
		mat2 jacobian = mat2(dFdx(position.xy), dFdy(position.xy));
		float oldArea = determinant(jacobian);

		// calculate (squared) new area
		vec3 rv  = refract(vec3(0,0,-1), mat3(shadowModelView) * normal, 0.75);
		     rv /= abs(rv.z);
		jacobian += waterDepth * mat2(dFdx(rv.xy), dFdy(rv.xy));

		float newArea = determinant(jacobian);

		// calculate relative density from old and new area
		return abs(oldArea / newArea);
	}
	vec2 CalculateProjectedCausticsCoeffs(vec3 position, vec3 normal) {
		/*
		determinant(m) = m[0].x * m[1].y - m[1].x * m[0].y
		determinant(jacobian) = determinant(mat2(dFdx(position.xy), dFdy(position.xy)) + waterDepth * mat2(dFdx(rv.xy), dFdy(rv.xy)))
		determinant(jacobian) = (dFdx(position.xy).x + waterDepth * dFdx(rv.xy).x) * (dFdy(position.xy).y + waterDepth * dFdy(rv.xy).y)
		                      - (dFdy(position.xy).x + waterDepth * dFdy(rv.xy).x) * (dFdx(position.xy).y + waterDepth * dFdx(rv.xy).y)
		determinant(jacobian) = (dFdx(position.xy).x * dFdy(position.xy).y + dFdx(position.xy).x * waterDepth * dFdy(rv.xy).y + waterDepth * dFdx(rv.xy).x * dFdy(position.xy).y + waterDepth * dFdx(rv.xy).x * waterDepth * dFdy(rv.xy).y)
		                      - (dFdy(position.xy).x * dFdx(position.xy).y + dFdy(position.xy).x * waterDepth * dFdx(rv.xy).y + waterDepth * dFdy(rv.xy).x * dFdx(position.xy).y + waterDepth * dFdy(rv.xy).x * waterDepth * dFdx(rv.xy).y)
		determinant(jacobian) = determinant(mat2(dFdx(position.xy), dFdy(position.xy)))
		                      + waterDepth * (dFdx(position.xy).x * dFdy(rv.xy).y - dFdy(position.xy).x * dFdx(rv.xy).y + dFdx(rv.xy).x * dFdy(position.xy).y - dFdy(rv.xy).x * dFdx(position.xy).y)
		                      + waterDepth * waterDepth * determinant(mat2(dFdx(rv.xy), dFdy(rv.xy)))
		//*/

		vec3 rv  = refract(vec3(0,0,-1), mat3(shadowModelView) * normal, 0.75);
		     rv /= abs(rv.z);

		float c0 = determinant(mat2(dFdx(position.xy), dFdy(position.xy)));
		float c1 = dFdx(position.xy).x * dFdy(rv.xy).y - dFdy(position.xy).x * dFdx(rv.xy).y + dFdx(rv.xy).x * dFdy(position.xy).y - dFdy(rv.xy).x * dFdx(position.xy).y;
		float c2 = determinant(mat2(dFdx(rv.xy), dFdy(rv.xy)));

		return vec2(c1, c2) / c0;
	}
	#endif

	void main() {
		#ifdef PROCEDURAL_WATER
		if (blockId == 8 || blockId == 9) {
			shadowcolor1Write.rgb = vec3(1.0);
			shadowcolor1Write.a   = 0.0;

			#if CAUSTICS != CAUSTICS_OFF
				vec3 waterNormal = CalculateWaterNormal(scenePosition);

				vec2 projectedCausticsCoeffs = CalculateProjectedCausticsCoeffs(mat3(shadowModelView) * scenePosition + shadowModelView[3].xyz, waterNormal);
				     projectedCausticsCoeffs = 1.0 / (1.0 + exp2(projectedCausticsCoeffs));
				shadowcolor0Write.zw = projectedCausticsCoeffs * (254.0 / 255.0) + (1.0 / 255.0);
			#else
				shadowcolor0Write.zw = vec2(0.0);
			#endif
			#if CAUSTICS == CAUSTICS_HIGH
				shadowcolor0Write.xy = EncodeNormal(waterNormal) * 0.5 + 0.5;
			#endif
		} else
		#endif
		{
			#ifdef SHADOW_DISABLE_ALPHA_MIPMAP
				shadowcolor1Write.a = textureLod(tex, textureCoordinates, 0).a;
				if (shadowcolor1Write.a < 0.102) { discard; }
				shadowcolor1Write.rgb = texture(tex, textureCoordinates).rgb;
			#else
				shadowcolor1Write = texture(tex, textureCoordinates);
				if (shadowcolor1Write.a < 0.102) { discard; }
			#endif
			shadowcolor1Write.rgb *= tint;

			shadowcolor0Write.zw = vec2(0.0);
			#if defined PROCEDURAL_WATER && CAUSTICS == CAUSTICS_HIGH
				shadowcolor0Write.xy = EncodeNormal(normal) * 0.5 + 0.5;
			#endif
		}

		#if defined PROCEDURAL_WATER && CAUSTICS != CAUSTICS_HIGH
			shadowcolor0Write.xy = EncodeNormal(normal) * 0.5 + 0.5;
		#endif
	}
#endif
