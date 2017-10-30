#include "extension.glsl"

//--// Shader stages

#define STAGE_VERTEX   0
#define STAGE_FRAGMENT 1

//--// Shader programs

/* By program ID
#define PROGRAM_BASIC               1
#define PROGRAM_TEXTURED            2
#define PROGRAM_TEXTURED_LIT        3
#define PROGRAM_SKYBASIC            4
#define PROGRAM_SKYTEXTURED         5
#define PROGRAM_CLOUDS              6
#define PROGRAM_TERRAIN             7
#define PROGRAM_TERRAIN_SOLID       8
#define PROGRAM_TERRAIN_CUTOUT_MIP  9
#define PROGRAM_TERRAIN_CUTOUT     10
#define PROGRAM_DAMAGEDBLOCK       11
#define PROGRAM_WATER              12
#define PROGRAM_BLOCK              13
#define PROGRAM_BEACONBEAM         14
#define PROGRAM_ITEM               15
#define PROGRAM_ENTITIES           16
#define PROGRAM_ARMOR_GLINT        17
#define PROGRAM_SPIDEREYES         18
#define PROGRAM_HAND               19
#define PROGRAM_WEATHER            20
#define PROGRAM_COMPOSITE          21
#define PROGRAM_COMPOSITE1         22
#define PROGRAM_COMPOSITE2         23
#define PROGRAM_COMPOSITE3         24
#define PROGRAM_COMPOSITE4         25
#define PROGRAM_COMPOSITE5         26
#define PROGRAM_COMPOSITE6         27
#define PROGRAM_COMPOSITE7         28
#define PROGRAM_FINAL              29
#define PROGRAM_SHADOW             30
#define PROGRAM_SHADOW_SOLID       31
#define PROGRAM_SHADOW_CUTOUT      32
#define PROGRAM_DEFERRED           33
#define PROGRAM_DEFERRED1          34
#define PROGRAM_DEFERRED2          35
#define PROGRAM_DEFERRED3          36
#define PROGRAM_DEFERRED4          37
#define PROGRAM_DEFERRED5          38
#define PROGRAM_DEFERRED6          39
#define PROGRAM_DEFERRED7          40
#define PROGRAM_HAND_WATER         41
//*/

//* By (approximate) execution order
//--// shadow maps are presumably first, definitely before terrain*
#define PROGRAM_SHADOW              1
#define PROGRAM_SHADOW_SOLID        2
#define PROGRAM_SHADOW_CUTOUT       3
//--// sky
#define PROGRAM_SKYBASIC            4 // stars, horizon
#define PROGRAM_SKYTEXTURED         5 // sun, moon, custom skies(?)
#define PROGRAM_CLOUDS              6 // clouds solid
//--// opaque terrain
#define PROGRAM_TERRAIN             7 // instead of terrain_solid, terrain_cutout_mip or terrain_cutout
#define PROGRAM_TERRAIN_SOLID       8 // unused
#define PROGRAM_TERRAIN_CUTOUT_MIP  9 // unused
#define PROGRAM_TERRAIN_CUTOUT     10 // unused
//--// entities & tile entities
#define PROGRAM_ENTITIES           11
#define PROGRAM_SPIDEREYES         12 // rendered just after entities, I guess?
#define PROGRAM_ARMOR_GLINT        13 // presumably just after what it's being applied to, so entities & hand
#define PROGRAM_ITEM               14 // unused, items are done with textured_lit currently. presumably around entities
#define PROGRAM_BLOCK              15 // tile entities like chests
#define PROGRAM_BEACONBEAM         16 // beacon beam, not sure if activated yet. probably done with block
//--// idk what to name this section
#define PROGRAM_BASIC              17 // selected block outline | debug renderers? presumably use basic if they use any program
#define PROGRAM_DAMAGEDBLOCK       18 // block breaking overlay
//--// particles and the like
#define PROGRAM_TEXTURED           19 // particles
#define PROGRAM_TEXTURED_LIT       20 // lit particles
#define PROGRAM_WEATHER            21 // weather (rain, snow)
//--// another section idk what to name
// world border is done now, uses textured_lit
#define PROGRAM_HAND               22 // held items and hand itself
//--// deferred
#define PROGRAM_DEFERRED           23
#define PROGRAM_DEFERRED1          24
#define PROGRAM_DEFERRED2          25
#define PROGRAM_DEFERRED3          26
#define PROGRAM_DEFERRED4          27
#define PROGRAM_DEFERRED5          28
#define PROGRAM_DEFERRED6          29
#define PROGRAM_DEFERRED7          30
//--// translucent
#define PROGRAM_WATER              31
// clouds translucent are done now, presumably still uses clouds program
#define PROGRAM_HAND_WATER         32
//--// composites and final are done last
#define PROGRAM_COMPOSITE          33
#define PROGRAM_COMPOSITE1         34
#define PROGRAM_COMPOSITE2         35
#define PROGRAM_COMPOSITE3         36
#define PROGRAM_COMPOSITE4         37
#define PROGRAM_COMPOSITE5         38
#define PROGRAM_COMPOSITE6         39
#define PROGRAM_COMPOSITE7         40
#define PROGRAM_FINAL              41
//*/

//--// Worlds (dimension IDs)

#define WORLD_NETHER    -1
#define WORLD_OVERWORLD  0
#define WORLD_END        1
