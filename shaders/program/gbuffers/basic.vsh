#include "/settings.glsl"

//----------------------------------------------------------------------------//

uniform int isEyeInWater;

// Time
uniform int frameCounter;

// Viewport
uniform float viewWidth, viewHeight;

//----------------------------------------------------------------------------//

varying vec4 color;

//----------------------------------------------------------------------------//

#include "/lib/misc/temporalAA.glsl"

#include "/lib/uniform/gbufferMatrices.glsl"

#include "/lib/vertex/projectVertex.vsh"

void main() {
	calculateGbufferMatrices();

	gl_Position.xyz = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
	gl_Position = projectVertex(gl_Position.xyz);

	color = gl_Color;
}
