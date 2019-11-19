#version 400 compatibility
#include "/include/shared/header.glsl"
#define WORLD_OVERWORLD
#define PROGRAM_DEFERRED4
#define STAGE_FRAGMENT

#define FILTER_ITERATION 2

#include "/program/rsmFilterIteration.glsl"
