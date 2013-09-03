///**********************************************************************************************************************************
///  DKImageShape.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 23/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawableShape.h"

// option constants for crop or scale image

typedef enum
{
	kDKImageScaleToPath		= 0,
	kDKImageCropToPath		= 1
}
DKImageCroppingOptions;


// the class

@interface DKImageShape : DKDrawableShape <NSCoding, NSCopying>
{
@private
	NSString*				mImageKey;				// key in the image manager holding original data for this image
	NSImage*				m_image;				// the image the shape displays
	CGFloat					m_opacity;				// its opacity
	CGFloat					m_imageScale;			// its scale (currently ignored, but set to 1.0)
	NSPoint					m_imageOffset;			// the offset of the image within the bounds
	BOOL					m_drawnOnTop;			// YES if image drawn after style, NO for before
	NSCompositingOperation	m_op;					// the Quartz compositing mode to apply
	DKImageCroppingOptions	mImageCropping;			// whether the image is scaled or cropped to the bounds
	NSInteger				mImageOffsetPartcode;	// the partcode of the image offset hotspot
	NSData*					mOriginalImageData;		// original image data (shared with image manager)
}

+ (DKStyle*)				imageShapeDefaultStyle;

- (id)						initWithImage:(NSImage*) anImage;
- (id)						initWithImageData:(NSData*) imageData;
- (id)						initWithContentsOfFile:(NSString*) filepath;

- (void)					setImage:(NSImage*) anImage;
- (NSImage*)				image;
- (NSImage*)				imageAtRenderedSize;
- (void)					setImageWithKey:(NSString*) key coder:(NSCoder*) coder;
- (void)					transferImageKeyToNewContainer:(id<DKDrawableContainer>) container;

- (BOOL)					setImageWithPasteboard:(NSPasteboard*) pb;
- (BOOL)					writeImageToPasteboard:(NSPasteboard*) pb;

- (void)					setImageKey:(NSString*) key;
- (NSString*)				imageKey;

- (void)					setImageData:(NSData*) data;
- (NSData*)					imageData;

- (void)					setImageOpacity:(CGFloat) opacity;
- (CGFloat)					imageOpacity;

- (void)					setImageDrawsOnTop:(BOOL) onTop;
- (BOOL)					imageDrawsOnTop;

- (void)					setCompositingOperation:(NSCompositingOperation) op;
- (NSCompositingOperation)	compositingOperation;

- (void)					setImageScale:(CGFloat) scale;
- (CGFloat)					imageScale;

- (void)					setImageOffset:(NSPoint) imgoff;
- (NSPoint)					imageOffset;

- (void)					setImageCroppingOptions:(DKImageCroppingOptions) crop;
- (DKImageCroppingOptions)	imageCroppingOptions;

// user actions

- (IBAction)				selectCropOrScaleAction:(id) sender;
- (IBAction)				toggleImageAboveAction:(id) sender;
- (IBAction)				copyImage:(id) sender;
- (IBAction)				pasteImage:(id) sender;
- (IBAction)				fitToImage:(id) sender;

@end


// deprecated methods

#ifdef DRAWKIT_DEPRECATED

@interface DKImageShape (Deprecated)

- (id)						initWithPasteboard:(NSPasteboard*) pboard;
- (id)						initWithImageNamed:(NSString*) imageName;

@end

#endif

// metadata keys for data installed by this object when created

extern NSString*	kDKOriginalFileMetadataKey;
extern NSString*	kDKOriginalImageDimensionsMetadataKey;
extern NSString*	kDKOriginalNameMetadataKey;

/*

DKImageShape is a drawable shape that displays an image. The image is scaled and rotated to the path bounds and clipped to the
path. The opacity of the image can be set, and whether the image is drawn before or after the normal path rendering.

This object is quite flexible - by changing the path clipping and drawing styles, a very wide range of different effects are
possible. (n.b. if you don't attach a style, the path is not drawn at all [the default], but still clips the image. The default
path is a rect so that the entire image is drawn.

There are two basic modes of operation - scaling and cropping. Scaling fills the shape's bounds with the image. Cropping keeps the image at its
original size and allows the path to clip it as it is resized. In both cases the image offset can be used to position the image within the bounds.
A hotspot is added to allow the user to drag the image offset position around.
 
 Image shapes automatically manage image data efficiently, such that if there is more than one shape with the same image, only one copy of
 the data is maintained, and that data is the original compressed data from the file (if it did come from a file). This data sharing is
 facilitated by a central DKImageDataManager object, which is managed by the drawing. Note that using certian operations, such as creating
 the shape with an NSImage will bypass this benefit.

*/
