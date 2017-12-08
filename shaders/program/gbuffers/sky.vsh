#include "/settings.glsl"

//----------------------------------------------------------------------------//

uniform int isEyeInWater;

// Time
uniform int frameCounter;

// Viewport
uniform float viewWidth, viewHeight;

//----------------------------------------------------------------------------//

varying vec3 color;

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"

#include "/lib/misc/temporalAA.glsl"

#include "/lib/uniform/gbufferMatrices.glsl"

#include "/lib/vertex/projectVertex.vsh"

void main() {
	calculateGbufferMatrices();

	gl_Position.xyz = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
	gl_Position = projectVertex(gl_Position.xyz);

	color = gl_Color.rgb * gl_Color.a * 100.0;
	if (abs(length(gl_Vertex.xyz) - 100.0005) > 0.0004) color = vec3(0.0);
}
