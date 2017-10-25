flat varying mat4 projectionShadow, projectionShadowInverse;

uniform mat4 shadowModelView, shadowModelViewInverse;

#if STAGE == STAGE_VERTEX
uniform mat4 shadowProjection, shadowProjectionInverse;

void calculateShadowMatrices() {
	projectionShadow        = shadowProjection;
	projectionShadowInverse = shadowProjectionInverse;

	projectionShadow[2].z         /= 6.0;
	projectionShadow[3].z         /= 6.0;
	projectionShadowInverse[2].zw *= 6.0;
}
#endif
