///**********************************************************************************************************************************
///  NSImage+Tracing.m
///  DrawKit
///
///  Created by graham on 23/06/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#ifdef qUsePotrace

#import "NSImage+Tracing.h"

#import "bitmap.h"
#import "DKColourQuantizer.h"
#import "LogEvent.h"


#pragma mark Contants (Non-localized)

// dict keys for tracing parameters

NSString*	kGCTracingParam_turdsize		= @"kGCTracingParam_turdsize";		
NSString*	kGCTracingParam_turnpolicy		= @"kGCTracingParam_turnpolicy";		
NSString*	kGCTracingParam_alphamax		= @"kGCTracingParam_alphamax";
NSString*	kGCTracingParam_opticurve		= @"kGCTracingParam_opticurve";		
NSString*	kGCTracingParam_opttolerance	= @"kGCTracingParam_opttolerance";		


#pragma mark -
@implementation NSImage (Tracing)
#pragma mark As a NSImage
- (NSArray*)			vectorizeToGrayscale:(int) levels
{
	// vectorize the image using potrace and return a list of GCImageVectorReps for each pixel value in the 8-bit representation of
	// the image. <Levels> is the number of quantization levels - it can be any value between 2 and 256. The result is a grayscale
	// of this many levels.
	
	if ( levels < 2 || levels > 256 )
		return nil;
		
	NSBitmapImageRep* b8 = [self eightBitImageRep];
	
	// OK, we have an 8-bit grayscale version of the image. Now we need to convert each "bitplane" to a bitmap structure
	// compatible with potrace. To do this we scan the image pixel by pixel, and set the corresponding pixel in each
	// bitmap. If no pixels of a given value are found, those bitplanes will be discarded later.
	
	NSMutableArray*		bitplanes = [[NSMutableArray alloc] init];
	int					i;
	DKImageVectorRep*	rep;
	potrace_bitmap_t*	bmaps[256];
	unsigned			pixCounts[256];
	
	// initialise for all non-background values
	
	for( i = 0; i < levels; ++i )
	{
		rep = [[DKImageVectorRep alloc] initWithImageSize:[b8 size] pixelValue:i levels:levels];
		[bitplanes addObject:rep];
		
		// keep a local copy of the bitmap pointers so that we can set all the planes in one pass of the image
		bmaps[i] = [rep bitmap];
		[rep release];
		
		pixCounts[i] = 0;
	}
	
	NSSize	imageSize = [self size];
	
	int width, height;
	
	width = imageSize.width + 4;
	height = imageSize.height + 4;
	
	// scan the image, thresholding it into <levels> separate planes
	
	int				x, y;
	unsigned int	pixel;
	unsigned int	destPixValue;
	
	// how many bits to shift the pixel value to quantize to <levels>?
	
	for( y = 1; y < height - 1; ++y )
	{
		for( x = 1; x < width - 1; ++x )
		{
			[b8 getPixel:&pixel atX:x y:y];
		
			// set the pixel at x,y in the appropriate bitmap plane
			
			if ( pixel < 256 )
			{
				// work out what the destination pixel value is depending on the number of levels we have asked for
				
				destPixValue = ( pixel * levels ) / 256;
				
				BM_USET( bmaps[destPixValue], x, height - y );
				++pixCounts[destPixValue];
			}
		}
	}
	
	// discard those reps for which no pixels were set (corresponding pixcount will be 0)
	
	NSMutableIndexSet*	rmindexes = [[NSMutableIndexSet alloc] init];
	
	for( i = 0; i < levels; ++i )
	{
		if ( pixCounts[i] == 0 )
			[rmindexes addIndex:i];
	}
	[bitplanes removeObjectsAtIndexes:rmindexes];
	[rmindexes release];
	
	// ok, done... the actual trace work is performed when the vector data is requested from the rep. This saves time in case
	// that really we don't want to use all the data.

	return [bitplanes autorelease];
}

- (NSArray*)			vectorizeToColourWithPrecision:(int) prec quantizationMethod:(DKColourQuantizationMethod) qm
{
	// makes a colour vectorisation based on a precisiosn value of <prec>, which can range from 3 to 8. This represents the
	// number of mBits of resolution of R, G and B used to determine the colour.
	
	if ( prec < 3 || prec > 8 )
		return nil;
		
	unsigned int levels = ( 1 << prec );

	NSBitmapImageRep* b24 = [self twentyFourBitImageRep];
	
	// in order to use the best colour palette for the precision selected, perform an octree analysis on the image
	
	DKColourQuantizer* quant;
	
	switch ( qm )
	{
		default:
		case kGCColourQuantizeUniform:
			quant = [[DKColourQuantizer alloc] initWithBitmapImageRep:b24 maxColours:levels colourBits:prec];
			break;
			
		case kGCColourQuantizeOctree:
			quant = [[DKOctreeQuantizer alloc] initWithBitmapImageRep:b24 maxColours:levels colourBits:prec];
			break;
	}
	
	// quantize the image colours:
	
	[quant analyse:b24];
	levels = [quant numberOfColours];
	
//	LogEvent_(kReactiveEvent, @"levels = %d, #colours = %d", levels, [quant numberOfColours] );
	
	NSMutableArray*		bitplanes = [[NSMutableArray alloc] init];
	unsigned			i;
	DKImageVectorRep*	rep;
	potrace_bitmap_t*	bmaps[256];
	unsigned			pixCounts[256];
	
	// initialise vector reps for all values
	
	for( i = 0; i < levels; ++i )
	{
		rep = [[DKImageVectorRep alloc] initWithImageSize:[b24 size] pixelValue:i levels:levels];
		[bitplanes addObject:rep];
		
		// keep a local copy of the bitmap pointers so that we can set all the planes in one pass of the image
		
		bmaps[i] = [rep bitmap];
		[rep release];
		
		pixCounts[i] = 0;
		
		[rep setColour:[quant colourForIndex:i]];
	}
	
	NSSize	imageSize = [self size];
	
	int width, height;
	
	width = imageSize.width + 4;
	height = imageSize.height + 4;
	
	// scan the image, thresholding it into <levels> separate planes
	
	int				x, y;
	unsigned int	rgb[4];
	unsigned char	destPixValue;
	
	for( y = 1; y < height - 1; ++y )
	{
		for( x = 1; x < width - 1; ++x )
		{
			[b24 getPixel:rgb atX:x y:y];
			
			// set the pixel at x,y in the appropriate bitmap plane

			destPixValue = [quant indexForRGB:rgb];
			
			if ( destPixValue < levels )
			{
				// work out what the destination pixel value is depending on the number of levels we have asked for
				
				BM_USET( bmaps[destPixValue], x, height - y );
				++pixCounts[destPixValue];
			}
		}
	}
	
	// done with the quantizer
	
	[quant release];
	
	// discard those reps for which no pixels were set (pixcount will be 0)
	
	NSMutableIndexSet*	rmindexes = [[NSMutableIndexSet alloc] init];
	
	for( i = 0; i < levels; ++i )
	{
		if ( pixCounts[i] == 0 )
			[rmindexes addIndex:i];
	}
	[bitplanes removeObjectsAtIndexes:rmindexes];
	[rmindexes release];
	
	// ok, done... the actual trace work is performed when the vector data is requested from the rep. This saves time in case
	// that really we don't want to use all the data.

	return [bitplanes autorelease];
}


#pragma mark -
- (NSBitmapImageRep*)	eightBitImageRep
{
	NSSize	imageSize = [self size];
	
	int width, height;
	
	width = imageSize.width + 4;
	height = imageSize.height + 4;
	
	// make an 8-bit representation of the image which is a little larger than this, so that there is a clear border around the pixels.

	NSBitmapImageRep* b8 = [[NSBitmapImageRep alloc]	initWithBitmapDataPlanes:NULL
														pixelsWide:width
														pixelsHigh:height
														bitsPerSample:8
														samplesPerPixel:1
														hasAlpha:NO
														isPlanar:NO
														colorSpaceName:NSDeviceWhiteColorSpace
														bitmapFormat:0
														bytesPerRow:0
														bitsPerPixel:0 ];
														
//	LogEvent_(kInfoEvent, @"8-bit image: %@", b8 );
														
	NSRect hr = NSMakeRect( 0, 0, imageSize.width, imageSize.height );
														
	// copy the image to the bitmap, converting it to the 8-bit rep as we go
	
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:b8]];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	
	// fill background - has pixel value 255

	[[NSColor whiteColor] set];
	NSRectFill( hr );
	
	[self drawAtPoint:NSMakePoint( 2, 2 ) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
	[NSGraphicsContext restoreGraphicsState];
	
	return [b8 autorelease];
}


- (NSBitmapImageRep*)	twentyFourBitImageRep
{
	NSSize	imageSize = [self size];
	
	int width, height;
	
	width = imageSize.width + 4;
	height = imageSize.height + 4;
	
	// make an 8-bit representation of the image which is a little larger than this, so that there is a clear border around the pixels.

	NSBitmapImageRep* b24 = [[NSBitmapImageRep alloc]	initWithBitmapDataPlanes:NULL
														pixelsWide:width
														pixelsHigh:height
														bitsPerSample:8
														samplesPerPixel:4
														hasAlpha:YES
														isPlanar:NO
														colorSpaceName:NSCalibratedRGBColorSpace
														bitmapFormat:0
														bytesPerRow:0
														bitsPerPixel:0 ];
														
	LogEvent_(kInfoEvent, @"24-bit image: %@", b24 );
														
	NSRect hr = NSMakeRect( 0, 0, imageSize.width, imageSize.height );
														
	// copy the image to the bitmap, converting it to the 8-bit rep as we go
	
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:b24]];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	//[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	
	// fill background - has pixel value FFFFFF

	[[NSColor whiteColor] set];
	NSRectFill( hr );
	
	[self drawAtPoint:NSMakePoint( 2, 2 ) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
	[NSGraphicsContext restoreGraphicsState];
	
	return [b24 autorelease];
}


@end




#pragma mark -
@implementation DKImageVectorRep
#pragma mark As a DKImageVectorRep
- (id)					initWithImageSize:(NSSize) isize pixelValue:(unsigned) pixv levels:(unsigned) lev
{
	self = [super init];
	if (self != nil)
	{
		mBits = bm_new( isize.width, isize.height );
		mLevels = lev;
		mPixelValue = pixv;
		mTraceParams = potrace_param_default();
		mTraceParams->turdsize = 6;
		NSAssert(mVectorData == nil, @"Expected init to zero");
		NSAssert(mColour == nil, @"Expected init to zero");
		
		if (mBits == NULL)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		bm_clear( mBits, 0 );
	}
	return self;
}


#pragma mark -
- (potrace_bitmap_t*)	bitmap
{
	return mBits;
}


#pragma mark -
#pragma mark - get the traced path, performing the trace if needed
- (NSBezierPath*)		pathFromTracePath:(potrace_path_t*) tp
{
	if ( tp == NULL || tp->curve.n == 0 )
		return nil;
	
	NSBezierPath* vd = [[NSBezierPath bezierPath] retain];
	
	int					i, m, k, tag;
	potrace_dpoint_t	cp;
	NSPoint				p[3];
	
	m = tp->curve.n;
	cp = tp->curve.c[m-1][2];
	
	p[0].x = cp.x;
	p[0].y = cp.y;
	
	[vd moveToPoint:p[0]];
	
	for( i = 0; i < m; ++i )
	{
		tag = tp->curve.tag[i];
		
		if ( tag == POTRACE_CURVETO )
		{
			for( k = 0; k < 3; ++k )
			{
				cp = tp->curve.c[i][k];
				p[k].x = cp.x;
				p[k].y = cp.y;
			}
			
			[vd curveToPoint:p[2] controlPoint1:p[0] controlPoint2:p[1]];
		}
		else
		{
			cp = tp->curve.c[i][1];
			p[0].x = cp.x;
			p[0].y = cp.y;
			[vd lineToPoint:p[0]];
			cp = tp->curve.c[i][2];
			p[0].x = cp.x;
			p[0].y = cp.y;
			[vd lineToPoint:p[0]];
		}
	}
	[vd closePath];
	
	// for - sign, reverse the path
	
	if ( tp->sign == '-' )
	{
		NSBezierPath* temp = [vd bezierPathByReversingPath];
		[vd release];
		vd = [temp retain];
	}
	
	// not auroreleased as this is private and caller will release directly as needed
	
	return vd;
}
- (NSBezierPath*)		vectorPath
{
	if ( mVectorData == nil && mBits != NULL )
	{
		// actually perform the trace
	
		LogEvent_(kReactiveEvent,  @"tracing bitmap for bitplane: %d", mPixelValue );
		
		potrace_state_t* traceResult = potrace_trace( mTraceParams, mBits );
		
		// check the result and convert to a bezierPath:
		
		if ( traceResult != NULL && traceResult->status == POTRACE_STATUS_OK )
		{
			// success, convert vector data to NSBezierPath form. Each subpath is appended to the
			// NSBezierpath object
			
			potrace_path_t*		tp = traceResult->plist;
			NSBezierPath*		temp;
			
			if ( tp )
			{
				mVectorData = [[NSBezierPath bezierPath] retain];
				[mVectorData setWindingRule:NSEvenOddWindingRule];
			}
			
			while( tp )
			{
				temp = [self pathFromTracePath:tp];
				
				if ( temp && ![temp isEmpty])
					[mVectorData appendBezierPath:temp];
					
				[temp release];
			
				tp = tp->next;
			}
		}
		
		// discard the trace result
		
		potrace_state_free( traceResult );
	}
	
	return mVectorData;
}


#pragma mark -
#pragma mark - colour from original image associated with this bitplane
- (void)				setColour:(NSColor*) cin
{
	[cin retain];
	[mColour release];
	mColour = cin;
}


- (NSColor*)			colour
{
	// if the colour wasn't explicitly set as part of the image analysis, assume we are working in grayscale
	// and calculate the colour based on the pixel value and number of levels
	
	if ( mColour == nil )
	{
		float gray = (float)mPixelValue / (float)mLevels;
		mColour = [[NSColor colorWithCalibratedWhite:gray alpha:1.0] retain];
	}
	
	return mColour;
}


#pragma mark -
- (void)				setTurdSize:(int) turdsize
{
	mTraceParams->turdsize = turdsize;
	
	// retrace next time the path is requested
	
	[mVectorData release];
	mVectorData = nil;
}


- (int)					turdSize
{
	return mTraceParams->turdsize;
}


#pragma mark -
- (void)				setTurnPolicy:(int) turnPolicy
{
	mTraceParams->turnpolicy = turnPolicy;
	[mVectorData release];
	mVectorData = nil;
}


- (int)					turnPolicy
{
	return mTraceParams->turnpolicy;
}


#pragma mark -
- (void)				setAlphaMax:(double) alphaMax
{
	mTraceParams->alphamax = alphaMax;
	[mVectorData release];
	mVectorData = nil;
}


- (double)				alphaMax
{
	return mTraceParams->alphamax;
}


#pragma mark -
- (void)				setOptimizeCurve:(BOOL) opt
{
	mTraceParams->opticurve = opt;
	[mVectorData release];
	mVectorData = nil;
}


- (BOOL)				optimizeCurve
{
	return mTraceParams->opticurve;
}


#pragma mark -
- (void)				setOptimizeTolerance:(double) optTolerance
{
	mTraceParams->opttolerance = optTolerance;
	[mVectorData release];
	mVectorData = nil;
}


- (double)				optimizeTolerance
{
	return mTraceParams->opttolerance;
}


#pragma mark -
- (void)				setTracingParameters:(NSDictionary*) dict
{
	if ( dict == nil )
	{
		// reset defaults
		if ( mTraceParams )
			potrace_param_free( mTraceParams );
		
		mTraceParams = potrace_param_default();
		mTraceParams->turdsize = 6;

		[mVectorData release];
		mVectorData = nil;
		
		return;
	}
	
	id val;
	
	if ((val = [dict objectForKey:kGCTracingParam_turdsize]))
		[self setTurdSize:[val intValue]];

	if ((val = [dict objectForKey:kGCTracingParam_turnpolicy]))
		[self setTurnPolicy:[val intValue]];

	if ((val = [dict objectForKey:kGCTracingParam_alphamax]))
		[self setAlphaMax:[val doubleValue]];

	if ((val = [dict objectForKey:kGCTracingParam_opticurve]))
		[self setOptimizeCurve:[val boolValue]];

	if ((val = [dict objectForKey:kGCTracingParam_opttolerance]))
		[self setOptimizeTolerance:[val doubleValue]];
}


- (NSDictionary*)		tracingParameters
{
	// copies the current tracing params to a dictionary
	if ( mTraceParams == NULL )
		return nil;
		
	NSMutableDictionary* dict = [NSMutableDictionary dictionary];
	
	[dict setObject:[NSNumber numberWithInt:mTraceParams->turdsize] forKey:kGCTracingParam_turdsize];
	[dict setObject:[NSNumber numberWithInt:mTraceParams->turnpolicy] forKey:kGCTracingParam_turnpolicy];
	[dict setObject:[NSNumber numberWithDouble:mTraceParams->alphamax] forKey:kGCTracingParam_alphamax];
	[dict setObject:[NSNumber numberWithBool:mTraceParams->opticurve] forKey:kGCTracingParam_opticurve];
	[dict setObject:[NSNumber numberWithDouble:mTraceParams->opttolerance] forKey:kGCTracingParam_opttolerance];
	
	return dict;
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	[mColour release];
	[mVectorData release];
	
	if (mTraceParams != NULL)
	{
		potrace_param_free( mTraceParams );
	}
	if (mBits != NULL)
	{
		bm_free( mBits );
	}
	
	[super dealloc];
}


@end

#endif /* defined qUsePotrace */
