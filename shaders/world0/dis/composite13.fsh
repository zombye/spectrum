#version 440 compatibility
#include "/include/shared/header.glsl"
#define WORLD_OVERWORLD
#define PROGRAM_COMPOSITE13
#define STAGE_FRAGMENT
#define UPSAMPLE_LOD2 5
#define UPSAMPLE_LOD1 4
#define UPSAMPLE_LOD0 3
#include "/program/post/bloom/upsample_multi.glsl"
