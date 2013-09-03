///**********************************************************************************************************************************
///  NSImage+Tracing.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 23/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#ifdef qUsePotrace

#import <Cocoa/Cocoa.h>
#import "potracelib.h"

// possible values for the quantization method (not all implemented)

typedef enum
{
	kDKColourQuantizeUniform	= 0,		// implemented, very basic results but fast
	kDKColourQuantizePopular555	= 1,
	kDKColourQuantizePopular444	= 2,
	kDKColourQuantizeOctree		= 3,		// implemented, fairly good results and fast
	kDKColourQuantizeMedianCut	= 4
}
DKColourQuantizationMethod;


// category on NSImage returns lists of 'vector rep' objects (see below)

@interface NSImage (Tracing)

- (NSArray*)			vectorizeToGrayscale:(NSInteger) levels;
- (NSArray*)			vectorizeToColourWithPrecision:(NSInteger) prec quantizationMethod:(DKColourQuantizationMethod) qm;

- (NSBitmapImageRep*)	eightBitImageRep;
- (NSBitmapImageRep*)	twentyFourBitImageRep;

@end

// the 'vector rep' object represents each bitplane or separate colour in the image, and will perform the vectorization
// using potrace when the vector data is requested (lazy vectorization).

@interface DKImageVectorRep	: NSObject
{
	potrace_bitmap_t*	mBits;
	NSUInteger			mLevels;
	NSUInteger			mPixelValue;
	potrace_param_t*	mTraceParams;
	NSBezierPath*		mVectorData;
	NSColor*			mColour;
}

- (id)					initWithImageSize:(NSSize) isize pixelValue:(NSUInteger) pixv levels:(NSUInteger) lev;

- (potrace_bitmap_t*)	bitmap;

// get the traced path, performing the trace if needed

- (NSBezierPath*)		vectorPath;

// colour from original image associated with this bitplane

- (void)				setColour:(NSColor*) cin;
- (NSColor*)			colour;

// tracing parameters

- (void)				setTurdSize:(NSInteger) turdsize;
- (NSInteger)					turdSize;

- (void)				setTurnPolicy:(NSInteger) turnPolicy;
- (NSInteger)					turnPolicy;

- (void)				setAlphaMax:(double) alphaMax;
- (double)				alphaMax;

- (void)				setOptimizeCurve:(BOOL) opt;
- (BOOL)				optimizeCurve;

- (void)				setOptimizeTolerance:(double) optTolerance;
- (double)				optimizeTolerance;

- (void)				setTracingParameters:(NSDictionary*) dict;
- (NSDictionary*)		tracingParameters;

@end

// dict keys used to set tracing parameters from a dictionary

extern NSString*	kDKTracingParam_turdsize;			// integer value, sets pixel area below which is not traced
extern NSString*	kDKTracingParam_turnpolicy;			// integer value, turn policy
extern NSString*	kDKTracingParam_alphamax;			// double value, sets smoothness of corners
extern NSString*	kDKTracingParam_opticurve;			// boolean value, 1 = simplify curves, 0 = do not simplify
extern NSString*	kDKTracingParam_opttolerance;		// double value, epsilon limit for curve fit



/*

This image category implements image vectorization using Peter Selinger's potrace algorithm and OSS code.

It works as follows:

// stage 1:

1. A 24-bit bit image is made from the NSImage contents (ensures that regardless of image format, we have a standard RGB bitmap to work from)
2. The image is analysed using a quantizer to determine the best set of colours needed to represent it at the chosen sampling value
3. A DKImageVectorRep is allocated for each colour. This allocates a bitmap data structure that potrace can work with.
4. The 24-bit image is scanned and the corresponding bits in the bit images are set according to the index value returned by the quantizer
5. Empty bitplanes are discarded
6. The resulting list of DKImageVectorRep objects is returned

// stage 2:

7. The client code requests the vector path from the DKImageVectorRep. This triggers a call to potrace with the generated bitmap for that colour
8. The client assembles the resulting paths into objects that can use the paths, for example DKDrawableShapes.
9. The client assembles the shapes into a group and adds it to the drawing.

(Steps 8 and 9 are what is done in DrawKit - other client code might have other ideas).

Note that the API to this operates at a high level in a category on DKImageShape - see DKImageShape+Vectorization.

*/

#endif /* defined qUsePotrace */
