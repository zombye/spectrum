#define OFF   0
#define FAST  1
#define FANCY 2

//--// Miscellaneous

#define COMPOSITE0_SCALE 0.5 // [0.5 1.0]

//--// Lighting

#define DIRECTIONAL_SKY_DIFFUSE        OFF // [OFF FAST FANCY]
#define DIRECTIONAL_SKY_DIFFUSE_SAMPLES 25 // [20 25 30 35 40 45 50]

#define RSM
#define RSM_SAMPLES    12 // [10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50]
#define RSM_RADIUS    4.0 // [4.0 5.0 6.0 7.0 8.0]
#define RSM_INTENSITY 1.0 // [1.0 2.0 3.0 4.0 5.0]

#define FAKE_CREPUSCULAR_RAYS
#define SIMPLE_FOG

//#define VOLUMETRIC_FOG

//--// Optics

#define APERTURE_RADIUS          0.05 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09]
#define APERTURE_BLADE_COUNT     7    // [3 4 5 6 7 8 9 10 11]
#define APERTURE_BLADE_ROTATION 10    //

#define GLARE