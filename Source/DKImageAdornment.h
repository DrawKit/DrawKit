/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRasterizer.h"

@class DKDrawableObject, DKDrawing;

// fitting options:

typedef enum {
	kDKScaleToFitBounds = 0, // scale setting ignored - image will fill bounds
	kDKScaleToFitPreservingAspectRatio = 1, // scale setting ignored - image will fit bounds with original aspect ratio preserved
	kDKClipToBounds = 2 // scales according to setting, but clipped to object's path if size exceeds it
} DKImageFittingOption;

/** @brief This class allows any image to be part of the rendering tree.

This class allows any image to be part of the rendering tree.
*/
@interface DKImageAdornment : DKRasterizer <NSCoding, NSCopying> {
@private
	NSString* mImageKey;
	NSImage* m_image;
	CGFloat m_scale;
	CGFloat m_opacity;
	CGFloat m_angle;
	NSPoint m_origin;
	NSCompositingOperation m_op;
	DKImageFittingOption m_fittingOption;
	NSString* m_imageIdentifier;
}

+ (DKImageAdornment*)imageAdornmentWithImage:(NSImage*)image;
+ (DKImageAdornment*)imageAdornmentWithImageFromFile:(NSString*)path;

- (void)setImage:(NSImage*)image;
- (NSImage*)image;

- (void)setImageWithKey:(NSString*)key forDrawing:(DKDrawing*)drawing;
- (void)setImageKey:(NSString*)key;
- (NSString*)imageKey;

- (void)setImageIdentifier:(NSString*)imageID;
- (NSString*)imageIdentifier;

- (void)setScale:(CGFloat)scale;
- (CGFloat)scale;

- (void)setOpacity:(CGFloat)opacity;
- (CGFloat)opacity;

- (void)setOrigin:(NSPoint)origin;
- (NSPoint)origin;

- (void)setAngle:(CGFloat)angle;
- (CGFloat)angle;
- (void)setAngleInDegrees:(CGFloat)degrees;
- (CGFloat)angleInDegrees;

- (void)setOperation:(NSCompositingOperation)op;
- (NSCompositingOperation)operation;

- (void)setFittingOption:(DKImageFittingOption)fopt;
- (DKImageFittingOption)fittingOption;

- (NSAffineTransform*)imageTransformForObject:(id<DKRenderable>)renderableObject;

@end
