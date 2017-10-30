struct masks {
	float id;

	bool sky;
	bool opaque;

	bool plant;
	bool water;
};

masks calculateMasks(float id) {
	masks mask;

	mask.id = id;

	mask.sky    = id == 0;
	mask.opaque = id != 0;

	mask.plant = id == 18 || id == 31 || id == 175;
	mask.water = id > 7.9 && id < 9.1;

	return mask;
}
masks calculateMasks(float backID, float frontID) {
	masks mask;

	mask.id = backID;

	mask.sky    = backID == 0;
	mask.opaque = backID != 0;

	mask.plant = backID == 18 || backID == 31 || backID == 175;
	mask.water = frontID > 7.9 && frontID < 9.1;

	return mask;
}
