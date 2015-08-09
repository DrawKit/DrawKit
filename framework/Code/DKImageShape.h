/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawableShape.h"

// option constants for crop or scale image

typedef enum {
	kDKImageScaleToPath = 0,
	kDKImageCropToPath = 1
} DKImageCroppingOptions;

// the class

/** @brief DKImageShape is a drawable shape that displays an image.

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
@interface DKImageShape : DKDrawableShape <NSCoding, NSCopying> {
@private
	NSString* mImageKey; // key in the image manager holding original data for this image
	NSImage* m_image; // the image the shape displays
	CGFloat m_opacity; // its opacity
	CGFloat m_imageScale; // its scale (currently ignored, but set to 1.0)
	NSPoint m_imageOffset; // the offset of the image within the bounds
	BOOL m_drawnOnTop; // YES if image drawn after style, NO for before
	NSCompositingOperation m_op; // the Quartz compositing mode to apply
	DKImageCroppingOptions mImageCropping; // whether the image is scaled or cropped to the bounds
	NSInteger mImageOffsetPartcode; // the partcode of the image offset hotspot
	NSData* mOriginalImageData; // original image data (shared with image manager)
}

+ (DKStyle*)imageShapeDefaultStyle;

/** @brief Initializes the image shape from an image

 The object's metdata also record's the image's original size
 @param anImage a valid image object
 @return the object if it was successfully initialized, or nil
 */
- (id)initWithImage:(NSImage*)anImage;

/** @brief Initializes the image shape from image data

 This method is preferred where data is available as it allows the original data to be cached
 very efficiently by the document's image data manager. This maintains quality and keeps file
 sizes to a minimum.
 @param imageData image data of some kind
 @return the object if it was successfully initialized, or nil
 */
- (id)initWithImageData:(NSData*)imageData;

/** @brief Initializes the image shape from an image file given by the path

 The original name and path of the image is recorded in the object's metadata. This extracts the
 original data which allows the image to be efficiently stored.
 @param filepath the path to an image file on disk
 @return the object if it was successfully initialized, or nil
 */
- (id)initWithContentsOfFile:(NSString*)filepath;

/** @brief Sets the object's image

 The shape's path, size, angle, etc. are not changed by this method
 @param anImage an image to display in this shape.
 */
- (void)setImage:(NSImage*)anImage;

/** @brief Get the object's image
 @return the image
 */
- (NSImage*)image;

/** @brief Get a copy of the object's image scaled to the same size, angle and aspect ratio as the image drawn

 This also applies the path clipping, if any
 @return the image
 */
- (NSImage*)imageAtRenderedSize;

/** @brief Set the object's image from image data in the drawing's image data manager

 The object must usually have been added to a drawing before this is called, so that it can locate the
 image data manager to use. However, during dearchiving this isn't the case so the coder itself can
 return a reference to the image manager.
 @param key the image's key
 @param coder the dearchiver in use, if any.
 */
- (void)setImageWithKey:(NSString*)key coder:(NSCoder*)coder;

/** @brief Transfer the image key when the object is added to a new container

 Called as necessary by other methods
 @param container the new container 
 */
- (void)transferImageKeyToNewContainer:(id<DKDrawableContainer>)container;

/** @brief Set the object's image from image data on the pasteboard

 This first tries to use the image data manager to handle the pasteboard, so that the image is
 efficiently cached. If that doesn't work, falls back to the original direct approach.
 @param pb the pasteboard
 @return YES if the operation succeeded, NO otherwise
 */
- (BOOL)setImageWithPasteboard:(NSPasteboard*)pb;

/** @brief Place the object's image data on the pasteboard

 Adds the image data in a variety of forms to the pasteboard - raw data (as file content type)
 TIFF and PDF formats.
 @param pb the pasteboard
 @return YES if the operation succeeded, NO otherwise
 */
- (BOOL)writeImageToPasteboard:(NSPasteboard*)pb;

/** @brief Set the object's image key

 This is called by other methods as necessary. It currently simply retains the key.
 @param key the image's key
 */
- (void)setImageKey:(NSString*)key;

/** @brief Return the object's image key
 @return the image's key
 */
- (NSString*)imageKey;

/** @brief Sets the image from data

 This method liases with the image manager so that the image key is correctly recorded or assigned
 as needed.
 @param data data containing image data 
 */
- (void)setImageData:(NSData*)data;

/** @brief Returns the image original data

 This returns either the locally retained original data, or the data held by the image manager. In
 either case the data returned is the original data from which the image was created. If the image
 was set directly and not from data, and the key is unknown to the image manager, returns nil.
 @return data containing image data
 */
- (NSData*)imageData;

/** @brief Set the image's opacity

 The default is 1.0
 @param opacity an opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
 */
- (void)setImageOpacity:(CGFloat)opacity;

/** @brief Get the image's opacity

 Default is 1.0
 @return <opacity> an opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
 */
- (CGFloat)imageOpacity;

/** @brief Set whether the image draws above or below the rendering done by the style

 Default is NO
 @param onTop YES to draw on top (after) the style, NO to draw below (before)
 */
- (void)setImageDrawsOnTop:(BOOL)onTop;

/** @brief Whether the image draws above or below the rendering done by the style

 Default is NO
 @return YES to draw on top (after) the style, NO to draw below (before)
 */
- (BOOL)imageDrawsOnTop;

/** @brief Set the Quartz composition mode to use when compositing the image

 Default is NSCompositeSourceAtop
 @param op an NSCompositingOperation constant
 */
- (void)setCompositingOperation:(NSCompositingOperation)op;

/** @brief Get the Quartz composition mode to use when compositing the image

 Default is NSCompositeSourceAtop
 @return an NSCompositingOperation constant
 */
- (NSCompositingOperation)compositingOperation;

/** @brief Set the scale factor for the image

 This is not currently implemented - images scale to fit the bounds when in scale mode, and are
 drawn at their native size in crop mode.
 @param scale a scaling value, 1.0 = 100% 
 */
- (void)setImageScale:(CGFloat)scale;

/** @brief Get the scale factor for the image

 This is not currently implemented - images scale to fit the bounds when in scale mode, and are
 drawn at their native size in crop mode.
 @return the scale
 */
- (CGFloat)imageScale;

/** @brief Set the offset position for the image

 The default is 0,0. The value is the distance in points from the top, left corner of the shape's
 bounds to the top, left corner of the image
 @param imgoff the offset position 
 */
- (void)setImageOffset:(NSPoint)imgoff;

/** @brief Get the offset position for the image

 The default is 0,0. The value is the distance in points from the top, left corner of the shape's
 bounds to the top, left corner of the image
 @return the image offset
 */
- (NSPoint)imageOffset;

/** @brief Set the display mode for the object - crop image or scale it

 The default is scale. 
 @param crop a mode value
 */
- (void)setImageCroppingOptions:(DKImageCroppingOptions)crop;

/** @brief Get the display mode for the object - crop image or scale it

 The default is scale. 
 @return a mode value
 */
- (DKImageCroppingOptions)imageCroppingOptions;

// user actions

/** @brief Select whether the object displays using crop or scale modes

 This action method uses the sender's tag value as the cropping mode to set. It can be connected
 directly to a menu item with a suitable tag set for example.
 @param sender the message sender
 */
- (IBAction)selectCropOrScaleAction:(id)sender;

/** @brief Toggle between image drawn on top and image drawn below the rest of the style
 @param sender the message sender
 */
- (IBAction)toggleImageAboveAction:(id)sender;

/** @brief Copy the image directly to the pasteboard.

 A normal "Copy" does place an image of the object on the pb, but that is the whole object with
 all style elements based on the bounds. For some work, such as uing images for pattern fills,
 that's not appropriate, so this action allows you to extract the internal image.
 @param sender the message sender
 */
- (IBAction)copyImage:(id)sender;

/** @brief Replace the shape's image with one from the pasteboard if possible.
 @param sender the message sender
 */
- (IBAction)pasteImage:(id)sender;

/** @brief Resizes the shape to exactly fit the image at its original size.

 Cropped images remain in the same visual location that they are currently at, with the shape's
 frame moved to fit around it exactly. Scaled images are resized to the original size and the object's
 location remains the same. A side effect is to reset any offset, image offset, but not the angle.
 @param sender the message sender
 */
- (IBAction)fitToImage:(id)sender;

@end

// deprecated methods

#ifdef DRAWKIT_DEPRECATED

@interface DKImageShape (Deprecated)

/** @brief Initializes the image shape from the pasteboard
 @param pboard a pasteboard
 @return the objet if it was successfully initialized, or nil
 */
- (id)initWithPasteboard:(NSPasteboard*)pboard;

/** @brief Initializes the image shape from an image

 The original name of the image is recorded in the object's metadata
 @param imageName the name of an image
 @return the object if it was successfully initialized, or nil
 */
- (id)initWithImageNamed:(NSString*)imageName;

@end

#endif

// metadata keys for data installed by this object when created

extern NSString* kDKOriginalFileMetadataKey;
extern NSString* kDKOriginalImageDimensionsMetadataKey;
extern NSString* kDKOriginalNameMetadataKey;
