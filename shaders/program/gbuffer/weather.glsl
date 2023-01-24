//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

#define EMISSIVE_TEMP_FIX

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D noisetex;

//--// Time uniforms

uniform float frameTime;
uniform float frameTimeCounter;

//--// Camera uniforms

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

//--// Custom uniforms

uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 shadowLightVector;

//--// Shared Includes //-----------------------------------------------------//

#include "/include/utility.glsl"

#if defined STAGE_VERTEX
	//--// Vertex Inputs //---------------------------------------------------//

	attribute vec4 at_tangent;
	attribute vec2 mc_Entity;
	attribute vec2 mc_midTexCoord;

	//--// Vertex Outputs //--------------------------------------------------//

	// Interpolated
	#if defined MOTION_BLUR || defined TAA
		out vec4 previousScreenPosition;
	#endif
	out vec3 viewPosition;
	out vec2 lightmapCoordinates;
	out vec2 textureCoordinates;
	out float vertexAo;

	// Flat
	flat out vec3 tint;

	//--// Vertex Functions //------------------------------------------------//

	vec2 GetLightmapCoordinates() {
		#ifdef EMISSIVE_TEMP_FIX
			bool emissive =
			   mc_Entity.x ==  10.0 // Lava (Flowing)
			|| mc_Entity.x ==  11.0 // Lava (Still)
			|| mc_Entity.x ==  51.0 // Fire
			|| mc_Entity.x ==  89.0 // Glowstone
			|| mc_Entity.x ==  91.0 // Jack o'Lantern
			|| mc_Entity.x == 119.0 // End Portal
			|| mc_Entity.x == 124.0 // Redstone Lamp (Lit)
			|| mc_Entity.x == 138.0 // Beacon
			|| mc_Entity.x == 169.0 // Sea Lantern
			|| mc_Entity.x == 209.0;// End gateway

			vec2 coordinates;
			if (emissive) {
				coordinates.x = 1.0;
				coordinates.y = gl_MultiTexCoord1.y / 240.0;
			} else {
				coordinates = gl_MultiTexCoord1.xy / 240.0;
			}

			return coordinates;
		#else
			return gl_MultiTexCoord1.xy / 240.0;
		#endif
	}

	void main() {
		tint = gl_Color.rgb;
		textureCoordinates = gl_MultiTexCoord0.xy;
		lightmapCoordinates = GetLightmapCoordinates();
		vertexAo = gl_Color.a;

		viewPosition = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;

		#if defined MOTION_BLUR || defined TAA || defined VERTEX_ANIMATION
			vec3 scenePosition = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;
		#endif

		#if defined MOTION_BLUR || defined TAA // Previous frame position
			vec3 previousScenePosition = scenePosition + cameraPosition - previousCameraPosition;

			vec3 previousViewPosition = mat3(gbufferPreviousModelView) * previousScenePosition + gbufferPreviousModelView[3].xyz;

			previousScreenPosition = vec4(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].zw) * previousViewPosition.xyzz + gbufferPreviousProjection[3];
		#endif

		gl_Position = vec4(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y, gl_ProjectionMatrix[2].zw) * viewPosition.xyzz + gl_ProjectionMatrix[3];

		#ifdef TAA
			gl_Position.xy += taaOffset * gl_Position.w;
		#endif
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

	// Interpolated
	#if defined MOTION_BLUR || defined TAA
		in vec4 previousScreenPosition;
	#endif
	in vec3 viewPosition;
	in vec2 lightmapCoordinates;
	in vec2 textureCoordinates;
	in float vertexAo;

	// Flat
	flat in vec3 tint; // Interestingly, the tint color seems to always be the same for the entire quad.

	//--// Fragment Outputs //------------------------------------------------//

	#if defined MOTION_BLUR || defined TAA
		/* DRAWBUFFERS:018 */
	#else
		/* DRAWBUFFERS:01 */
	#endif

	layout (location = 0) out vec4 colortex0Write;
	layout (location = 1) out vec4 colortex1Write;
	#if defined MOTION_BLUR || defined TAA
		layout (location = 2) out vec3 velocity; // Velocity
	#endif

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/dithering.glsl"
	#include "/include/utility/encoding.glsl"
	#include "/include/utility/fastMath.glsl"
	#include "/include/utility/packing.glsl"

	//--// Fragment Functions //----------------------------------------------//

	void main() {
		#define ReadTexture(sampler) texture(sampler, textureCoordinates)

		vec4 baseTex = ReadTexture(tex);
		if (baseTex.a < 0.102) { discard; }
		baseTex.rgb *= tint;

		// Not entirely sure if specualr should be here...
		// Don't _think_ it should be, though.
		//vec4 specTex = ReadTexture(specular);
		vec4 specTex = vec4(0.0);

		vec3 normal = mat3(gbufferModelViewInverse) * normalize(cross(dFdx(viewPosition), dFdy(viewPosition)));

		#define parallaxShadow 1.0
		#define blocklightShading 1.0

		float dither = Bayer4(gl_FragCoord.xy);

		colortex0Write = vec4(Pack2x8(baseTex.rg), Pack2x8(baseTex.b, Clamp01(78.0 / 255.0)), Pack2x8Dithered(lightmapCoordinates, dither), float(PackUnormArbitrary(vec4(vertexAo + dither / 255.0, parallaxShadow, blocklightShading + dither / 127.0, 0.0), uvec4(8, 1, 7, 0))) / 65535.0);
		colortex1Write = vec4(Pack2x8(specTex.rg), Pack2x8(specTex.ba), Pack2x8(EncodeNormal(normal) * 0.5 + 0.5), Pack2x8(EncodeNormal(normal) * 0.5 + 0.5));

		#if defined MOTION_BLUR || defined TAA
			velocity = vec3(gl_FragCoord.xy * viewPixelSize - 0.5 * taaOffset, gl_FragCoord.z) - ((previousScreenPosition.xyz / previousScreenPosition.w) * 0.5 + 0.5);
		#endif
	}
#endif
