#if !defined INCLUDE_COLOR_DISPLAY_TRANSFORM_CONFIG
#define INCLUDE_COLOR_DISPLAY_TRANSFORM_CONFIG

// Ajusts colors to account for the difference between input brightness & display brightness.
// This particularly affects colorfulness.
// Recommended as long as you have an estimate of both input & display brightness.
// NOTE: Resource packs are not designed with this in mind.
// Non-PBR resource packs expect close to a 1:1 conversion from texture hue/saturation to screen hue/saturation in daylight.
// As such, consider desaturating their textures slightly to compensate.
#define DISPLAY_TRANSFORM_ABSOLUTE_LUMINANCE_EFFECTS
// Colorfulness multiplier when not using absolute luminance effects.
// This is mainly to keep daytime colorfulness comparable in both modes.
#define DISPLAY_TRANSFORM_RELATIVE_MODE_COLORFULNESS_SCALE 1.8

#define DISPLAY_TRANSFORM_COLORFULNESS_PERCENT 100 // [0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200]
#define DISPLAY_TRANSFORM_COLORFULNESS_SCALE (0.01 * float(DISPLAY_TRANSFORM_COLORFULNESS_PERCENT))
#define DISPLAY_TRANSFORM_CONTRAST_MODIFIER 0.0 // [-1.0 -0.9 -0.8 -0.6 -0.5 -0.4 -0.3 -0.2 -0.1 0.0 +0.1 +0.2 +0.3 +0.4 +0.5 +0.6 +0.7 +0.8 +0.9 +1.0]

#define DISPLAY_TRANSFORM_BRIGHTNESS_COMPRESSION_PERCENT 50 // Controls how brightness is compressed downwards into the displayable range. Higher values result in less contrast overall due to more compression, but is better able to represent contrast in highlights. [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100]
#define DISPLAY_TRANSFORM_BRIGHTNESS_COMPRESSION (0.01 * float(DISPLAY_TRANSFORM_BRIGHTNESS_COMPRESSION_PERCENT))

//#define DISPLAY_TRANSFORM_VISIBILITY_TOE // Use a different toe curve with better visibility, but slightly muted contrast. Can be very beneficial for gameplay.

// Use lookup tables to get colorfulness boundaries for much better performance.
#define DISPLAY_TRANSFORM_USE_COLORFULNESS_BOUNDARY_LUTS

#define DISPLAY_TRANSFORM_LUT_HUE_SIZE 512
#define DISPLAY_TRANSFORM_LUT_DISPLAY_BRIGHTNESS_SIZE 64
#define DISPLAY_TRANSFORM_LUT_INPUT_BRIGHTNESS_SIZE 128
#define DISPLAY_TRANSFORM_LUT_GRAYLINE_SIZE 128

#endif
