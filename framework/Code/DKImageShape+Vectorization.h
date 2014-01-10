/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#ifdef qUsePotrace

#import "DKImageShape.h"
#import "NSImage+Tracing.h"

@class DKShapeGroup;

typedef enum {
    kDKVectorizeGrayscale = 0,
    kDKVectorizeColour = 1
} DKVectorizingMethod;

// this category implements very high-level vectorizing operations on an image shape. At its simplest,
// it vectorizes the image using the default settings and replaces the image object by a group containing the
// shapes resulting. For the user, this looks like a vectorization operation was applied "in place".

// Apps are free to implement this in a more controlled way if they wish, for example by using a dialog
// to set up the various parameters.

// Be sure to also check out NSImage+Tracing because that's where the real work is done.

@interface DKImageShape (Vectorization)

+ (void)setPreferredVectorizingMethod:(DKVectorizingMethod)method;
+ (void)setPreferredVectorizingLevels:(NSInteger)levelsOfGray;
+ (void)setPreferredVectorizingPrecision:(NSInteger)colourPrecision;
+ (void)setPreferredQuantizationMethod:(DKColourQuantizationMethod)qm;

+ (void)setTracingParameters:(NSDictionary*)traceInfo;
+ (NSDictionary*)tracingParameters;

- (DKShapeGroup*)makeGroupByVectorizing;
- (DKShapeGroup*)makeGroupByGrayscaleVectorizingWithLevels:(NSInteger)levelsOfGray;
- (DKShapeGroup*)makeGroupByColourVectorizingWithPrecision:(NSInteger)colourPrecision;

- (NSArray*)makeObjectsByVectorizing;
- (NSArray*)makeObjectsByGrayscaleVectorizingWithLevels:(NSInteger)levelsOfGray;
- (NSArray*)makeObjectsByColourVectorizingWithPrecision:(NSInteger)colourPrecision;

- (IBAction)vectorize:(id)sender;

@end

// additional dict keys that can be set in the trace params:

extern NSString* kDKIncludeStrokeStyle; // BOOL
extern NSString* kDKStrokeStyleWidth; // float
extern NSString* kDKStrokeStyleColour; // NSColor

#endif /* defined qUsePotrace */
