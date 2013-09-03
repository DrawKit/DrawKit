///**********************************************************************************************************************************
///  DKDrawing+Export.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 14/06/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawing+Export.h"
#import "DKLayer+Metadata.h"
#import "LogEvent.h"


NSString* kDKExportPropertiesResolution = @"kDKExportPropertiesResolution";
NSString* kDKExportedImageHasAlpha		= @"kDKExportedImageHasAlpha";
NSString* kDKExportedImageRelativeScale = @"kDKExportedImageRelativeScale";



@implementation DKDrawing (Export)


///*********************************************************************************************************************
///
/// method:			CGImageWithResolution:hasAlpha:
/// scope:			public instance method
/// description:	creates the initial bitmap image that the various bitmap formats are created from.
/// 
/// parameters:		<dpi> the resolution of the image in dots per inch.
///					<hasAlpha> specifies whether the image is painted in the background paper colour or not.
///					<relScale> scaling factor, 1.0 = actual size, 0.5 = half size, etc.
/// result:			a CG image that is used to generate the export image formats
///
/// notes:			returned ref is autoreleased. The image always has an alpha channel, but the <hasAlpha> flag will
///					paint the background in the paper colour if hasAlpha is NO.
///
///********************************************************************************************************************

- (CGImageRef)			CGImageWithResolution:(NSInteger) dpi hasAlpha:(BOOL) hasAlpha
{
	return [self CGImageWithResolution:dpi hasAlpha:hasAlpha relativeScale:1.0];
}




- (CGImageRef)			CGImageWithResolution:(NSInteger) dpi hasAlpha:(BOOL) hasAlpha relativeScale:(CGFloat) relScale

{
	NSPDFImageRep* pdfRep = [NSPDFImageRep imageRepWithData:[self pdf]];
	
	NSAssert( pdfRep != nil, @"couldn't create pdf image rep");
	NSAssert( relScale > 0, @"scale factor must be greater than zero");
	
	if( pdfRep == nil )
		return nil;
	
	// create a bitmap rep of the requisite size.
	
	NSSize	bmSize = [self drawingSize];
	
	bmSize.width = ceil(( bmSize.width * (CGFloat)dpi * relScale ) / 72.0f );
	bmSize.height = ceil(( bmSize.height * (CGFloat)dpi * relScale ) / 72.0f );
	
	NSBitmapImageRep* bmRep;
	
	bmRep = [[NSBitmapImageRep alloc]	initWithBitmapDataPlanes:NULL
										pixelsWide:bmSize.width
										pixelsHigh:bmSize.height
										bitsPerSample:8
										samplesPerPixel:4
										hasAlpha:YES
										isPlanar:NO
										colorSpaceName:NSCalibratedRGBColorSpace
										bytesPerRow:0
										bitsPerPixel:0];
										
	NSAssert( bmRep != nil, @"couldn't create bitmap for export");
	
	if( bmRep == nil )
		return nil;
	
	LogEvent_( kInfoEvent, @"size = %@, dpi = %d, rep = %@", NSStringFromSize( bmSize ), dpi, bmRep );
	
	NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bmRep];
	[bmRep release];
	
	SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:context];
	
	[context setShouldAntialias:YES];
	[context setImageInterpolation:NSImageInterpolationHigh];
	
	NSRect destRect = NSZeroRect;
	destRect.size = bmSize;
	
	// if not preserving alpha, paint the background in the paper colour
	
	if ( !hasAlpha )
	{
		[[self paperColour] set];
		NSRectFill( destRect );
	}
	
	// draw the PDF rep into the bitmap rep.

	[pdfRep drawInRect:destRect];
	
	RESTORE_GRAPHICS_CONTEXT			//[NSGraphicsContext restoreGraphicsState];
	
	CGImageRef	image = CGBitmapContextCreateImage([context graphicsPort]);
	
	return (CGImageRef)[(NSObject*)image autorelease];
}


///*********************************************************************************************************************
///
/// method:			JPEGDataWithProperties:
/// scope:			public instance method
/// description:	returns JPEG data for the drawing.
/// 
/// parameters:		<props> various parameters and properties
/// result:			JPEG data or nil if there was a problem
///
/// notes:			the properties can include a mixture of Image I/O properties, NSBitMapImageRep properties and
///					DrawKit properties that control the data generation. Users may find the convenience methods
///					below easier to use for many typical situations.
///
///********************************************************************************************************************

- (NSData*)				JPEGDataWithProperties:(NSDictionary*) props
{
	NSAssert( props != nil, @"cannot create JPEG data - properties were nil");
	
	// convert properties into a form useful to Image I/O
	
	NSInteger dpi = [[props objectForKey:kDKExportPropertiesResolution] integerValue];
	
	if( dpi == 0 )
		dpi = 72;
	
	CGFloat scale = [[props objectForKey:kDKExportedImageRelativeScale] doubleValue];
	
	if( scale == 0 )
		scale = 1.0;
		
	NSMutableDictionary* options = [[props mutableCopy] autorelease];
		
	[options setObject:[NSNumber numberWithInteger:dpi] forKey:(NSString*)kCGImagePropertyDPIWidth];
	[options setObject:[NSNumber numberWithInteger:dpi] forKey:(NSString*)kCGImagePropertyDPIHeight];
	
	NSNumber* value = [props objectForKey:NSImageCompressionFactor];
	if( value == nil )
		value = [NSNumber numberWithDouble:0.67];
		
	[options setObject:value forKey:(NSString*)kCGImageDestinationLossyCompressionQuality];
	
	value = [props objectForKey:NSImageProgressive];
	if ( value != nil )
		[options setObject:[NSDictionary dictionaryWithObject:value forKey:(NSString*)kCGImagePropertyJFIFIsProgressive] forKey:(NSString*)kCGImagePropertyJFIFDictionary];
	
	// generate the bitmap image at the required size
			
	CGImageRef image = [self CGImageWithResolution:dpi hasAlpha:NO relativeScale:scale];
	
	NSAssert( image != nil, @"could not create image for JPEG export");
	
	if ( image == nil )
		return nil;
	
	// encode it to data using Image I/O
	
	CFMutableDataRef data = CFDataCreateMutable( kCFAllocatorDefault, 0 );
	CGImageDestinationRef destRef = CGImageDestinationCreateWithData( data, kUTTypeJPEG, 1, NULL );

	CGImageDestinationAddImage( destRef, image, (CFDictionaryRef)options );
	
	BOOL result = CGImageDestinationFinalize( destRef );
	
	CFRelease( destRef );
	
	if ( result )
		return [(NSData*)data autorelease];
	else
	{
		CFRelease( data );
		return nil;
	}
}



///*********************************************************************************************************************
///
/// method:			TIFFDataWithProperties:
/// scope:			public instance method
/// description:	returns TIFF data for the drawing.
/// 
/// parameters:		<props> various parameters and properties
/// result:			TIFF data or nil if there was a problem
///
/// notes:			the properties can include a mixture of Image I/O properties, NSBitMapImageRep properties and
///					DrawKit properties that control the data generation. Users may find the convenience methods
///					below easier to use for many typical situations.
///
///********************************************************************************************************************

- (NSData*)				TIFFDataWithProperties:(NSDictionary*) props
{
	NSAssert( props != nil, @"cannot create TIFF data - properties were nil");
	
	NSInteger dpi = [[props objectForKey:kDKExportPropertiesResolution] integerValue];
	
	if( dpi == 0 )
		dpi = 72;
		
	CGFloat scale = [[props objectForKey:kDKExportedImageRelativeScale] doubleValue];
	
	if( scale == 0 )
		scale = 1.0;
	
	NSMutableDictionary* options = [[props mutableCopy] autorelease];
		
	[options setObject:[NSNumber numberWithInteger:dpi] forKey:(NSString*)kCGImagePropertyDPIWidth];
	[options setObject:[NSNumber numberWithInteger:dpi] forKey:(NSString*)kCGImagePropertyDPIHeight];
	
	// set up a TIFF-specific dictionary
	
	NSNumber*	value;
	
	NSMutableDictionary* tiffInfo = [NSMutableDictionary dictionary];

	value = [props objectForKey:NSImageCompressionMethod];
	if ( value != nil )
		[tiffInfo setObject:value forKey:(NSString*)kCGImagePropertyTIFFCompression];
		
	[tiffInfo setObject:[NSString stringWithFormat:@"DrawKit %@ (c)2008 apptree.net", [[self class] drawkitVersionString]] forKey:(NSString*)kCGImagePropertyTIFFSoftware];
	
	NSString* metaStr;
	
	metaStr = [[self drawingInfo] objectForKey:[kDKDrawingInfoDraughter lowercaseString]];
	
	if( metaStr )
		[tiffInfo setObject:metaStr forKey:(NSString*)kCGImagePropertyTIFFArtist];
	
	metaStr = [[self drawingInfo] objectForKey:[kDKDrawingInfoDrawingNumber lowercaseString]];
	
	if( metaStr )
		[tiffInfo setObject:metaStr forKey:(NSString*)kCGImagePropertyTIFFDocumentName];
	
	[tiffInfo setObject:[[NSDate date] description] forKey:(NSString*)kCGImagePropertyTIFFDateTime];
	
	[options setObject:tiffInfo forKey:(NSString*)kCGImagePropertyTIFFDictionary];
	
	value = [props objectForKey:kDKExportedImageHasAlpha];
	
	BOOL hasAlpha = NO;
	
	if( value != nil )
		hasAlpha = [value boolValue];
	
	// generate the bitmap image at the required size
			
	CGImageRef image = [self CGImageWithResolution:dpi hasAlpha:hasAlpha relativeScale:scale];
	
	NSAssert( image != nil, @"could not create image for TIFF export");
	
	if ( image == nil )
		return nil;

	// encode it to data using Image I/O
	
	CFMutableDataRef data = CFDataCreateMutable( kCFAllocatorDefault, 0 );
	CGImageDestinationRef destRef = CGImageDestinationCreateWithData( data, kUTTypeTIFF, 1, NULL );

	CGImageDestinationAddImage( destRef, image, (CFDictionaryRef)options );
	
	BOOL result = CGImageDestinationFinalize( destRef );
	
	CFRelease( destRef );
	
	if ( result )
		return [(NSData*)data autorelease];
	else
	{
		CFRelease( data );
		return nil;
	}
}



///*********************************************************************************************************************
///
/// method:			PNGDataWithProperties:
/// scope:			public instance method
/// description:	returns PNG data for the drawing.
/// 
/// parameters:		<props> various parameters and properties
/// result:			PNG data or nil if there was a problem
///
/// notes:			the properties can include a mixture of Image I/O properties, NSBitMapImageRep properties and
///					DrawKit properties that control the data generation. Users may find the convenience methods
///					below easier to use for many typical situations.
///
///********************************************************************************************************************

- (NSData*)				PNGDataWithProperties:(NSDictionary*) props
{
	NSAssert( props != nil, @"cannot create PNG data - properties were nil");
	
	NSInteger dpi = [[props objectForKey:kDKExportPropertiesResolution] integerValue];
	
	if( dpi == 0 )
		dpi = 72;
		
	CGFloat scale = [[props objectForKey:kDKExportedImageRelativeScale] doubleValue];
	
	if( scale == 0 )
		scale = 1.0;
	
	NSMutableDictionary* options = [[props mutableCopy] autorelease];
		
	[options setObject:[NSNumber numberWithInteger:dpi] forKey:(NSString*)kCGImagePropertyDPIWidth];
	[options setObject:[NSNumber numberWithInteger:dpi] forKey:(NSString*)kCGImagePropertyDPIHeight];
	
	NSNumber* value;
		
	value = [props objectForKey:NSImageInterlaced];
	if ( value != nil )
		[options setObject:[NSDictionary dictionaryWithObject:value forKey:(NSString*)kCGImagePropertyPNGInterlaceType] forKey:(NSString*)kCGImagePropertyPNGDictionary];
	
	// generate the bitmap image at the required size
			
	CGImageRef image = [self CGImageWithResolution:dpi hasAlpha:NO relativeScale:scale];
	
	NSAssert( image != nil, @"could not create image for PNG export");
	
	if ( image == nil )
		return nil;

	// encode it to data using Image I/O
	
	CFMutableDataRef data = CFDataCreateMutable( kCFAllocatorDefault, 0 );
	CGImageDestinationRef destRef = CGImageDestinationCreateWithData( data, kUTTypePNG, 1, NULL );

	CGImageDestinationAddImage( destRef, image, (CFDictionaryRef)options );
	
	BOOL result = CGImageDestinationFinalize( destRef );
	
	CFRelease( destRef );
	
	if ( result )
		return [(NSData*)data autorelease];
	else
	{
		CFRelease( data );
		return nil;
	}
}


#pragma mark -
#pragma mark - high-level easy use methods
///*********************************************************************************************************************
///
/// method:			JPEGDataWithResolution:quality:progressive:
/// scope:			public instance method
/// description:	returns JPEG data for the drawing or nil if there was a problem
/// 
/// parameters:		<dpi> the resolution in dots per inch
///					<quality> a value 0..1 that indicates the amount of compression - 0 = max, 1 = none.
///					<progressive> YES if the data is progressive, NO otherwise
/// result:			JPEG data
///
/// notes:			this is a convenience wrapper around the dictionary-based methods above
///
///********************************************************************************************************************

- (NSData*)				JPEGDataWithResolution:(NSInteger) dpi quality:(CGFloat) quality progressive:(BOOL) progressive
{
	NSDictionary* props = [NSDictionary dictionaryWithObjectsAndKeys:	[NSNumber numberWithInteger:dpi],			kDKExportPropertiesResolution,
																		[NSNumber numberWithDouble:quality],		NSImageCompressionFactor,
																		[NSNumber numberWithBool:progressive],	NSImageProgressive,
																		nil ];
																		
	return [self JPEGDataWithProperties:props];
}



///*********************************************************************************************************************
///
/// method:			TIFFDataWithResolution:compressionType:
/// scope:			public instance method
/// description:	returns TIFF data for the drawing or nil if there was a problem
/// 
/// parameters:		<dpi> the resolution in dots per inch
///					<compType> a valid TIFF compression type (see NSBitMapImageRep.h)
/// result:			TIFF data
///
/// notes:			this is a convenience wrapper around the dictionary-based methods above
///
///********************************************************************************************************************

- (NSData*)				TIFFDataWithResolution:(NSInteger) dpi compressionType:(NSTIFFCompression) compType
{
	NSDictionary* props = [NSDictionary dictionaryWithObjectsAndKeys:	[NSNumber numberWithInteger:dpi],			kDKExportPropertiesResolution,
																		[NSNumber numberWithInteger:compType],		NSImageCompressionMethod,
																		nil ];
																		
	return [self TIFFDataWithProperties:props];
}



///*********************************************************************************************************************
///
/// method:			PNGDataWithResolution:gamma:interlaced:
/// scope:			public instance method
/// description:	returns PNG data for the drawing or nil if there was a problem
/// 
/// parameters:		<dpi> the resolution in dots per inch
///					<gamma> the gamma value 0..1
///					<interlaced> YES to interlace the image, NO otherwise
/// result:			PNG data
///
/// notes:			this is a convenience wrapper around the dictionary-based methods above
///
///********************************************************************************************************************

- (NSData*)				PNGDataWithResolution:(NSInteger) dpi gamma:(CGFloat) gumma interlaced:(BOOL) interlaced
{
	NSDictionary* props = [NSDictionary dictionaryWithObjectsAndKeys:	[NSNumber numberWithInteger:dpi],			kDKExportPropertiesResolution,
																		[NSNumber numberWithDouble:gumma],		NSImageGamma,
																		[NSNumber numberWithBool:interlaced],	NSImageInterlaced,
																		nil ];
																		
	return [self PNGDataWithProperties:props];
}


///*********************************************************************************************************************
///
/// method:			thumbnailData
/// scope:			public instance method
/// description:	returns JPEG data for the drawing at 50% actual size, with 50% quality
/// 
/// parameters:		none
/// result:			JPEG data
///
/// notes:			useful for e.g. generating QuickLook thumbnails
///
///********************************************************************************************************************

- (NSData*)				thumbnailData
{
	NSDictionary* props = [NSDictionary dictionaryWithObjectsAndKeys:	[NSNumber numberWithInteger:72],			kDKExportPropertiesResolution,
						   [NSNumber numberWithDouble:0.5],		NSImageCompressionFactor,
						   [NSNumber numberWithBool:YES],	NSImageProgressive,
						   [NSNumber numberWithDouble:0.5], kDKExportedImageRelativeScale,
						   nil ];
	
	return [self JPEGDataWithProperties:props];
}


///*********************************************************************************************************************
///
/// method:			layerBitmapsWithDPI:
/// scope:			public instance method
/// description:	returns an array of bitmaps (NSBitmapImageReps) one per layer
/// 
/// parameters:		<dpi> the desired resolution in dots per inch.
/// result:			an array of bitmaps
///
/// notes:			the lowest index is the bottom layer. Hidden layers and non-printing layers are excluded.
///
///********************************************************************************************************************

- (NSArray*)			layerBitmapsWithDPI:(NSUInteger) dpi
{
	NSMutableArray* layerBitmaps = [NSMutableArray array];
	NSEnumerator*	iter = [[self flattenedLayers] reverseObjectEnumerator];
	DKLayer*		layer;
	
	while(( layer = [iter nextObject]))
	{
		if([layer visible] && [layer shouldDrawToPrinter])
		{
			NSBitmapImageRep* rep = [layer bitmapRepresentationWithDPI:dpi];
			if( rep )
				[layerBitmaps addObject:rep];
		}
	}
	
	return layerBitmaps;
}


///*********************************************************************************************************************
///
/// method:			multipartTIFFDataWithResolution:
/// scope:			public instance method
/// description:	returns TIFF data
/// 
/// parameters:		<dpi> the desired resolution in dots per inch.
/// result:			TIFF data
///
/// notes:			Each layer is written as a separate image. This is not the same as a layered TIFF however.
///
///********************************************************************************************************************

- (NSData*)				multipartTIFFDataWithResolution:(NSUInteger) dpi
{
	return [NSBitmapImageRep TIFFRepresentationOfImageRepsInArray:[self layerBitmapsWithDPI:dpi]];
}


@end
