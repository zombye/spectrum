/*\
 * Program Description:
\*/

//--// Settings

#include "/settings.glsl"

#define EMISSIVE_TEMP_FIX

//--// Uniforms

#if PROGRAM == PROGRAM_HAND || PROGRAM == PROGRAM_HAND_WATER
	uniform int heldItemId;
	uniform int heldItemId2;
#endif

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

// Time
uniform float frameTime;
uniform float frameTimeCounter;

// Gbuffer uniforms
#if PROGRAM == PROGRAM_ENTITIES
	uniform vec4 entityColor;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

// Misc samplers
uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D noisetex;

// Custom Uniforms
uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 shadowLightVector;

//--// Shared Libraries

#include "/lib/utility.glsl"

//--// Shared Functions

#if STAGE == STAGE_VERTEX
	//--// Vertex Inputs

	attribute vec4 at_tangent;
	attribute vec2 mc_Entity;
	attribute vec2 mc_midTexCoord;

	//--// Vertex Outputs

	// Interpolated
	out mat3 tbn;
	#if defined MOTION_BLUR || defined TAA
		out vec4 previousScreenPosition;
	#endif
	#if defined PARALLAX || defined SMOOTH_ALBEDO || defined SMOOTH_NORMALS || defined SMOOTH_SPECULAR
		out vec3 tangentViewVector;
	#endif
	out vec3 viewPosition;
	out vec2 lightmapCoordinates;
	out vec2 textureCoordinates;
	out float vertexAo;

	// Flat
	#if defined PARALLAX || defined SMOOTH_ALBEDO || defined SMOOTH_NORMALS || defined SMOOTH_SPECULAR
		flat out mat3x2 atlasTileInfo;
		#define atlasTileOffset     atlasTileInfo[0]
		#define atlasTileSize       atlasTileInfo[1]
		#define atlasTileResolution atlasTileInfo[2]
	#endif
	flat out vec3 tint;
	flat out int blockId;

	//--// Vertex Libraries

	#include "/lib/vertex/animation.vsh"

	//--// Vertex Functions

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

	mat3 CalculateTBNMatrix() {
		mat3 tbn;
		tbn[0] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * at_tangent.xyz);
		tbn[2] = mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal);
		tbn[1] = cross(tbn[0], tbn[2]) * (at_tangent.w < 0.0 ? -1.0 : 1.0);
		return tbn;
	}

	void main() {
		tint = gl_Color.rgb;
		textureCoordinates = gl_MultiTexCoord0.xy;
		lightmapCoordinates = GetLightmapCoordinates();
		blockId = max(int(mc_Entity.x), 1);
		vertexAo = gl_Color.a;

		tbn = CalculateTBNMatrix();

		#if defined PARALLAX || defined SMOOTH_ALBEDO || defined SMOOTH_NORMALS || defined SMOOTH_SPECULAR
			ivec2 atlasResolution = textureSize(tex, 0); // TODO: See if replacing this with atlasSize whenever it's set is faster
			atlasTileSize       = abs(textureCoordinates - mc_midTexCoord);
			atlasTileOffset     = round((mc_midTexCoord - atlasTileSize) * atlasResolution) / atlasResolution;
			atlasTileResolution = round(2.0 * atlasTileSize * atlasResolution);
			atlasTileSize       = atlasTileResolution / atlasResolution;
		#endif

		viewPosition = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;

		#if defined MOTION_BLUR || defined TAA || defined VERTEX_ANIMATION
			vec3 scenePosition = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;
		#endif

		#if defined MOTION_BLUR || defined TAA // Previous frame position
			#if PROGRAM == PROGRAM_HAND || PROGRAM == PROGRAM_HAND_WATER
				vec3 previousScenePosition = scenePosition;
			#else
				vec3 previousScenePosition = scenePosition + cameraPosition - previousCameraPosition;
			#endif

			#if defined VERTEX_ANIMATION
				previousScenePosition += AnimateVertex(previousScenePosition, previousScenePosition + previousCameraPosition, blockId, frameTimeCounter - frameTime);
			#endif

			#if PROGRAM == PROGRAM_HAND || PROGRAM == PROGRAM_HAND_WATER
				// No correct previous matrix for hand rotation, but the current frame rotation + previous frame motion is close.
				vec3 previousViewPosition = mat3(gbufferModelView) * previousScenePosition + gbufferPreviousModelView[3].xyz;
			#else
				vec3 previousViewPosition = mat3(gbufferPreviousModelView) * previousScenePosition + gbufferPreviousModelView[3].xyz;
			#endif

			#if PROGRAM == PROGRAM_HAND || PROGRAM == PROGRAM_HAND_WATER
				//float projectionScalePrevious = (gbufferPreviousProjection[1].y / gl_ProjectionMatrix[1].y) * tan((HAND_FOV / 70.0) * atan(gl_ProjectionMatrixInverse[1].y / gbufferPreviousProjection[1].y));
				//previousScreenPosition = vec4(vec2(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y) / projectionScalePrevious, gbufferPreviousProjection[2].zw) * previousViewPosition.xyzz + gbufferPreviousProjection[3];
				float projectionScalePrevious = gl_ProjectionMatrix[1].y * tan((HAND_FOV / 70.0) * atan(gl_ProjectionMatrixInverse[1].y));
				previousScreenPosition = vec4(vec2(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y) / projectionScalePrevious, gl_ProjectionMatrix[2].zw) * previousViewPosition.xyzz + gl_ProjectionMatrix[3];
			#else
				previousScreenPosition = vec4(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].zw) * previousViewPosition.xyzz + gbufferPreviousProjection[3];
			#endif
			previousScreenPosition.xy += taaOffset * previousScreenPosition.w;
		#endif

		#if defined VERTEX_ANIMATION
			scenePosition += AnimateVertex(scenePosition, scenePosition + cameraPosition, blockId, frameTimeCounter);
			viewPosition = mat3(gbufferModelView) * scenePosition + gbufferModelView[3].xyz;
		#endif

		#if PROGRAM == PROGRAM_HAND || PROGRAM == PROGRAM_HAND_WATER
			float projectionScale = gl_ProjectionMatrix[1].y * tan((HAND_FOV / 70.0) * atan(gl_ProjectionMatrixInverse[1].y));
			gl_Position = vec4(vec2(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y) / projectionScale, gl_ProjectionMatrix[2].zw) * viewPosition.xyzz + gl_ProjectionMatrix[3];
		#else
			gl_Position = vec4(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y, gl_ProjectionMatrix[2].zw) * viewPosition.xyzz + gl_ProjectionMatrix[3];
		#endif

		#ifdef TAA
			gl_Position.xy += taaOffset * gl_Position.w;
		#endif

		#ifdef PARALLAX
			tangentViewVector = (mat3(gbufferModelViewInverse) * viewPosition) * tbn;
		#endif
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	// Interpolated
	in mat3 tbn;
	#if defined MOTION_BLUR || defined TAA
		in vec4 previousScreenPosition;
	#endif
	#if defined PARALLAX || defined SMOOTH_ALBEDO || defined SMOOTH_NORMALS || defined SMOOTH_SPECULAR
		in vec3 tangentViewVector;
	#endif
	in vec3 viewPosition;
	in vec2 lightmapCoordinates;
	in vec2 textureCoordinates;
	in float vertexAo;

	// Flat
	#if defined PARALLAX || defined SMOOTH_ALBEDO || defined SMOOTH_NORMALS || defined SMOOTH_SPECULAR
		flat in mat3x2 atlasTileInfo;
		#define atlasTileOffset     atlasTileInfo[0]
		#define atlasTileSize       atlasTileInfo[1]
		#define atlasTileResolution atlasTileInfo[2]
	#endif
	flat in vec3 tint; // Interestingly, the tint color seems to always be the same for the entire quad.
	flat in int blockId;

	//--// Fragment Outputs

	#if defined MOTION_BLUR || defined TAA
		/* DRAWBUFFERS:015 */
	#else
		/* DRAWBUFFERS:01 */
	#endif

	layout (location = 0) out vec4 colortex0Write;
	layout (location = 1) out vec4 colortex1Write;
	#if defined MOTION_BLUR || defined TAA
		layout (location = 2) out vec3 velocity; // Velocity
	#endif

	//--// Fragment Libraries

	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/encoding.glsl"
	#include "/lib/utility/math.glsl"
	#include "/lib/utility/packing.glsl"

	#ifdef PARALLAX
		#include "/lib/fragment/parallax.fsh"
	#endif

	//--// Fragment Functions

	#if defined SMOOTH_ALBEDO || defined SMOOTH_NORMALS || defined SMOOTH_SPECULAR
		#extension GL_ARB_texture_query_levels : require

		vec4 ReadTextureSmoothLod(sampler2D sampler, vec2 coordinates, int lod) {
			ivec2 textureResolution = textureSize(sampler, lod);

			ivec2 tileResolution = ivec2(round(atlasTileResolution) / exp2(lod));
			ivec2 tileOffset     = ivec2(atlasTileOffset * textureResolution);

			coordinates = coordinates * textureResolution - 0.5;
			ivec2 i = ivec2(floor(coordinates));
			vec2  f = coordinates - i;

			vec4 s0 = texelFetch(sampler, ((i + ivec2(0, 1)) % tileResolution) + tileOffset, lod);
			vec4 s1 = texelFetch(sampler, ((i + ivec2(1, 1)) % tileResolution) + tileOffset, lod);
			vec4 s2 = texelFetch(sampler, ((i + ivec2(1, 0)) % tileResolution) + tileOffset, lod);
			vec4 s3 = texelFetch(sampler, ((i + ivec2(0, 0)) % tileResolution) + tileOffset, lod);

			return mix(mix(s3, s2, f.x), mix(s0, s1, f.x), f.y);
		}
		vec4 ReadTextureSmoothLod(sampler2D sampler, vec2 coordinates, float lod) {
			int iLod = int(floor(lod));
			return mix(
				ReadTextureSmoothLod(sampler, coordinates, iLod),
				ReadTextureSmoothLod(sampler, coordinates, iLod + 1),
				lod - iLod
			);
		}
		vec4 ReadTextureSmoothGrad(sampler2D sampler, vec2 coordinates, vec2 dx, vec2 dy) {
			ivec2 textureResolution = textureSize(sampler, 0);
			dx *= textureResolution;
			dy *= textureResolution;

			float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1.0));

			lod = min(lod, textureQueryLevels(sampler) - 1);

			return ReadTextureSmoothLod(sampler, coordinates, lod);
		}
		vec4 ReadTextureSmooth(sampler2D sampler, vec2 coordinates) {
			return ReadTextureSmoothGrad(sampler, coordinates, dFdx(coordinates), dFdy(coordinates));
		}
	#endif

	#ifdef ARTIFICIAL_LIGHT_DIRECTIONAL
		vec3 CalculateBlocklightVector(vec3 flatNormal) {
			#define blocklight lightmapCoordinates.x

			vec2   lightmapDerivatives = vec2(dFdx(lightmapCoordinates.x), dFdy(lightmapCoordinates.x));
			mat2x3 positionDerivatives = mat2x3(mat3(gbufferModelViewInverse) * dFdx(viewPosition), mat3(gbufferModelViewInverse) * dFdy(viewPosition));

			// cross() to rotate 90 degrees
			vec3 lightmapVector  = positionDerivatives * vec2(-lightmapDerivatives.y, lightmapDerivatives.x);
			     lightmapVector  = cross(lightmapVector, flatNormal);
			     lightmapVector += flatNormal * dot(positionDerivatives[0] + positionDerivatives[1], positionDerivatives[0] + positionDerivatives[1]) * 0.5 / 16.0;

			float len = length(lightmapVector);
			return len > 0.0 ? normalize(mix(lightmapVector, flatNormal * len, Pow8(blocklight))) : flatNormal;
		}
		float CalculateBlocklightShading(vec3 normal, vec3 lv) {
			float NoL = dot(lv, normal);
			return Clamp01(Clamp01(NoL * 0.7) + 0.2);
		}
	#endif

	void main() {
		#ifdef PARALLAX
			mat2 textureCoordinateDerivatives = mat2(dFdx(textureCoordinates), dFdy(textureCoordinates));
			vec3 parallaxEndPosition;
			vec2 parallaxedCoordinates = CalculateParallaxedCoordinate(textureCoordinates, textureCoordinateDerivatives, tangentViewVector, parallaxEndPosition);

			#define ReadTexture(sampler) textureGrad(sampler, parallaxedCoordinates, textureCoordinateDerivatives[0], textureCoordinateDerivatives[1])
			#if defined SMOOTH_ALBEDO || defined SMOOTH_NORMALS || defined SMOOTH_SPECULAR
				#define ReadTextureSmooth(sampler) ReadTextureSmoothGrad(sampler, parallaxedCoordinates, textureCoordinateDerivatives[0], textureCoordinateDerivatives[1])
			#endif
		#else
			#define ReadTexture(sampler) texture(sampler, textureCoordinates)
			#if defined SMOOTH_ALBEDO || defined SMOOTH_NORMALS || defined SMOOTH_SPECULAR
				#define ReadTextureSmooth(sampler) ReadTextureSmooth(sampler, textureCoordinates)
			#endif
		#endif

		#ifdef SMOOTH_ALBEDO
			vec4 baseTex = ReadTextureSmooth(tex);
		#else
			vec4 baseTex = ReadTexture(tex);
		#endif
		if (baseTex.a < 0.102) { discard; }
		baseTex.rgb *= tint;
		#if PROGRAM == PROGRAM_ENTITIES
			baseTex.rgb = mix(baseTex.rgb, entityColor.rgb, entityColor.a);
		#endif

		#if PROGRAM != PROGRAM_TEXTURED
			#ifdef SMOOTH_SPECULAR
				vec4 specTex = ReadTextureSmooth(specular);
			#else
				vec4 specTex = ReadTexture(specular);
			#endif
		#else
			vec4 specTex = vec4(0.0);
		#endif

		#if PROGRAM != PROGRAM_BLOCK && PROGRAM != PROGRAM_ENTITIES
			#ifdef SMOOTH_NORMALS
				vec3 normal = ReadTextureSmooth(normals).rgb;
			#else
				vec3 normal = ReadTexture(normals).rgb;
			#endif
			normal = normal * 2.0 - (254.0 / 255.0);
		#else
			vec3 normal = vec3(0,0,1);
		#endif
		normal = normalize(tbn * normal);

		#if defined PARALLAX && defined PARALLAX_SHADOWS
			float parallaxShadow = CalculateParallaxSelfShadow(parallaxedCoordinates, parallaxEndPosition, textureCoordinateDerivatives, shadowLightVector * tbn);
		#else
			#define parallaxShadow 1.0
		#endif

		#if PROGRAM == PROGRAM_TERRAIN && defined ARTIFICIAL_LIGHT_DIRECTIONAL
			vec3 blocklightVector = CalculateBlocklightVector(tbn[2]);
			float blocklightShading = CalculateBlocklightShading(normal, blocklightVector);
		#else
			#define blocklightShading 1.0
		#endif

		float dither = Bayer4(gl_FragCoord.xy);

		colortex0Write = vec4(Pack2x8(baseTex.rg), Pack2x8(baseTex.b, Clamp01(blockId / 255.0)), Pack2x8Dithered(lightmapCoordinates, dither), float(PackUnormArbitrary(vec4(vertexAo + dither / 255.0, parallaxShadow, blocklightShading + dither / 127.0, 0.0), uvec4(8, 1, 7, 0))) / 65535.0);
		colortex1Write = vec4(Pack2x8(specTex.rg), Pack2x8(specTex.ba), Pack2x8(EncodeNormal(normal) * 0.5 + 0.5), Pack2x8(EncodeNormal(tbn[2]) * 0.5 + 0.5));

		#if defined MOTION_BLUR || defined TAA
			velocity = vec3(gl_FragCoord.xy * viewPixelSize, gl_FragCoord.z) - ((previousScreenPosition.xyz / previousScreenPosition.w) * 0.5 + 0.5);
		#endif
	}
#endif