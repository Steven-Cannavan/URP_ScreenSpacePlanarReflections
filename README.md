# URP_ScreenSpacePlanarReflections
Simple example of implementing screen space planar reflections as a RenderFeature for URP

![Screen Space Reflections in URP](/Images/PuddleScreenshot.png)

Based upon Remi Genin's work: [Screen Space Plane Indexed Reflection In Ghost Recon Wildlands](http://remi-genin.fr/blog/screen-space-plane-indexed-reflection-in-ghost-recon-wildlands/)

This has been created for educational purposes, not for production. Use this at your own risk.

Known Issues:
* Doesn't work for Android
* Still in progress :)

## How To Use

Add the ScreenSpacePlanarReflectionFeature to your Feature list

![SSPR Render Feature](/Images/Feature.png)

Adjust the position and rotation of the reflection plane by adjusting 'Plane Rotation' & 'Plane Location'

The edge stretch option will stretch the edges of the reflection make them fit better, in my expereience this looks terrible in VR as it breaks perspective but looks pretty good in general.

The blur option should really always be on, at somepoint if i get round to implementing the temporal history I have it as an option to switch between. However right now it will blur the pixels to help cover any gaps, which can be quite significant depending on the angle.

Render reflective layer is an option to do another opaque pass on objects which have the specific layer mask selected (Reflective Surface Layer), remember to remove that layer from the default layer mask, if you only intend to use this on transparent materials then I wouldnt worry about enabling this.

Stencil optimization should only be used if you have a reflective surface layer and your happy to only generate reflections where theyre on screen.

An Example material that uses this is in Assets/Materials/Puddle which uses the example URPExample/SSPR_Lit shader

## How it works

This feature will inject upto 3 passes into URP

1. \[Optional\] Stencil Pass - Before Opaques

The stencil pass is there to render out any 'Surfaces' that are in the reflective pass with the intention of using that stencil information to exclude rendering out pixels that wont be reflected.

2. Reflection Pass - After Skybox

The reflection pass using a mixture of compute and pixel shader will render the reflection into a globa texture called 
_\_ScreenSpacePlanarReflectionTexture_ if the device does not support compute we will not render anything, this means with this implementation the reflection is only valid for after this pass

3. \[Optional\] Render Reflectives Pass  - After Skybox
Renderes all renderers in the Reflective Surface Layer, follows opaque rules (forward to back sorting etc)


## In Progress
* Roughness / Kawase blur sampling

## TODO
* Implement Temporal History Buffer
* Stereo Support
* Test Support for Consoles
* Fix RenderDoc Bug ( Material is lost when you load render doc)
* Switch to RTHandle
* Deferred Support

## Wishlist / Maybes
* 2D Renderer Support
* Get working for Android GLES 3
