//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex0;
uniform sampler2D colortex1;

uniform sampler2D depthtex1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

writeonly uniform image2D colorimg5;

uniform vec2 viewResolution;
uniform vec2 taaOffset;

//--// Inputs //--------------------------------------------------------------//

layout (local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
const vec2 workGroups = vec2(0.5, 0.5);

//--// Includes //------------------------------------------------------------//

#include "/include/utility.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/packing.glsl"
#include "/include/utility/rotation.glsl"
#include "/include/utility/spaceConversion.glsl"

#include "/include/shared/shadowDistortion.glsl"

//--// Functions //-----------------------------------------------------------//

float GetLinearDepth(sampler2D depthSampler, vec2 coord) {
	//float depth = texelFetch(depthSampler, ivec2(coord * viewResolution), 0).r + gbufferProjectionInverse[1].y*exp2(-3.0);
	//return ScreenSpaceToViewSpace(depth, gbufferProjectionInverse);

	// Interpolates after linearizing, significantly reduces a lot of issues for screen-space shadows
	coord = coord * viewResolution + 0.5;

	vec2  f = fract(coord);
	ivec2 i = ivec2(coord - f);

	vec4 s = textureGather(depthSampler, i / viewResolution) * 2.0 - 1.0;
	     s = 1.0 / (gbufferProjectionInverse[2].w * s + gbufferProjectionInverse[3].w);

	s.xy = mix(s.wx, s.zy, f.x);
	return mix(s.x,  s.y,  f.y) * gbufferProjectionInverse[3].z;
}

/*
void DitherTiles(ivec2 fragCoord, int patternSize, float scale, out ivec2 tile, out ivec2 tileFragCoord, out vec2 tileScreenCoord) {
	ivec2 quadResolution      = ivec2(ceil(viewResolution / scale));
	ivec2 floorTileResolution = ivec2(floor(vec2(quadResolution) / float(patternSize)));
	ivec2 ceilTileResolution  = ivec2( ceil(vec2(quadResolution) / float(patternSize)));

	fragCoord = fragCoord % quadResolution;

	ivec2 ceilTiles         = quadResolution % patternSize;
	ivec2 tileSizeThreshold = ceilTileResolution * ceilTiles;
	bvec2 belowThreshold;
	belowThreshold.x = fragCoord.x < tileSizeThreshold.x;
	belowThreshold.y = fragCoord.y < tileSizeThreshold.y;

	ivec2 tileResolution;
	tileResolution.x = belowThreshold.x ? ceilTileResolution.x : floorTileResolution.x;
	tileResolution.y = belowThreshold.y ? ceilTileResolution.y : floorTileResolution.y;

	tileFragCoord.x = belowThreshold.x ? fragCoord.x : fragCoord.x - tileSizeThreshold.x;
	tileFragCoord.y = belowThreshold.y ? fragCoord.y : fragCoord.y - tileSizeThreshold.y;

	tile = tileFragCoord / tileResolution;
	tile.x += belowThreshold.x ? 0 : ceilTiles.x;
	tile.y += belowThreshold.y ? 0 : ceilTiles.y;
	tileFragCoord = tileFragCoord % tileResolution;

	tileFragCoord = tileFragCoord * patternSize + tile;
	tileScreenCoord = (tileFragCoord + 0.5) * scale / viewResolution;
}

void UnditherTiles(ivec2 fragCoord, int patternSize, float scale, out ivec2 tile, out ivec2 tileFragCoord) {
	ivec2 quadResolution      = ivec2(ceil(viewResolution / scale));
	ivec2 floorTileResolution = ivec2(floor(vec2(quadResolution) / float(patternSize)));
	ivec2 ceilTileResolution  = ivec2( ceil(vec2(quadResolution) / float(patternSize)));

	ivec2 ceilTiles         = quadResolution % patternSize;
	ivec2 tileSizeThreshold = ceilTileResolution * ceilTiles;

	fragCoord = fragCoord % quadResolution;

	tile = fragCoord % patternSize;
	tileFragCoord = (fragCoord - tile) / patternSize;

	tileFragCoord.x += tile.x <= ceilTiles.x ? tile.x * ceilTileResolution.x : (tile.x - ceilTiles.x) * floorTileResolution.x + tileSizeThreshold.x;
	tileFragCoord.y += tile.y <= ceilTiles.y ? tile.y * ceilTileResolution.y : (tile.y - ceilTiles.y) * floorTileResolution.y + tileSizeThreshold.y;
}
*/

void main() {
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);

	if (any(greaterThanEqual(vec2(gl_GlobalInvocationID.xy), ceil(workGroups * viewResolution)))) {
		return;
	}

	vec2 tmp = (vec2(gl_GlobalInvocationID.xy) + 0.5) / (workGroups * viewResolution);

	vec3 positionScreen;
	positionScreen.xy = tmp;
	#ifdef TAA
	positionScreen.xy -= taaOffset * 0.5;
	#endif
	vec3 positionView  = GetViewDirection(positionScreen.xy, gbufferProjectionInverse);
	     positionView *= GetLinearDepth(depthtex1, tmp) / positionView.z;
	positionScreen.z   = ViewSpaceToScreenSpace(positionView.z, gbufferProjection);

	if (positionScreen.z >= 1.0) {
		return;
	}

	vec3  position = mat3(gbufferModelViewInverse) * positionView + gbufferModelViewInverse[3].xyz;
	vec3  normal   = DecodeNormal(Unpack2x8(texelFetch(colortex1, 2 * ivec2(gl_GlobalInvocationID.xy), 0).a) * 2.0 - 1.0);
	float skylight = Unpack2x8Y(texelFetch(colortex0, 2 * ivec2(gl_GlobalInvocationID.xy), 0).b);
	float dither   = Bayer16(gl_GlobalInvocationID.xy);
	const float ditherSize = 16.0*16.0;

	// Main RSM compute
	vec3 rsm = vec3(0.0); {
		dither = dither * ditherSize + 0.5;
		float dither2 = dither / ditherSize;

		const float radiusSquared     = RSM_RADIUS * RSM_RADIUS;
		const float perSampleArea     = pi * radiusSquared / RSM_SAMPLES;
		const float sampleDistanceAdd = sqrt((perSampleArea / RSM_SAMPLES) / pi); // Added to sampleDistanceSquared to prevent fireflies

		vec3 projectionScale        = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z / SHADOW_DEPTH_SCALE);
		vec3 projectionInverseScale = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z * SHADOW_DEPTH_SCALE);
		vec2 offsetScale            = RSM_RADIUS * projectionScale.xy;

		vec3 shadowPosition = mat3(shadowModelView) * position + shadowModelView[3].xyz;
		vec3 shadowClip     = projectionScale * shadowPosition + shadowProjection[3].xyz;
		vec3 shadowNormal   = mat3(shadowModelView) * normal;

		mat2 rot = GetRotationMatrix(ditherSize * goldenAngle);

		vec2 dir = SinCos(dither * goldenAngle);
		for (int i = 0; i < RSM_SAMPLES; ++i) {
			float r = (i + dither2) / RSM_SAMPLES;
			vec2 sampleOffset = dir * offsetScale * r;
			dir *= rot;

			vec3 sampleClip     = shadowClip;
			     sampleClip.xy += sampleOffset;

			float distortionFactor = CalculateDistortionFactor(sampleClip.xy);
			vec2 sampleCoord    = (sampleClip.xy * distortionFactor) * 0.5 + 0.5;
			     sampleClip.z   = textureLod(shadowtex0, sampleCoord, 0.0).r * 2.0 - 1.0;
			vec3 samplePosition = projectionInverseScale * sampleClip + shadowProjectionInverse[3].xyz;

			vec3  sampleVector          = samplePosition - shadowPosition;
			float sampleDistanceSquared = dot(sampleVector, sampleVector);

			if (sampleDistanceSquared > radiusSquared) { continue; } // Discard samples that are too far away

			sampleVector *= inversesqrt(sampleDistanceSquared);

			vec3 shadowcolor0Sample = textureLod(shadowcolor0, sampleCoord, 0.0).rgb;
			vec3 sampleNormal = DecodeNormal(shadowcolor0Sample.rg * 2.0 - 1.0);

			// Calculate BRDF (lambertian)
			float sampleIn  = 2.0 * r; // Light's projected area for each sample
			float sampleOut = Clamp01(dot(sampleNormal, -sampleVector)) / pi; // Divide by pi for energy conservation.
			float bounceIn  = Clamp01(dot(shadowNormal,  sampleVector));
			const float bounceOut = 1.0 / pi; // Divide by pi for energy conservation.

			float brdf = sampleIn * sampleOut * bounceIn * bounceOut;

			#ifdef RSM_LEAK_PREVENTION
				float sampleSkylight = shadowcolor0Sample.b;
				brdf *= Clamp01(1.0 - 5.0 * abs(sampleSkylight - skylight));
			#endif

			vec4 sampleAlbedo = textureLod(shadowcolor1, sampleCoord, 0.0);
			rsm += LinearFromSrgb(sampleAlbedo.rgb) * sampleAlbedo.a * brdf / (sampleDistanceSquared + sampleDistanceAdd);
		}

		rsm *= perSampleArea;
	}

	// Save output
	imageStore(colorimg5, ivec2(gl_GlobalInvocationID.xy) + ivec2(workGroups.x * viewResolution.x, 0), vec4(rsm, 1.0));
}