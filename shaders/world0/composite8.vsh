#version 440 compatibility
#include "/include/shared/header.glsl"
#define WORLD_OVERWORLD
#define PROGRAM_COMPOSITE8
#define STAGE_VERTEX
#define DOWNSAMPLE_LOD 3
#include "/program/post/bloom/downsample.glsl"
