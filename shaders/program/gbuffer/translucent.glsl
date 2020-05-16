//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform float sunAngle;

uniform float rainStrength;
uniform float wetness;

uniform float fogDensity = 0.1;

uniform float screenBrightness;

#define texture(a, b) texture2D(a, b)
#define tex texture
uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

#ifdef SSR_MULTILAYER
uniform sampler2D depthtex1;
#endif

#ifdef SSR_MULTILAYER
uniform sampler2D gaux1;
#define colortex4 gaux1
#endif
uniform sampler2D gaux2; // Image storing some stuff that would ideally be uniforms but currently can't be
#define colortex5 gaux2
uniform sampler2D gaux3; // Sky Scattering Image
#define colortex6 gaux3

uniform sampler2D noisetex;

//--// Time uniforms

uniform int   frameCounter;
uniform float frameTimeCounter;

uniform int worldDay;
uniform int worldTime;

//--// Camera uniforms

uniform int isEyeInWater;
uniform float eyeAltitude;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float far;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

//--// Shadow uniforms

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

//--// Custom Uniforms

uniform vec2 viewResolution;
uniform vec2 viewPixelSize;

uniform float frameR1;

uniform vec2 taaOffset;

uniform vec3 shadowLightVectorView;
uniform vec3 shadowLightVector;

//--// Shared Includes //-----------------------------------------------------//

#include "/include/utility.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/sampling.glsl"

#include "/include/shared/celestialConstants.glsl"

#include "/include/shared/atmosphere/constants.glsl"
#include "/include/shared/skyProjection.glsl"

#if defined STAGE_VERTEX
	//--// Vertex Inputs //---------------------------------------------------//

	attribute vec4 at_tangent;
	attribute vec3 mc_Entity;
	attribute vec2 mc_midTexCoord;

	//--// Vertex Outputs //--------------------------------------------------//

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

	//--// Vertex Includes //-------------------------------------------------//

	#include "/include/shared/atmosphere/lookup.glsl"
	#include "/include/shared/atmosphere/transmittance.glsl"

	//--// Vertex Functions //------------------------------------------------//

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

			#if defined PROGRAM_HAND || defined PROGRAM_HAND_WATER
				vec3 previousScenePosition = scenePosition;
			#else
				vec3 previousScenePosition = scenePosition + cameraPosition - previousCameraPosition;
			#endif

			#if defined PROGRAM_HAND || defined PROGRAM_HAND_WATER
				// No correct previous matrix for hand rotation, but the current frame rotation + previous frame motion is close.
				vec3 previousViewPosition = mat3(gbufferModelView) * previousScenePosition + gbufferPreviousModelView[3].xyz;
			#else
				vec3 previousViewPosition = mat3(gbufferPreviousModelView) * previousScenePosition + gbufferPreviousModelView[3].xyz;
			#endif

			#if defined PROGRAM_HAND || defined PROGRAM_HAND_WATER
				//float projectionScalePrevious = (gbufferPreviousProjection[1].y / gl_ProjectionMatrix[1].y) * tan((HAND_FOV / 70.0) * atan(gl_ProjectionMatrixInverse[1].y / gbufferPreviousProjection[1].y));
				//previousScreenPosition = vec4(vec2(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y) / projectionScalePrevious, gbufferPreviousProjection[2].zw) * previousViewPosition.xyzz + gbufferPreviousProjection[3];
				float projectionScalePrevious = gl_ProjectionMatrix[1].y * tan((HAND_FOV / 70.0) * atan(gl_ProjectionMatrixInverse[1].y));
				previousScreenPosition = vec4(vec2(gl_ProjectionMatrix[0].x, gl_ProjectionMatrix[1].y) / projectionScalePrevious, gl_ProjectionMatrix[2].zw) * previousViewPosition.xyzz + gl_ProjectionMatrix[3];
			#else
				previousScreenPosition = vec4(gbufferPreviousProjection[0].x, gbufferPreviousProjection[1].y, gbufferPreviousProjection[2].zw) * previousViewPosition.xyzz + gbufferPreviousProjection[3];
			#endif
			previousScreenPosition.xy += taaOffset * previousScreenPosition.w;
		#endif

		#if defined PROGRAM_HAND || defined PROGRAM_HAND_WATER
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

		skylightPosX = texelFetch(colortex5, ivec2(0, 0), 0).rgb;
		skylightPosY = texelFetch(colortex5, ivec2(1, 0), 0).rgb;
		skylightPosZ = texelFetch(colortex5, ivec2(2, 0), 0).rgb;
		skylightNegX = texelFetch(colortex5, ivec2(3, 0), 0).rgb;
		skylightNegY = texelFetch(colortex5, ivec2(4, 0), 0).rgb;
		skylightNegZ = texelFetch(colortex5, ivec2(5, 0), 0).rgb;

		vec3 shadowlightTransmittance = texelFetch(colortex5, ivec2(0, 1), 0).rgb;
		luminanceShadowlight   = (sunAngle < 0.5 ? sunLuminance   : moonLuminance)   * shadowlightTransmittance;
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : moonIlluminance) * shadowlightTransmittance;
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

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

	#define illuminanceSky skylightPosY // TODO: Make this the thing it's supposed to be

	flat in vec3 luminanceShadowlight;
	flat in vec3 illuminanceShadowlight;

	//--// Fragment Outputs //------------------------------------------------//

	#if defined MOTION_BLUR || defined TAA
		/* DRAWBUFFERS:01732 */
	#else
		/* DRAWBUFFERS:0173 */
	#endif

	layout (location = 0) out vec4 colortex0Write;
	layout (location = 1) out vec4 colortex1Write;
	layout (location = 2) out vec4 shadowsOut;
	layout (location = 3) out vec4 colortex3Write;
	#if defined MOTION_BLUR || defined TAA
		layout (location = 4) out vec4 velocity; // Velocity
	#endif

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/complex.glsl"
	#include "/include/utility/dithering.glsl"
	#include "/include/utility/fastMath.glsl"
	#include "/include/utility/geometry.glsl"
	#include "/include/utility/noise.glsl"
	#include "/include/utility/packing.glsl"
	#include "/include/utility/rotation.glsl"
	#include "/include/utility/spaceConversion.glsl"

	#include "/include/shared/shadowDistortion.glsl"

	#ifdef PARALLAX
		#include "/include/fragment/parallax.fsh"
	#endif

	#include "/include/fragment/waterNormal.fsh"

	#include "/include/fragment/material.fsh"
	#include "/include/fragment/brdf.fsh"
	#include "/include/fragment/diffuseLighting.fsh"
	#if CAUSTICS != CAUSTICS_OFF
		#include "/include/fragment/waterCaustics.fsh"
	#endif
	#include "/include/fragment/shadows.fsh"

	#include "/include/fragment/clouds3D.fsh"


	#ifdef SSR_MULTILAYER
		#include "/include/shared/phaseFunctions.glsl"

		#include "/include/shared/atmosphere/density.glsl"
		#include "/include/shared/atmosphere/phase.glsl"
		#include "/include/fragment/fog.fsh"

		#include "/include/fragment/brdf.fsh"
		#include "/include/fragment/raytracer.fsh"
		#include "/include/fragment/specularLighting.fsh"
	#endif

	//--// Fragment Functions //----------------------------------------------//

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
			float mipLevel = textureQueryLod(normals, textureCoordinates).x;
			vec3 parallaxEndPosition; ivec2 parallaxEndIndex;
			vec2 parallaxedCoordinates = CalculateParallaxedCoordinate(textureCoordinates, mipLevel, tangentViewVector, parallaxEndPosition, parallaxEndIndex);

			#define ReadTexture(sampler) textureLod(sampler, parallaxedCoordinates, mipLevel)
		#else
			#define ReadTexture(sampler) texture(sampler, textureCoordinates)
		#endif

		#ifdef PROCEDURAL_WATER
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
		#if RESOURCE_FORMAT == RESOURCE_FORMAT_LAB_1_2 || RESOURCE_FORMAT == RESOURCE_FORMAT_LAB_1_3
		normal.xy = ReadTexture(normals).rg * 2.0 - (254.0 / 255.0);
		normal.z = sqrt(Clamp01(1.0 - dot(normal.xy, normal.xy)));
		#else
		normal = ReadTexture(normals).rgb * 2.0 - (254.0 / 255.0);
		#endif

		#ifdef PROCEDURAL_WATER
			}
		#endif

		normal = normalize(tbn * normal);

		colortex0Write = vec4(Pack2x8(baseTex.rg), Pack2x8(baseTex.b, Clamp01(blockId / 255.0)), Pack2x8Dithered(lightmapCoordinates, dither), 1.0);
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

		#ifdef TOTAL_INTERNAL_REFLECTION
		float fresnel = FresnelDielectric(abs(NoV), (isEyeInWater == 1 ? 1.333 : 1.000275) / material.n.x);
		#else
		float fresnel = FresnelDielectric(abs(NoV), airMaterial.n.x / material.n.x);
		#endif
		float totalOpacity = baseTex.a * (1.0 - fresnel) + fresnel;

		#if defined PARALLAX && defined PARALLAX_SHADOWS
			float parallaxShadow = CalculateParallaxSelfShadow(parallaxEndPosition, parallaxEndIndex, mipLevel, shadowLightVector * tbn);
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

		float sssDepth = 0.0;
		#ifdef GLOBAL_LIGHT_FADE_WITH_SKYLIGHT
			vec3 shadows = vec3(0.0), bounce = vec3(0.0);
			float cloudShadow = 0.0;
			if (lightmapCoordinates.y > 0.0) {
				cloudShadow = GetCloudShadows(position[2]);
				shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
				if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
					shadows *= CalculateShadows(position, tbn[2], translucent, dither, ditherSize, sssDepth);
				}

				bounce  = CalculateFakeBouncedLight(normal, shadowLightVector);
				bounce *= lightmapCoordinates.y * lightmapCoordinates.y * lightmapCoordinates.y;
				bounce *= cloudShadow * vertexAo;
			}
		#else
			float cloudShadow = GetCloudShadows(position[2]);
			vec3 shadows = vec3(parallaxShadow * cloudShadow * (translucent ? 1.0 : step(0.0, NoL)));
			if (shadows.r > 0.0 && (NoL > 0.0 || translucent)) {
				shadows *= CalculateShadows(position, tbn[2], translucent, dither, ditherSize, sssDepth);
			}

			vec3 bounce  = CalculateFakeBouncedLight(normal, shadowLightVector);
			     bounce *= lightmapCoordinates.y * lightmapCoordinates.y * lightmapCoordinates.y;
			     bounce *= cloudShadow * vertexAo;
		#endif
		shadowsOut = vec4(Clamp01(SrgbFromLinear(shadows)), 1.0);

		float blocklightShading = 1.0; // TODO

		material.albedo *= baseTex.a;
		colortex3Write.rgb  = CalculateDiffuseLighting(NoL, NoH, NoV, LoV, material, shadows, cloudShadow, bounce, sssDepth, skylight, lightmapCoordinates, blocklightShading, vertexAo);
		#ifdef SSR_MULTILAYER
		colortex3Write.rgb += CalculateEnvironmentReflections(colortex4, position, normal, NoV, material.roughness, material.n, material.k, 1.0, blockId == 8 || blockId == 9, dither, ditherSize);
		#endif
		colortex3Write.rgb += material.emission;
		colortex3Write.a    = Clamp01(totalOpacity);
		#if defined MOTION_BLUR || defined TAA
			velocity.rgb = vec3(gl_FragCoord.xy * viewPixelSize, gl_FragCoord.z) - ((previousScreenPosition.xyz / previousScreenPosition.w) * 0.5 + 0.5);
			velocity.a = 1.0;
		#endif
	}
#endif
