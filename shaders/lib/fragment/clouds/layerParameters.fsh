struct cloudLayerParameters {
	float altitudeMin;
	float altitudeMax;
	float coverage;
	float coeff; // TODO: Name this better

	// Density function parameters - Shape
	int octaves; // More octaves gives more details
	float gain; // Higher gain makes detaile more noticable
	int distortOctaves;
	float distortAmplitude;
	int distortOctaves2;
	float distortAmplitude2;

	float frequency;
	float frequency2;

	// Multiple scattering approximation
	int   msa_octaves; // 2 is recommended
	float msa_a; // msa_a <= msa_b
	float msa_b; // when summed over all octaves <= 1
	float msa_c; // currently unused

	// Samples
	int baseSamples;
	float maxSamplesScale;
	int visSamplesShadow;
	int visSamplesSky;
	int visSamplesBounced;

	// Ranges
	float visRangeShadow;
	float visRangeSky;
	float visRangeBounced;
};

cloudLayerParameters[2] clouds_layers = cloudLayerParameters[2]( // Must be in order of top layer to bottom layer!
	cloudLayerParameters(
		10000.0,
		12000.0,
		0.37,
		0.001,

		6,
		0.5,
		2,
		0.7,
		4,
		3.3,

		13.9,
		15.1,

		2,
		0.618,
		0.618,
		0.5,

		4,
		1.0,
		0,
		0,
		0,

		750.0,
		375.0,
		375.0
	),
	cloudLayerParameters(
		500.0,
		2000.0,
		0.33,
		0.05,

		5,
		0.4,
		5,
		1.5,
		5,
		1.2,

		48.0,
		25.0,

		2,
		0.618,
		0.618,
		0.5,

		7,
		7.0,
		1,
		0,
		0,

		750.0,
		375.0,
		375.0
	)
);
