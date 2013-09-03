///**********************************************************************************************************************************
///  DKDrawing+Export.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 14/06/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawing.h"


@interface DKDrawing (Export)

// generate the master bitmap (from pdf data):

- (CGImageRef)			CGImageWithResolution:(NSInteger) dpi hasAlpha:(BOOL) hasAlpha;
- (CGImageRef)			CGImageWithResolution:(NSInteger) dpi hasAlpha:(BOOL) hasAlpha relativeScale:(CGFloat) relScale;

// convert to various formats:

- (NSData*)				JPEGDataWithProperties:(NSDictionary*) props;
- (NSData*)				TIFFDataWithProperties:(NSDictionary*) props;
- (NSData*)				PNGDataWithProperties:(NSDictionary*) props;

// convenience methods that set up the property dictionaries for you:

- (NSData*)				JPEGDataWithResolution:(NSInteger) dpi quality:(CGFloat) quality progressive:(BOOL) progressive;
- (NSData*)				TIFFDataWithResolution:(NSInteger) dpi compressionType:(NSTIFFCompression) compType;
- (NSData*)				PNGDataWithResolution:(NSInteger) dpi gamma:(CGFloat) gamma interlaced:(BOOL) interlaced;

- (NSData*)				thumbnailData;

// another approach - get an array of bitmaps from each layer

- (NSArray*)			layerBitmapsWithDPI:(NSUInteger) dpi;
- (NSData*)				multipartTIFFDataWithResolution:(NSUInteger) dpi;

@end



extern NSString* kDKExportPropertiesResolution;
extern NSString* kDKExportedImageHasAlpha;
extern NSString* kDKExportedImageRelativeScale;



/*

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


