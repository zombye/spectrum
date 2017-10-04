#include "/settings.glsl"

const bool colortex2MipmapEnabled = true;
//----------------------------------------------------------------------------//

// Viewport
uniform float viewWidth, viewHeight;
uniform float aspectRatio;

// Samplers
uniform sampler2D colortex2;

//----------------------------------------------------------------------------//

varying vec2 screenCoord;

//----------------------------------------------------------------------------//

#include "/lib/util/clamping.glsl"
#include "/lib/util/math.glsl"

vec3 generateGlareTile(vec2 coord, const float lod) {
	if (floor(coord) != vec2(0.0)) return vec3(0.0);

	const float loopRadius = 5.0;
	const float lodScale = exp2(lod);

	vec3 tile = vec3(0.0);
	float totalWeight = 0.0;

	for (float i = -loopRadius; i <= loopRadius; i++) {
		for (float j = -loopRadius; j <= loopRadius; j++) {
			vec2 offset = vec2(i, j) / loopRadius;
			float weight = pow2(max0(1.0 - dot(offset, offset)));
			offset *= loopRadius * lodScale / vec2(viewWidth, viewHeight);
			
			tile += texture2DLod(colortex2, coord + offset, lod).rgb * weight;
			totalWeight += weight;
		}
	}

	return tile / totalWeight;
}

void main() {
	#ifdef GLARE
	vec2 px = 1.0 / vec2(viewWidth, viewHeight);

	vec3
	glare  = generateGlareTile(screenCoord * exp2(1), 1);
	glare += generateGlareTile((screenCoord - (vec2(0,2) * px + vec2(0.0000, 0.50000))) * exp2(2), 2);
	glare += generateGlareTile((screenCoord - (vec2(2,2) * px + vec2(0.2500, 0.50000))) * exp2(3), 3);
	glare += generateGlareTile((screenCoord - (vec2(2,4) * px + vec2(0.2500, 0.62500))) * exp2(4), 4);
	glare += generateGlareTile((screenCoord - (vec2(4,4) * px + vec2(0.3125, 0.62500))) * exp2(5), 5);
	glare += generateGlareTile((screenCoord - (vec2(4,6) * px + vec2(0.3125, 0.65625))) * exp2(6), 6);

/* DRAWBUFFERS:3 */

	gl_FragData[0] = vec4(glare, 1.0);
	#endif
}
