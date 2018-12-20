#if !defined INCLUDE_SHARED_HEADER
#define INCLUDE_SHARED_HEADER

// This is defined so that OptiFine detects them.
#define attribute in

//--// Extensions

// Fastest way to do what it does, but not required.
#ifdef MC_GL_ARB_texture_gather
	#extension GL_ARB_texture_gather : enable
#else
	vec4 textureGather(sampler2D sampler, vec2 coord) {
		ivec2 res = textureSize(sampler, 0);
		ivec2 iCoord = ivec2(coord * res);

		return vec4(
			texelFetch(sampler, (iCoord + ivec2(0, 1)) % res, 0).r,
			texelFetch(sampler, (iCoord + ivec2(1, 1)) % res, 0).r,
			texelFetch(sampler, (iCoord + ivec2(1, 0)) % res, 0).r,
			texelFetch(sampler, (iCoord + ivec2(0, 0)) % res, 0).r
		);
	}
#endif

//--// Defined IDs

// World IDs
#define WORLD_NETHER   -1
#define WORLD_OVERWORLD 0
#define WORLD_END       1

// Program IDs (by execution order)
#define PROGRAM_SHADOW              1
#define PROGRAM_SHADOW_SOLID        2
#define PROGRAM_SHADOW_CUTOUT       3
#define PROGRAM_SKYBASIC            4
#define PROGRAM_SKYTEXTURED         5
#define PROGRAM_CLOUDS              6
#define PROGRAM_TERRAIN             7
#define PROGRAM_TERRAIN_SOLID       8
#define PROGRAM_TERRAIN_CUTOUT_MIP  9
#define PROGRAM_TERRAIN_CUTOUT     10
#define PROGRAM_ENTITIES           11
#define PROGRAM_SPIDEREYES         12
#define PROGRAM_ARMOR_GLINT        13
#define PROGRAM_ITEM               14
#define PROGRAM_BLOCK              15
#define PROGRAM_BEACONBEAM         16
#define PROGRAM_BASIC              17
#define PROGRAM_DAMAGEDBLOCK       18
#define PROGRAM_TEXTURED           19
#define PROGRAM_TEXTURED_LIT       20
#define PROGRAM_WEATHER            21
#define PROGRAM_HAND               22
#define PROGRAM_DEFERRED           23
#define PROGRAM_DEFERRED1          24
#define PROGRAM_DEFERRED2          25
#define PROGRAM_DEFERRED3          26
#define PROGRAM_DEFERRED4          27
#define PROGRAM_DEFERRED5          28
#define PROGRAM_DEFERRED6          29
#define PROGRAM_DEFERRED7          30
#define PROGRAM_WATER              31
// clouds translucent would be here
#define PROGRAM_HAND_WATER         32
#define PROGRAM_COMPOSITE          33
#define PROGRAM_COMPOSITE1         34
#define PROGRAM_COMPOSITE2         35
#define PROGRAM_COMPOSITE3         36
#define PROGRAM_COMPOSITE4         37
#define PROGRAM_COMPOSITE5         38
#define PROGRAM_COMPOSITE6         39
#define PROGRAM_COMPOSITE7         40
#define PROGRAM_COMPOSITE8         41
#define PROGRAM_COMPOSITE9         42
#define PROGRAM_COMPOSITE10        43
#define PROGRAM_COMPOSITE11        44
#define PROGRAM_COMPOSITE12        45
#define PROGRAM_COMPOSITE13        46
#define PROGRAM_COMPOSITE14        47
#define PROGRAM_COMPOSITE15        48
#define PROGRAM_FINAL              49

// Stage IDs
#define STAGE_VERTEX   0
#define STAGE_GEOMETRY 1
#define STAGE_FRAGMENT 2

#endif
