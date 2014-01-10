/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKImageShape.h"
#import "DKImageShape+Vectorization.h"
#import "DKObjectOwnerLayer.h"
#import "DKDrawableObject+Metadata.h"
#import "DKStyle.h"
#import "DKDrawableShape+Hotspots.h"
#import "DKDrawKitMacros.h"
#import "LogEvent.h"
#import "DKDrawing.h"
#import "DKImageDataManager.h"
#import "DKKeyedUnarchiver.h"

#pragma mark Constants

NSString* kDKOriginalFileMetadataKey = @"dk_original_file";
NSString* kDKOriginalImageDimensionsMetadataKey = @"dk_image_original_dims";
NSString* kDKOriginalNameMetadataKey = @"dk_original_name";

@interface DKImageShape (Private)

/** @brief Return a transform that can be used to position, size and rotate the image to the shape
 @note
 A separate transform is necessary because trying to use the normal shape transform and rendering the
 image into a unit square results in some very visible rounding errors. Instead the image is
 transformed independently from its orginal size directly to the final size, so the errors are
 eliminated.
 @return a transform
 */
- (NSAffineTransform*)imageTransformWithoutLocation;
- (NSAffineTransform*)imageTransform;

/** @brief Draw the image applying all of the shape's settings
 */
- (void)drawImage;

@end

@implementation DKImageShape
#pragma mark As a DKImageShape

+ (DKStyle*)imageShapeDefaultStyle
{
    return [DKStyle styleWithFillColour:[NSColor clearColor]
                           strokeColour:nil];
}

/** @brief Initializes the image shape from the pasteboard
 @param pboard a pasteboard
 @return the objet if it was successfully initialized, or nil
 */
- (id)initWithPasteboard:(NSPasteboard*)pboard;
{
    NSImage* image = nil;
    if ([NSImage canInitWithPasteboard:pboard]) {
        image = [[[NSImage alloc] initWithPasteboard:pboard] autorelease];
    }
    if (image == nil) {
        [self autorelease];
        self = nil;
    } else {
        self = [self initWithImage:image];

        if (self != nil) {
            NSString* urlType = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]];

            if (urlType != nil) {
                NSArray* files = (NSArray*)[pboard propertyListForType:NSFilenamesPboardType];

                //	LogEvent_(kReactiveEvent, @"dropped files = %@", files);

                NSString* path = [files objectAtIndex:0];

                // add this info to the metadata for the object

                [self setString:path
                         forKey:kDKOriginalFileMetadataKey];
                [self setString:[[path lastPathComponent] stringByDeletingPathExtension]
                         forKey:kDKOriginalNameMetadataKey];
            }
        }
    }
    return self;
}

#pragma mark -

/** @brief Initializes the image shape from an image
 @note
 The object's metdata also record's the image's original size
 @param anImage a valid image object
 @return the object if it was successfully initialized, or nil
 */
- (id)initWithImage:(NSImage*)anImage
{
    NSAssert(anImage != nil, @"cannot init with a nil image");

    NSRect r = NSZeroRect;
    r.size = [anImage size];

    self = [super initWithRect:r
                         style:[[self class] imageShapeDefaultStyle]];
    if (self != nil) {
        [self setImage:anImage];
        [self setImageOpacity:1.0];
        m_imageScale = 1.0;

        [self setImageDrawsOnTop:NO];
        [self setCompositingOperation:NSCompositeSourceOver];
        [self setImageCroppingOptions:kDKImageScaleToPath];

        DKHotspot* hs = [[DKHotspot alloc] initHotspotWithOwner:self
                                                       partcode:0
                                                       delegate:self];
        mImageOffsetPartcode = [self addHotspot:hs];
        [hs setRelativeLocation:NSZeroPoint];
        [hs release];

        if (m_image == nil) {
            [self autorelease];
            self = nil;
        }
    }

    return self;
}

/** @brief Initializes the image shape from image data
 @note
 This method is preferred where data is available as it allows the original data to be cached
 very efficiently by the document's image data manager. This maintains quality and keeps file
 sizes to a minimum.
 @param imageData image data of some kind
 @return the object if it was successfully initialized, or nil
 */
- (id)initWithImageData:(NSData*)imageData
{
    NSAssert(imageData != nil, @"cannot initialise with nil data");

    NSImage* image = [[NSImage alloc] initWithData:imageData];

    if (image) {
        self = [self initWithImage:image];
        [image release];

        if (self)
            [self setImageData:imageData];
    } else {
        [self autorelease];
        self = nil;
    }

    return self;
}

/** @brief Initializes the image shape from an image
 @note
 The original name of the image is recorded in the object's metadata
 @param imageName the name of an image
 @return the object if it was successfully initialized, or nil
 */
- (id)initWithImageNamed:(NSString*)imageName
{
    [self initWithImage:[NSImage imageNamed:imageName]];
    [self setString:imageName
             forKey:kDKOriginalNameMetadataKey];

    return self;
}

/** @brief Initializes the image shape from an image file given by the path
 @note
 The original name and path of the image is recorded in the object's metadata. This extracts the
 original data which allows the image to be efficiently stored.
 @param filepath the path to an image file on disk
 @return the object if it was successfully initialized, or nil
 */
- (id)initWithContentsOfFile:(NSString*)filepath
{
    NSAssert(filepath != nil, @"path was nil");

    NSData* data = [NSData dataWithContentsOfFile:filepath];

    if (data) {
        self = [self initWithImageData:data];

        if (self) {
            [self setString:filepath
                     forKey:kDKOriginalFileMetadataKey];
            [self setString:[[filepath lastPathComponent] stringByDeletingPathExtension]
                     forKey:kDKOriginalNameMetadataKey];
        }
    } else {
        [self autorelease];
        self = nil;
    }
    return self;
}

#pragma mark -

/** @brief Sets the object's image
 @note
 The shape's path, size, angle, etc. are not changed by this method
 @param anImage an image to display in this shape.
 */
- (void)setImage:(NSImage*)anImage
{
    NSAssert(anImage != nil, @"can't set a nil image");

    if (anImage != [self image]) {
        [[self undoManager] registerUndoWithTarget:self
                                          selector:@selector(setImage:)
                                            object:[self image]];

        [anImage retain];
        [m_image release];
        m_image = anImage;

        [m_image setCacheMode:NSImageCacheNever];
        [m_image recache];
        [m_image setScalesWhenResized:YES];
        [self notifyVisualChange];

        // setting the image nils the key. Callers that know there is a key should use setImageWithKey:coder: instead.

        [mImageKey release];
        mImageKey = nil;

        // record image size in metadata

        [self setSize:[anImage size]
               forKey:kDKOriginalImageDimensionsMetadataKey];
    }
}

/** @brief Get the object's image
 @return the image
 */
- (NSImage*)image
{
    return m_image;
}

/** @brief Get a copy of the object's image scaled to the same size, angle and aspect ratio as the image drawn
 @note
 This also applies the path clipping, if any
 @return the image
 */
- (NSImage*)imageAtRenderedSize
{
    NSCompositingOperation savedOp = [self compositingOperation];
    NSSize niSize = [self logicalBounds].size;
    NSImage* newImage = [[NSImage alloc] initWithSize:niSize];

    if (newImage != nil) {
        [self setCompositingOperation:NSCompositeCopy];
        [newImage lockFocus];

        CGFloat dx, dy;

        dx = niSize.width * 0.5f;
        dy = niSize.height * 0.5f;

        NSAffineTransform* tfm = [NSAffineTransform transform];
        [tfm translateXBy:-([self location].x - dx)
            yBy:-([self location].y - dy)];
        [tfm concat];

        [self drawImage];
        [newImage unlockFocus];
    }

    [self setCompositingOperation:savedOp];
    return [newImage autorelease];
}

/** @brief Set the object's image from image data in the drawing's image data manager
 @note
 The object must usually have been added to a drawing before this is called, so that it can locate the
 image data manager to use. However, during dearchiving this isn't the case so the coder itself can
 return a reference to the image manager.
 @param key the image's key
 @param coder the dearchiver in use, if any.
 */
- (void)setImageWithKey:(NSString*)key coder:(NSCoder*)coder
{
    if (![key isEqualToString:[self imageKey]]) {
        DKImageDataManager* dm;

        if (coder && [coder respondsToSelector:@selector(imageManager)])
            dm = [(DKKeyedUnarchiver*)coder imageManager];
        else
            dm = [[self container] imageManager];

        if (dm) {
            NSLog(@"image shape %@ loading image from image manager, key = %@", self, key);

            NSImage* image = [dm makeImageForKey:key];

            if (image) {
                [key retain];
                [self setImage:image]; // releases key and sets it to nil
                mImageKey = key;
            }
        }
    }
}

/** @brief Set the object's image key
 @note
 This is called by other methods as necessary. It currently simply retains the key.
 @param key the image's key
 */
- (void)setImageKey:(NSString*)key
{
    [key retain];
    [mImageKey release];
    mImageKey = key;
}

/** @brief Return the object's image key
 @return the image's key
 */
- (NSString*)imageKey
{
    return mImageKey;
}

/** @brief Transfer the image key when the object is added to a new container
 @note
 Called as necessary by other methods
 @param container the new container 
 */
- (void)transferImageKeyToNewContainer:(id<DKDrawableContainer>)container
{
    // when an image shape has a new container, image data may need to be transferred to it. This is called
    // by setContainer: and usually is not needed by apps.

    if (container) {
        NSAssert2([container conformsToProtocol:@protocol(DKDrawableContainer)], @"container (%@) passed to %@ does not conform to the DKDrawableContainer protocol", container, self);

        DKImageDataManager* newIM = [container imageManager];
        NSData* imageData = [self imageData];

        if (newIM && imageData) {
            //NSLog(@"transferring image data (%d bytes) to new IM: %@", [imageData length], newIM );

            // does new IM know about this data? If so, simply keep a note of the key and use its copy of the data.
            // If not, add our copy of the data to it and get a new key if we need one. There is only ever one copy of the
            // image data no matter how many image shapes use it across any number of documents, etc.

            NSString* key = [newIM keyForImageData:imageData];

            if (key) {
                imageData = [[newIM imageDataForKey:key] retain];
                [mOriginalImageData release];
                mOriginalImageData = imageData;
                [self setImageKey:key];

                //NSLog(@"image data was found in new IM, updated key: %@", key );
            } else {
                key = [self imageKey];

                if (key == nil)
                    key = [newIM generateKey];

                [newIM setImageData:imageData
                             forKey:key];
                [self setImageKey:key];

                //NSLog(@"image data was added to new IM, key: %@", key );
            }
        }
    }
}

/** @brief Sets the image from data
 @note
 This method liases with the image manager so that the image key is correctly recorded or assigned
 as needed.
 @param data data containing image data 
 */
- (void)setImageData:(NSData*)data
{
    [data retain];
    [mOriginalImageData release];
    mOriginalImageData = data;

    // link up with the image manager - if it already knows the data it will return a key for it, otherwise a new key
    // if there is no image manager, create an image anyway, retain the data but don't create a key.

    DKImageDataManager* imgMgr = [[self container] imageManager];
    NSImage* image;

    if (imgMgr) {
        NSString* key;
        image = [imgMgr makeImageWithData:data
                                      key:&key];

        [self setImage:image];
        [self setImageKey:key];
    } else {
        image = [[NSImage alloc] initWithData:data];
        [self setImage:image];
        [image release];
    }
}

/** @brief Returns the image original data
 @note
 This returns either the locally retained original data, or the data held by the image manager. In
 either case the data returned is the original data from which the image was created. If the image
 was set directly and not from data, and the key is unknown to the image manager, returns nil.
 @return data containing image data
 */
- (NSData*)imageData
{
    if (mOriginalImageData == nil)
        mOriginalImageData = [[[[self container] imageManager] imageDataForKey:[self imageKey]] retain];

    return mOriginalImageData;
}

/** @brief Set the object's image from image data on the pasteboard
 @note
 This first tries to use the image data manager to handle the pasteboard, so that the image is
 efficiently cached. If that doesn't work, falls back to the original direct approach.
 @param pb the pasteboard
 @return YES if the operation succeeded, NO otherwise
 */
- (BOOL)setImageWithPasteboard:(NSPasteboard*)pb
{
    NSAssert(pb != nil, @"pasteboard is nil");

    DKImageDataManager* dm = [[self container] imageManager];

    if (dm) {
        NSString* newKey = nil;
        NSImage* image = [dm makeImageWithPasteboard:pb
                                                 key:&newKey];

        if (image) {
            [image setScalesWhenResized:YES];
            [image setCacheMode:NSImageCacheNever];

            // keep a local reference to the data if possible

            NSData* imgData = [dm imageDataForKey:newKey];
            [imgData retain];
            [mOriginalImageData release];
            mOriginalImageData = imgData;

            [self setImage:image];
            [self setImageKey:newKey];

            return YES;
        }
    }

    if ([NSImage canInitWithPasteboard:pb]) {
        NSImage* image = [[NSImage alloc] initWithPasteboard:pb];

        if (image != nil) {
            [self setImage:image];
            [image release];

            return YES;
        }
    }

    return NO;
}

/** @brief Place the object's image data on the pasteboard
 @note
 Adds the image data in a variety of forms to the pasteboard - raw data (as file content type)
 TIFF and PDF formats.
 @param pb the pasteboard
 @return YES if the operation succeeded, NO otherwise
 */
- (BOOL)writeImageToPasteboard:(NSPasteboard*)pb
{
    NSAssert(pb != nil, @"cannot write to nil pasteboard");

    BOOL result = NO;

    [pb declareTypes:[NSArray arrayWithObjects:NSFileContentsPboardType, NSTIFFPboardType, NSPDFPboardType, nil]
               owner:self];

    NSData* imgData = [self imageData];
    if (imgData)
        result = [pb setData:imgData
                     forType:NSFileContentsPboardType];

    NSImage* image = [self image];
    if (image) {
        imgData = [image TIFFRepresentation];
        result |= [pb setData:imgData
                      forType:NSTIFFPboardType];

        // look for PDF data

        NSEnumerator* iter = [[image representations] objectEnumerator];
        NSImageRep* rep;

        while ((rep = [iter nextObject])) {
            if ([rep respondsToSelector:@selector(PDFRepresentation)]) {
                imgData = [(NSPDFImageRep*)rep PDFRepresentation];
                result |= [pb setData:imgData
                              forType:NSPDFPboardType];
                break;
            }
        }
    }

    return result;
}

#pragma mark -

/** @brief Set the image's opacity
 @note
 The default is 1.0
 @param opacity an opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
 */
- (void)setImageOpacity:(CGFloat)opacity
{
    if (opacity != m_opacity) {
        [[[self undoManager] prepareWithInvocationTarget:self] setImageOpacity:[self imageOpacity]];
        m_opacity = opacity;
        [self notifyVisualChange];
    }
}

/** @brief Get the image's opacity
 @note
 Default is 1.0
 @return <opacity> an opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
 */
- (CGFloat)imageOpacity
{
    return m_opacity;
}

/** @brief Set whether the image draws above or below the rendering done by the style
 @note
 Default is NO
 @param onTop YES to draw on top (after) the style, NO to draw below (before)
 */
- (void)setImageDrawsOnTop:(BOOL)onTop
{
    if (onTop != [self imageDrawsOnTop]) {
        [[[self undoManager] prepareWithInvocationTarget:self] setImageDrawsOnTop:[self imageDrawsOnTop]];
        m_drawnOnTop = onTop;
        [self notifyVisualChange];
    }
}

/** @brief Whether the image draws above or below the rendering done by the style
 @note
 Default is NO
 @return YES to draw on top (after) the style, NO to draw below (before)
 */
- (BOOL)imageDrawsOnTop
{
    return m_drawnOnTop;
}

/** @brief Set the Quartz composition mode to use when compositing the image
 @note
 Default is NSCompositeSourceAtop
 @param op an NSCompositingOperation constant
 */
- (void)setCompositingOperation:(NSCompositingOperation)op
{
    if (op != m_op) {
        [[[self undoManager] prepareWithInvocationTarget:self] setCompositingOperation:[self compositingOperation]];
        m_op = op;
        [self notifyVisualChange];
    }
}

/** @brief Get the Quartz composition mode to use when compositing the image
 @note
 Default is NSCompositeSourceAtop
 @return an NSCompositingOperation constant
 */
- (NSCompositingOperation)compositingOperation
{
    return m_op;
}

/** @brief Set the scale factor for the image
 @note
 This is not currently implemented - images scale to fit the bounds when in scale mode, and are
 drawn at their native size in crop mode.
 @param scale a scaling value, 1.0 = 100% 
 */
- (void)setImageScale:(CGFloat)scale
{
    if (scale != m_imageScale) {
        [[[self undoManager] prepareWithInvocationTarget:self] setImageScale:[self imageScale]];
        [self notifyVisualChange];
        m_imageScale = scale;
        [self notifyVisualChange];
    }
}

/** @brief Get the scale factor for the image
 @note
 This is not currently implemented - images scale to fit the bounds when in scale mode, and are
 drawn at their native size in crop mode.
 @return the scale
 */
- (CGFloat)imageScale
{
    return m_imageScale;
}

/** @brief Set the offset position for the image
 @note
 The default is 0,0. The value is the distance in points from the top, left corner of the shape's
 bounds to the top, left corner of the image
 @param imgoff the offset position 
 */
- (void)setImageOffset:(NSPoint)imgoff
{
    if (!NSEqualPoints(imgoff, m_imageOffset)) {
        [[[self undoManager] prepareWithInvocationTarget:self] setImageOffset:[self imageOffset]];
        [self notifyVisualChange];
        m_imageOffset = imgoff;
        [self notifyVisualChange];
    }
}

/** @brief Get the offset position for the image
 @note
 The default is 0,0. The value is the distance in points from the top, left corner of the shape's
 bounds to the top, left corner of the image
 @return the image offset
 */
- (NSPoint)imageOffset
{
    return m_imageOffset;
}

/** @brief Set the display mode for the object - crop image or scale it
 @note
 The default is scale. 
 @param crop a mode value
 */
- (void)setImageCroppingOptions:(DKImageCroppingOptions)crop
{
    if (crop != mImageCropping) {
        [[[self undoManager] prepareWithInvocationTarget:self] setImageCroppingOptions:[self imageCroppingOptions]];
        [self notifyVisualChange];
        mImageCropping = crop;
        [self notifyVisualChange];
    }
}

/** @brief Get the display mode for the object - crop image or scale it
 @note
 The default is scale. 
 @return a mode value
 */
- (DKImageCroppingOptions)imageCroppingOptions
{
    return mImageCropping;
}

#pragma mark -

- (void)drawImage
{
    // the image must be transformed to the object's scale, rotation and position. This is achieved by concatenating the transform
    // to the current graphics context.

    SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
        NSAffineTransform* xt = [self containerTransform];

    [[self transformedPath] addClip];

    NSAffineTransform* tx = [self imageTransform];
    [tx appendTransform:xt];
    [tx concat];

    NSRect ir;

    ir.size = [[self image] size];

    if ([self imageCroppingOptions] == kDKImageScaleToPath) {
        ir.origin.x = m_imageOffset.x - (ir.size.width / 2.0);
        ir.origin.y = m_imageOffset.y - (ir.size.height / 2.0);
    } else {
        ir.origin.x = m_imageOffset.x;
        ir.origin.y = m_imageOffset.y;
    }

    // render at high quality

    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [[self image] setFlipped:[[NSGraphicsContext currentContext] isFlipped]];

    [[self image] drawInRect:ir
                    fromRect:NSZeroRect
                   operation:[self compositingOperation]
                    fraction:[self imageOpacity]];

    RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
}

- (NSAffineTransform*)imageTransform
{
    NSAffineTransform* tfm = [NSAffineTransform transform];
    NSAffineTransform* twl = [self imageTransformWithoutLocation];
    NSPoint loc;

    if ([self imageCroppingOptions] == kDKImageScaleToPath)
        loc = [self location];
    else
        loc = [self locationIgnoringOffset];

    [tfm translateXBy:loc.x
                  yBy:loc.y];
    [twl appendTransform:tfm];
    return twl;
}

- (NSAffineTransform*)imageTransformWithoutLocation
{
    NSSize si = [[self image] size];
    NSSize sc = [self size];
    CGFloat sx, sy;

    NSAffineTransform* xform = [NSAffineTransform transform];

    if ([self imageCroppingOptions] == kDKImageScaleToPath) {
        si.width /= [self imageScale];
        si.height /= [self imageScale];
        sx = sc.width / si.width;
        sy = sc.height / si.height;

        [xform rotateByRadians:[self angle]];

        if (sx != 0.0 && sy != 0.0)
            [xform scaleXBy:sx
                        yBy:sy];

        [xform translateXBy:-[self offset].width * si.width
            yBy:-[self offset].height * si.height];
    } else {
        // cropping is based on the top, left point not the centre
        // TO DO - doesn't take into account flipped shape correctly

        [xform rotateByRadians:[self angle]];
        [xform translateXBy:(-0.5 * sc.width)
                        yBy:(-0.5 * sc.height)];
    }

    return xform;
}

#pragma mark -

/** @brief Select whether the object displays using crop or scale modes
 @note
 This action method uses the sender's tag value as the cropping mode to set. It can be connected
 directly to a menu item with a suitable tag set for example.
 @param sender the message sender
 */
- (IBAction)selectCropOrScaleAction:(id)sender
{
    DKImageCroppingOptions opt = (DKImageCroppingOptions)[sender tag];

    if (opt != [self imageCroppingOptions]) {
        [self setImageCroppingOptions:opt];

        if (opt == kDKImageScaleToPath)
            [[self undoManager] setActionName:NSLocalizedString(@"Scale Image To Path", @"undo string for scale image to path")];
        else
            [[self undoManager] setActionName:NSLocalizedString(@"Crop Image To Path", @"undo string for crop image to path")];
    }
}

/** @brief Toggle between image drawn on top and image drawn below the rest of the style
 @param sender the message sender
 */
- (IBAction)toggleImageAboveAction:(id)sender
{
// user action permits the image on top setting to be flipped

#pragma unused(sender)

    [self setImageDrawsOnTop:![self imageDrawsOnTop]];
    [[self undoManager] setActionName:NSLocalizedString(@"Image On Top", @"undo string for image on top")];
}

/** @brief Copy the image directly to the pasteboard.
 @note
 A normal "Copy" does place an image of the object on the pb, but that is the whole object with
 all style elements based on the bounds. For some work, such as uing images for pattern fills,
 that's not appropriate, so this action allows you to extract the internal image.
 @param sender the message sender
 */
- (IBAction)copyImage:(id)sender
{
#pragma unused(sender)

    [self writeImageToPasteboard:[NSPasteboard generalPasteboard]];
}

/** @brief Replace the shape's image with one from the pasteboard if possible.
 @param sender the message sender
 */
- (IBAction)pasteImage:(id)sender
{
#pragma unused(sender)

    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    if ([self setImageWithPasteboard:pb]) {
        [[self undoManager] setActionName:NSLocalizedString(@"Paste Image Into Shape", @"undo string for paste image into shape")];
    }
}

/** @brief Resizes the shape to exactly fit the image at its original size.
 @note
 Cropped images remain in the same visual location that they are currently at, with the shape's
 frame moved to fit around it exactly. Scaled images are resized to the original size and the object's
 location remains the same. A side effect is to reset any offset, image offset, but not the angle.
 @param sender the message sender
 */
- (IBAction)fitToImage:(id)sender
{
#pragma unused(sender)

    if ([self imageCroppingOptions] == kDKImageScaleToPath) {
        [self setImageOffset:NSZeroPoint];

        NSSize is = [[self image] size];

        is.width *= [self imageScale];
        is.height *= [self imageScale];
        [self setImageScale:1.0];
        [self setSize:is];
    } else {
        // where is the top, left corner of the image?

        NSAffineTransform* tfm = [self imageTransform];
        NSPoint p = [self imageOffset];

        p = [tfm transformPoint:p];

        // this is where the new top, left corner of the bounds needs to be
        // reset any offset to the centre

        [self setOffset:NSZeroSize];
        [self setSize:[[self image] size]];
        [self setImageOffset:NSZeroPoint];

        // the rotation isn't reset - take it into account

        tfm = [self transform];
        NSPoint topLeft = [tfm transformPoint:NSMakePoint(-0.5, -0.5)];

        [self offsetLocationByX:p.x - topLeft.x
                            byY:p.y - topLeft.y];
    }
    [[self hotspotForPartCode:mImageOffsetPartcode] setRelativeLocation:NSZeroPoint];
    [[self undoManager] setActionName:NSLocalizedString(@"Fit To Image", @"undo string for fit to image")];
}

#pragma mark -
#pragma mark As a DKDrawableObject

/** @brief Draws the object
 */
- (void)drawContent
{
    if ([self isBeingHitTested]) {
        [[NSColor grayColor] set];
        [[self renderingPath] fill];
    } else {
        if (![self imageDrawsOnTop])
            [self drawImage];

        [super drawContent];

        if ([self imageDrawsOnTop])
            [self drawImage];
    }
}

/** @brief Add contextual menu items pertaining to the current object's context
 @param themenu a menu object to add items to
 @return YES
 */
- (BOOL)populateContextualMenu:(NSMenu*)theMenu
{
    [super populateContextualMenu:theMenu];

    [theMenu addItem:[NSMenuItem separatorItem]];

    [[theMenu addItemWithTitle:NSLocalizedString(@"Fit To Image", @"menu item for fit to image")
                        action:@selector(fitToImage:)
                 keyEquivalent:@""] setTarget:self];
    [[theMenu addItemWithTitle:NSLocalizedString(@"Copy Image", @"menu item for copy image")
                        action:@selector(copyImage:)
                 keyEquivalent:@""] setTarget:self];

    if ([NSImage canInitWithPasteboard:[NSPasteboard generalPasteboard]])
        [[theMenu addItemWithTitle:NSLocalizedString(@"Paste Image", @"menu item for Paste Image")
                            action:@selector(pasteImage:)
                     keyEquivalent:@""] setTarget:self];

    return YES;
}

- (NSString*)undoActionNameForPartCode:(NSInteger)pc
{
    if (pc == mImageOffsetPartcode)
        return NSLocalizedString(@"Move Image Origin", @"undo string for move image origin");
    else
        return [super undoActionNameForPartCode:pc];
}

- (void)setContainer:(id<DKDrawableContainer>)container
{
    // when an image shape is transferred to a new container, and it is using an image key, the data must be copied from the old image manager
    // to the image manager of the new container, to maintain data integrity when the object is subsequently archived. Otherwise the image
    // may get "lost" and the shape will be unable to be dearchived.

    [self transferImageKeyToNewContainer:container];
    [super setContainer:container];
}

#pragma mark -
#pragma mark As an NSObject

/** @brief Deallocates the object
 */
- (void)dealloc
{
    [m_image release];
    [mImageKey release];
    [mOriginalImageData release];
    [super dealloc];
}

#pragma mark -
#pragma mark As part of the DKHotspotDelegate protocol

/** @brief Saves the current cursor and sets the hand cursor
 @param hs the hotspot hit
 @param event the mouse down event
 @param view the currentview */
- (void)hotspot:(DKHotspot*)hs willBeginTrackingWithEvent:(NSEvent*)event inView:(NSView*)view
{
#pragma unused(hs)
#pragma unused(event)
#pragma unused(view)

    [[NSCursor currentCursor] push];

    NSInteger pc = [hs partcode];

    if (pc == mImageOffsetPartcode) {
        [[NSCursor openHandCursor] set];
    }
}

/** @brief Moves the hotspot to a new place dragging the image offset with it
 @param hs the hotspot hit
 @param event the mouse down event
 @param view the currentview */
- (void)hotspot:(DKHotspot*)hs isTrackingWithEvent:(NSEvent*)event inView:(NSView*)view
{
    NSInteger pc = [hs partcode];

    if (pc == mImageOffsetPartcode) {
        [[NSCursor closedHandCursor] set];

        NSPoint p = [view convertPoint:[event locationInWindow]
                              fromView:nil];

        NSPoint offset;

        p = [[self inverseTransform] transformPoint:p];

        p.x = LIMIT(p.x, -0.5, 0.5);
        p.y = LIMIT(p.y, -0.5, 0.5);
        [hs setRelativeLocation:p];
        [self notifyVisualChange];

        offset.x = p.x * [[self image] size].width;
        offset.y = p.y * [[self image] size].height;
        [self setImageOffset:offset];
    }
}

/** @brief Restores hte cursor
 @param hs the hotspot hit
 @param event the mouse down event
 @param view the currentview */
- (void)hotspot:(DKHotspot*)hs didEndTrackingWithEvent:(NSEvent*)event inView:(NSView*)view
{
#pragma unused(hs)
#pragma unused(event)
#pragma unused(view)

    [NSCursor pop];
}

#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

/** @brief Receive a drag onto this object
 @note
 DK allows images to be simply dragged right into an existing image shape, replacing the current image
 @param sender the drag sender
 @return YES if the operation could be carried out, NO otherwise */
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard* pb = [sender draggingPasteboard];

    if ([self setImageWithPasteboard:pb])
        return YES;
    else
        return [super performDragOperation:sender];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol

/** @brief Archive the object
 @param coder a coder */
- (void)encodeWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    [super encodeWithCoder:coder];

    // if there's an image key, just archive that and the data instead of the expanded image itself. The image can then be efficiently
    // recovered from the image data cache using the key. The data itself is also archived, though only one copy is actually saved.
    // This allows us to recover the image under all circumstances

    if (mImageKey) {
        [coder encodeObject:[self imageKey]
                     forKey:@"DKImageShape_imageKey"];
        [coder encodeObject:[self imageData]
                     forKey:@"DKImageShape_imageData"];
    } else
        [coder encodeObject:[self image]
                     forKey:@"image"];

    [coder encodeDouble:[self imageOpacity]
                 forKey:@"imageOpacity"];
    [coder encodeDouble:[self imageScale]
                 forKey:@"imageScale"];
    [coder encodePoint:[self imageOffset]
                forKey:@"imageOffset"];
    [coder encodeBool:[self imageDrawsOnTop]
               forKey:@"imageOnTop"];
    [coder encodeInteger:[self compositingOperation]
                  forKey:@"imageComp"];
    [coder encodeInteger:[self imageCroppingOptions]
                  forKey:@"DKImageShape_croppingOptions"];
}

/** @brief Dearchive the object
 @param coder a coder
 @return the object */
- (id)initWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    self = [super initWithCoder:coder];
    if (self != nil) {
        // first see if an image key was archived. If so, we can recover our image from the image archive. If not,
        // load the original archived image.

        NSString* imKey = [coder decodeObjectForKey:@"DKImageShape_imageKey"];

        if (imKey) {
            // if we have a ref to the image data itself, initialise using that - it's much more straightforward
            // than trying to determine which image manager to use in every case. Older files don't have this (b6 onwards).
            // This recovers the image even if we have no container, etc. If a container is later set, the image data is
            // consolidated with whatever image manager is in use for the container.

            NSData* imgData = [coder decodeObjectForKey:@"DKImageShape_imageData"];

            if (imgData)
                [self setImageData:imgData];
            else {
                // older method: create image from original data in the master cache & store the key

                [self setImageWithKey:imKey
                                coder:coder];
            }
        } else
            [self setImage:[coder decodeObjectForKey:@"image"]];

        [self setImageOpacity:[coder decodeDoubleForKey:@"imageOpacity"]];
        [self setImageScale:[coder decodeDoubleForKey:@"imageScale"]];
        [self setImageOffset:[coder decodePointForKey:@"imageOffset"]];
        [self setImageDrawsOnTop:[coder decodeBoolForKey:@"imageOnTop"]];
        [self setCompositingOperation:[coder decodeIntegerForKey:@"imageComp"]];
        [self setImageCroppingOptions:[coder decodeIntegerForKey:@"DKImageShape_croppingOptions"]];

        mImageOffsetPartcode = [[[self hotspots] lastObject] partcode];
    }
    return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol

/** @brief Copy the object
 @param zone a zone
 @return a copy of the object */
- (id)copyWithZone:(NSZone*)zone
{
    DKImageShape* copy = [super copyWithZone:zone];

    if ([self imageData])
        [copy setImageData:[self imageData]];
    else {
        [copy setImage:[self image]];
        [copy setImageKey:[self imageKey]];
    }
    [copy setImageOpacity:[self imageOpacity]];
    [copy setImageScale:[self imageScale]];
    [copy setImageOffset:[self imageOffset]];
    [copy setImageDrawsOnTop:[self imageDrawsOnTop]];
    [copy setCompositingOperation:[self compositingOperation]];
    [copy setImageCroppingOptions:[self imageCroppingOptions]];

    copy->mImageOffsetPartcode = mImageOffsetPartcode;
    [[copy hotspotForPartCode:mImageOffsetPartcode] setDelegate:copy];

    return copy;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

/** @brief Enable menu items this object can respond to
 @param item the menu item
 @return YES if the item is enabled, NO otherwise */
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    if ([item action] == @selector(vectorize:) ||
        [item action] == @selector(fitToImage:))
        return ![self locked];

    if ([item action] == @selector(selectCropOrScaleAction:)) {
        [item setState:([item tag] == (NSInteger)[self imageCroppingOptions]) ? NSOnState : NSOffState];
        return ![self locked];
    }

    if ([item action] == @selector(toggleImageAboveAction:)) {
        [item setState:[self imageDrawsOnTop] ? NSOnState : NSOffState];
        return ![self locked];
    }

    if ([item action] == @selector(copyImage:))
        return YES;

    if ([item action] == @selector(pasteImage:)) {
        return [NSImage canInitWithPasteboard:[NSPasteboard generalPasteboard]] && ![self locked];
    }

    return [super validateMenuItem:item];
}

@end
