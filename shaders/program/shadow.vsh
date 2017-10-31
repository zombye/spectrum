#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Positions
uniform vec3 cameraPosition;

// Time
uniform float frameTimeCounter;

//----------------------------------------------------------------------------//

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

//----------------------------------------------------------------------------//

varying vec4 tint;
varying vec2 baseUV;
vec2 lightmap;

varying vec3 normal;

varying vec4 metadata;

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"
#include "/lib/util/math.glsl"

#include "/lib/uniform/shadowMatrices.glsl"

#include "/lib/misc/shadowDistortion.glsl"

float calculateAntiAcneOffset(vec3 normal, float distortFactor) {
	#if SHADOW_FILTER_TYPE == 1
	const float sampleDiameter = 2.0;
	#else
	const float sampleDiameter = 1.0;
	#endif

	normal.xy = abs(normalize(normal.xy));
	normal    = clamp(normal, 0.0, 1.0);

	float projectionScale = projectionShadow[2].z * 2.0 / projectionShadow[0].x;

	float baseOffset = sampleDiameter * projectionScale / (shadowMapResolution * distortFactor * distortFactor);
	float normalScaling = (normal.x + normal.y) * tanacos(normal.z);

	return baseOffset * min(normalScaling, 9.0) - 0.0001 * distortFactor;
}

#include "/lib/vertex/displacement.vsh"
#include "/lib/vertex/projectVertex.vsh"
#include "/lib/vertex/uv.vsh"

//--//

void main() {
	calculateShadowMatrices();

	tint     = gl_Color;
	baseUV   = getTextureCoordinates();
	lightmap = getEngineLightmap();
	normal   = gl_NormalMatrix * gl_Normal;
	metadata = mc_Entity;

	gl_Position.xyz = mat3(shadowModelViewInverse) * (mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz) + shadowModelViewInverse[3].xyz;
	gl_Position.xyz = calculateDisplacement(gl_Position.xyz);
	gl_Position.xyz = mat3(shadowModelView) * gl_Position.xyz + shadowModelView[3].xyz;
	gl_Position     = projectVertex(gl_Position.xyz);

	normal.z = abs(normal.z);
	if (metadata.x > 7.9 && metadata.x < 9.1) normal.z = -normal.z;
}
