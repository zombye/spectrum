float CalculateFocalLength(float sensorHeight, float rcpTanHalfFov) {
	/*\
	 * Projection matrix X/Y mult from FOV on X/Y is:
	 * proj = 1 / tan(fov / 2)
	 *
	 * Therefore, FOV from the projection matrix is:
	 * fov = 2 * atan(1 / proj)
	 *
	 * FOV from focal length and sensor size is:
	 * fov = 2 * atan(sensor / (2 * focal));
	 *
	 * Therefore, focal length from FOV and sensor height is:
	 * focal = sensor / (2 * tan(fov / 2))
	 *
	 * From this, focal length from the projection matrix and sensor size after combining and simplifying the above is:
	 * focal = sensor * proj / 2
	\*/

	return 0.5 * sensorHeight * rcpTanHalfFov;
}
float CalculateApertureRadius(float focalLength, float fStop) {
	/*\
	 * The f-stop/f-number is defined as:
	 * `N = ƒ/D`, with f being the focal length and D being the aperture diameter
	 *
	 * Therefore, the aperture diameter can be found as:
	 * D = ƒ/N
	\*/

	return focalLength / fStop;
}

float CalculateCircleOfConfusion(float depth, float focus, float apertureRadius, float focalLength) {
	return apertureRadius * focalLength * abs(depth - focus) / (depth * abs(focus - focalLength));
}

#if DOF == DOF_SIMPLE
	//--// Filter constants //------------------------------------------------//

	/********************************************************************/
	/********************************************************************/
	/*         Generated Filter by CircularDofFilterGenerator tool      */
	/*     Copyright (c)     Kleber A Garcia  (kecho_garcia@hotmail.com)*/
	/*       https://github.com/kecho/CircularDofFilterGenerator        */
	/********************************************************************/
	/********************************************************************/
	/**
	 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
	**/
	const int KERNEL_RADIUS = 8;
	const int KERNEL_COUNT = 17;
	const vec4 Kernel0BracketsRealXY_ImZW = vec4(-0.038708,0.943062,-0.025574,0.660892);
	const vec2 Kernel0Weights_RealX_ImY = vec2(0.411259,-0.548794);
	const vec4 Kernel0_RealX_ImY_RealZ_ImW[] = vec4[](
	        vec4(/*XY: Non Bracketed*/0.014096,-0.022658,/*Bracketed WZ:*/0.055991,0.004413),
	        vec4(/*XY: Non Bracketed*/-0.020612,-0.025574,/*Bracketed WZ:*/0.019188,0.000000),
	        vec4(/*XY: Non Bracketed*/-0.038708,0.006957,/*Bracketed WZ:*/0.000000,0.049223),
	        vec4(/*XY: Non Bracketed*/-0.021449,0.040468,/*Bracketed WZ:*/0.018301,0.099929),
	        vec4(/*XY: Non Bracketed*/0.013015,0.050223,/*Bracketed WZ:*/0.054845,0.114689),
	        vec4(/*XY: Non Bracketed*/0.042178,0.038585,/*Bracketed WZ:*/0.085769,0.097080),
	        vec4(/*XY: Non Bracketed*/0.057972,0.019812,/*Bracketed WZ:*/0.102517,0.068674),
	        vec4(/*XY: Non Bracketed*/0.063647,0.005252,/*Bracketed WZ:*/0.108535,0.046643),
	        vec4(/*XY: Non Bracketed*/0.064754,0.000000,/*Bracketed WZ:*/0.109709,0.038697),
	        vec4(/*XY: Non Bracketed*/0.063647,0.005252,/*Bracketed WZ:*/0.108535,0.046643),
	        vec4(/*XY: Non Bracketed*/0.057972,0.019812,/*Bracketed WZ:*/0.102517,0.068674),
	        vec4(/*XY: Non Bracketed*/0.042178,0.038585,/*Bracketed WZ:*/0.085769,0.097080),
	        vec4(/*XY: Non Bracketed*/0.013015,0.050223,/*Bracketed WZ:*/0.054845,0.114689),
	        vec4(/*XY: Non Bracketed*/-0.021449,0.040468,/*Bracketed WZ:*/0.018301,0.099929),
	        vec4(/*XY: Non Bracketed*/-0.038708,0.006957,/*Bracketed WZ:*/0.000000,0.049223),
	        vec4(/*XY: Non Bracketed*/-0.020612,-0.025574,/*Bracketed WZ:*/0.019188,0.000000),
	        vec4(/*XY: Non Bracketed*/0.014096,-0.022658,/*Bracketed WZ:*/0.055991,0.004413)
	);
	const vec4 Kernel1BracketsRealXY_ImZW = vec4(0.000115,0.559524,0.000000,0.178226);
	const vec2 Kernel1Weights_RealX_ImY = vec2(0.513282,4.561110);
	const vec4 Kernel1_RealX_ImY_RealZ_ImW[] = vec4[](
	        vec4(/*XY: Non Bracketed*/0.000115,0.009116,/*Bracketed WZ:*/0.000000,0.051147),
	        vec4(/*XY: Non Bracketed*/0.005324,0.013416,/*Bracketed WZ:*/0.009311,0.075276),
	        vec4(/*XY: Non Bracketed*/0.013753,0.016519,/*Bracketed WZ:*/0.024376,0.092685),
	        vec4(/*XY: Non Bracketed*/0.024700,0.017215,/*Bracketed WZ:*/0.043940,0.096591),
	        vec4(/*XY: Non Bracketed*/0.036693,0.015064,/*Bracketed WZ:*/0.065375,0.084521),
	        vec4(/*XY: Non Bracketed*/0.047976,0.010684,/*Bracketed WZ:*/0.085539,0.059948),
	        vec4(/*XY: Non Bracketed*/0.057015,0.005570,/*Bracketed WZ:*/0.101695,0.031254),
	        vec4(/*XY: Non Bracketed*/0.062782,0.001529,/*Bracketed WZ:*/0.112002,0.008578),
	        vec4(/*XY: Non Bracketed*/0.064754,0.000000,/*Bracketed WZ:*/0.115526,0.000000),
	        vec4(/*XY: Non Bracketed*/0.062782,0.001529,/*Bracketed WZ:*/0.112002,0.008578),
	        vec4(/*XY: Non Bracketed*/0.057015,0.005570,/*Bracketed WZ:*/0.101695,0.031254),
	        vec4(/*XY: Non Bracketed*/0.047976,0.010684,/*Bracketed WZ:*/0.085539,0.059948),
	        vec4(/*XY: Non Bracketed*/0.036693,0.015064,/*Bracketed WZ:*/0.065375,0.084521),
	        vec4(/*XY: Non Bracketed*/0.024700,0.017215,/*Bracketed WZ:*/0.043940,0.096591),
	        vec4(/*XY: Non Bracketed*/0.013753,0.016519,/*Bracketed WZ:*/0.024376,0.092685),
	        vec4(/*XY: Non Bracketed*/0.005324,0.013416,/*Bracketed WZ:*/0.009311,0.075276),
	        vec4(/*XY: Non Bracketed*/0.000115,0.009116,/*Bracketed WZ:*/0.000000,0.051147)
	);

	//------------------------------------------------------------------------//

	vec4 GetC0C1(int x) {
		vec2 c0 = Kernel0_RealX_ImY_RealZ_ImW[x + KERNEL_RADIUS].xy;
		vec2 c1 = Kernel1_RealX_ImY_RealZ_ImW[x + KERNEL_RADIUS].xy;
		return vec4(c0, c1);
	}
	vec4 GetC0C1(float x) {
		float xSq = x * x;

		vec2 c0, c1;

		{ // First component
			const float a = -0.8865280000, b = 5.2689090000, c = -0.7406246191, d = -0.3704940302;
			c0 = exp(a * xSq) * (vec2(c, d) * cos(b * xSq) + vec2(-d, c) * sin(b * xSq));
		}

		{ // Second component
			const float a = -1.9605180000, b = 1.5582130000, c = 1.5973700402, d = -1.4276936105;
			c1 = exp(a * xSq) * (vec2(c, d) * cos(b * xSq) + vec2(-d, c) * sin(b * xSq));
		}

		return vec4(c0, c1);
	}
#endif
