/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawing.h"

NS_ASSUME_NONNULL_BEGIN

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

 Returned ref is autoreleased. The image always has an alpha channel, but the \c hasAlpha flag will
 paint the background in the paper colour if \c hasAlpha is NO.
 @param dpi the resolution of the image in dots per inch.
 @param hasAlpha specifies whether the image is painted in the background paper colour or not.
 @return a CG image that is used to generate the export image formats
 */
- (nullable CGImageRef)CGImageWithResolution:(NSInteger)dpi hasAlpha:(BOOL)hasAlpha CF_RETURNS_NOT_RETAINED;
/** @brief Creates the initial bitmap image that the various bitmap formats are created from.
 
 Returned ref is autoreleased. The image always has an alpha channel, but the \c hasAlpha flag will
 paint the background in the paper colour if \c hasAlpha is NO.
 @param dpi the resolution of the image in dots per inch.
 @param hasAlpha specifies whether the image is painted in the background paper colour or not.
 @param relScale scaling factor, 1.0 = actual size, 0.5 = half size, etc.
 @return a CG image that is used to generate the export image formats
 */
- (nullable CGImageRef)CGImageWithResolution:(NSInteger)dpi hasAlpha:(BOOL)hasAlpha relativeScale:(CGFloat)relScale CF_RETURNS_NOT_RETAINED;

// convert to various formats:

/** @brief Returns JPEG data for the drawing.
 @param props various parameters and properties
 @return JPEG data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (nullable NSData*)JPEGDataWithProperties:(NSDictionary<NSBitmapImageRepPropertyKey,id>*)props;

/** @brief Returns TIFF data for the drawing.
 @param props various parameters and properties
 @return TIFF data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (nullable NSData*)TIFFDataWithProperties:(NSDictionary<NSBitmapImageRepPropertyKey,id>*)props;

/** @brief Returns PNG data for the drawing.
 @param props various parameters and properties
 @return PNG data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (nullable NSData*)PNGDataWithProperties:(NSDictionary<NSBitmapImageRepPropertyKey,id>*)props;

// convenience methods that set up the property dictionaries for you:

/** @brief Returns JPEG data for the drawing or nil if there was a problem

 This is a convenience wrapper around the dictionary-based methods above
 @param dpi the resolution in dots per inch
 @param quality a value 0..1 that indicates the amount of compression - 0 = max, 1 = none.
 @param progressive YES if the data is progressive, NO otherwise
 @return JPEG data
 */
- (nullable NSData*)JPEGDataWithResolution:(NSInteger)dpi quality:(CGFloat)quality progressive:(BOOL)progressive;

/** @brief Returns TIFF data for the drawing or nil if there was a problem

 This is a convenience wrapper around the dictionary-based methods above
 @param dpi the resolution in dots per inch
 @param compType a valid TIFF compression type (see NSBitMapImageRep.h)
 @return TIFF data
 */
- (nullable NSData*)TIFFDataWithResolution:(NSInteger)dpi compressionType:(NSTIFFCompression)compType;

/** @brief Returns PNG data for the drawing or nil if there was a problem
 
 This is a convenience wrapper around the dictionary-based methods above
 @param dpi the resolution in dots per inch
 @param gamma the gamma value 0..1
 @param interlaced YES to interlace the image, NO otherwise
 @return PNG data
 */
- (nullable NSData*)PNGDataWithResolution:(NSInteger)dpi gamma:(CGFloat)gamma interlaced:(BOOL)interlaced;

/** @brief Returns JPEG data for the drawing at 50% actual size, with 50% quality

 Useful for e.g. generating QuickLook thumbnails
 @return JPEG data
 */
- (nullable NSData*)thumbnailData;

// another approach - get an array of bitmaps from each layer

/** @brief Returns an array of bitmaps (NSBitmapImageReps) one per layer

 The lowest index is the bottom layer. Hidden layers and non-printing layers are excluded.
 @param dpi the desired resolution in dots per inch.
 @return an array of bitmaps
 */
- (NSArray<NSBitmapImageRep*>*)layerBitmapsWithDPI:(NSUInteger)dpi;

/** @brief Returns TIFF data

 Each layer is written as a separate image. This is not the same as a layered TIFF however.
 @param dpi the desired resolution in dots per inch.
 @return TIFF data
 */
- (nullable NSData*)multipartTIFFDataWithResolution:(NSUInteger)dpi;

@end

extern NSBitmapImageRepPropertyKey const kDKExportPropertiesResolution;
extern NSBitmapImageRepPropertyKey const kDKExportedImageHasAlpha;
extern NSBitmapImageRepPropertyKey const kDKExportedImageRelativeScale;

NS_ASSUME_NONNULL_END
