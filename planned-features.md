# General

Terrain deformation
* Disabled by default
* Affect normals correctly
* Should affect clouds and other world-space effects
* Types:
  * Planetoid
  * Acid

Parallax Mapping

Various ambient occlusion methods
Reflective Shadow Maps - implemented

PCSS/some other method for realistic shadows
HSSRS

Subsurface Scattering approximation

Reflective Caustics?
Refractive Caustics - implemented

Subtle blocklight "flicker"

Held light - implemented

Refractions - implemented

Screen-Space Reflections - partially implemented
* Should take into account fog & clouds. Clouds may be slow tough

Fog - partially implemented
* Volumetric by default
* Water fog is also volumetric
* Simple fog as an option (brightness based on `max(eyeBrightness.y / 240.0, skyLightmap)`)

Eye Adaptation - implemented
* Smoothed over a short period

Temporal Anti-Aliasing

Proper weather effects:
* Rain & Storms are extra cloudy
* Lightning bolts light up everything with proper directional lighting
* Puddles form on the ground
* Possibly rainbows for a short period after rain?

# Procedural effects

All: Vary day-by-day, with seasonal tendencies. 8 days per month, 2 months per season, 4 seasons per year, 8 months per year, game starts during spring

Wind effects on foliage & rain - partially implemented
* Fades out as skylight access decreases

Water Waves - partially implemented
* Takes into account direction of flowing water
* Fades into much calmer waves as skylight access decreases

Clouds - partially implemented
* Planes - Cirrus if I can get them looking right as a plane. Otherwise they'll be volumetric. Probably a few other types as well
* Volumetric - Cumulus, likely also stratocumulus
* Curve very distant clouds down below the horizon

# Post-processing

All: Ensure they do not change the overall brightness of the image

Depth of Field - partially implemented
* Stuff does not blur over things closer to the camera, but does blur over things further away

Motion Blur - partially implemented
* Variable sample count

Bloom/Glare - implemented, but needs improvements

Tonemapping - implemented

# Things I may or may not implement

Idle animation for hand
* Fades in/out depending on current movement speed so that it doesn't affect the walking animation

An option for vanilla-like clouds
