/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "NSImage+DKAdditions.h"
#import "DKGeometryUtilities.h"

@implementation NSImage (DKAdditions)

+ (NSImage*)imageFromImage:(NSImage*)srcImage withSize:(NSSize)size
{
	return [self imageFromImage:srcImage
					   withSize:size
					   fraction:1.0
				   allowScaleUp:YES];
}

+ (NSImage*)imageFromImage:(NSImage*)srcImage withSize:(NSSize)size fraction:(CGFloat)opacity allowScaleUp:(BOOL)scaleUp
{
	NSAssert(srcImage != nil, @"source image was nil");

	if (NSEqualSizes(size, NSZeroSize))
		size = [srcImage size];

	NSAssert(size.width > 0, @"invalid size, width is zero or -ve");
	NSAssert(size.height > 0, @"invalid size, height is zero or -ve");

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

	NSAssert(bm != nil, @"bitmap could not be created");

	NSRect destRect = NSMakeRect(0, 0, size.width, size.height);

	// see if a scale-up would result, in which case keep the image at its original size and aspect ratio, centered as needed.

	NSSize srcSize = [srcImage size];

	if (!scaleUp && srcSize.width < size.width && srcSize.height < size.height) {
		NSRect srcRect = NSMakeRect(0, 0, srcSize.width, srcSize.height);
		destRect = CentreRectInRect(srcRect, destRect);
	} else
		destRect = ScaledRectForSize(srcSize, destRect);

	NSImage* image = [[NSImage alloc] initWithSize:size];
	[image addRepresentation:bm];

	NSGraphicsContext* tempContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bm];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:tempContext];
	[tempContext setImageInterpolation:NSImageInterpolationHigh];

	[image lockFocus];

	[[NSColor clearColor] set];
	NSRectFill(NSMakeRect(0, 0, size.width, size.height));

	[srcImage drawInRect:destRect
				fromRect:NSZeroRect
			   operation:NSCompositeSourceOver
				fraction:opacity];
	[image unlockFocus];

	[NSGraphicsContext restoreGraphicsState];

	// do not make additional image caches

	[image setCacheMode:NSImageCacheNever];

	return image;
}

@end
