/*
const float sunPathRotation = -40.0;

const float centerDepthHalflife = 2.0;

// Shadow maps
const int   shadowMapResolution     = 2048; // [1024 2048 4096 8192]
const float shadowDistance          = 32.0;
const float shadowRenderDistanceMul = -1.0;

// Buffers
const int colortex0Format = RGB16;          // Core MC: Albedo(1.5), Material ID(0.5), Lightmap(1)
const int colortex1Format = RGB16;          // Shaders: Normal(2), Reflectance(0.5), Smoothness(0.5)
const int colortex2Format = R11F_G11F_B10F; // Composite
const int colortex3Format = RGBA16F;        // Auxiliary
const int colortex4Format = RGB10_A2;       // Auxiliary
const int colortex5Format = RGBA16F;        // Transparent composite
const int colortex6Format = R8;             //
const int colortex7Format = R16F;           // Exposure

const bool colortex0Clear = true;
const bool colortex1Clear = false;
const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool colortex4Clear = false;
const bool colortex5Clear = true;
const bool colortex6Clear = false;
const bool colortex7Clear = false;

// Shadow mipmaps
const bool shadowtex0Mipmap   = true;
const bool shadowtex1Mipmap   = false;
const bool shadowcolor0Mipmap = true;
const bool shadowcolor1Mipmap = true;
*/

/*
albedo      = 24 --- 32
material id =  8 -/
normals     = 32
lightmap    = 16 ---------- 32
reflectance =  8 --- 16 -/
smoothness  =  8 -/
composite   = 32
tcomposite  = 32
topacity    =  8

5x32 + 1x8

--------------------------------------------

colortex0: RGB16          |  99,532,800 bits
colortex1: RGB16          |  99,532,800 bits
colortex2: R11F_G11F_B10F |  66,355,200 bits
colortex3: RGBA16F        | 132,710,400 bits
colortex4: RGB10_A2       |  66,355,200 bits
colortex5: RGBA16F        | 132,710,400 bits
colortex6: R8             |  16,588,800 bits
colortex7: R16F           |  33,177,600 bits

total: 646,963,200 bits
*/

/* ebin:

albedo      = 32
normals     = 32
lightmap    = 16 ---------- 32
material id =  8 --- 16 -/
specularity =  8 -/
topacity    =  8

7x32 + 3x8

--------------------------------------------

colortex0: RG32F          | 132,710,400 bits
colortex1: R11F_G11F_B10F |  66,355,200 bits
colortex2: R8             |  16,588,800 bits
colortex3: R11F_G11F_B10F |  66,355,200 bits
colortex4: RG32F          | 132,710,400 bits
colortex5: RGBA8          |  66,355,200 bits
colortex6: RG8            |  33,177,600 bits
colortex7: RGBA8          |  66,355,200 bits

total: 580,608,000 bits
*/
