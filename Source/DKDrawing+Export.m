/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawing+Export.h"
#import "DKLayer+Metadata.h"
#import "LogEvent.h"

NSString* kDKExportPropertiesResolution = @"kDKExportPropertiesResolution";
NSString* kDKExportedImageHasAlpha = @"kDKExportedImageHasAlpha";
NSString* kDKExportedImageRelativeScale = @"kDKExportedImageRelativeScale";

@implementation DKDrawing (Export)

/** @brief Creates the initial bitmap image that the various bitmap formats are created from.

 Returned ref is autoreleased. The image always has an alpha channel, but the <hasAlpha> flag will
 paint the background in the paper colour if hasAlpha is NO.
 @param dpi the resolution of the image in dots per inch.
 @param hasAlpha specifies whether the image is painted in the background paper colour or not.
 @param relScale scaling factor, 1.0 = actual size, 0.5 = half size, etc.
 @return a CG image that is used to generate the export image formats
 */
- (CGImageRef)CGImageWithResolution:(NSInteger)dpi hasAlpha:(BOOL)hasAlpha
{
	return [self CGImageWithResolution:dpi
							  hasAlpha:hasAlpha
						 relativeScale:1.0];
}

- (CGImageRef)CGImageWithResolution:(NSInteger)dpi hasAlpha:(BOOL)hasAlpha relativeScale:(CGFloat)relScale

{
	NSPDFImageRep* pdfRep = [NSPDFImageRep imageRepWithData:[self pdf]];

	NSAssert(pdfRep != nil, @"couldn't create pdf image rep");
	NSAssert(relScale > 0, @"scale factor must be greater than zero");

	if (pdfRep == nil)
		return nil;

	// create a bitmap rep of the requisite size.

	NSSize bmSize = [self drawingSize];

	bmSize.width = ceil((bmSize.width * (CGFloat)dpi * relScale) / 72.0);
	bmSize.height = ceil((bmSize.height * (CGFloat)dpi * relScale) / 72.0);

	NSBitmapImageRep* bmRep;

	bmRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
													pixelsWide:bmSize.width
													pixelsHigh:bmSize.height
												 bitsPerSample:8
											   samplesPerPixel:4
													  hasAlpha:YES
													  isPlanar:NO
												colorSpaceName:NSCalibratedRGBColorSpace
												   bytesPerRow:0
												  bitsPerPixel:0];

	NSAssert(bmRep != nil, @"couldn't create bitmap for export");

	if (bmRep == nil)
		return nil;

	LogEvent_(kInfoEvent, @"size = %@, dpi = %ld, rep = %@", NSStringFromSize(bmSize), (long)dpi, bmRep);

	NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bmRep];
	[bmRep release];

	SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext : context];

	[context setShouldAntialias:YES];
	[context setImageInterpolation:NSImageInterpolationHigh];

	NSRect destRect = NSZeroRect;
	destRect.size = bmSize;

	// if not preserving alpha, paint the background in the paper colour

	if (!hasAlpha) {
		[[self paperColour] set];
		NSRectFill(destRect);
	}

	// draw the PDF rep into the bitmap rep.

	[pdfRep drawInRect:destRect];

	RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
		CGImageRef image = CGBitmapContextCreateImage([context graphicsPort]);

	return (CGImageRef)CFAutorelease(image);
}

/** @brief Returns JPEG data for the drawing.
 @param props various parameters and properties
 @return JPEG data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (NSData*)JPEGDataWithProperties:(NSDictionary*)props
{
	NSAssert(props != nil, @"cannot create JPEG data - properties were nil");

	// convert properties into a form useful to Image I/O

	NSInteger dpi = [[props objectForKey:kDKExportPropertiesResolution] integerValue];

	if (dpi == 0)
		dpi = 72;

	CGFloat scale = [[props objectForKey:kDKExportedImageRelativeScale] doubleValue];

	if (scale == 0)
		scale = 1.0;

	NSMutableDictionary* options = [[props mutableCopy] autorelease];

	[options setObject:@(dpi)
				forKey:(NSString*)kCGImagePropertyDPIWidth];
	[options setObject:@(dpi)
				forKey:(NSString*)kCGImagePropertyDPIHeight];

	NSNumber* value = [props objectForKey:NSImageCompressionFactor];
	if (value == nil)
		value = @0.67;

	[options setObject:value
				forKey:(NSString*)kCGImageDestinationLossyCompressionQuality];

	value = [props objectForKey:NSImageProgressive];
	if (value != nil)
		[options setObject:@{(NSString*)kCGImagePropertyJFIFIsProgressive: value}
					forKey:(NSString*)kCGImagePropertyJFIFDictionary];

	// generate the bitmap image at the required size

	CGImageRef image = [self CGImageWithResolution:dpi
										  hasAlpha:NO
									 relativeScale:scale];

	NSAssert(image != nil, @"could not create image for JPEG export");

	if (image == nil)
		return nil;

	// encode it to data using Image I/O

	NSMutableData *data = [[NSMutableData alloc] init];
	CGImageDestinationRef destRef = CGImageDestinationCreateWithData((CFMutableDataRef)data, kUTTypeJPEG, 1, NULL);

	CGImageDestinationAddImage(destRef, image, (CFDictionaryRef)options);

	BOOL result = CGImageDestinationFinalize(destRef);

	CFRelease(destRef);

	if (result) {
		return [data autorelease];
	} else {
		[data release];
		return nil;
	}
}

/** @brief Returns TIFF data for the drawing.
 @param props various parameters and properties
 @return TIFF data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (NSData*)TIFFDataWithProperties:(NSDictionary*)props
{
	NSAssert(props != nil, @"cannot create TIFF data - properties were nil");

	NSInteger dpi = [[props objectForKey:kDKExportPropertiesResolution] integerValue];

	if (dpi == 0)
		dpi = 72;

	CGFloat scale = [[props objectForKey:kDKExportedImageRelativeScale] doubleValue];

	if (scale == 0)
		scale = 1.0;

	NSMutableDictionary* options = [[props mutableCopy] autorelease];

	[options setObject:@(dpi)
				forKey:(NSString*)kCGImagePropertyDPIWidth];
	[options setObject:@(dpi)
				forKey:(NSString*)kCGImagePropertyDPIHeight];

	// set up a TIFF-specific dictionary

	NSNumber* value;

	NSMutableDictionary* tiffInfo = [NSMutableDictionary dictionary];

	value = [props objectForKey:NSImageCompressionMethod];
	if (value != nil)
		[tiffInfo setObject:value
					 forKey:(NSString*)kCGImagePropertyTIFFCompression];

	[tiffInfo setObject:[NSString stringWithFormat:@"DrawKit %@ (c)2008 apptree.net", [[self class] drawkitVersionString]]
				 forKey:(NSString*)kCGImagePropertyTIFFSoftware];

	NSString* metaStr;

	metaStr = [[self drawingInfo] objectForKey:[kDKDrawingInfoDraughter lowercaseString]];

	if (metaStr)
		[tiffInfo setObject:metaStr
					 forKey:(NSString*)kCGImagePropertyTIFFArtist];

	metaStr = [[self drawingInfo] objectForKey:[kDKDrawingInfoDrawingNumber lowercaseString]];

	if (metaStr)
		[tiffInfo setObject:metaStr
					 forKey:(NSString*)kCGImagePropertyTIFFDocumentName];

	[tiffInfo setObject:[[NSDate date] description]
				 forKey:(NSString*)kCGImagePropertyTIFFDateTime];

	[options setObject:tiffInfo
				forKey:(NSString*)kCGImagePropertyTIFFDictionary];

	value = [props objectForKey:kDKExportedImageHasAlpha];

	BOOL hasAlpha = NO;

	if (value != nil)
		hasAlpha = [value boolValue];

	// generate the bitmap image at the required size

	CGImageRef image = [self CGImageWithResolution:dpi
										  hasAlpha:hasAlpha
									 relativeScale:scale];

	NSAssert(image != nil, @"could not create image for TIFF export");

	if (image == nil)
		return nil;

	// encode it to data using Image I/O

	NSMutableData *data = [[NSMutableData alloc] init];
	CGImageDestinationRef destRef = CGImageDestinationCreateWithData((CFMutableDataRef)data, kUTTypeTIFF, 1, NULL);

	CGImageDestinationAddImage(destRef, image, (CFDictionaryRef)options);

	BOOL result = CGImageDestinationFinalize(destRef);

	CFRelease(destRef);

	if (result) {
		return [data autorelease];
	} else {
		[data release];
		return nil;
	}
}

/** @brief Returns PNG data for the drawing.
 @param props various parameters and properties
 @return PNG data or nil if there was a problem
 DrawKit properties that control the data generation. Users may find the convenience methods
 below easier to use for many typical situations.
 */
- (NSData*)PNGDataWithProperties:(NSDictionary*)props
{
	NSAssert(props != nil, @"cannot create PNG data - properties were nil");

	NSInteger dpi = [[props objectForKey:kDKExportPropertiesResolution] integerValue];

	if (dpi == 0)
		dpi = 72;

	CGFloat scale = [[props objectForKey:kDKExportedImageRelativeScale] doubleValue];

	if (scale == 0)
		scale = 1.0;

	NSMutableDictionary* options = [[props mutableCopy] autorelease];

	[options setObject:@(dpi)
				forKey:(NSString*)kCGImagePropertyDPIWidth];
	[options setObject:@(dpi)
				forKey:(NSString*)kCGImagePropertyDPIHeight];

	NSNumber* value;

	value = [props objectForKey:NSImageInterlaced];
	if (value != nil)
		[options setObject:@{(NSString*)kCGImagePropertyPNGInterlaceType: value}
					forKey:(NSString*)kCGImagePropertyPNGDictionary];

	// generate the bitmap image at the required size

	CGImageRef image = [self CGImageWithResolution:dpi
										  hasAlpha:NO
									 relativeScale:scale];

	NSAssert(image != nil, @"could not create image for PNG export");

	if (image == nil)
		return nil;

	// encode it to data using Image I/O

	NSMutableData *data = [[NSMutableData alloc] init];
	CGImageDestinationRef destRef = CGImageDestinationCreateWithData((CFMutableDataRef)data, kUTTypePNG, 1, NULL);

	CGImageDestinationAddImage(destRef, image, (CFDictionaryRef)options);

	BOOL result = CGImageDestinationFinalize(destRef);

	CFRelease(destRef);

	if (result) {
		return [data autorelease];
	} else {
		[data release];
		return nil;
	}
}

#pragma mark -
#pragma mark - high - level easy use methods

/** @brief Returns JPEG data for the drawing or nil if there was a problem

 This is a convenience wrapper around the dictionary-based methods above
 @param dpi the resolution in dots per inch
 @param quality a value 0..1 that indicates the amount of compression - 0 = max, 1 = none.
 @param progressive YES if the data is progressive, NO otherwise
 @return JPEG data
 */
- (NSData*)JPEGDataWithResolution:(NSInteger)dpi quality:(CGFloat)quality progressive:(BOOL)progressive
{
	NSDictionary* props = @{kDKExportPropertiesResolution: @(dpi),
							NSImageCompressionFactor: @(quality),
							NSImageProgressive: @(progressive)};

	return [self JPEGDataWithProperties:props];
}

/** @brief Returns TIFF data for the drawing or nil if there was a problem

 This is a convenience wrapper around the dictionary-based methods above
 @param dpi the resolution in dots per inch
 @param compType a valid TIFF compression type (see NSBitMapImageRep.h)
 @return TIFF data
 */
- (NSData*)TIFFDataWithResolution:(NSInteger)dpi compressionType:(NSTIFFCompression)compType
{
	NSDictionary* props = @{kDKExportPropertiesResolution: @(dpi),
							NSImageCompressionMethod:@(compType)};

	return [self TIFFDataWithProperties:props];
}

/** @brief Returns PNG data for the drawing or nil if there was a problem

 This is a convenience wrapper around the dictionary-based methods above
 @param dpi the resolution in dots per inch
 @param gamma the gamma value 0..1
 @param interlaced YES to interlace the image, NO otherwise
 @return PNG data
 */
- (NSData*)PNGDataWithResolution:(NSInteger)dpi gamma:(CGFloat)gamma interlaced:(BOOL)interlaced
{
	NSDictionary* props = @{kDKExportPropertiesResolution: @(dpi),
							NSImageGamma: @(gamma),
							NSImageInterlaced: @(interlaced)};

	return [self PNGDataWithProperties:props];
}

/** @brief Returns JPEG data for the drawing at 50% actual size, with 50% quality

 Useful for e.g. generating QuickLook thumbnails
 @return JPEG data
 */
- (NSData*)thumbnailData
{
	NSDictionary* props = @{kDKExportPropertiesResolution: @72,
							NSImageCompressionFactor: @0.5,
							NSImageProgressive: @YES,
							kDKExportedImageRelativeScale: @0.5};

	return [self JPEGDataWithProperties:props];
}

/** @brief Returns an array of bitmaps (NSBitmapImageReps) one per layer

 The lowest index is the bottom layer. Hidden layers and non-printing layers are excluded.
 @param dpi the desired resolution in dots per inch.
 @return an array of bitmaps
 */
- (NSArray<NSBitmapImageRep*>*)layerBitmapsWithDPI:(NSUInteger)dpi
{
	NSMutableArray<NSBitmapImageRep*>* layerBitmaps = [NSMutableArray array];
	NSEnumerator* iter = [[self flattenedLayers] reverseObjectEnumerator];

	for (DKLayer* layer in iter) {
		if ([layer visible] && [layer shouldDrawToPrinter]) {
			NSBitmapImageRep* rep = [layer bitmapRepresentationWithDPI:dpi];
			if (rep)
				[layerBitmaps addObject:rep];
		}
	}

	return layerBitmaps;
}

/** @brief Returns TIFF data

 Each layer is written as a separate image. This is not the same as a layered TIFF however.
 @param dpi the desired resolution in dots per inch.
 @return TIFF data
 */
- (NSData*)multipartTIFFDataWithResolution:(NSUInteger)dpi
{
	return [NSBitmapImageRep TIFFRepresentationOfImageRepsInArray:[self layerBitmapsWithDPI:dpi]];
}

@end
