/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKRasterizer.h"

NS_ASSUME_NONNULL_BEGIN

@class DKDrawableObject, DKDrawing;

//! fitting options:
typedef NS_ENUM(NSInteger, DKImageFittingOption) {
	kDKScaleToFitBounds = 0, //!< scale setting ignored - image will fill bounds
	kDKScaleToFitPreservingAspectRatio = 1, //!< scale setting ignored - image will fit bounds with original aspect ratio preserved
	kDKClipToBounds = 2 //!< scales according to setting, but clipped to object's path if size exceeds it
};

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

+ (instancetype)imageAdornmentWithImage:(NSImage*)image;
+ (instancetype)imageAdornmentWithImageFromFile:(NSString*)path;

@property (atomic, strong, nullable) NSImage* image;

- (void)setImageWithKey:(NSString*)key forDrawing:(DKDrawing*)drawing;
@property (copy) NSString* imageKey;

@property (copy) NSString* imageIdentifier;

@property (atomic) CGFloat scale;

@property (atomic) CGFloat opacity;

@property NSPoint origin;

@property CGFloat angle;
@property CGFloat angleInDegrees;

@property NSCompositingOperation operation;

@property DKImageFittingOption fittingOption;

- (NSAffineTransform*)imageTransformForObject:(id<DKRenderable>)renderableObject;

@end

NS_ASSUME_NONNULL_END
