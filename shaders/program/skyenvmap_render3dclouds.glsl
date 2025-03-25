//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform float sunAngle;

uniform float wetness;

uniform float screenBrightness;

uniform sampler2D depthtex1;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex8; // Velocity buffer
uniform sampler2D colortex5; // Previous frame data
uniform sampler3D colortex7; // 3D noise
uniform sampler2D colortex9; // Cloud patch noise
uniform sampler2D noisetex;

uniform sampler2D depthtex0; // Sky Transmittance LUT
uniform sampler3D depthtex2; // Sky Scattering LUT
#define transmittanceLut depthtex0
#define scatteringLut depthtex2

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

//--// Custom uniforms

uniform vec2 viewResolution;
uniform vec2 viewPixelSize;

uniform float frameR1;

uniform vec2 taaOffset;

uniform vec3 sunVector;

uniform vec3 moonVector;

uniform vec3 shadowLightVector;

//--// Shared Includes //-----------------------------------------------------//

#include "/include/utility.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/fastMath.glsl"
#include "/include/utility/noise.glsl"
#include "/include/utility/sampling.glsl"

#include "/include/shared/celestialConstants.glsl"
#define moonIlluminance (moonIlluminance * NIGHT_SKY_BRIGHTNESS)
#include "/include/shared/phaseFunctions.glsl"

#include "/include/shared/atmosphere/constants.glsl"
#include "/include/shared/atmosphere/lookup.glsl"
#include "/include/shared/atmosphere/transmittance.glsl"
#include "/include/shared/atmosphere/phase.glsl"
#include "/include/shared/atmosphere/scattering.glsl"

#include "/include/shared/skyProjection.glsl"

#if defined STAGE_VERTEX
	//--// Vertex Outputs //--------------------------------------------------//

	out vec2 screenCoord;

	out vec3 skyAmbient;
	out vec3 skyAmbientUp;
	out vec3 illuminanceShadowlight;

	out float averageCloudTransmittance;

	//--// Vertex Includes //-------------------------------------------------//

	#include "/include/fragment/clouds3D.fsh"

	//--// Vertex Functions //------------------------------------------------//

	void main() {
		screenCoord = gl_Vertex.xy;
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);

		const ivec2 samples = ivec2(16, 8);

		skyAmbient = vec3(0.0);
		skyAmbientUp = vec3(0.0);
		for (int x = 0; x < samples.x; ++x) {
			for (int y = 0; y < samples.y; ++y) {
				vec3 dir = SampleSphere((vec2(x, y) + 0.5) / samples);

				vec3 skySample  = AtmosphereScattering(scatteringLut, vec3(0.0, atmosphere_planetRadius, 0.0), dir, sunVector ) * sunIlluminance;
				     skySample += AtmosphereScattering(scatteringLut, vec3(0.0, atmosphere_planetRadius, 0.0), dir, moonVector) * moonIlluminance;

				skyAmbient += skySample;
				skyAmbientUp += skySample * Clamp01(dir.y);
			}
		}

		const float sampleWeight = 4.0 * pi / (samples.x * samples.y);
		skyAmbient *= sampleWeight;
		skyAmbientUp *= sampleWeight;

		vec3 shadowlightTransmittance  = AtmosphereTransmittance(transmittanceLut, vec3(0.0, atmosphere_planetRadius, 0.0), shadowLightVector);
		     shadowlightTransmittance *= smoothstep(0.0, 0.01, abs(shadowLightVector.y));
		illuminanceShadowlight = (sunAngle < 0.5 ? sunIlluminance : (moonIlluminance / NIGHT_SKY_BRIGHTNESS)) * shadowlightTransmittance;

		averageCloudTransmittance = Calculate3DCloudsAverageTransmittance();
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Inputs //-------------------------------------------------//

	in vec2 screenCoord;

	in vec3 skyAmbient;
	in vec3 skyAmbientUp;
	in vec3 illuminanceShadowlight;

	in float averageCloudTransmittance;

	//--// Fragment Outputs //------------------------------------------------//

	/* RENDERTARGETS: 10,11 */

	layout (location = 0) out vec4 out_clouds;
	layout (location = 1) out float out_clouddist;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility/complex.glsl"
	#include "/include/utility/dithering.glsl"
	#include "/include/utility/packing.glsl"
	#include "/include/utility/rotation.glsl"
	#include "/include/utility/spaceConversion.glsl"

	#include "/include/shared/atmosphere/density.glsl"

	#include "/include/fragment/clouds2D.fsh"
	#include "/include/fragment/clouds3D.fsh"

	#include "/include/fragment/material.fsh"
	#include "/include/fragment/brdf.fsh"
	#include "/include/fragment/diffuseLighting.fsh"
	#include "/include/fragment/specularLighting.fsh"

	//--// Fragment Functions //----------------------------------------------//

	void main() {
		ivec2 pixel = ivec2(gl_FragCoord.xy);

		float tileSize = min(floor(viewResolution.x * 0.5) / 1.5, floor(viewResolution.y * 0.5)) * exp2(-SKY_IMAGE_LOD);
		vec2 cmp = tileSize * vec2(3.0, 2.0);
		bool render_clouds = gl_FragCoord.x < cmp.x && gl_FragCoord.y < cmp.y;

		vec3 viewVector;
		if (render_clouds) {
			vec3 viewPosition = vec3(0.0, atmosphere_planetRadius + eyeAltitude, 0.0);

			viewVector = UnprojectSky(screenCoord, SKY_IMAGE_LOD);

			float lowerLimitDistance = RaySphereIntersection(viewPosition, viewVector, atmosphere_lowerLimitRadius).x;
			render_clouds = lowerLimitDistance <= 0.0 || eyeAltitude >= CLOUDS3D_ALTITUDE_MIN;
		}

		if (render_clouds) {
			const float ditherSize = 16.0 * 16.0;
			float dither = Bayer16(gl_FragCoord.st);
			#ifdef TAA
			      dither = fract(dither + frameR1);
			#endif

			out_clouds = Render3DClouds(viewVector, dither, out_clouddist);
		} else {
			out_clouds = vec4(0.0);
			out_clouddist = 0.0;
		}
	}
#endif
