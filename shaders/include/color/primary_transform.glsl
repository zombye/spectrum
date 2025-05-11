#if !defined INCLUDE_COLOR_PRIMARY_TRANSFORM
#define INCLUDE_COLOR_PRIMARY_TRANSFORM

/*
This file contains conversions between various sets of primaries.
Each conversion can have 2 versions:
* The first treats the color as actual light of that color.
* The second treats it as light scattered or transmitted by a surface or media.
  The white point is then relative to the illumination. These are suffixed with
  "relative" to distinguish them.

For example, the color of a light source would use the first, while the albedo
of a surface would use the second.

The second version is suffixed with "Relative"
*/

// BT709/sRGB
//   x      y
// W 0.3127 0.329
// R 0.64   0.33
// G 0.3    0.6
// B 0.15   0.06
const mat3 XYZ_from_BT709 = mat3(
	 0.4123908,  0.21263901, 0.01933082,
	 0.35758434, 0.71516868, 0.11919478,
	 0.18048079, 0.07219232, 0.95053215
);
const mat3 BT709_from_XYZ = mat3(
	 3.24096994,-0.96924364, 0.05563008,
	-1.53738318, 1.8759675, -0.20397696,
	-0.49861076, 0.04155506, 1.05697151
);

const mat3 XYZ_from_BT709_relative = mat3(
	 0.43388735, 0.21263901, 0.01775004,
	 0.37622401, 0.71516868, 0.10944762,
	 0.18988865, 0.07219232, 0.87280234
);
const mat3 BT709_from_XYZ_relative = mat3(
	 3.08039909,-0.92122336, 0.05287394,
	-1.53738318, 1.8759675, -0.20397696,
	-0.54301591, 0.04525586, 1.15110302
);

// BT2020
//   x      y
// W 0.3127 0.329
// R 0.708  0.292
// G 0.17   0.797
// B 0.131  0.046
const mat3 XYZ_from_BT2020 = mat3(
	 6.36958048e-01, 2.62700212e-01, 4.99410657e-17,
	 1.44616904e-01, 6.77998072e-01, 2.80726930e-02,
	 1.68880975e-01, 5.93017165e-02, 1.06098506e+00
);
const mat3 BT2020_from_XYZ = mat3(
	 1.71665119,-0.66668435, 0.01763986,
	-0.35567078, 1.61648124,-0.04277061,
	-0.25336628, 0.01576855, 0.94210312
);

const mat3 XYZ_from_BT2020_relative = mat3(
	 6.70160531e-01, 2.62700212e-01, 4.58571327e-17,
	 1.52155297e-01, 6.77998072e-01, 2.57770472e-02,
	 1.77684173e-01, 5.93017165e-02, 9.74222953e-01
);
const mat3 BT2020_from_XYZ_relative = mat3(
	 1.6316013, -0.63365409, 0.01676591,
	-0.35567078, 1.61648124,-0.04277061,
	-0.27593051, 0.01717286, 1.02600471
);


#define PRIMARIES_BT709 0
#define PRIMARIES_BT2020 1
#define RENDER_PRIMARIES PRIMARIES_BT709

#if RENDER_PRIMARIES == PRIMARIES_BT2020
	const mat3 render_from_XYZ = BT2020_from_XYZ;
	const mat3 XYZ_from_render = XYZ_from_BT2020;
	const mat3 render_from_XYZ_relative = BT2020_from_XYZ_relative;
	const mat3 XYZ_from_render_relative = XYZ_from_BT2020_relative;
#else // RENDER_PRIMARIES == PRIMARIES_BT709
	const mat3 render_from_XYZ = BT709_from_XYZ;
	const mat3 XYZ_from_render = XYZ_from_BT709;
	const mat3 render_from_XYZ_relative = BT709_from_XYZ_relative;
	const mat3 XYZ_from_render_relative = XYZ_from_BT709_relative;
#endif

#if RENDER_PRIMARIES != PRIMARIES_BT709
	const mat3 render_from_BT709 = render_from_XYZ * XYZ_from_BT709;
	const mat3 render_from_BT709_relative = render_from_XYZ_relative * XYZ_from_BT709_relative;

	const mat3 BT709_from_render = BT709_from_XYZ * XYZ_from_render;
	const mat3 BT709_from_render_relative = BT709_from_XYZ_relative * XYZ_from_render_relative;
#else
	const mat3 render_from_BT709 = mat3(1.0);
	const mat3 render_from_BT709_relative = mat3(1.0);

	const mat3 BT709_from_render = mat3(1.0);
	const mat3 BT709_from_render_relative = mat3(1.0);
#endif

#endif
