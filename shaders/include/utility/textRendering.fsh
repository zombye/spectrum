#if !defined INCLUDE_UTILITY_TEXTRENDERING
#define INCLUDE_UTILITY_TEXTRENDERING

#define CHAR_A 10
#define CHAR_B 11
#define CHAR_C 12
#define CHAR_D 13
#define CHAR_E 14
#define CHAR_F 15
#define CHAR_G 16
#define CHAR_H 17
#define CHAR_I 18
#define CHAR_J 19
#define CHAR_K 20
#define CHAR_L 21
#define CHAR_M 22
#define CHAR_N 23
#define CHAR_O 24
#define CHAR_P 25
#define CHAR_Q 26
#define CHAR_R 27
#define CHAR_S 28
#define CHAR_T 29
#define CHAR_U 30
#define CHAR_V 31
#define CHAR_W 32
#define CHAR_X 33
#define CHAR_Y 34
#define CHAR_Z 35
#define CHAR_PERIOD 36
#define CHAR_COMMA 37
#define CHAR_HYPHEN 38
#define CHAR_PLUS 39

bool textCharacter(ivec2 c, int idx) {
	/*\
	 * Each character is 5w*6h
	 * No capitalization, (currently) no punctuation.
	 *
	 * Each letter's shape is stored in 30 bits of a 32-bit integer.
	 * Last two bits are currently unused.
	 *
	 * 0-9   = 0-9
	 * 10-35 = A-Z
	 * 36    = .
	 * 37    = ,
	 * 38    = -
	 * 39    = +
	\*/

	const int[40] chars = int[40](
		0x1D19F62E, // 0 | 01:1 1101:D 0001:1 1001:9 1111:F 0110:6 0010:2 1110:E
		0x1942109F, // 1 | 01:1 1001:9 0100:4 0010:2 0001:1 0000:0 1001:9 1111:F
		0x1D11111F, // 2 | 01:1 1101:D 0001:1 0001:1 0001:1 0001:1 0001:1 1111:F
		0x1D11062E, // 3 | 01:1 1101:D 0001:1 0001:1 0000:0 0110:6 0010:2 1110:E
		0x0CA97C42, // 4 | 00:0 1100:C 1010:A 1001:9 0111:7 1100:C 0100:4 0010:2
		0x3F0F062E, // 5 | 11:3 1111:F 0000:0 1111:F 0000:0 0110:6 0010:2 1110:E
		0x1D0F462E, // 6 | 01:1 1101:D 0000:0 1111:F 0100:4 0110:6 0010:2 1110:E
		0x3E111110, // 7 | 11:3 1110:E 0001:1 0001:1 0001:1 0001:1 0001:1 0000:0
		0x1D17462E, // 8 | 01:1 1101:D 0001:1 0111:7 0100:4 0110:6 0010:2 1110:E
		0x1D17862E, // 9 | 01:1 1101:D 0001:1 0111:7 1000:8 0110:6 0010:2 1110:E
		0x1D1FC631, // A | 01:1 1101:D 0001:1 1111:F 1100:C 0110:6 0011:3 0001:1
		0x3D1F463E, // B | 11:3 1101:D 0001:1 1111:F 0100:4 0110:6 0011:3 1110:E
		0x1D18422E, // C | 01:1 1101:D 0001:1 1000:8 0100:4 0010:2 0010:2 1110:E
		0x3D18C63E, // D | 11:3 1101:D 0001:1 1000:8 1100:C 0110:6 0011:3 1110:E
		0x3F0E421F, // E | 11:3 1111:F 0000:0 1110:E 0100:4 0010:2 0001:1 1111:F
		0x3F0E4210, // F | 11:3 1111:F 0000:0 1110:E 0100:4 0010:2 0001:1 0000:0
		0x1D185E2F, // G | 01:1 1101:D 0001:1 1000:8 0101:5 1110:E 0010:2 1111:F
		0x231FC631, // H | 10:2 0011:3 0001:1 1111:F 1100:C 0110:6 0011:3 0001:1
		0x3E42109F, // I | 11:3 1110:E 0100:4 0010:2 0001:1 0000:0 1001:9 1111:F
		0x3E10862E, // J | 11:3 1110:E 0001:1 0000:0 1000:8 0110:6 0010:2 1110:E
		0x232E4A31, // K | 10:2 0011:3 0010:2 1110:E 0100:4 1010:A 0011:3 0001:1
		0x2108421F, // L | 10:2 0001:1 0000:0 1000:8 0100:4 0010:2 0001:1 1111:F
		0x23BAC631, // M | 10:2 0011:3 1011:B 1010:A 1100:C 0110:6 0011:3 0001:1
		0x239ACE31, // N | 10:2 0011:3 1001:9 1010:A 1100:C 1110:E 0011:3 0001:1
		0x1D18C62E, // O | 01:1 1101:D 0001:1 1000:8 1100:C 0110:6 0010:2 1110:E
		0x3D1F4210, // P | 11:3 1101:D 0001:1 1111:F 0100:4 0010:2 0001:1 0000:0
		0x1D18D64D, // Q | 01:1 1101:D 0001:1 1000:8 1101:D 0110:6 0100:4 1101:D
		0x3D1F4A31, // R | 11:3 1101:D 0001:1 1111:F 0100:4 1010:A 0011:3 0001:1
		0x1F07043E, // S | 01:1 1111:F 0000:0 0111:7 0000:0 0100:4 0011:3 1110:E
		0x3E421084, // T | 11:3 1110:E 0100:4 0010:2 0001:1 0000:0 1000:8 0100:4
		0x2318C62E, // U | 10:2 0011:3 0001:1 1000:8 1100:C 0110:6 0010:2 1110:E
		0x2318A944, // V | 10:2 0011:3 0001:1 1000:8 1010:A 1001:9 0100:4 0100:4
		0x2318D771, // W | 10:2 0011:3 0001:1 1000:8 1101:D 0111:7 0111:7 0001:1
		0x22A22A31, // X | 10:2 0010:2 1010:A 0010:2 0010:2 1010:A 0011:3 0001:1
		0x22A21084, // Y | 10:2 0010:2 1010:A 0010:2 0001:1 0000:0 1000:8 0100:4
		0x3E22221F, // Z | 11:3 1110:E 0010:2 0010:2 0010:2 0010:2 0001:1 1111:F
		0x00000004, // . | 00:0 0000:0 0000:0 0000:0 0000:0 0000:0 0000:0 0100:4
		0x00000088, // , | 00:0 0000:0 0000:0 0000:0 0000:0 0000:0 1000:8 8000:8
		0x00070000, // - | 00:0 0000:0 0000:0 0111:7 0000:0 0000:0 0000:0 0000:0
		0x00471000  // + | 00:0 0000:0 0100:4 0111:7 0001:1 0000:0 0000:0 000:0
	);

	int px = (5 - c.x) + c.y * 5;
	return ((chars[idx] >> px) & 0x00000001) != 0;
}

vec3 DimTextBackground(vec3 bg, const int totalChars, const ivec2 pos, const int textScale, const int margin) {
	ivec2 c = ivec2(floor((gl_FragCoord.xy - pos - margin) / textScale));

	if(c.x >= 1 - margin
	&& c.x <= totalChars * 6 + margin - 1
	&& c.y >= -margin
	&& c.y <= 5 + margin
	) { bg *= 0.2; }

	return bg;
}

vec3 TextTest(vec3 col) {
	const int margin = 1;
	col = DimTextBackground(col, 40, ivec2(3.0, 33.0), 2, margin);

	ivec2 c = ivec2(floor((gl_FragCoord.xy - vec2(3.0, 33.0) - margin) / 2.0));

	if (c.x < 0 || c.y < 0 || c.y > 5) {
		return col;
	}

	for (int i = 0; i < 40; ++i) {
		ivec2 charCoord = c - ivec2(i * 6, 0);
		if (charCoord.x < 1 || charCoord.x > 5) { continue; }

		bool text = textCharacter(charCoord, i);

		if (text) {
			return vec3(1.0);
		}
	}

	return col;
}

float iexp10(int x) {
	if (x == 0) { return 1.0; }

	float r = 1.0;

	if (x > 0) {
		for (int i = 0; i < x; ++i) {
			r *= 10.0;
		}
	} else {
		for (int i = 0; i > x; --i) {
			r /= 10.0;
		}
	}

	return r;
}

vec3 DrawFloat(vec3 bg, float val, int digits, int mostSignificantDigit, const ivec2 pos, const int textScale, const int margin) {
	const bool alwaysIncludeSign = false; // Include sign even when positive?
	const bool includeDecimalPoint = true; // Include the decimal point?

	bool drawDecimalPoint = digits > mostSignificantDigit && mostSignificantDigit > 0 && includeDecimalPoint;
	bool drawSign = val < 0.0 || alwaysIncludeSign;

	int nondigits = int(drawSign) + int(drawDecimalPoint);
	int characters = digits + nondigits;

	//--//

	ivec2 c = ivec2(floor((gl_FragCoord.xy - pos - margin) / textScale));

	if (c.x <= 0 || c.x >= characters * 6 || c.y < 0 || c.y > 5) {
		return bg;
	}

	int charIdx = c.x / 6;

	if (drawSign && charIdx == 0) {
		return textCharacter(c, val >= 0.0 ? CHAR_PLUS : CHAR_HYPHEN) ? vec3(1.0) : bg;
	}

	val = abs(val);

	if (mostSignificantDigit > 0) {
		for (int i = 1; i <= mostSignificantDigit; ++i) {
			ivec2 charCoord = c - ivec2((i + int(drawSign) - 1) * 6, 0);
			if (charCoord.x <= 0 || charCoord.x >= 6) { continue; }

			int charIdx = int(floor(val * iexp10(i - mostSignificantDigit))) % 10;
			bool digit = textCharacter(charCoord, charIdx);

			if (digit) { return vec3(1.0); }
			else { return bg; }
		}

		// decimal point
		if (drawDecimalPoint) {
			ivec2 charCoord = c - ivec2((mostSignificantDigit + int(drawSign)) * 6, 0);
			if (charCoord.x > 0 && charCoord.x < 6) {
				return textCharacter(charCoord, CHAR_PERIOD) ? vec3(1.0) : bg;
			}
		}
	}

	/*
	for (int i = mostSignificantDigit + 1; i <= digits; ++i) {
		ivec2 charCoord = c - ivec2((i + nondigits - 1) * 6, 0);
		if (charCoord.x <= 0 || charCoord.x >= 6) { continue; }

		int charIdx = int(floor(val * iexp10(i - mostSignificantDigit))) % 10;
		bool digit = textCharacter(charCoord, charIdx);

		if (digit) { return vec3(1.0); }
		else { return bg; }
	}
	//*/

	//*
	if (charIdx >= 0 && charIdx < characters && c.x % 6 > 0) {
		c.x -= charIdx * 6;

		// Digits before the decimal point
		if (charIdx >= (drawSign ? 1 : 0) && charIdx < (drawSign ? 1 : 0) + digits - nondigits) {
			if (textCharacter(c, int(floor(val * iexp10(charIdx + 1 - nondigits - mostSignificantDigit))) % 10)) {
				return vec3(1.0);
			}
		}

		// Digits after the decimal point
		if (charIdx >= (drawSign ? 1 : 0) + digits - nondigits) {
			if (textCharacter(c, int(floor(val * iexp10(charIdx + (drawSign ? 2 : 1) - nondigits - mostSignificantDigit))) % 10)) {
				return vec3(1.0);
			}
		}
	}
	//*/

	return bg;
}

#endif
