/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
 * @note
 * The object's metdata also record's the image's original size
 * @param anImage a valid image object
 * @return the object if it was successfully initialized, or nil
 * @public
 */
- (id)initWithImage:(NSImage*)anImage;

/** @brief Initializes the image shape from image data
 * @note
 * This method is preferred where data is available as it allows the original data to be cached
 * very efficiently by the document's image data manager. This maintains quality and keeps file
 * sizes to a minimum.
 * @param imageData image data of some kind
 * @return the object if it was successfully initialized, or nil
 * @public
 */
- (id)initWithImageData:(NSData*)imageData;

/** @brief Initializes the image shape from an image file given by the path
 * @note
 * The original name and path of the image is recorded in the object's metadata. This extracts the
 * original data which allows the image to be efficiently stored.
 * @param filepath the path to an image file on disk
 * @return the object if it was successfully initialized, or nil
 * @public
 */
- (id)initWithContentsOfFile:(NSString*)filepath;

/** @brief Sets the object's image
 * @note
 * The shape's path, size, angle, etc. are not changed by this method
 * @param anImage an image to display in this shape.
 * @public
 */
- (void)setImage:(NSImage*)anImage;

/** @brief Get the object's image
 * @return the image
 * @public
 */
- (NSImage*)image;

/** @brief Get a copy of the object's image scaled to the same size, angle and aspect ratio as the image drawn
 * @note
 * This also applies the path clipping, if any
 * @return the image
 * @public
 */
- (NSImage*)imageAtRenderedSize;

/** @brief Set the object's image from image data in the drawing's image data manager
 * @note
 * The object must usually have been added to a drawing before this is called, so that it can locate the
 * image data manager to use. However, during dearchiving this isn't the case so the coder itself can
 * return a reference to the image manager.
 * @param key the image's key
 * @param coder the dearchiver in use, if any.
 * @public
 */
- (void)setImageWithKey:(NSString*)key coder:(NSCoder*)coder;

/** @brief Transfer the image key when the object is added to a new container
 * @note
 * Called as necessary by other methods
 * @param container the new container 
 * @public
 */
- (void)transferImageKeyToNewContainer:(id<DKDrawableContainer>)container;

/** @brief Set the object's image from image data on the pasteboard
 * @note
 * This first tries to use the image data manager to handle the pasteboard, so that the image is
 * efficiently cached. If that doesn't work, falls back to the original direct approach.
 * @param pb the pasteboard
 * @return YES if the operation succeeded, NO otherwise
 * @public
 */
- (BOOL)setImageWithPasteboard:(NSPasteboard*)pb;

/** @brief Place the object's image data on the pasteboard
 * @note
 * Adds the image data in a variety of forms to the pasteboard - raw data (as file content type)
 * TIFF and PDF formats.
 * @param pb the pasteboard
 * @return YES if the operation succeeded, NO otherwise
 * @public
 */
- (BOOL)writeImageToPasteboard:(NSPasteboard*)pb;

/** @brief Set the object's image key
 * @note
 * This is called by other methods as necessary. It currently simply retains the key.
 * @param key the image's key
 * @public
 */
- (void)setImageKey:(NSString*)key;

/** @brief Return the object's image key
 * @return the image's key
 * @public
 */
- (NSString*)imageKey;

/** @brief Sets the image from data
 * @note
 * This method liases with the image manager so that the image key is correctly recorded or assigned
 * as needed.
 * @param data data containing image data 
 * @public
 */
- (void)setImageData:(NSData*)data;

/** @brief Returns the image original data
 * @note
 * This returns either the locally retained original data, or the data held by the image manager. In
 * either case the data returned is the original data from which the image was created. If the image
 * was set directly and not from data, and the key is unknown to the image manager, returns nil.
 * @return data containing image data
 * @public
 */
- (NSData*)imageData;

/** @brief Set the image's opacity
 * @note
 * The default is 1.0
 * @param opacity an opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
 * @public
 */
- (void)setImageOpacity:(CGFloat)opacity;

/** @brief Get the image's opacity
 * @note
 * Default is 1.0
 * @return <opacity> an opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
 * @public
 */
- (CGFloat)imageOpacity;

/** @brief Set whether the image draws above or below the rendering done by the style
 * @note
 * Default is NO
 * @param onTop YES to draw on top (after) the style, NO to draw below (before)
 * @public
 */
- (void)setImageDrawsOnTop:(BOOL)onTop;

/** @brief Whether the image draws above or below the rendering done by the style
 * @note
 * Default is NO
 * @return YES to draw on top (after) the style, NO to draw below (before)
 * @public
 */
- (BOOL)imageDrawsOnTop;

/** @brief Set the Quartz composition mode to use when compositing the image
 * @note
 * Default is NSCompositeSourceAtop
 * @param op an NSCompositingOperation constant
 * @public
 */
- (void)setCompositingOperation:(NSCompositingOperation)op;

/** @brief Get the Quartz composition mode to use when compositing the image
 * @note
 * Default is NSCompositeSourceAtop
 * @return an NSCompositingOperation constant
 * @public
 */
- (NSCompositingOperation)compositingOperation;

/** @brief Set the scale factor for the image
 * @note
 * This is not currently implemented - images scale to fit the bounds when in scale mode, and are
 * drawn at their native size in crop mode.
 * @param scale a scaling value, 1.0 = 100% 
 * @public
 */
- (void)setImageScale:(CGFloat)scale;

/** @brief Get the scale factor for the image
 * @note
 * This is not currently implemented - images scale to fit the bounds when in scale mode, and are
 * drawn at their native size in crop mode.
 * @return the scale
 * @public
 */
- (CGFloat)imageScale;

/** @brief Set the offset position for the image
 * @note
 * The default is 0,0. The value is the distance in points from the top, left corner of the shape's
 * bounds to the top, left corner of the image
 * @param imgoff the offset position 
 * @public
 */
- (void)setImageOffset:(NSPoint)imgoff;

/** @brief Get the offset position for the image
 * @note
 * The default is 0,0. The value is the distance in points from the top, left corner of the shape's
 * bounds to the top, left corner of the image
 * @return the image offset
 * @public
 */
- (NSPoint)imageOffset;

/** @brief Set the display mode for the object - crop image or scale it
 * @note
 * The default is scale. 
 * @param crop a mode value
 * @public
 */
- (void)setImageCroppingOptions:(DKImageCroppingOptions)crop;

/** @brief Get the display mode for the object - crop image or scale it
 * @note
 * The default is scale. 
 * @return a mode value
 * @public
 */
- (DKImageCroppingOptions)imageCroppingOptions;

// user actions

/** @brief Select whether the object displays using crop or scale modes
 * @note
 * This action method uses the sender's tag value as the cropping mode to set. It can be connected
 * directly to a menu item with a suitable tag set for example.
 * @param sender the message sender
 * @public
 */
- (IBAction)selectCropOrScaleAction:(id)sender;

/** @brief Toggle between image drawn on top and image drawn below the rest of the style
 * @param sender the message sender
 * @public
 */
- (IBAction)toggleImageAboveAction:(id)sender;

/** @brief Copy the image directly to the pasteboard.
 * @note
 * A normal "Copy" does place an image of the object on the pb, but that is the whole object with
 * all style elements based on the bounds. For some work, such as uing images for pattern fills,
 * that's not appropriate, so this action allows you to extract the internal image.
 * @param sender the message sender
 * @public
 */
- (IBAction)copyImage:(id)sender;

/** @brief Replace the shape's image with one from the pasteboard if possible.
 * @param sender the message sender
 * @public
 */
- (IBAction)pasteImage:(id)sender;

/** @brief Resizes the shape to exactly fit the image at its original size.
 * @note
 * Cropped images remain in the same visual location that they are currently at, with the shape's
 * frame moved to fit around it exactly. Scaled images are resized to the original size and the object's
 * location remains the same. A side effect is to reset any offset, image offset, but not the angle.
 * @param sender the message sender
 * @public
 */
- (IBAction)fitToImage:(id)sender;

@end

// deprecated methods

#ifdef DRAWKIT_DEPRECATED

@interface DKImageShape (Deprecated)

/** @brief Initializes the image shape from the pasteboard
 * @param pboard a pasteboard
 * @return the objet if it was successfully initialized, or nil
 * @public
 */
- (id)initWithPasteboard:(NSPasteboard*)pboard;

/** @brief Initializes the image shape from an image
 * @note
 * The original name of the image is recorded in the object's metadata
 * @param imageName the name of an image
 * @return the object if it was successfully initialized, or nil
 * @public
 */
- (id)initWithImageNamed:(NSString*)imageName;

@end

#endif

// metadata keys for data installed by this object when created

extern NSString* kDKOriginalFileMetadataKey;
extern NSString* kDKOriginalImageDimensionsMetadataKey;
extern NSString* kDKOriginalNameMetadataKey;
