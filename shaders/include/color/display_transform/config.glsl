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

//#define DISPLAY_TRANSFORM_VISIBILITY_TOE // Use a different toe curve with better visibility, but slightly muted contrast. Can be very beneficial for gameplay.

// Use lookup tables to get colorfulness boundaries for much better performance.
#define DISPLAY_TRANSFORM_USE_COLORFULNESS_BOUNDARY_LUTS

#define DISPLAY_TRANSFORM_LUT_HUE_SIZE 512
#define DISPLAY_TRANSFORM_LUT_DISPLAY_BRIGHTNESS_SIZE 64
#define DISPLAY_TRANSFORM_LUT_INPUT_BRIGHTNESS_SIZE 128
#define DISPLAY_TRANSFORM_LUT_GRAYLINE_SIZE 128

#endif
