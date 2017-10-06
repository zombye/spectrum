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

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"

#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"

#include "/lib/misc/shadowDistortion.glsl"

#include "/lib/vertex/displacement.vsh"
#include "/lib/vertex/projectVertex.vsh"
#include "/lib/vertex/uv.vsh"

//--//

void main() {
	calculateGbufferMatrices();
	calculateShadowMatrices();

	tint     = gl_Color;
	baseUV   = getTextureCoordinates();
	lightmap = getEngineLightmap();
	normal   = mat3(modelViewShadow) * gl_Normal;

	gl_Position.xyz = mat3(modelViewShadowInverse) * (mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz) + modelViewShadowInverse[3].xyz;
	gl_Position.xyz = calculateDisplacement(gl_Position.xyz);
	gl_Position.xyz = mat3(modelViewShadow) * gl_Position.xyz + modelViewShadow[3].xyz;
	gl_Position     = projectVertex(gl_Position.xyz);
}
