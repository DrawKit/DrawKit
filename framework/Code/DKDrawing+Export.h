/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawing.h"

/** @brief This category provides methods for exporting drawings in a variety of formats, such as TIFF, JPEG and PNG.

This category provides methods for exporting drawings in a variety of formats, such as TIFF, JPEG and PNG. As these are all bitmap formats,
a way to specify the resolution of the exported image is also provided. All methods return NSData that is the formatted image data - this can be
written directly as a file of the designated kind.

All image export starts with the pdf representation of the drawing as exported directly by DKDrawing. This is then imaged into a new bitmap image
rep before conversion to the final format. The use of the pdf data ensures that results are consistent and require no major knowledge of the
drawing's internals.

All images are exported in 24/32 bit full colour.

dpi is specified directly, e.g. 72 for 72 dpi, 150 for 150 dpi, etc. The image size will be the drawing size scaled by the dpi, so a 144dpi image
will be twice as wide and twice as high as the drawing. If the dpi passed does not result in a whole multiple of the drawing size, it is rounded up
to the nearest whole value that is.

This uses Image I/O to perform the data encoding.
*/
@interface DKDrawing (Export)

// generate the master bitmap (from pdf data):

/** @brief Creates the initial bitmap image that the various bitmap formats are created from.

 Returned ref is autoreleased. The image always has an alpha channel, but the <hasAlpha> flag will
 paint the background in the paper colour if hasAlpha is NO.
 @param dpi the resolution of the image in dots per inch.
 @param hasAlpha specifies whether the image is painted in the background paper colour or not.
 @param relScale scaling factor, 1.0 = actual size, 0.5 = half size, etc.
 @return a CG image that is used to generate the export image formats
 */
- (CGImageRef)CGImageWithResolution:(NSInteger)dpi hasAlpha:(BOOL)hasAlpha;
- (CGImageRef)CGImageWithResolution:(NSInteger)dpi hasAlpha:(BOOL)hasAlpha relativeScale:(CGFloat)relScale;

// convert to various formats:

/** @brief Returns JPEG data for the drawing.
 @param props various parameters and properties
 @return JPEG data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (NSData*)JPEGDataWithProperties:(NSDictionary*)props;

/** @brief Returns TIFF data for the drawing.
 @param props various parameters and properties
 @return TIFF data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (NSData*)TIFFDataWithProperties:(NSDictionary*)props;

/** @brief Returns PNG data for the drawing.
 @param props various parameters and properties
 @return PNG data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (NSData*)PNGDataWithProperties:(NSDictionary*)props;

// convenience methods that set up the property dictionaries for you:

/** @brief Returns JPEG data for the drawing or nil if there was a problem

 This is a convenience wrapper around the dictionary-based methods above
 @param dpi the resolution in dots per inch
 @param quality a value 0..1 that indicates the amount of compression - 0 = max, 1 = none.
 @param progressive YES if the data is progressive, NO otherwise
 @return JPEG data
 */
- (NSData*)JPEGDataWithResolution:(NSInteger)dpi quality:(CGFloat)quality progressive:(BOOL)progressive;

/** @brief Returns TIFF data for the drawing or nil if there was a problem

 This is a convenience wrapper around the dictionary-based methods above
 @param dpi the resolution in dots per inch
 @param compType a valid TIFF compression type (see NSBitMapImageRep.h)
 @return TIFF data
 */
- (NSData*)TIFFDataWithResolution:(NSInteger)dpi compressionType:(NSTIFFCompression)compType;
- (NSData*)PNGDataWithResolution:(NSInteger)dpi gamma:(CGFloat)gamma interlaced:(BOOL)interlaced;

/** @brief Returns JPEG data for the drawing at 50% actual size, with 50% quality

 Useful for e.g. generating QuickLook thumbnails
 @return JPEG data
 */
- (NSData*)thumbnailData;

// another approach - get an array of bitmaps from each layer

/** @brief Returns an array of bitmaps (NSBitmapImageReps) one per layer

 The lowest index is the bottom layer. Hidden layers and non-printing layers are excluded.
 @param dpi the desired resolution in dots per inch.
 @return an array of bitmaps
 */
- (NSArray*)layerBitmapsWithDPI:(NSUInteger)dpi;

/** @brief Returns TIFF data

 Each layer is written as a separate image. This is not the same as a layered TIFF however.
 @param dpi the desired resolution in dots per inch.
 @return TIFF data
 */
- (NSData*)multipartTIFFDataWithResolution:(NSUInteger)dpi;

@end

extern NSString* kDKExportPropertiesResolution;
extern NSString* kDKExportedImageHasAlpha;
extern NSString* kDKExportedImageRelativeScale;
