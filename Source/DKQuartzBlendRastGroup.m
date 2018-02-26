/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKQuartzBlendRastGroup.h"

static CGImageRef CreateMaskFromImage(NSImage* image);

@implementation DKQuartzBlendRastGroup
#pragma mark As a DKQuartzBlendRastGroup

@synthesize blendMode = m_blendMode;

#pragma mark -
@synthesize alpha = m_alpha;

#pragma mark -
@synthesize maskImage = m_maskImage;

#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:@[@"blendMode", @"alpha", @"maskImage"]];
}

- (void)registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Blend Mode"
			 forKeyPath:@"blendMode"];
	[self setActionName:@"#kind# Blend Alpha"
			 forKeyPath:@"alpha"];
	[self setActionName:@"#kind# Blend Mask Image"
			 forKeyPath:@"maskImage"];
}

#pragma mark -
#pragma mark As an NSObject
- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self setBlendMode:kCGBlendModeNormal];
		[self setAlpha:1.0];
		NSAssert(m_maskImage == nil, @"Expected init to zero");
	}
	return self;
}

#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (void)render:(id)object
{
	if (![self enabled])
		return;

	[[NSGraphicsContext currentContext] saveGraphicsState];

	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSetBlendMode(context, [self blendMode]);
	CGContextSetAlpha(context, [self alpha]);

	// apply the mask image if there is one

	if ([self maskImage]) {
		CGImageRef mask = CreateMaskFromImage([self maskImage]);

		// TO DO: set up he image so it's aligned to the shape's path bounds and takes account of the
		// rotation, etc. (As per DKImageAdornment). This is currently only OK for unrotated shapes.

		NSRect clipr;

		clipr = [object bounds];

		CGContextClipToMask(context, NSRectToCGRect(clipr), mask);

		//CGContextDrawImage( context, *(CGRect*)&clipr, mask );

		CGImageRelease(mask);
	}
	[super render:object];

	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeInteger:[self blendMode]
				  forKey:@"blend_mode"];
	[coder encodeDouble:[self alpha]
				 forKey:@"alpha"];
	[coder encodeObject:[self maskImage]
				 forKey:@"mask_image"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		[self setBlendMode:[coder decodeIntForKey:@"blend_mode"]];
		[self setAlpha:[coder decodeDoubleForKey:@"alpha"]];
		[self setMaskImage:[coder decodeObjectForKey:@"mask_image"]];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKQuartzBlendRastGroup* copy = [super copyWithZone:zone];

	[copy setBlendMode:[self blendMode]];
	[copy setAlpha:[self alpha]];
	[copy setMaskImage:[self maskImage]];
	return copy;
}

@end

static CGImageRef CreateMaskFromImage(NSImage* image)
{
	// return a bitmap image that can be used as a mask

	if (image == nil)
		return NULL;

	NSSize size = [image size];
	NSInteger width = (NSInteger)size.width;
	NSInteger height = (NSInteger)size.height;

	if (width < 1 || height < 1)
		return NULL;

	CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
	void* buffer;

	buffer = malloc(height * width);

	CGContextRef bmc = CGBitmapContextCreate(buffer, width, height, 8, width, graySpace, 0);
	CGContextClearRect(bmc, CGRectMake(0, 0, width, height));

	CGImageRef mask = NULL;

	// draw the image into the bitmap context

	SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
		NSGraphicsContext* gc
		= [NSGraphicsContext graphicsContextWithGraphicsPort:bmc
													 flipped:YES];

	[NSGraphicsContext setCurrentContext:gc];

	[image drawAtPoint:NSZeroPoint
			  fromRect:NSZeroRect
			 operation:NSCompositeCopy
			  fraction:1.0];

	mask = CGBitmapContextCreateImage(bmc);

	RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
		CGContextRelease(bmc);
	free(buffer);
	CGColorSpaceRelease(graySpace);

	return mask;
}
