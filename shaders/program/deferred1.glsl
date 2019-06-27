//--// Settings //------------------------------------------------------------//

#include "/settings.glsl"

//--// Uniforms //------------------------------------------------------------//

uniform sampler2D colortex5;

//--// Custom uniforms

uniform vec2 viewResolution;
uniform vec2 viewPixelSize;

#if defined STAGE_VERTEX
	//--// Vertex Functions //------------------------------------------------//

	void main() {
		gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
	}
#elif defined STAGE_FRAGMENT
	//--// Fragment Outputs //------------------------------------------------//

	/* DRAWBUFFERS:5 */

	layout (location = 0) out vec4 colortex5Write;

	//--// Fragment Functions //----------------------------------------------//

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

	void main() {
		ivec2 fragCoord = ivec2(gl_FragCoord.xy);
		vec2 screenCoord = gl_FragCoord.xy * viewPixelSize;

		colortex5Write = texelFetch(colortex5, fragCoord, 0);

		#ifdef RSM
			if (screenCoord.x > 0.5 && screenCoord.y < 0.5) { // RSM
				ivec2 tile, tileFragCoord; vec2 tileScreenCoord;
				UnditherTiles(fragCoord, 4, 2.0, tile, tileFragCoord);

				ivec2 quadResolution = ivec2(ceil(viewResolution / 2.0));
				tileFragCoord.x += quadResolution.x;

				colortex5Write = texelFetch(colortex5, tileFragCoord, 0);
			}
		#endif
	}
#endif
