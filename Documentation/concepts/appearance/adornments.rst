Adornments
==========

`DKImageAdornment`
------------------

`DKImageAdornment` is a `DKRasterizer` that can display a single image within the path's bounds - typically centred. The image scale, opacity, angle and offset can all be controlled, or the image can be scaled to fill the bounds or fit proportionally within it.
This approach to displaying images may be more versatile than using a `DKImageShape`, depending on your needs. If you want to apply a Core Image effect to an image using a `DKCIFilterRastGroup`, this is currently the only built-in way within DrawKit to do it.

`DKTextAdornment`
-----------------

`DKTextAdornment` is a `DKRasterizer` that provides two main ways to add text to an object. It can lay text out in a block in much the same way as a `DKTextShape`, or it can lay it out along a path (including curved paths). Text attributes can be controlled using the Font Panel or other UI.

This rasterizer is also able to lay out text by flowing it into a path or shape, using the `DKBezierTextContainer` class. In this mode, the vertical placement parameter is ignored (always acts as per 'top' alignment), as is the separate text angle. The text can be set to adopt the object's angle or not however.

`DKPathDecorator`
-----------------

`DKPathDecorator` is a `DKRasterizer` that can place copies of an image (called the "motif") at linear intervals along a path. Wherever possible it uses the PDF representation of the image to maximise quality, so vector images remain vector images. The spacing and scale of the motif can be controlled, and also whether the image is rotated to the instantaneous slope of the path at the point where it is drawn. This gives a very powerful effect where a path effectively becomes the guideline for the placement of much more complicated objects.

In addition, you can specify a lead-in and a lead-out scale, where the scale of objects drawn close to the ends of the path are reduced to give a gradual ramping in and out of the motif.

This object also supports a special "chain mode" of operation where successive links formed by the motif can be positioned accurately so that their nominated end points line up precisely. This has application in mechanical drawing for example, or for drawing linked train cars on a track.

`DKPathDecorator` is computationally and graphically expensive, and can cause slow drawing. To alleviate this, it is able to use a cached offscreen version of the motif for faster, low quality updates. It also takes care only to draw those copies of the motif that actually intersect the view's update region. Nevertheless, beware that complex motifs can sap drawing performance considerably.
