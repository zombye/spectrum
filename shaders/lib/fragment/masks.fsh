struct masks {
	float id;

	bool sky;
	bool opaque;
	bool transparent;

	bool plant;
};

masks calculateMasks(float id) {
	masks mask;

	mask.id = id;

	mask.sky         = id == 0;
	mask.opaque      = id != 0;
	mask.transparent = false; // TODO
	
	mask.plant = id == 18 || id == 31;

	return mask;
}
