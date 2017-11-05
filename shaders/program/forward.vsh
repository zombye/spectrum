#include "/settings.glsl"

//----------------------------------------------------------------------------//

uniform int isEyeInWater;

// Positions
uniform vec3 cameraPosition;

// Time
uniform int   frameCounter;
uniform float frameTimeCounter;

// Viewport
uniform float viewWidth, viewHeight;

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

varying vec3 positionView;
varying vec3 positionScene;

//----------------------------------------------------------------------------//

#include "/lib/util/constants.glsl"

#include "/lib/misc/temporalAA.glsl"

#include "/lib/uniform/vectors.glsl"
#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"

#include "/lib/vertex/displacement.vsh"
#include "/lib/vertex/projectVertex.vsh"
#include "/lib/vertex/tbn.vsh"
#include "/lib/vertex/uv.vsh"

void main() {
	calculateVectors();
	calculateColors();
	calculateGbufferMatrices();
	calculateShadowMatrices();

	tint     = gl_Color;
	baseUV   = getTextureCoordinates();
	lightmap = getEngineLightmap();
	metadata = max(mc_Entity.xz, vec2(1.0, 0.0));

	positionScene = mat3(gbufferModelViewInverse) * (mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz) + gbufferModelViewInverse[3].xyz;
	positionScene = calculateDisplacement(positionScene);
	positionView  = mat3(gbufferModelView) * positionScene + gbufferModelView[3].xyz;
	gl_Position = projectVertex(positionView);

	tbn = calculateTBN();
}
