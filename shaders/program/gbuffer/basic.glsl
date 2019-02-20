/*\
 * Program Description:
\*/

//--// Settings

#include "/settings.glsl"

//--// Uniforms

#ifdef TAA
	uniform vec3 cameraPosition;
	uniform vec3 previousCameraPosition;

	// Gbuffer uniforms
	uniform mat4 gbufferModelViewInverse;
	uniform mat4 gbufferPreviousModelView;

	uniform mat4 gbufferPreviousProjection;

	// Custom Uniforms
	uniform vec2 viewPixelSize;
	uniform vec2 taaOffset;
#endif

//--// Shared Libraries

//--// Shared Functions

#if defined STAGE_VERTEX
	//--// Vertex Inputs

	//--// Vertex Outputs

	// Interpolated
	#ifdef TAA
		out vec4 previousScreenPosition;
	#endif
	out vec2 lightmapCoordinates;

	// Flat
	flat out vec3 color; // Must be flat for correct results.

	//--// Vertex Functions

	void main() {
		color = gl_Color.rgb;
		lightmapCoordinates = gl_MultiTexCoord1.st / 240.0;

		gl_Position.xyz = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;

		#ifdef TAA // Previous frame position
			vec3 scenePosition = mat3(gbufferModelViewInverse) * gl_Position.xyz + gbufferModelViewInverse[3].xyz;

			vec3 previousScenePosition = scenePosition + cameraPosition - previousCameraPosition;
			vec3 previousViewPosition  = mat3(gbufferPreviousModelView) * previousScenePosition + gbufferPreviousModelView[3].xyz;
			previousScreenPosition     = vec4(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].zw) * previousViewPosition.xyzz + gbufferPreviousProjection[3];
			previousScreenPosition.xy += taaOffset * previousScreenPosition.w;
		#endif

		gl_Position = vec4(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y, gl_ProjectionMatrix[2].zw) * gl_Position.xyzz + gl_ProjectionMatrix[3];

		#ifdef TAA
			gl_Position.xy += taaOffset * gl_Position.w;
		#endif
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs

	// Interpolated
	#ifdef TAA
		in vec4 previousScreenPosition;
	#endif
	in vec2 lightmapCoordinates;

	// Flat
	flat in vec3 color; // Must be flat for correct results.

	//--// Fragment Outputs

	#ifdef TAA
		/* DRAWBUFFERS:015 */
	#else
		/* DRAWBUFFERS:01 */
	#endif

	layout (location = 0) out vec4 colortex0Write;
	layout (location = 1) out vec4 colortex1Write;
	#ifdef TAA
		layout (location = 2) out vec3 colortex5Write; // Velocity
	#endif

	//--// Fragment Libraries

	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/encoding.glsl"
	#include "/lib/utility/packing.glsl"

	//--// Fragment Functions

	void main() {
		float dither = Bayer4(gl_FragCoord.xy);

		colortex0Write = vec4(Pack2x8(color.rg), Pack2x8(color.b, 1.0 / 255.0), Pack2x8Dithered(lightmapCoordinates, dither), Pack2x8(1.0, 1.0));
		colortex1Write = vec4(Pack2x8(0.0, 0.0), Pack2x8(0.0, 1.0), Pack2x8(EncodeNormal(vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5), Pack2x8(EncodeNormal(vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5));
		#ifdef TAA
			colortex5Write = vec3(gl_FragCoord.xy * viewPixelSize, gl_FragCoord.z) - ((previousScreenPosition.xyz / previousScreenPosition.w) * 0.5 + 0.5);
		#endif
	}
#endif
