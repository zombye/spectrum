flat varying float time_years;
flat varying float time_seasons;

flat varying vec4 seasonVector; // x = spring | y = summer | z = autumn | w = winter

#if STAGE == STAGE_VERTEX
void calculateTimeVariables() {
	const float yearDayCount   = 100.0;
	const float seasonsPerYear =   4.0;

	time_years   = worldDay / yearDayCount;
	time_seasons = worldDay / (yearDayCount / seasonsPerYear);

	seasonVector = vec4(equal(vec4(floor(mod(time_seasons, 4.0))), vec4(0.0, 1.0, 2.0, 3.0)));
}
#endif
