#include "/settings.glsl"

//----------------------------------------------------------------------------//

varying vec4 color;

//----------------------------------------------------------------------------//

#include "/lib/vertex/projectVertex.vsh"

void main() {
	gl_Position.xyz = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
	gl_Position = projectVertex(gl_Position.xyz);

	color = gl_Color;
}
