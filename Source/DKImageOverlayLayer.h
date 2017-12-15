/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKLayer.h"

//! coverage method flags - can be combined to give different effects
typedef NS_OPTIONS(NSUInteger, DKImageCoverageFlags) {
	kDKDrawingImageCoverageNormal = 0,
	kDKDrawingImageCoverageHorizontallyCentred = 1,
	kDKDrawingImageCoverageHorizontallyStretched = 2,
	kDKDrawingImageCoverageHorizontallyTiled = 4,
	kDKDrawingImageCoverageVerticallyCentred = 32,
	kDKDrawingImageCoverageVerticallyStretched = 64,
	kDKDrawingImageCoverageVerticallyTiled = 128,
};

/** @brief This layer type implements a single image overlay, for example for tracing a photograph in another layer.

This layer type implements a single image overlay, for example for tracing a photograph in another layer. The coverage method
sets whether the image is scaled, tiled or drawn only once in a particular position.
*/
@interface DKImageOverlayLayer : DKLayer <NSCoding> {
	NSImage* m_image;
	CGFloat m_opacity;
	DKImageCoverageFlags m_coverageMethod;
}

- (instancetype)initWithImage:(NSImage*)image;
- (instancetype)initWithContentsOfFile:(NSString*)imagefile;

@property (strong) NSImage *image;
- (void)setImage:(NSImage*)image;
- (NSImage*)image;

@property CGFloat opacity;
- (void)setOpacity:(CGFloat)op;
- (CGFloat)opacity;

@property DKImageCoverageFlags coverageMethod;
- (void)setCoverageMethod:(DKImageCoverageFlags)cm;
- (DKImageCoverageFlags)coverageMethod;

- (NSRect)imageDestinationRect;
@property (readonly) NSRect imageDestinationRect;

@end
