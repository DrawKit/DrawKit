Rasterizer Groups
-----------------

Because styles are organised into a rasterizer tree, rasterizers can be grouped. Normally there is not much advantage to doing this unless you want to enable or disable several rasterizers at once. However, when the group itself is able to perform some drawing work of its own, things start to get more interesting.

`DKCIFilterRastGroup` is a rasterizer group that is able to process whatever it contains using a Core Image filter (at the present time, only one filter at a time). Thus the output from whatever other rasterizers it contains is passed through the CI Filter before being displayed, which really opens up some amazing effects.

`DKQuartzBlendRastGroup` does a similar thing but applies a different Quartz blending mode to the result before displaying it (Hard Light, Multiply, Difference, etc).
