flat varying mat4 modelViewShadow, projectionShadow;
flat varying mat4 modelViewShadowInverse, projectionShadowInverse;

#if STAGE == STAGE_VERTEX
uniform mat4 shadowModelView, shadowProjection;
uniform mat4 shadowModelViewInverse, shadowProjectionInverse;

void calculateShadowMatrices() {
	modelViewShadow         = shadowModelView;
	modelViewShadowInverse  = shadowModelViewInverse;
	projectionShadow        = shadowProjection;
	projectionShadowInverse = shadowProjectionInverse;

	projectionShadow[2].z         /= 6.0;
	projectionShadow[3].z         /= 6.0;
	projectionShadowInverse[2].zw *= 6.0;
}
#endif
