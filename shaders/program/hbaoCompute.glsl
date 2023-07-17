//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex0;
uniform sampler2D colortex1;

uniform sampler2D depthtex1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
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

float CalculateCosBaseHorizonAngle(
	vec3  Po,   // Point on the plane
	vec3  Td,   // Direction to get tangent vector for
	vec3  L,    // (Normalized) Vector in the direction of the line
	vec3  N,    // Normal vector to the plane
	float LdotN // Dot product of L and N
) {
	vec3 negPoLd = Td - Po;

	float D = -dot(negPoLd, N) / LdotN;
	float Mu = dot(negPoLd, L);

	return (Mu + D) * inversesqrt(D * D + 2.0 * Mu * D + dot(negPoLd, negPoLd));
}
float CalculateCosHorizonAngle(vec3 horizonDirection, vec3 position, vec3 viewVector, vec3 normal, float NoV, float sampleOffset) {
	float cosHorizonAngle = CalculateCosBaseHorizonAngle(position, horizonDirection, viewVector, normal, NoV);

	for (int i = 0; i < HBAO_ANGLE_SAMPLES; ++i) {
		float sampleRadius = Pow2(float(i) / float(HBAO_ANGLE_SAMPLES) + sampleOffset);
		vec2 sampleCoord = ViewSpaceToScreenSpace(position + horizonDirection * sampleRadius * HBAO_RADIUS, gbufferProjection).xy;

		if (Clamp01(sampleCoord) != sampleCoord) { break; }

		//vec3 samplePosition = vec3(sampleCoord, texture(depthtex1, sampleCoord).r);
		//     samplePosition = ScreenSpaceToViewSpace(samplePosition, gbufferProjectionInverse);
		vec3 samplePosition = vec3(sampleCoord * 2.0 - 1.0, GetLinearDepth(depthtex1, sampleCoord + 0.5 * taaOffset));
		samplePosition.xy *= Diagonal(gbufferProjectionInverse).xy * -samplePosition.z;
		samplePosition.z += samplePosition.z * 2e-4; // done to prevent overocclusion in some cases

		vec3  sampleVector          = samplePosition - position;
		float sampleDistanceSquared = dot(sampleVector, sampleVector);

		if (sampleDistanceSquared > HBAO_RADIUS * HBAO_RADIUS) { continue; }

		float cosSampleAngle = dot(viewVector, sampleVector) * inversesqrt(sampleDistanceSquared);

		cosHorizonAngle = max(cosHorizonAngle, cosSampleAngle);
	}

	return cosHorizonAngle;
}

/*
float RTAO(mat3 position, vec3 normal, float dither, out vec3 lightdir) {
	const int rays = RTAO_RAYS;
	normal = mat3(gbufferModelView) * normal;

	lightdir = vec3(0.0);
	float ao = 0.0;
	for (int i = 0; i < rays; ++i) {
		vec3 dir = SampleSphere(Hash2(vec2(dither, i / float(rays))));
		float NoL = dot(dir, normal);
		if (NoL < 0.0) {
			dir = -dir;
			NoL = -NoL;
		}

		vec3 hitPos = position[0];
		if (!RaytraceIntersection(hitPos, position[1], dir, dither, HBAO_RADIUS, RTAO_RAY_STEPS, 4)) {
			lightdir += dir * NoL;
			ao += NoL;
		}
	}
	float ldl = dot(lightdir, lightdir);
	lightdir = ldl == 0.0 ? normal : lightdir * inversesqrt(ldl);
	lightdir = mat3(gbufferModelViewInverse) * lightdir;

	return ao * 2.0 / rays;
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

	vec4 hbao;
	if (positionScreen.z < 1.0) {
		const float ditherSize = 4.0 * 4.0;
		float dither = Bayer4(gl_GlobalInvocationID.xy);

		vec3 normal = DecodeNormal(Unpack2x8(texelFetch(colortex1, ivec2(gl_GlobalInvocationID.xy) * 2, 0).a) * 2.0 - 1.0);
		normal = mat3(gbufferModelView) * normal;

		vec3 viewerDirection = -normalize(positionView);

		dither += 0.5 / ditherSize;

		float NoV = dot(normal, viewerDirection);

		mat3 rot = GetRotationMatrix(vec3(0, 0, 1), viewerDirection);

		vec3 normal2 = normal * rot;
		float phiN = atan(normal2.y, normal2.x);
		float sinThetaN = sqrt(Clamp01(1.0 - normal2.z * normal2.z));
		float cosThetaN = normal2.z;

		hbao = vec4(0.0);
		for (int i = 0; i < HBAO_DIRECTIONS; ++i) {
			float idx = i + dither;
			float phi = idx * pi / HBAO_DIRECTIONS;
			vec2 xy = vec2(cos(phi), sin(phi));
			vec3 horizonDirection = rot * vec3(xy, 0.0);

			//--// Get cosine horizon angles

			float sampleOffset = fract(idx * ditherSize * phi) / HBAO_ANGLE_SAMPLES;

			float cosTheta1 = CalculateCosHorizonAngle( horizonDirection, positionView, viewerDirection, normal, NoV, sampleOffset);
			float cosTheta2 = CalculateCosHorizonAngle(-horizonDirection, positionView, viewerDirection, normal, NoV, sampleOffset);

			//--// Integral over theta

			// Parts that are reused
			float theta1 = acos(clamp(cosTheta1, -1.0, 1.0));
			float theta2 = acos(clamp(cosTheta2, -1.0, 1.0));
			float sinThetaSq1 = 1.0 - cosTheta1 * cosTheta1;
			float sinThetaSq2 = 1.0 - cosTheta2 * cosTheta2;
			float sinTheta1 = sin(theta1);
			float sinTheta2 = sin(theta2);
			float cu1MinusCu2 = sinThetaSq1 * sinTheta1 - sinThetaSq2 * sinTheta2;

			float temp = cos(phiN - phi) * sinThetaN;

			// Average non-occluded direction
			float xym = 4.0 - cosTheta1 * (2.0 + sinThetaSq1) - cosTheta2 * (2.0 + sinThetaSq2);
			      xym = temp * xym + cosThetaN * cu1MinusCu2;

			hbao.xy += xy * xym;
			hbao.z  += temp * cu1MinusCu2 + cosThetaN * (2.0 - Pow3(cosTheta1) - Pow3(cosTheta2));

			// AO
			hbao.w += temp * ((theta1 - cosTheta1 * sinTheta1) - (theta2 - cosTheta2 * sinTheta2));
			hbao.w += cosThetaN * (sinThetaSq1 + sinThetaSq2);
		}

		float coneLength = length(hbao.xyz);
		hbao.xyz = coneLength <= 0.0 ? normal : rot * hbao.xyz / coneLength;
		hbao.w /= 2.0 * HBAO_DIRECTIONS;

		hbao.xyz = mat3(gbufferModelViewInverse) * hbao.xyz;
		hbao.xyz = normalize(hbao.xyz);
	} else {
		hbao = vec4(vec3(0.0), 1.0);
	}
	
	// Save output
	imageStore(colorimg5, ivec2(gl_GlobalInvocationID.xy), hbao);
}
