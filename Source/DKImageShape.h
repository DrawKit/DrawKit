/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawableShape.h"
#import "DKDrawableShape+Hotspots.h"

NS_ASSUME_NONNULL_BEGIN

//! option constants for crop or scale image
typedef NS_OPTIONS(NSInteger, DKImageCroppingOptions) {
	kDKImageScaleToPath = 0,
	kDKImageCropToPath = 1
};

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
@interface DKImageShape : DKDrawableShape <NSCoding, NSCopying, DKHotspotDelegate> {
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
- (instancetype)initWithImage:(NSImage*)anImage NS_DESIGNATED_INITIALIZER;

/** @brief Initializes the image shape from image data

 This method is preferred where data is available as it allows the original data to be cached
 very efficiently by the document's image data manager. This maintains quality and keeps file
 sizes to a minimum.
 @param imageData image data of some kind
 @return the object if it was successfully initialized, or nil
 */
- (instancetype)initWithImageData:(NSData*)imageData;

/** @brief Initializes the image shape from an image file given by the path

 The original name and path of the image is recorded in the object's metadata. This extracts the
 original data which allows the image to be efficiently stored.
 @param filepath the path to an image file on disk
 @return the object if it was successfully initialized, or nil
 */
- (instancetype)initWithContentsOfFile:(NSString*)filepath;

/** @brief Dearchive the object
 @param coder a coder
 @return the object */
- (nullable instancetype)initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;

/** @brief Sets the object's image

 The shape's path, size, angle, etc. are not changed by this method
 */
@property (nonatomic, retain) NSImage *image;

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
 */
@property (copy) NSString *imageKey;

/** @brief Returns the image original data

 This method liases with the image manager so that the image key is correctly recorded or assigned
 as needed.
 This returns either the locally retained original data, or the data held by the image manager. In
 either case the data returned is the original data from which the image was created. If the image
 was set directly and not from data, and the key is unknown to the image manager, returns nil.
 @return data containing image data
 */
@property (copy, nullable) NSData*imageData;

/** @brief Set the image's opacity

 The default is 1.0.
 An opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
 */
@property (nonatomic) CGFloat imageOpacity;

/** @brief Set whether the image draws above or below the rendering done by the style

 Default is NO
 Set to \c YES to draw on top (after) the style, \c NO to draw below (before).
 */
@property (nonatomic) BOOL imageDrawsOnTop;

/** @brief Set the Quartz composition mode to use when compositing the image

 Default is \c NSCompositeSourceAtop
 */
@property (nonatomic) NSCompositingOperation compositingOperation;

/** @brief Set the scale factor for the image

 This is not currently implemented - images scale to fit the bounds when in scale mode, and are
 drawn at their native size in crop mode.
 */
@property (nonatomic) CGFloat imageScale;

/** @brief Set the offset position for the image

 The default is 0,0. The value is the distance in points from the top, left corner of the shape's
 bounds to the top, left corner of the image
 */
@property (nonatomic) NSPoint imageOffset;

/** @brief Set the display mode for the object - crop image or scale it

 The default is scale. 
 */
@property (nonatomic) DKImageCroppingOptions imageCroppingOptions;

// user actions

/** @brief Select whether the object displays using crop or scale modes

 This action method uses the sender's tag value as the cropping mode to set. It can be connected
 directly to a menu item with a suitable tag set for example.
 @param sender the message sender
 */
- (IBAction)selectCropOrScaleAction:(nullable id)sender;

/** @brief Toggle between image drawn on top and image drawn below the rest of the style
 @param sender the message sender
 */
- (IBAction)toggleImageAboveAction:(nullable id)sender;

/** @brief Copy the image directly to the pasteboard.

 A normal "Copy" does place an image of the object on the pb, but that is the whole object with
 all style elements based on the bounds. For some work, such as uing images for pattern fills,
 that's not appropriate, so this action allows you to extract the internal image.
 @param sender the message sender
 */
- (IBAction)copyImage:(nullable id)sender;

/** @brief Replace the shape's image with one from the pasteboard if possible.
 @param sender the message sender
 */
- (IBAction)pasteImage:(nullable id)sender;

/** @brief Resizes the shape to exactly fit the image at its original size.

 Cropped images remain in the same visual location that they are currently at, with the shape's
 frame moved to fit around it exactly. Scaled images are resized to the original size and the object's
 location remains the same. A side effect is to reset any offset, image offset, but not the angle.
 @param sender the message sender
 */
- (IBAction)fitToImage:(nullable id)sender;

@end


#ifdef DRAWKIT_DEPRECATED

/** @brief deprecated methods
 */
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

extern NSString* const kDKOriginalFileMetadataKey;
extern NSString* const kDKOriginalImageDimensionsMetadataKey;
extern NSString* const kDKOriginalNameMetadataKey;

NS_ASSUME_NONNULL_END
