//--// Global

#define PLANET_RADIUS 6731e3

//--// Miscellaneous

#define EXPOSURE 0.15

#define TEMPORAL_AA

//#define WATER_TEXTURE

//--// Lighting

const int shadowMapResolution = 2048; // [1024 2048 4096 8192]
#define SHADOW_FILTER_TYPE 1 // [0 1 2 3]
#define SHADOW_COLORED

/*
	To match water caustics more closely SEUS v11, use the following settings
	samples      = 9
	radius       = 0.2
	defocus      = 1.5
	result power = 2.0
*/
#define CAUSTICS_SAMPLES        9   // [0 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50]
#define CAUSTICS_RADIUS         0.3 // [0.2 0.3 0.4]
#define CAUSTICS_DEFOCUS        1.0 // [1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define CAUSTICS_RESULT_POWER   1.0 // [1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define RSM_SAMPLES    4   // [0 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25]
#define RSM_RADIUS     8   // [5 6 7 8 9 10 11 12 13 14 15 16]
#define RSM_BRIGHTNESS 1.0 // [1.0 2.0 3.0 4.0 5.0]

//--// Optics

#define APERTURE_RADIUS          0.05 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09]
#define APERTURE_BLADE_COUNT     7    // [3 4 5 6 7 8 9 10 11]
#define APERTURE_BLADE_ROTATION 10    //

#define BLOOM_AMOUNT 0.05 // [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15]
