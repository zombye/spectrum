//#define DEBUG

#define DEBUG_PROGRAM PROGRAM_DEFERRED // [PROGRAM_DEFERRED PROGRAM_DEFERRED1 PROGRAM_COMPOSITE PROGRAM_COMPOSITE1 PROGRAM_COMPOSITE2 PROGRAM_COMPOSITE3 PROGRAM_COMPOSITE4 PROGRAM_COMPOSITE5 PROGRAM_FINAL]

vec4 debugVisual = vec4(0.0);

void show(float x) { debugVisual.rgb = vec3(x); debugVisual.a = 1.0; }
void show(vec3  x) { debugVisual.rgb = x;       debugVisual.a = 1.0; }

void exit() {
	#ifndef DEBUG
	return;
	#endif

	#if   PROGRAM == DEBUG_PROGRAM
		#if PROGRAM == PROGRAM_WATER
			gl_FragData[0] = mix(gl_FragData[0], debugVisual, debugVisual.a);
		#else
			gl_FragData[0].rgb = mix(gl_FragData[0].rgb, debugVisual.rgb, debugVisual.a);
		#endif
	#elif PROGRAM > DEBUG_PROGRAM
		#if PROGRAM == PROGRAM_DEFERRED1
			#if DEBUG_PROGRAM == PROGRAM_DEFERRED // deferred puts debug in colortex5
			gl_FragData[0].rgb = texture2D(gaux2, screenCoord).rgb;
			#else // gbuffers put debug in colortex0
			gl_FragData[0].rgb = texture2D(colortex0, screenCoord).rgb;
			#endif
		#elif PROGRAM == PROGRAM_WATER // gbuffers_water output has alpha
			gl_FragData[0] = texture2D(gaux1, gl_FragCoord.st / vec2(viewWidth, viewHeight));
		#elif PROGRAM == PROGRAM_COMPOSITE // composite
			// data from gbuffers_water and last deferred needs to be combined
			vec4 transparentPass = texture2D(colortex6, screenCoord);
			gl_FragData[0].rgb = mix(texture2D(gaux1, screenCoord).rgb, transparentPass.rgb, transparentPass.a);
		#elif PROGRAM >= PROGRAM_COMPOSITE1 && PROGRAM <= PROGRAM_COMPOSITE3 // composite1 - composite3
			gl_FragData[0].rgb = texture2D(colortex4, screenCoord).rgb;
		#elif PROGRAM == PROGRAM_COMPOSITE4 // composite4
		#elif PROGRAM == PROGRAM_COMPOSITE5 // composite5
			gl_FragData[0].rgb = texture2D(colortex5, screenCoord).rgb;
		#elif PROGRAM == PROGRAM_FINAL // final
			#if DEBUG_PROGRAM == PROGRAM_COMPOSITE5 // composite5 only writes to colortex5
				gl_FragData[0].rgb = texture2D(colortex5, screenCoord).rgb;
			#else
				gl_FragData[0].rgb = texture2D(colortex4, screenCoord).rgb;
			#endif
		#endif
	#endif
}
