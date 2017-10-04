flat varying vec3 shadowLightVector;
flat varying vec3 sunVector;
flat varying vec3 moonVector;
flat varying vec3 upVector;

#if STAGE == STAGE_VERTEX
uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

void calculateVectors() {
	shadowLightVector = normalize(shadowLightPosition);
	sunVector         = normalize(sunPosition);
	moonVector        = normalize(moonPosition);
	upVector          = normalize(upPosition);
}
#endif
