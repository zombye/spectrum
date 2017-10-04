#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Positions
uniform vec3 cameraPosition;

// Time
uniform float frameTimeCounter;

//----------------------------------------------------------------------------//

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

//----------------------------------------------------------------------------//

varying vec4 tint;

varying vec2 baseUV;
varying vec2 lightmap;

varying mat3 tbn;

varying vec2 metadata;

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"

#include "/lib/uniform/gbufferMatrices.glsl"

#include "/lib/vertex/displacement.vsh"
#include "/lib/vertex/projectVertex.vsh"
#include "/lib/vertex/uv.vsh"
mat3 calculateTBN() {
	vec3 tangent = normalize(at_tangent.xyz / at_tangent.w);
	vec3 normal  = normalize(gl_Normal);
	return mat3(modelView) * mat3(tangent, cross(tangent, normal), normal);
}

void main() {
	calculateGbufferMatrices();

	tint     = gl_Color;
	baseUV   = getTextureCoordinates();
	lightmap = getEngineLightmap();
	metadata = max(mc_Entity.xz, vec2(1.0, 0.0));

	gl_Position.xyz = mat3(modelViewInverse) * (mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz) + modelViewInverse[3].xyz;
	gl_Position.xyz = calculateDisplacement(gl_Position.xyz);
	gl_Position.xyz = mat3(modelView) * gl_Position.xyz + modelView[3].xyz;
	gl_Position = projectVertex(gl_Position.xyz);

	tbn = calculateTBN();
}
