bool PointInTriangle(vec2 p, vec2 v0, vec2 v1, vec2 v2) {
	vec2 n0 = vec2(v0.y - v1.y, v1.x - v0.x);
	vec2 n1 = vec2(v1.y - v2.y, v2.x - v1.x);
	vec2 n2 = vec2(v2.y - v0.y, v0.x - v2.x);

	float d0 = dot(p - v0, n0) * dot(v2 - v0, n0);
	float d1 = dot(p - v1, n1) * dot(v0 - v1, n1);
	float d2 = dot(p - v2, n2) * dot(v1 - v2, n2);

	return (d0 >= 0.0) && (d1 >= 0.0) && (d2 >= 0.0);
}
float TriangleArea(vec2 v0, vec2 v1, vec2 v2) {
	vec2 x = v1 - v0, y = v2 - v0;
	return 0.5 * abs(x.x * y.y - y.x * x.y);
}

bool PointInQuad(
	vec2 p,
	vec2 v00, vec2 v10,
	vec2 v01, vec2 v11
) {
	// v00--v10
	//  |    |
	// v01--v11

	// this is simple and works but probably inefficient
	return PointInTriangle(p, v00, v10, v01) != PointInTriangle(p, v11, v10, v01);
}
float QuadArea(vec2 v00, vec2 v10, vec2 v01, vec2 v11) {
	// v00--v10
	//  |    |
	// v01--v11

	vec2 xv0 = v10 - v00;
	vec2 xv1 = v11 - v01;
	vec2 yv0 = v01 - v00;
	vec2 yv1 = v11 - v10;

	// check if crossing and calculate area for that case if necessary
	float xdiv = xv0.x * xv1.y - xv0.y * xv1.x;
	float xt0 = (yv0.x * xv1.y - yv0.y * xv1.x) / xdiv;
	float xt1 = (yv0.x * xv0.y - yv0.y * xv0.x) / xdiv;
	if (Clamp01(xt0) == xt0 && Clamp01(xt1) == xt1) {
		vec2 vc = v00 + xt0 * xv0;
		return TriangleArea(vc, v00, v01) + TriangleArea(vc, v10, v11);
	}

	float ydiv = yv0.x * yv1.y - yv0.y * yv1.x;
	float yt0 = (xv0.x * yv1.y - xv0.y * yv1.x) / ydiv;
	float yt1 = (xv0.x * yv0.y - xv0.y * yv0.x) / ydiv;
	if (Clamp01(yt0) == yt0 && Clamp01(yt1) == yt1) {
		vec2 vc = v00 + yt0 * yv0;
		return TriangleArea(vc, v00, v10) + TriangleArea(vc, v01, v11);
	}

	// neither edge pair was crossing
	vec2 x = v11 - v00, y = v10 - v01;
	return 0.5 * abs(x.x * y.y - y.x * x.y);
}
