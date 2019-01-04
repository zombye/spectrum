/*\
 * Program Description:
\*/

//--// Settings

#include "/settings.glsl"

//--// Uniforms

uniform int isEyeInWater;
uniform float eyeAltitude;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float sunAngle;

uniform float wetness;

uniform float fogDensity = 0.1;

uniform float screenBrightness;

// Time
uniform int   frameCounter;
uniform float frameTimeCounter;

uniform int worldDay;
uniform int worldTime;

// Gbuffer Uniforms
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

#define texture(a, b) texture2D(a, b)
#define tex texture
uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

// Misc Samplers
uniform sampler2D gaux3; // Sky Scattering Image
#define colortex6 gaux3
uniform sampler2D gaux4; // Sky Transmittance LUT
#define colortex7 gaux4

uniform sampler2D noisetex;

// Shadow uniforms
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
#ifdef SHADOW_COLORED
	uniform sampler2D shadowcolor1;
#endif

// Custom Uniforms
uniform vec2 viewResolution;
uniform vec2 viewPixelSize;
uniform vec2 taaOffset;

uniform vec3 shadowLightVectorView;
uniform vec3 shadowLightVector;

//--// Shared Libraries

#include "/lib/utility.glsl"
#include "/lib/utility/colorspace.glsl"
#include "/lib/utility/encoding.glsl"
#include "/lib/utility/sampling.glsl"

#include "/lib/shared/celestialConstants.glsl"

#include "/lib/shared/atmosphere/constants.glsl"
#include "/lib/shared/skyProjection.glsl"

//--// Shared Functions

#if STAGE == STAGE_VERTEX
	//--// Vertex Inputs

	attribute vec4 at_tangent;
	attribute vec3 mc_Entity;
	attribute vec2 mc_midTexCoord;

	//--// Vertex Outputs

	// Interpolated
	#if defined MOTION_BLUR || defined TAA
		out vec4 previousScreenPosition;
	#endif
	#if defined PARALLAX || defined WATER_PARALLAX
		out vec3 tangentViewVector;
	#endif
	out vec3 viewPosition;
	out vec2 lightmapCoordinates;
	out vec2 textureCoordinates;
	out float vertexAo;

	// Flat
	flat out mat3 tbn;
	#ifdef PARALLAX
		flat out mat3x2 atlasTileInfo;
		#define atlasTileOffset     atlasTileInfo[0]
		#define atlasTileSize       atlasTileInfo[1]
		#define atlasTileResolution atlasTileInfo[2]
	#endif
	flat out vec3 tint; // Interestingly, the tint color seems to always be the same for the entire quad.
	flat out int blockId;

	// Stuff that would ideally be uniforms
	flat out vec3 skylightPosX;
	flat out vec3 skylightPosY;
	flat out vec3 skylightPosZ;
	flat out vec3 skylightNegX;
	flat out vec3 skylightNegY;
	flat out vec3 skylightNegZ;

	flat out vec3 luminanceShadowlight;
	flat out vec3 illuminanceShadowlight;

	//--// Vertex Libraries

	#include "/lib/shared/atmosphere/lookup.glsl"
	#include "/lib/shared/atmosphere/transmittance.glsl"

	//--// Vertex Functions

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
		lightmapCoordinates = gl_MultiTexCoord1.xy / 240.0;
		blockId = int(round(mc_Entity.x));
		vertexAo = gl_Color.a;

		tbn = CalculateTBNMatrix();

		#ifdef PARALLAX
			ivec2 atlasResolution = textureSize(tex, 0);
			atlasTileSize       = abs(textureCoordinates - mc_midTexCoord);
			atlasTileOffset     = round((mc_midTexCoord - atlasTileSize) * atlasResolution) / atlasResolution;
			atlasTileResolution = round(2.0 * atlasTileSize * atlasResolution);
			atlasTileSize       = atlasTileResolution / atlasResolution;
		#endif

		viewPosition = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;

		#if defined MOTION_BLUR || defined TAA
			vec3 scenePosition = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;

			#if PROGRAM == PROGRAM_HAND || PROGRAM == PROGRAM_HAND_WATER
				vec3 previousScenePosition = scenePosition;
			#else
				vec3 previousScenePosition = scenePosition + cameraPosition - previousCameraPosition;
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

		#if PROGRAM == PROGRAM_HAND || PROGRAM == PROGRAM_HAND_WATER
			float projectionScale = gl_ProjectionMatrix[1].y * tan((HAND_FOV / 70.0) * atan(gl_ProjectionMatrixInverse[1].y));
			gl_Position = vec4(vec2(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y) / projectionScale, gl_ProjectionMatrix[2].zw) * viewPosition.xyzz + gl_ProjectionMatrix[3];
		#else
			gl_Position = vec4(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y, gl_ProjectionMatrix[2].zw) * viewPosition.xyzz + gl_ProjectionMatrix[3];
		#endif

		#ifdef TAA
			gl_Position.xy += taaOffset * gl_Position.w;
		#endif

		#if defined PARALLAX || defined WATER_PARALLAX
			tangentViewVector = (mat3(gbufferModelViewInverse) * viewPosition) * tbn;
		#endif

		skylightPosX = texelFetch(colortex6, ivec2(0, 0), 0).rgb;
		skylightPosY = texelFetch(colortex6, ivec2(1, 0), 0).rgb;
		skylightPosZ = texelFetch(colortex6, ivec2(2, 0), 0).rgb;
		skylightNegX = texelFetch(colortex6, ivec2(3, 0), 0).rgb;
		skylightNegY = texelFetch(colortex6, ivec2(4, 0), 0).rgb;
		skylightNegZ = texelFetch(colortex6, ivec2(5, 0), 0).rgb;

		vec3 shadowlightTransmittance = AtmosphereTransmittance(colortex7, vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector);
		luminanceShadowlight   = (sunAngle < 0.5 ? sunLuminance   : moonLuminance)   * shadowlightTransmittance;
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * shadowlightTransmittance;
	}
#elif STAGE == STAGE_FRAGMENT
	//--// Fragment Inputs

	// Interpolated
	#if defined MOTION_BLUR || defined TAA
		in vec4 previousScreenPosition;
	#endif
	#if defined PARALLAX || defined WATER_PARALLAX
		in vec3 tangentViewVector;
	#endif
	in vec3 viewPosition;
	in vec2 lightmapCoordinates;
	in vec2 textureCoordinates;
	in float vertexAo;

	// Flat
	flat in mat3 tbn;
	#ifdef PARALLAX
		flat in mat3x2 atlasTileInfo;
		#define atlasTileOffset     atlasTileInfo[0]
		#define atlasTileSize       atlasTileInfo[1]
		#define atlasTileResolution atlasTileInfo[2]
	#endif
	flat in vec3 tint; // Interestingly, the tint color seems to always be the same for the entire quad.
	flat in int blockId;

	// Stuff that would ideally be uniforms
	flat in vec3 skylightPosX;
	flat in vec3 skylightPosY;
	flat in vec3 skylightPosZ;
	flat in vec3 skylightNegX;
	flat in vec3 skylightNegY;
	flat in vec3 skylightNegZ;

	flat in vec3 luminanceShadowlight;
	flat in vec3 illuminanceShadowlight;

	//--// Fragment Outputs

	#if defined MOTION_BLUR || defined TAA
		/* DRAWBUFFERS:01235 */
	#else
		/* DRAWBUFFERS:0123 */
	#endif

	layout (location = 0) out vec4 colortex0Write;
	layout (location = 1) out vec4 colortex1Write;
	layout (location = 2) out vec4 colortex2Write;
	layout (location = 3) out vec4 colortex3Write;
	#if defined MOTION_BLUR || defined TAA
		layout (location = 4) out vec4 colortex5Write; // Velocity
	#endif

	//--// Fragment Libraries

	#include "/lib/utility/complex.glsl"
	#include "/lib/utility/dithering.glsl"
	#include "/lib/utility/math.glsl"
	#include "/lib/utility/noise.glsl"
	#include "/lib/utility/packing.glsl"
	#include "/lib/utility/spaceConversion.glsl"

	#include "/lib/shared/shadowDistortion.glsl"

	#ifdef PARALLAX
		#include "/lib/fragment/parallax.fsh"
	#endif

	#include "/lib/fragment/waterNormal.fsh"

	#include "/lib/fragment/material.fsh"
	#include "/lib/fragment/brdf.fsh"
	#include "/lib/fragment/diffuseLighting.fsh"
	#ifdef CAUSTICS
		#include "/lib/fragment/waterCaustics.fsh"
	#endif
	#include "/lib/fragment/shadows.fsh"

	#include "/lib/fragment/clouds3D.fsh"

	//--// Fragment Functions

	vec3 CalculateFakeBouncedLight(vec3 normal, vec3 lightVector) {
		const vec3 groundAlbedo = vec3(0.1, 0.1, 0.1);
		const vec3 weight = vec3(0.2, 0.6, 0.2); // Fraction of light bounced off the x, y, and z planes. Should sum to 1.0 or less.

		// Divide by pi^2 for energy conservation.
		float bounceIntensity = dot(abs(lightVector) * (-sign(lightVector) * normal * 0.5 + 0.5), weight / (pi * pi));

		return groundAlbedo * bounceIntensity;
	}

	void main() {
		mat3 position;
		position[0] = vec3(gl_FragCoord.st * viewPixelSize, gl_FragCoord.z);
		position[1] = viewPosition;
		position[2] = mat3(gbufferModelViewInverse) * position[1] + gbufferModelViewInverse[3].xyz;

		vec3 viewVector = normalize(position[2] - gbufferModelViewInverse[3].xyz);

		const float ditherSize = 8.0 * 8.0;
		float dither = Bayer8(gl_FragCoord.st);

		//--//

		vec4 baseTex;
		vec4 specTex;
		vec3 normal;

		#ifdef PARALLAX
			mat2 textureCoordinateDerivatives = mat2(dFdx(textureCoordinates), dFdy(textureCoordinates));
			vec3 parallaxEndPosition;
			vec2 parallaxedCoordinates = CalculateParallaxedCoordinate(textureCoordinates, textureCoordinateDerivatives, tangentViewVector, parallaxEndPosition);

			#define ReadTexture(sampler) textureGrad(sampler, parallaxedCoordinates, textureCoordinateDerivatives[0], textureCoordinateDerivatives[1])
		#else
			#define ReadTexture(sampler) texture(sampler, textureCoordinates)
		#endif

		#ifndef USE_WATER_TEXTURE
			if (blockId == 8 || blockId == 9) {
				baseTex = vec4(0.0);
				specTex = vec4(0.0);

				#ifdef WATER_PARALLAX
					normal = CalculateWaterNormal(position[2], tangentViewVector);
				#else
					normal = CalculateWaterNormal(position[2]).xzy;
				#endif
			} else {
		#endif

		baseTex = ReadTexture(tex);
		if (baseTex.a < 0.102) { discard; }
		baseTex.rgb *= tint;
		specTex = ReadTexture(specular);
		normal = ReadTexture(normals).rgb * 2.0 - (254.0 / 255.0);

		#ifndef USE_WATER_TEXTURE
			}
		#endif

		normal = normalize(tbn * normal);

		colortex0Write = vec4(Pack2x8(baseTex.rg), Pack2x8(baseTex.b, blockId / 255.0), Pack2x8Dithered(lightmapCoordinates, dither), 1.0);
		colortex1Write = vec4(Pack2x8(specTex.rg), Pack2x8(specTex.ba), Pack2x8(EncodeNormal(normal) * 0.5 + 0.5), 1.0);

		Material material = MaterialFromTex(baseTex.rgb, specTex, blockId);

		bool translucent = material.translucency.r + material.translucency.g + material.translucency.b > 0.0 || baseTex.a < 1.0;

		//--//

		float NoL = dot(normal, shadowLightVector);
		float NoV = dot(normal, -viewVector);
		float LoV = dot(shadowLightVector, -viewVector);
		float rcpLen_LV = inversesqrt(2.0 * LoV + 2.0);
		float NoH = (NoL + NoV) * rcpLen_LV;
		float VoH = LoV * rcpLen_LV + rcpLen_LV;

		float fresnel = FresnelDielectric(abs(NoV), (isEyeInWater == 1 ? 1.333 : 1.000275) / material.n.x);
		float totalOpacity = baseTex.a * (1.0 - fresnel) + fresnel;

		#if defined PARALLAX && defined PARALLAX_SHADOWS
			float parallaxShadow = CalculateParallaxSelfShadow(parallaxedCoordinates, parallaxEndPosition, textureCoordinateDerivatives, shadowLightVector * tbn);
		#else
			#define parallaxShadow 1.0
		#endif

		vec3 skylight = vec3(0.0);
		if (lightmapCoordinates.y > 0.0) {
			vec3 octahedronPoint = normal / (abs(normal.x) + abs(normal.y) + abs(normal.z));
			vec3 wPos = Clamp01( octahedronPoint);
			vec3 wNeg = Clamp01(-octahedronPoint);
			skylight = skylightPosX * wPos.x + skylightPosY * wPos.y + skylightPosZ * wPos.z
			         + skylightNegX * wNeg.x + skylightNegY * wNeg.y + skylightNegZ * wNeg.z;
		}

		#ifdef GLOBAL_LIGHT_FADE_WITH_SKYLIGHT
			vec3 shadows = vec3(0.0), vec3 bounce = vec3(0.0);
			if (lightmapCoordinates.y > 0.0) {
				float cloudShadow = Calculate3DCloudShadows(position[2] + cameraPosition);
				shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
				if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
					shadows *= CalculateShadows(position, tbn[2], translucent, dither, ditherSize);
				}

				bounce  = CalculateFakeBouncedLight(normal, shadowLightVector);
				bounce *= lightmapCoordinates.y * lightmapCoordinates.y * lightmapCoordinates.y;
				bounce *= cloudShadow * vertexAo;
			}
		#else
			float cloudShadow = Calculate3DCloudShadows(position[2] + cameraPosition);
			vec3 shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
			if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
				shadows *= CalculateShadows(position, tbn[2], translucent, dither, ditherSize);
			}

			vec3 bounce  = CalculateFakeBouncedLight(normal, shadowLightVector);
			     bounce *= lightmapCoordinates.y * lightmapCoordinates.y * lightmapCoordinates.y;
			     bounce *= cloudShadow * vertexAo;
		#endif
		colortex2Write = vec4(LinearToSrgb(shadows), 1.0);

		float blocklightShading = 1.0; // TODO

		material.albedo *= baseTex.a;
		colortex3Write.rgb  = CalculateDiffuseLighting(NoL, NoH, NoV, LoV, material, shadows, bounce, skylight, lightmapCoordinates, blocklightShading, vertexAo);
		colortex3Write.rgb += material.emission;
		colortex3Write.a    = totalOpacity;
		#if defined MOTION_BLUR || defined TAA
			colortex5Write.rgb = vec3(gl_FragCoord.xy * viewPixelSize, gl_FragCoord.z) - ((previousScreenPosition.xyz / previousScreenPosition.w) * 0.5 + 0.5);
			colortex5Write.a = 1.0;
		#endif
	}
#endif