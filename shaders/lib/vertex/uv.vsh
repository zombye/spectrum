vec2 getTextureCoordinates() {
	return mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st + gl_TextureMatrix[0][3].xy;
}
vec2 getEngineLightmap() {
	return (mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st + gl_TextureMatrix[1][3].xy) * 1.03125 - 0.03125;
}
