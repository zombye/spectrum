/*\
 * Program Description:
 * Generates noise map for cloud "patches"
\*/

//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

#define CLOUDS3D_NOISE_OCTAVES_2D 3 // 2D noise octaves, determines overall shape.

#define CLOUDS3D_USE_WORLD_TIME
#define CLOUDS3D_SPEED 2 // [0.2 0.4 0.6 0.8 1 1.2 1.4 1.6 1.8 2 2.2 2.4 2.6 2.8 3 3.2 3.4 3.6 3.8 4 4.2 4.4 4.6 4.8 5 5.2 5.4 5.6 5.8 6 6.2 6.4 6.6 6.8 7 7.2 7.4 7.6 7.8 8 8.2 8.4 8.6 8.8 9 9.2 9.4 9.6 9.8 10]
#define CLOUDS3D_ALTITUDE 700 // [300 400 500 600 700 800 900 1000]
#define CLOUDS3D_THICKNESS_MULT 0.5 // [0.5 0.6 0.7 0.8 0.9 1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2]
#define CLOUDS3D_SCALE 1 // [1 1.4 2 2.8 4]

#define CLOUDS3D_THICKNESS (CLOUDS3D_ALTITUDE * CLOUDS3D_THICKNESS_MULT)

//--// Uniforms //------------------------------------------------------------//

uniform float frameTimeCounter;
uniform int worldDay;
uniform int worldTime;

uniform sampler2D noisetex;

#if defined STAGE_VERTEX
	//--// Vertex Functions //------------------------------------------------//

	void main() {
		gl_Position = ftransform();
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Outputs //------------------------------------------------//

	/* RENDERTARGETS: 9 */

	layout (location = 0, component = 0) out float cloudPatchNoise;
	layout (location = 0, component = 1) out float cloudCellsNoise;

	//--// Fragment Includes //-----------------------------------------------//

	#include "/include/utility.glsl"

	//--// Fragment Functions //----------------------------------------------//

	float Clouds3DPatchNoise(vec2 pos2D) {
		#ifdef CLOUDS3D_USE_WORLD_TIME
			float cloudsTime = CLOUDS3D_SPEED * TIME_SCALE * (worldDay % 128 + worldTime / 24000.0);
		#else
			float cloudsTime = CLOUDS3D_SPEED * TIME_SCALE * (1.0 / 1200.0) * frameTimeCounter;
		#endif

		const int layers = CLOUDS3D_NOISE_OCTAVES_2D;

		const float baseNoiseBase = 2.0;

		vec2 noiseUv  = pos2D / CLOUDS3D_THICKNESS;
		     noiseUv /= pow(pi, 2);

		vec2 windVec2D = normalize(vec2(1.0));
		float patchRemaining = 1.0;
		float patchNoise; {
			const float useFraction = 1.0 / baseNoiseBase;

			vec2 layerUv = (noiseUv - windVec2D * cloudsTime) / textureSize(noisetex, 0);
			float layer = texture(noisetex, layerUv).x * 2.0 - 1.0;

			float use = useFraction * patchRemaining;
			patchNoise = use * layer;
			patchRemaining -= use;
			for (int i = 1; i < (layers - 1); ++i) {
				noiseUv   *= rotateGoldenAngle * pi;
				windVec2D *= rotateGoldenAngle * pi;
				vec2 layerUv = (noiseUv - windVec2D * pow(4.0 * i + 1, 0.5) * cloudsTime) / textureSize(noisetex, 0);
				float layer = texture(noisetex, layerUv).x * 2.0 - 1.0;

				float use = useFraction * patchRemaining;
				patchNoise += use * layer;
				patchRemaining -= use;
			}
			patchNoise = patchNoise * 0.5 + 0.5;
		}

		return patchNoise;
	}

	float Clouds3DCellsNoise(vec2 pos2D) {
		#ifdef CLOUDS3D_USE_WORLD_TIME
			float cloudsTime = CLOUDS3D_SPEED * TIME_SCALE * (worldDay % 128 + worldTime / 24000.0);
		#else
			float cloudsTime = CLOUDS3D_SPEED * TIME_SCALE * (1.0 / 1200.0) * frameTimeCounter;
		#endif

		vec2 noiseUv  = pos2D / CLOUDS3D_THICKNESS;
		     noiseUv /= pow(pi, 1);
		vec2 windVec2D = normalize(vec2(1.0)) * pi;
		for (int i = 1; i < (CLOUDS3D_NOISE_OCTAVES_2D - 1); ++i) {
			noiseUv   *= rotateGoldenAngle;
			windVec2D *= rotateGoldenAngle;
		}

		//vec2 cellUv = pos2D / CLOUDS3D_THICKNESS;
		vec2 cellUv = noiseUv * rotateGoldenAngle * pi;
		cellUv -= windVec2D * pow(4.0 * CLOUDS3D_NOISE_OCTAVES_2D + 1.0, 0.5) * cloudsTime;
		float cellsRemaining = 1.0;
		float cellsNoise = texture(noisetex, cellUv / textureSize(noisetex, 0)).x * 2.0 - 1.0;
		cellsNoise = 0.5 * cellsNoise;
		cellsRemaining -= 0.5;
		cellsNoise = cellsNoise * 0.5 + 0.5;

		return cellsNoise;
	}

	void main() {
		vec2 uv = gl_FragCoord.xy / 2048.0 - 1.0;
		//uv /= 1.0 - abs(uv);
		vec2 pos2D = uv * (512.0 * CLOUDS3D_THICKNESS);
		cloudPatchNoise = Clouds3DPatchNoise(pos2D);
		cloudCellsNoise = Clouds3DCellsNoise(pos2D);
		cloudPatchNoise += exp2(-(CLOUDS3D_NOISE_OCTAVES_2D - 1)) * (cloudCellsNoise - 0.5);
	}
#endif
