///**********************************************************************************************************************************
///  DKQuartzBlendRastGroup.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 30/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKQuartzBlendRastGroup.h"


static CGImageRef	CreateMaskFromImage( NSImage* image );



@implementation DKQuartzBlendRastGroup
#pragma mark As a DKQuartzBlendRastGroup
- (void)			setBlendMode:(CGBlendMode) mode
{
	m_blendMode = mode;
}


- (CGBlendMode)		blendMode
{
	return m_blendMode;
}


#pragma mark -
- (void)			setAlpha:(CGFloat) alpha
{
	m_alpha = alpha;
}


- (CGFloat)			alpha
{
	return m_alpha;
}


#pragma mark -
- (void)			setMaskImage:(NSImage*) image
{
	[image retain];
	[m_maskImage release];
	m_maskImage = image;
}


- (NSImage*)		maskImage
{
	return m_maskImage;
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"blendMode", @"alpha", @"maskImage", nil]];
}


- (void)			registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Blend Mode" forKeyPath:@"blendMode"];
	[self setActionName:@"#kind# Blend Alpha" forKeyPath:@"alpha"];
	[self setActionName:@"#kind# Blend Mask Image" forKeyPath:@"maskImage"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	[m_maskImage release];
	
	[super dealloc];
}


- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		[self setBlendMode:kCGBlendModeNormal];
		[self setAlpha:1.0];
		NSAssert(m_maskImage == nil, @"Expected init to zero");
	}
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (void)		render:(id) object
{
	if(! [self enabled])
		return;
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSetBlendMode( context, [self blendMode]);
	CGContextSetAlpha( context, [self alpha]);
	
	// apply the mask image if there is one
	
	if ([self maskImage])
	{
		CGImageRef	mask = CreateMaskFromImage([self maskImage]);
		
		// TO DO: set up he image so it's aligned to the shape's path bounds and takes account of the
		// rotation, etc. (As per DKImageAdornment). This is currently only OK for unrotated shapes.
		
		NSRect		clipr;
		
		clipr = [object bounds];
		
		CGContextClipToMask( context, *(CGRect*)&clipr, mask );

		//CGContextDrawImage( context, *(CGRect*)&clipr, mask );

		CGImageRelease( mask );
	}
	[super render:object];
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeInteger:[self blendMode] forKey:@"blend_mode"];
	[coder encodeDouble:[self alpha] forKey:@"alpha"];
	[coder encodeObject:[self maskImage] forKey:@"mask_image"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setBlendMode:[coder decodeIntegerForKey:@"blend_mode"]];
		[self setAlpha:[coder decodeDoubleForKey:@"alpha"]];
		[self setMaskImage:[coder decodeObjectForKey:@"mask_image"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)				copyWithZone:(NSZone*) zone
{
	DKQuartzBlendRastGroup* copy = [super copyWithZone:zone];
	
	[copy setBlendMode:[self blendMode]];
	[copy setAlpha:[self alpha]];
	[copy setMaskImage:[self maskImage]];
	return copy;
}


@end



static CGImageRef	CreateMaskFromImage( NSImage* image )
{
	// return a bitmap image that can be used as a mask
	
	if ( image == nil )
		return NULL;
	
	NSSize	size = [image size];
	NSInteger		width = (NSInteger)size.width;
	NSInteger		height = (NSInteger)size.height;
	
	if ( width < 1 || height < 1 )
		return NULL;
	
	CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
	void*			buffer;
	
	buffer = malloc( height * width );
	
	CGContextRef	bmc = CGBitmapContextCreate( buffer, width, height, 8, width, graySpace, 0 );
	CGContextClearRect( bmc, CGRectMake( 0, 0, width, height ));
	
	CGImageRef		mask = NULL;
	
	// draw the image into the bitmap context
	
	SAVE_GRAPHICS_CONTEXT	//[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext* gc = [NSGraphicsContext graphicsContextWithGraphicsPort:bmc flipped:YES];
	
	[NSGraphicsContext setCurrentContext:gc];
	
	[image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	
	mask = CGBitmapContextCreateImage( bmc );
	
	RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
	
	CGContextRelease( bmc );
	free( buffer );
	CGColorSpaceRelease( graySpace );
	
	return mask;
}

