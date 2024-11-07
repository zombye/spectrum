#if !defined INCLUDE_SPHERICAL_HARMONICS_CORE
#define INCLUDE_SPHERICAL_HARMONICS_CORE

// Calculates the SH basis coefficients for a specific direction
float sh_basis_order1(vec3 direction) {
	return sqrt(1.0 / (4.0 * pi));
}
float[4] sh_basis_order2(vec3 direction) {
	float basis_1 = sh_basis_order1(direction);
	return float[4](
		basis_1,
		sqrt(3.0 / (4.0 * pi)) * direction.y,
		sqrt(3.0 / (4.0 * pi)) * direction.z,
		sqrt(3.0 / (4.0 * pi)) * direction.x
	);
}
float[9] sh_basis_order3(vec3 direction) {
	float[4] basis_2 = sh_basis_order2(direction);
	return float[9](
		basis_2[0],
		basis_2[1],
		basis_2[2],
		basis_2[3],
		sqrt(15.0 / ( 4.0 * pi)) * (direction.x * direction.y),
		sqrt(15.0 / ( 4.0 * pi)) * (direction.y * direction.z),
		sqrt( 5.0 / ( 4.0 * pi)) * (3.0 * direction.z * direction.z - 1.0),
		sqrt(15.0 / ( 4.0 * pi)) * (direction.x * direction.z),
		sqrt(15.0 / (16.0 * pi)) * (direction.x * direction.x - direction.y * direction.y)
	);
}

// evaluates an SH-represented function for a specific direction
float sh_evaluate(float coefficient, vec3 direction) {
	return coefficient * sh_basis_order1(direction);
}
float sh_evaluate(float[4] coefficients, vec3 direction) {
	float[4] basis = sh_basis_order2(direction);
	float reconstructed = coefficients[0] * basis[0];
	for (int i = 1; i < 4; ++i) {
		reconstructed += coefficients[i] * basis[i];
	}
	return reconstructed;
}
float sh_evaluate(float[9] coefficients, vec3 direction) {
	float[9] basis = sh_basis_order3(direction);
	float reconstructed = coefficients[0] * basis[0];
	for (int i = 1; i < 4; ++i) {
		reconstructed += coefficients[i] * basis[i];
	}
	return reconstructed;
}

vec3 sh_evaluate(vec3 coefficient, vec3 direction) {
	return coefficient * sh_basis_order1(direction);
}
vec3 sh_evaluate(vec3[4] coefficients, vec3 direction) {
	float[4] basis = sh_basis_order2(direction);
	vec3 reconstructed = coefficients[0] * basis[0];
	for (int i = 1; i < 4; ++i) {
		reconstructed += coefficients[i] * basis[i];
	}
	return reconstructed;
}
vec3 sh_evaluate(vec3[9] coefficients, vec3 direction) {
	float[9] basis = sh_basis_order3(direction);
	vec3 reconstructed = coefficients[0] * basis[0];
	for (int i = 1; i < 4; ++i) {
		reconstructed += coefficients[i] * basis[i];
	}
	return reconstructed;
}

// directly scales the encoded function
// more formally, returns SH coefficients of g(x) where g(x) = c * f(x) from real number c and SH coefficients of f(x)
float sh_scale(float coefficient, float scale) {
	return scale * coefficient;
}
float[4] sh_scale(float[4] coefficients, float scale) {
	for (int i = 0; i < 4; ++i) {
		coefficients[i] *= scale;
	}
	return coefficients;
}
float[9] sh_scale(float[9] coefficients, float scale) {
	for (int i = 0; i < 9; ++i) {
		coefficients[i] *= scale;
	}
	return coefficients;
}

vec3 sh_scale(float coefficient, vec3 scale) {
	return scale * coefficient;
}
vec3[4] sh_scale(float[4] coefficients, vec3 scale) {
	vec3[4] scaled_coefficients;
	for (int i = 0; i < 4; ++i) {
		scaled_coefficients[i] = coefficients[i] * scale;
	}
	return scaled_coefficients;
}
vec3[9] sh_scale(float[9] coefficients, vec3 scale) {
	vec3[9] scaled_coefficients;
	for (int i = 0; i < 9; ++i) {
		scaled_coefficients[i] = coefficients[i] * scale;
	}
	return scaled_coefficients;
}

vec3 sh_scale(vec3 coefficient, float scale) {
	return scale * coefficient;
}
vec3[4] sh_scale(vec3[4] coefficients, float scale) {
	for (int i = 0; i < 4; ++i) {
		coefficients[i] *= scale;
	}
	return coefficients;
}
vec3[9] sh_scale(vec3[9] coefficients, float scale) {
	for (int i = 0; i < 9; ++i) {
		coefficients[i] *= scale;
	}
	return coefficients;
}

vec3 sh_scale(vec3 coefficient, vec3 scale) {
	return scale * coefficient;
}
vec3[4] sh_scale(vec3[4] coefficients, vec3 scale) {
	for (int i = 0; i < 4; ++i) {
		coefficients[i] *= scale;
	}
	return coefficients;
}
vec3[9] sh_scale(vec3[9] coefficients, vec3 scale) {
	for (int i = 0; i < 9; ++i) {
		coefficients[i] *= scale;
	}
	return coefficients;
}

// finds SH coefficients of c(x) where c(x) = a(x) + b(x) from SH coefficients of a(x) and b(x)
float sh_sum(float a, float b) {
	return a + b;
}
float[4] sh_sum(float[4] a, float[4] b) {
	float[4] c;
	for (int i = 0; i < 4; ++i) {
		c[i] = a[i] + b[i];
	}
	return c;
}
float[9] sh_sum(float[9] a, float[9] b) {
	float[9] c;
	for (int i = 0; i < 9; ++i) {
		c[i] = a[i] + b[i];
	}
	return c;
}

vec3 sh_sum(vec3 a, float b) {
	return a + b;
}
vec3[4] sh_sum(vec3[4] a, float[4] b) {
	vec3[4] c;
	for (int i = 0; i < 4; ++i) {
		c[i] = a[i] + b[i];
	}
	return c;
}
vec3[9] sh_sum(vec3[9] a, float[9] b) {
	vec3[9] c;
	for (int i = 0; i < 9; ++i) {
		c[i] = a[i] + b[i];
	}
	return c;
}

vec3 sh_sum(float a, vec3 b) {
	return a + b;
}
vec3[4] sh_sum(float[4] a, vec3[4] b) {
	vec3[4] c;
	for (int i = 0; i < 4; ++i) {
		c[i] = a[i] + b[i];
	}
	return c;
}
vec3[9] sh_sum(float[9] a, vec3[9] b) {
	vec3[9] c;
	for (int i = 0; i < 9; ++i) {
		c[i] = a[i] + b[i];
	}
	return c;
}

vec3 sh_sum(vec3 a, vec3 b) {
	return a + b;
}
vec3[4] sh_sum(vec3[4] a, vec3[4] b) {
	vec3[4] c;
	for (int i = 0; i < 4; ++i) {
		c[i] = a[i] + b[i];
	}
	return c;
}
vec3[9] sh_sum(vec3[9] a, vec3[9] b) {
	vec3[9] c;
	for (int i = 0; i < 9; ++i) {
		c[i] = a[i] + b[i];
	}
	return c;
}

// finds (band-limited to equal-order) SH coefficients of c(x) where c(x) = a(x) * b(x) from SH coefficients of a(x) and b(x)
// for bands >= 1, the product introduces higher-frequency components which are lost in this implementation, since it's limited to strictly the input bands
// if i'm not mistaken, an implementation with output order one less than the sum of input orders would be exact
float sh_product(float a, float b) {
	return sqrt(1.0 / (4.0 * pi)) * a * b;
}
float[4] sh_product(float[4] a, float[4] b) {
	return float[4](
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[1] + a[1] * b[0]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[2] + a[2] * b[0]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[3] + a[3] * b[0])
	);
}
float[9] sh_product(float[9] a, float[9] b) {
	return float[9](
		  sqrt( 1.0 / (4.0 * pi)) * ( a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4] + a[5] * b[5] + a[6] * b[6] + a[7] * b[7] + a[8] * b[8]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[1] + a[1] * b[0])
		+ sqrt( 1.0 / (20.0 * pi)) * (-a[1] * b[6] - a[6] * b[1])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[2] * b[5] + a[5] * b[2] + a[3] * b[4] + a[4] * b[3] - a[1] * b[8] - a[8] * b[1]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[2] + a[2] * b[0])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[1] * b[5] + a[5] * b[1] + a[3] * b[7] + a[7] * b[3])
		+ sqrt( 1.0 / ( 5.0 * pi)) * ( a[2] * b[6] + a[6] * b[2]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[3] + a[3] * b[0])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[1] * b[4] + a[4] * b[1] + a[2] * b[7] + a[7] * b[2] + a[3] * b[8] + a[8] * b[3])
		+ sqrt( 1.0 / (20.0 * pi)) * (-a[3] * b[6] - a[6] * b[3]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[4] + a[4] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[1] * b[3] + a[3] * b[1])
		+ sqrt( 5.0 / ( 49.0 * pi)) * (-a[4] * b[6] - a[6] * b[4])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[5] * b[7] + a[7] * b[5]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[5] + a[5] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[1] * b[2] + a[2] * b[1])
		+ sqrt( 5.0 / (196.0 * pi)) * ( a[5] * b[6] + a[6] * b[5])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[4] * b[7] + a[7] * b[4] - a[5] * b[8] - a[8] * b[5]),

		  sqrt(1.0 / (  4.0 * pi)) * ( a[0] * b[6] + a[6] * b[0])
		+ sqrt(1.0 / ( 20.0 * pi)) * (-a[1] * b[1] - a[3] * b[3])
		+ sqrt(1.0 / (  5.0 * pi)) * ( a[2] * b[2])
		+ sqrt(5.0 / (196.0 * pi)) * ( a[5] * b[5] + a[7] * b[7])
		+ sqrt(5.0 / ( 49.0 * pi)) * ( a[6] * b[6] - a[4] * b[4] - a[8] * b[8]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[7] + a[7] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[2] * b[3] + a[3] * b[2])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[4] * b[5] + a[5] * b[4] + a[7] * b[8] + a[8] * b[7])
		+ sqrt( 5.0 / (196.0 * pi)) * ( a[6] * b[7] + a[7] * b[6]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[8] + a[8] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[3] * b[3] - a[1] * b[1])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[7] * b[7] - a[5] * b[5])
		+ sqrt( 5.0 / ( 49.0 * pi)) * (-a[6] * b[8] - a[8] * b[6])
	);
}

vec3 sh_product(vec3 a, float b) {
	return sqrt(1.0 / (4.0 * pi)) * a * b;
}
vec3[4] sh_product(vec3[4] a, float[4] b) {
	return vec3[4](
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[1] + a[1] * b[0]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[2] + a[2] * b[0]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[3] + a[3] * b[0])
	);
}
vec3[9] sh_product(vec3[9] a, float[9] b) {
	return vec3[9](
		  sqrt( 1.0 / (4.0 * pi)) * ( a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4] + a[5] * b[5] + a[6] * b[6] + a[7] * b[7] + a[8] * b[8]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[1] + a[1] * b[0])
		+ sqrt( 1.0 / (20.0 * pi)) * (-a[1] * b[6] - a[6] * b[1])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[2] * b[5] + a[5] * b[2] + a[3] * b[4] + a[4] * b[3] - a[1] * b[8] - a[8] * b[1]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[2] + a[2] * b[0])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[1] * b[5] + a[5] * b[1] + a[3] * b[7] + a[7] * b[3])
		+ sqrt( 1.0 / ( 5.0 * pi)) * ( a[2] * b[6] + a[6] * b[2]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[3] + a[3] * b[0])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[1] * b[4] + a[4] * b[1] + a[2] * b[7] + a[7] * b[2] + a[3] * b[8] + a[8] * b[3])
		+ sqrt( 1.0 / (20.0 * pi)) * (-a[3] * b[6] - a[6] * b[3]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[4] + a[4] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[1] * b[3] + a[3] * b[1])
		+ sqrt( 5.0 / ( 49.0 * pi)) * (-a[4] * b[6] - a[6] * b[4])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[5] * b[7] + a[7] * b[5]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[5] + a[5] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[1] * b[2] + a[2] * b[1])
		+ sqrt( 5.0 / (196.0 * pi)) * ( a[5] * b[6] + a[6] * b[5])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[4] * b[7] + a[7] * b[4] - a[5] * b[8] - a[8] * b[5]),

		  sqrt(1.0 / (  4.0 * pi)) * ( a[0] * b[6] + a[6] * b[0])
		+ sqrt(1.0 / ( 20.0 * pi)) * (-a[1] * b[1] - a[3] * b[3])
		+ sqrt(1.0 / (  5.0 * pi)) * ( a[2] * b[2])
		+ sqrt(5.0 / (196.0 * pi)) * ( a[5] * b[5] + a[7] * b[7])
		+ sqrt(5.0 / ( 49.0 * pi)) * ( a[6] * b[6] - a[4] * b[4] - a[8] * b[8]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[7] + a[7] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[2] * b[3] + a[3] * b[2])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[4] * b[5] + a[5] * b[4] + a[7] * b[8] + a[8] * b[7])
		+ sqrt( 5.0 / (196.0 * pi)) * ( a[6] * b[7] + a[7] * b[6]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[8] + a[8] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[3] * b[3] - a[1] * b[1])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[7] * b[7] - a[5] * b[5])
		+ sqrt( 5.0 / ( 49.0 * pi)) * (-a[6] * b[8] - a[8] * b[6])
	);
}

vec3 sh_product(float a, vec3 b) {
	return sqrt(1.0 / (4.0 * pi)) * a * b;
}
vec3[4] sh_product(float[4] a, vec3[4] b) {
	return vec3[4](
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[1] + a[1] * b[0]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[2] + a[2] * b[0]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[3] + a[3] * b[0])
	);
}
vec3[9] sh_product(float[9] a, vec3[9] b) {
	return vec3[9](
		  sqrt( 1.0 / (4.0 * pi)) * ( a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4] + a[5] * b[5] + a[6] * b[6] + a[7] * b[7] + a[8] * b[8]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[1] + a[1] * b[0])
		+ sqrt( 1.0 / (20.0 * pi)) * (-a[1] * b[6] - a[6] * b[1])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[2] * b[5] + a[5] * b[2] + a[3] * b[4] + a[4] * b[3] - a[1] * b[8] - a[8] * b[1]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[2] + a[2] * b[0])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[1] * b[5] + a[5] * b[1] + a[3] * b[7] + a[7] * b[3])
		+ sqrt( 1.0 / ( 5.0 * pi)) * ( a[2] * b[6] + a[6] * b[2]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[3] + a[3] * b[0])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[1] * b[4] + a[4] * b[1] + a[2] * b[7] + a[7] * b[2] + a[3] * b[8] + a[8] * b[3])
		+ sqrt( 1.0 / (20.0 * pi)) * (-a[3] * b[6] - a[6] * b[3]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[4] + a[4] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[1] * b[3] + a[3] * b[1])
		+ sqrt( 5.0 / ( 49.0 * pi)) * (-a[4] * b[6] - a[6] * b[4])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[5] * b[7] + a[7] * b[5]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[5] + a[5] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[1] * b[2] + a[2] * b[1])
		+ sqrt( 5.0 / (196.0 * pi)) * ( a[5] * b[6] + a[6] * b[5])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[4] * b[7] + a[7] * b[4] - a[5] * b[8] - a[8] * b[5]),

		  sqrt(1.0 / (  4.0 * pi)) * ( a[0] * b[6] + a[6] * b[0])
		+ sqrt(1.0 / ( 20.0 * pi)) * (-a[1] * b[1] - a[3] * b[3])
		+ sqrt(1.0 / (  5.0 * pi)) * ( a[2] * b[2])
		+ sqrt(5.0 / (196.0 * pi)) * ( a[5] * b[5] + a[7] * b[7])
		+ sqrt(5.0 / ( 49.0 * pi)) * ( a[6] * b[6] - a[4] * b[4] - a[8] * b[8]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[7] + a[7] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[2] * b[3] + a[3] * b[2])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[4] * b[5] + a[5] * b[4] + a[7] * b[8] + a[8] * b[7])
		+ sqrt( 5.0 / (196.0 * pi)) * ( a[6] * b[7] + a[7] * b[6]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[8] + a[8] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[3] * b[3] - a[1] * b[1])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[7] * b[7] - a[5] * b[5])
		+ sqrt( 5.0 / ( 49.0 * pi)) * (-a[6] * b[8] - a[8] * b[6])
	);
}

vec3 sh_product(vec3 a, vec3 b) {
	return sqrt(1.0 / (4.0 * pi)) * a * b;
}
vec3[4] sh_product(vec3[4] a, vec3[4] b) {
	return vec3[4](
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[1] + a[1] * b[0]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[2] + a[2] * b[0]),
		sqrt(1.0 / (4.0 * pi)) * (a[0] * b[3] + a[3] * b[0])
	);
}
vec3[9] sh_product(vec3[9] a, vec3[9] b) {
	return vec3[9](
		  sqrt( 1.0 / (4.0 * pi)) * ( a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4] + a[5] * b[5] + a[6] * b[6] + a[7] * b[7] + a[8] * b[8]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[1] + a[1] * b[0])
		+ sqrt( 1.0 / (20.0 * pi)) * (-a[1] * b[6] - a[6] * b[1])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[2] * b[5] + a[5] * b[2] + a[3] * b[4] + a[4] * b[3] - a[1] * b[8] - a[8] * b[1]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[2] + a[2] * b[0])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[1] * b[5] + a[5] * b[1] + a[3] * b[7] + a[7] * b[3])
		+ sqrt( 1.0 / ( 5.0 * pi)) * ( a[2] * b[6] + a[6] * b[2]),

		  sqrt( 1.0 / ( 4.0 * pi)) * ( a[0] * b[3] + a[3] * b[0])
		+ sqrt( 3.0 / (20.0 * pi)) * ( a[1] * b[4] + a[4] * b[1] + a[2] * b[7] + a[7] * b[2] + a[3] * b[8] + a[8] * b[3])
		+ sqrt( 1.0 / (20.0 * pi)) * (-a[3] * b[6] - a[6] * b[3]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[4] + a[4] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[1] * b[3] + a[3] * b[1])
		+ sqrt( 5.0 / ( 49.0 * pi)) * (-a[4] * b[6] - a[6] * b[4])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[5] * b[7] + a[7] * b[5]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[5] + a[5] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[1] * b[2] + a[2] * b[1])
		+ sqrt( 5.0 / (196.0 * pi)) * ( a[5] * b[6] + a[6] * b[5])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[4] * b[7] + a[7] * b[4] - a[5] * b[8] - a[8] * b[5]),

		  sqrt(1.0 / (  4.0 * pi)) * ( a[0] * b[6] + a[6] * b[0])
		+ sqrt(1.0 / ( 20.0 * pi)) * (-a[1] * b[1] - a[3] * b[3])
		+ sqrt(1.0 / (  5.0 * pi)) * ( a[2] * b[2])
		+ sqrt(5.0 / (196.0 * pi)) * ( a[5] * b[5] + a[7] * b[7])
		+ sqrt(5.0 / ( 49.0 * pi)) * ( a[6] * b[6] - a[4] * b[4] - a[8] * b[8]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[7] + a[7] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[2] * b[3] + a[3] * b[2])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[4] * b[5] + a[5] * b[4] + a[7] * b[8] + a[8] * b[7])
		+ sqrt( 5.0 / (196.0 * pi)) * ( a[6] * b[7] + a[7] * b[6]),

		  sqrt( 1.0 / (  4.0 * pi)) * ( a[0] * b[8] + a[8] * b[0])
		+ sqrt( 3.0 / ( 20.0 * pi)) * ( a[3] * b[3] - a[1] * b[1])
		+ sqrt(15.0 / (196.0 * pi)) * ( a[7] * b[7] - a[5] * b[5])
		+ sqrt( 5.0 / ( 49.0 * pi)) * (-a[6] * b[8] - a[8] * b[6])
	);
}

// integrates an SH-represented function over all directions
float sh_integrate(float coefficient) {
	return sqrt(4.0 * pi) * coefficient;
}
float sh_integrate(float[4] coefficients) {
	return sqrt(4.0 * pi) * coefficients[0];
}
float sh_integrate(float[9] coefficients) {
	return sqrt(4.0 * pi) * coefficients[0];
}

vec3 sh_integrate(vec3 coefficient) {
	return sqrt(4.0 * pi) * coefficient;
}
vec3 sh_integrate(vec3[4] coefficients) {
	return sqrt(4.0 * pi) * coefficients[0];
}
vec3 sh_integrate(vec3[9] coefficients) {
	return sqrt(4.0 * pi) * coefficients[0];
}

// integrates the product of two SH-represented functions over all direcetions
float sh_integrate_product(float a, float b) {
	return a * b;
}
float sh_integrate_product(float[4] a, float[4] b) {
	float integral = a[0] * b[0];
	for (int i = 1; i < 4; ++i) {
		integral += a[i] * b[i];
	}
	return integral;
}
float sh_integrate_product(float[9] a, float[9] b) {
	float integral = a[0] * b[0];
	for (int i = 1; i < 9; ++i) {
		integral += a[i] * b[i];
	}
	return integral;
}

vec3 sh_integrate_product(vec3 a, float b) {
	return a * b;
}
vec3 sh_integrate_product(vec3[4] a, float[4] b) {
	vec3 integral = a[0] * b[0];
	for (int i = 1; i < 4; ++i) {
		integral += a[i] * b[i];
	}
	return integral;
}
vec3 sh_integrate_product(vec3[9] a, float[9] b) {
	vec3 integral = a[0] * b[0];
	for (int i = 1; i < 9; ++i) {
		integral += a[i] * b[i];
	}
	return integral;
}

vec3 sh_integrate_product(float a, vec3 b) {
	return a * b;
}
vec3 sh_integrate_product(float[4] a, vec3[4] b) {
	vec3 integral = a[0] * b[0];
	for (int i = 1; i < 4; ++i) {
		integral += a[i] * b[i];
	}
	return integral;
}
vec3 sh_integrate_product(float[9] a, vec3[9] b) {
	vec3 integral = a[0] * b[0];
	for (int i = 1; i < 9; ++i) {
		integral += a[i] * b[i];
	}
	return integral;
}

vec3 sh_integrate_product(vec3 a, vec3 b) {
	return a * b;
}
vec3 sh_integrate_product(vec3[4] a, vec3[4] b) {
	vec3 integral = a[0] * b[0];
	for (int i = 1; i < 4; ++i) {
		integral += a[i] * b[i];
	}
	return integral;
}
vec3 sh_integrate_product(vec3[9] a, vec3[9] b) {
	vec3 integral = a[0] * b[0];
	for (int i = 1; i < 9; ++i) {
		integral += a[i] * b[i];
	}
	return integral;
}

#endif
