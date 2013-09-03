//
//  NSImage+DKAdditions.m
//  GCDrawKit
//
//  Created by graham on 9/04/10.
//  Copyright 2010 Apptree.net. All rights reserved.
//

#import "NSImage+DKAdditions.h"
#import "DKGeometryUtilities.h"

@implementation NSImage (DKAdditions)

+ (NSImage*)	imageFromImage:(NSImage*) srcImage withSize:(NSSize) size
{
	return [self imageFromImage:srcImage withSize:size fraction:1.0 allowScaleUp:YES];
}


+ (NSImage*)	imageFromImage:(NSImage*) srcImage withSize:(NSSize) size fraction:(CGFloat) opacity allowScaleUp:(BOOL) scaleUp
{
	// makes a copy of <srcImage> by drawing it into a bitmap representation of <size>, scaling as needed. A new temporary graphics context is
	// made to ensure that there are no side effects such as arbitrary flippedness (the returned image is unflipped). This also sets high quality
	// image interpolation for best rendering quality. <size> can be NSZeroRect to copy the image at its original size. In addition, if the source
	// size is smaller than <size>, the src image is not scaled UP to the new image, but centred preserving its aspect ratio.
	
	NSAssert( srcImage != nil, @"source image was nil");
	
	if( NSEqualSizes( size, NSZeroSize ))
		size = [srcImage size];
	
	NSAssert( size.width > 0, @"invalid size, width is zero or -ve");
	NSAssert( size.height > 0, @"invalid size, height is zero or -ve");
	
	NSBitmapImageRep* bm = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																   pixelsWide:(NSInteger)ceil(size.width)
																   pixelsHigh:(NSInteger)ceil(size.height)
																bitsPerSample:8
															  samplesPerPixel:4
																	 hasAlpha:YES
																	 isPlanar:NO
															   colorSpaceName:NSCalibratedRGBColorSpace
																  bytesPerRow:0
																 bitsPerPixel:0];
	
	NSAssert( bm != nil, @"bitmap could not be created");
	
	NSRect destRect = NSMakeRect( 0, 0, size.width, size.height );
	
	// see if a scale-up would result, in which case keep the image at its original size and aspect ratio, centered as needed.
	
	NSSize srcSize = [srcImage size];
	
	if( !scaleUp && srcSize.width < size.width && srcSize.height < size.height )
	{
		NSRect srcRect = NSMakeRect( 0, 0, srcSize.width, srcSize.height );
		destRect = CentreRectInRect( srcRect, destRect );
	}
	else
		destRect = ScaledRectForSize( srcSize, destRect );
	
	NSImage* image = [[NSImage alloc] initWithSize:size];
	[image addRepresentation:bm];
	[bm release];
	
	NSGraphicsContext* tempContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bm];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:tempContext];
	[tempContext setImageInterpolation:NSImageInterpolationHigh];
	
	[image lockFocus];
	
	[[NSColor clearColor] set];
	NSRectFill( NSMakeRect( 0, 0, size.width, size.height ));
	
	[srcImage drawInRect:destRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:opacity];
	[image unlockFocus];
	
	[NSGraphicsContext restoreGraphicsState];
	
	// do not make additional image caches
	
	[image setCacheMode:NSImageCacheNever];
	
	return [image autorelease];
}




@end
