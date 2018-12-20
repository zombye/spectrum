#if !defined INCLUDE_SHARED_SKYPROJECTION
#define INCLUDE_SHARED_SKYPROJECTION

/*
vec2 ProjectSky(vec3 dir) {
	vec2 lonlat = vec2(atan(-dir.x, -dir.z), acos(dir.y));
	vec2 coord = vec2(lonlat.x / tau + 0.5, lonlat.y / pi);
	return coord * (exp2(-SKY_IMAGE_LOD) - viewPixelSize) + viewPixelSize * 0.5;
}
vec3 UnprojectSky(vec2 coord) {
	coord = (coord - viewPixelSize * 0.5) / (exp2(-SKY_IMAGE_LOD) - viewPixelSize);
	coord *= vec2(tau, pi);
	return vec3(SinCos(coord.x) * sin(coord.y), cos(coord.y)).xzy;
}
//*/
//*
vec2 ProjectSky(vec3 dir, float lod) {
	float tileSize       = min(floor(viewResolution.x * 0.5) / 1.5, floor(viewResolution.y * 0.5)) * exp2(-lod);
	float tileSizeDivide = (0.5 * tileSize) - 1.5;

	vec2 coord;
	if (abs(dir.x) > abs(dir.y) && abs(dir.x) > abs(dir.z)) {
		dir /= abs(dir.x);
		coord.x = dir.y * tileSizeDivide + tileSize * 0.5;
		coord.y = dir.z * tileSizeDivide + tileSize * (dir.x < 0.0 ? 0.5 : 1.5);
	} else if (abs(dir.y) > abs(dir.x) && abs(dir.y) > abs(dir.z)) {
		dir /= abs(dir.y);
		coord.x = dir.x * tileSizeDivide + tileSize * 1.5;
		coord.y = dir.z * tileSizeDivide + tileSize * (dir.y < 0.0 ? 0.5 : 1.5);
	} else {
		dir /= abs(dir.z);
		coord.x = dir.x * tileSizeDivide + tileSize * 2.5;
		coord.y = dir.y * tileSizeDivide + tileSize * (dir.z < 0.0 ? 0.5 : 1.5);
	}

	return coord / viewResolution;
}
vec3 UnprojectSky(vec2 coord, float lod) {
	coord *= viewResolution;
	float tileSize       = min(floor(viewResolution.x * 0.5) / 1.5, floor(viewResolution.y * 0.5)) * exp2(-lod);
	float tileSizeDivide = (0.5 * tileSize) - 1.5;

	vec3 direction = vec3(0.0);

	if (coord.x < tileSize) {
		direction.x =  coord.y < tileSize ? -1 : 1;
		direction.y = (coord.x - tileSize * 0.5) / tileSizeDivide;
		direction.z = (coord.y - tileSize * (coord.y < tileSize ? 0.5 : 1.5)) / tileSizeDivide;
	} else if (coord.x < 2.0 * tileSize) {
		direction.x = (coord.x - tileSize * 1.5) / tileSizeDivide;
		direction.y =  coord.y < tileSize ? -1 : 1;
		direction.z = (coord.y - tileSize * (coord.y < tileSize ? 0.5 : 1.5)) / tileSizeDivide;
	} else {
		direction.x = (coord.x - tileSize * 2.5) / tileSizeDivide;
		direction.y = (coord.y - tileSize * (coord.y < tileSize ? 0.5 : 1.5)) / tileSizeDivide;
		direction.z =  coord.y < tileSize ? -1 : 1;
	}

	return normalize(direction);
}
//*/

vec2 ProjectSky(vec3 dir) {
	return ProjectSky(dir, SKY_IMAGE_LOD);
}
vec3 UnprojectSky(vec2 coord) {
	return UnprojectSky(coord, SKY_IMAGE_LOD);
}

#endif
