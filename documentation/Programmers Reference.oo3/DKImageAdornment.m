///**********************************************************************************************************************************
///  DKImageAdornment.m
///  DrawKit
///
///  Created by graham on 15/05/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKImageAdornment.h"

#import "DKGeometryUtilities.h"
#import "DKDrawableObject+Metadata.h"
#import "DKDrawableShape.h"
#import "DKDrawKitMacros.h"

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
}


- (NSImage*)			image
{
	return m_image;
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
- (void)				setScale:(float) scale
{
	//_scale = MAX( 0.2, MIN( 8.0, scale ));
	m_scale = LIMIT( scale, 0.2, 8.0 );
}


- (float)				scale
{
	return m_scale;
}


#pragma mark -
- (void)				setOpacity:(float) opacity
{
	//_opacity = MAX( 0.0, MIN( 1.0, opacity ));
	m_opacity = LIMIT( opacity, 0.0, 1.0 );
}


- (float)				opacity
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
- (void)				setAngle:(float) angle
{
	m_angle = angle;
}


- (float)				angle
{
	return m_angle;
}


- (void)				setAngleInDegrees:(float) degrees
{
	[self setAngle:(degrees * pi)/180.0f];
}


- (float)				angleInDegrees
{
	return fmodf(([self angle] * 180.0f )/ pi, 360.0 );
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
- (void)				setClipsToPath:(BOOL) ctp
{
	m_clipToPath = ctp;
}


- (BOOL)				clipsToPath
{
	return m_clipToPath;
}


#pragma mark -
- (NSAffineTransform*)	imageTransformForObject:(DKDrawableObject*) renderableObject
{
	// to work around rounding error in image rendering, image needs to be transformed seperately from the clipping path - the
	// transform here will allow the image to be rendered rotated and scaled to the final position.
	
	// This also applies the "fitting option" setting - the scale is ignored if the setting is fit to bounds or
	// fit proportionally to bounds, and is calculated instead to fit exactly.
	
	NSSize	si = [[self image] size];
	NSSize	sc = [renderableObject size];
	float	sx, sy;
	
	sx = sy = [self scale];

	if ([self fittingOption] == kGCScaleToFitPreservingAspectRatio)
	{
		NSRect imageDestRect = ScaledRectForSize( si, NSMakeRect( 0, 0, sc.width, sc.height ));
		
		sx = imageDestRect.size.width / si.width;
		sy = imageDestRect.size.height / si.height;
	}
	else if ([self fittingOption] == kGCScaleToFitBounds)
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
				[NSArray arrayWithObjects:@"image", @"opacity", @"scale", @"clipsToPath", @"fittingOption", @"angle", nil]];
}


- (void)				registerActionNames
{
	[super registerActionNames];
	
	[self setActionName:@"#kind# Image" forKeyPath:@"image"];
	[self setActionName:@"#kind# Image Opacity" forKeyPath:@"opacity"];
	[self setActionName:@"#kind# Image Scale" forKeyPath:@"scale"];
	[self setActionName:@"#kind# Clips To Path" forKeyPath:@"clipsToPath"];
	[self setActionName:@"#kind# Image Fitting" forKeyPath:@"fittingOption"];
	[self setActionName:@"#kind# Image Angle" forKeyPath:@"angle"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	[m_imageIdentifier release];
	[m_image release];
	
	[super dealloc];
}


- (id)					init
{
	self = [super init];
	if (self != nil)
	{
		NSAssert(m_image == nil, @"Expected init to zero");
		m_scale = 1.0;
		m_opacity = 1.0;
		NSAssert(m_angle == 0.0, @"Expected init to zero");
		NSAssert(NSEqualPoints(m_origin, NSZeroPoint), @"Expected init to zero");
		m_op = NSCompositeSourceOver;
		m_fittingOption = kGCClipToBounds;
		m_imageIdentifier = @"";
		m_clipToPath = YES;
	}
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (void)				render:(DKDrawableObject*) object
{
	if([self enabled])
	{
		NSImage*	image = [self image];
		
		if ( image == nil )
		{
			// try obtaining the image from the object's metadata using the ID
			
			if ([self imageIdentifier] != nil && [[self imageIdentifier] length] > 0)
			{
				image = [object metadataObjectForKey:[self imageIdentifier]];
				
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

		if([self clipsToPath])
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


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self image] forKey:@"image"];
	[coder encodeFloat:[self scale] forKey:@"scale"];
	[coder encodeFloat:[self opacity] forKey:@"opacity"];
	[coder encodeFloat:[self angle] forKey:@"angle"];
	
	[coder encodeInt:[self operation] forKey:@"operation"];
	[coder encodeInt:[self fittingOption] forKey:@"fitting"];
	[coder encodeObject:[self imageIdentifier] forKey:@"ident"];
	[coder encodeBool:[self clipsToPath] forKey:@"clips"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setImage:[coder decodeObjectForKey:@"image"]];
		[self setScale:[coder decodeFloatForKey:@"scale"]];
		[self setOpacity:[coder decodeFloatForKey:@"opacity"]];
		[self setAngle:[coder decodeFloatForKey:@"angle"]];
		
		NSAssert(NSEqualPoints(m_origin, NSZeroPoint), @"Expected init to zero");
		[self setOperation:[coder decodeIntForKey:@"operation"]];
		[self setFittingOption:[coder decodeIntForKey:@"fitting"]];
		[self setImageIdentifier:[coder decodeObjectForKey:@"ident"]];
		[self setClipsToPath:[coder decodeBoolForKey:@"clips"]];
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
	[copy setClipsToPath:[self clipsToPath]];
	
	return copy;
}


@end
