///**********************************************************************************************************************************
///  DKImageAdornment.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 15/05/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKImageAdornment.h"
#import "DKGeometryUtilities.h"
#import "DKDrawableObject+Metadata.h"
#import "DKDrawableShape.h"
#import "DKDrawKitMacros.h"

#import "DKDrawing.h"
#import "DKImageDataManager.h"

@implementation DKImageAdornment
#pragma mark As a DKImageAdornment
+ (DKImageAdornment*)	imageAdornmentWithImage:(NSImage*) image
{
	DKImageAdornment* gir = [[self alloc] init];
	
	[gir setImage:image];
	
	return [gir autorelease];
}


+ (DKImageAdornment*)	imageAdornmentWithImageFromFile:(NSString*) path
{
	NSImage* image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	return [self imageAdornmentWithImage:image];
}


#pragma mark -
- (void)				setImage:(NSImage*) image
{
	[image retain];
	[m_image release];
	m_image = image;
	
	//[_image setFlipped:YES];
	[m_image setScalesWhenResized:YES];
	[m_image setCacheMode:NSImageCacheNever];
}


- (NSImage*)			image
{
	return m_image;
}


- (void)				setImageWithKey:(NSString*) key forDrawing:(DKDrawing*) drawing
{
	DKImageDataManager* dm = [drawing imageManager];
	
	NSImage* image = [dm makeImageForKey:key];
	[self setImage:image];
	[self setImageKey:key];
}


- (void)				setImageKey:(NSString*) key
{
	[key retain];
	[mImageKey release];
	mImageKey = key;
}


- (NSString*)			imageKey
{
	return mImageKey;
}



- (void)				setImageIdentifier:(NSString*) imageID
{
	[imageID retain];
	[m_imageIdentifier release];
	m_imageIdentifier = imageID;
}


- (NSString*)			imageIdentifier
{
	return m_imageIdentifier;
}


#pragma mark -
- (void)				setScale:(CGFloat) scale
{
	m_scale = LIMIT( scale, 0.2, 8.0 );
}


- (CGFloat)				scale
{
	return m_scale;
}


#pragma mark -
- (void)				setOpacity:(CGFloat) opacity
{
	m_opacity = LIMIT( opacity, 0.0, 1.0 );
}


- (CGFloat)				opacity
{
	return m_opacity;
}


#pragma mark -
- (void)				setOrigin:(NSPoint) origin
{
	m_origin = origin;
}


- (NSPoint)				origin
{
	return m_origin;
}


#pragma mark -
- (void)				setAngle:(CGFloat) angle
{
	m_angle = angle;
}


- (CGFloat)				angle
{
	return m_angle;
}


- (void)				setAngleInDegrees:(CGFloat) degrees
{
	[self setAngle:DEGREES_TO_RADIANS(degrees)];
}


- (CGFloat)				angleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self angle]);
	
	if ( angle < 0 )
		angle += 360.0f;
		
	return angle;
}


#pragma mark -
- (void)				setOperation:(NSCompositingOperation) op
{
	m_op = op;
}


- (NSCompositingOperation) operation
{
	return m_op;
}


#pragma mark -
- (void)				setFittingOption:(DKImageFittingOption) fopt
{
	m_fittingOption = fopt;
}


- (DKImageFittingOption) fittingOption
{
	return m_fittingOption;
}


#pragma mark -
- (NSAffineTransform*)	imageTransformForObject:(id<DKRenderable>) renderableObject
{
	// to work around rounding error in image rendering, image needs to be transformed seperately from the clipping path - the
	// transform here will allow the image to be rendered rotated and scaled to the final position.
	
	// This also applies the "fitting option" setting - the scale is ignored if the setting is fit to bounds or
	// fit proportionally to bounds, and is calculated instead to fit exactly.
	
	NSSize	si = [[self image] size];
	NSSize	sc = [renderableObject size];
	CGFloat	sx, sy;
	
	sx = sy = [self scale];

	if ([self fittingOption] == kDKScaleToFitPreservingAspectRatio)
	{
		NSRect imageDestRect = ScaledRectForSize( si, NSMakeRect( 0, 0, sc.width, sc.height ));
		
		sx = imageDestRect.size.width / si.width;
		sy = imageDestRect.size.height / si.height;
	}
	else if ([self fittingOption] == kDKScaleToFitBounds)
	{
		sx = sc.width / si.width;
		sy = sc.height / si.height;
	}

	NSPoint locP;
	
	if([renderableObject respondsToSelector:@selector(locationIgnoringOffset)])
		locP = [(id)renderableObject locationIgnoringOffset];
	else
		locP = [renderableObject location];

	NSAffineTransform* xform = [NSAffineTransform transform];
	[xform translateXBy:locP.x yBy:locP.y];
	[xform rotateByRadians:[renderableObject angle] + [self angle]];
	
	if( sx != 0.0 && sy != 0.0 )
		[xform scaleXBy:sx yBy:sy];
	[xform translateXBy:[self origin].x yBy:[self origin].y];
	
	// factor in the object's parent transform
	
	NSAffineTransform* pt = [renderableObject containerTransform];
	
	if ( pt != nil )
		[xform appendTransform:pt];
	
	return xform;
}


#pragma mark -
#pragma mark As a DKRasterizer
- (BOOL)				isValid
{
	return m_image != nil;
}


#pragma mark -
#pragma mark As a GCObservableObject

+ (NSArray*)			observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:
				[NSArray arrayWithObjects:@"image", @"opacity", @"scale", @"fittingOption", @"angle", @"operation", nil]];
}


- (void)				registerActionNames
{
	[super registerActionNames];
	
	[self setActionName:@"#kind# Image" forKeyPath:@"image"];
	[self setActionName:@"#kind# Image Opacity" forKeyPath:@"opacity"];
	[self setActionName:@"#kind# Image Scale" forKeyPath:@"scale"];
	[self setActionName:@"#kind# Image Fitting" forKeyPath:@"fittingOption"];
	[self setActionName:@"#kind# Image Angle" forKeyPath:@"angle"];
	[self setActionName:@"#kind# Compositing Operation" forKeyPath:@"operation"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	[m_imageIdentifier release];
	[m_image release];
	[mImageKey release];
	
	[super dealloc];
}


- (id)					init
{
	self = [super init];
	if (self != nil)
	{
		m_scale = 1.0;
		m_opacity = 1.0;
		m_op = NSCompositeSourceOver;
		m_fittingOption = kDKClipToBounds;
		m_imageIdentifier = @"";
	}
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol

- (void)				render:(id<DKRenderable>) object
{
	if( ![object conformsToProtocol:@protocol(DKRenderable)])
		return;

	if([self enabled])
	{
		NSImage*	image = [self image];
		
		if ( image == nil )
		{
			// try obtaining the image from the object's metadata using the ID
			
			if ([self imageIdentifier] != nil && [[self imageIdentifier] length] > 0 && [object respondsToSelector:@selector(metadataObjectForKey:)])
			{
				image = [(DKDrawableObject*)object metadataObjectForKey:[self imageIdentifier]];
				
				NSLog( @"metadata image = %@", image );
			}
		}
		
		// if still no image, bail
		
		if ( image == nil )
			return;
			
		// OK, got an image - draw it according to settings with the object's path bounds
		
		NSBezierPath*	path = [self renderingPathForObject:object];
		NSRect			destRect;
		
		[[NSGraphicsContext currentContext] saveGraphicsState];

		if([self clipping] != kDKClippingNone)
			[path addClip];
		else
			[NSBezierPath clipRect:[object bounds]];

		NSAffineTransform* tfm = [self imageTransformForObject:object];
		[tfm concat];
		
		// assumes 'location' of object is its centre:
		
		destRect.size = [[self image] size];
		destRect.origin.x = [self origin].x - ( destRect.size.width / 2.0 );
		destRect.origin.y = [self origin].y - ( destRect.size.height / 2.0 );
		
		// draw the image
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[image setFlipped:YES];
		[image drawInRect:destRect fromRect:NSZeroRect operation:[self operation] fraction:[self opacity]];
		[image setFlipped:NO];
			
		// clean up
		
		[[NSGraphicsContext currentContext] restoreGraphicsState];
	}
}


- (BOOL)		isFill
{
	return YES;
}



#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self imageKey] forKey:@"DKImageAdornment_imageKey"];
	
	[coder encodeObject:[self image] forKey:@"image"];
	[coder encodeDouble:[self scale] forKey:@"scale"];
	[coder encodeDouble:[self opacity] forKey:@"opacity"];
	[coder encodeDouble:[self angle] forKey:@"angle"];
	
	[coder encodeInteger:[self operation] forKey:@"operation"];
	[coder encodeInteger:[self fittingOption] forKey:@"fitting"];
	[coder encodeObject:[self imageIdentifier] forKey:@"ident"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setImage:[coder decodeObjectForKey:@"image"]];
		[self setScale:[coder decodeDoubleForKey:@"scale"]];
		[self setOpacity:[coder decodeDoubleForKey:@"opacity"]];
		[self setAngle:[coder decodeDoubleForKey:@"angle"]];
		[self setOperation:[coder decodeIntegerForKey:@"operation"]];
		[self setFittingOption:[coder decodeIntegerForKey:@"fitting"]];
		[self setImageIdentifier:[coder decodeObjectForKey:@"ident"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)					copyWithZone:(NSZone*) zone
{
	DKImageAdornment* copy = [super copyWithZone:zone];
	
	[copy setImage:[self image]];
	[copy setImageIdentifier:[self imageIdentifier]];
	[copy setScale:[self scale]];
	[copy setOpacity:[self opacity]];
	[copy setAngle:[self angle]];
	[copy setFittingOption:[self fittingOption]];
	[copy setOperation:[self operation]];
	
	return copy;
}


@end
