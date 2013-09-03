///**********************************************************************************************************************************
///  DKPathDecorator.m
///  DrawKit
///
///  Created by graham on 17/06/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKPathDecorator.h"

#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "LogEvent.h"
#import "NSBezierPath+Geometry.h"
#import "NSBezierPath+Shapes.h"
#import "DKGeometryUtilities.h"

@implementation DKPathDecorator
#pragma mark As a DKPathDecorator

+ (DKPathDecorator*)	pathDecoratorWithImage:(NSImage*) image;
{
	return [[[self alloc] initWithImage:image] autorelease];
}


- (id)					initWithImage:(NSImage*) image
{
	self = [super init];
	if(self != nil)
	{
		[self setImage:image];
		m_scale = 1.0;
		m_interval = 50.0;
		NSAssert(m_leader == 0.0, @"Expected init to zero");
		NSAssert(m_leadInLength == 0.0, @"Expected init to zero");
		NSAssert(m_leadOutLength == 0.0, @"Expected init to zero");
		m_liloProportion = 0.2;
		
		m_normalToPath = YES;
		NSAssert(!m_useChainMethod, @"Expected init to NO");
		NSAssert(m_cache == nil, @"Expected init to zero");
		NSAssert(!m_lowQuality, @"Expected init to NO");
		NSAssert(m_pathClip == kGCPathDecoratorClippingNone, @"Expected init to zero");
	}
	return self;
}


#pragma mark -
- (void)				setImage:(NSImage*) image
{
	LogEvent_(kStateEvent, @"setting image of %@, size = %@", self, NSStringFromSize([image size]));
	
	if( NSEqualSizes([image size], NSZeroSize))
		return;
	
	// whatever happens the pdf rep is also released
	
	[m_pdf release];
	m_pdf = nil;

	// remove any CGLayer cache so that next time the rasterizer is used it
	// will be recreated using the new image
	
	if ( m_cache )
	{
		CGLayerRelease( m_cache );
		m_cache = nil;
	}

	[image retain];
	[m_image release];
	m_image = image;

	if ( m_image != nil )
	{
		[m_image setScalesWhenResized:YES];
		
		// get any PDF image rep and retain it for later quick access
		
		NSArray* reps = [m_image representations];
		NSEnumerator*	iter = [reps objectEnumerator];
		NSImageRep*		rep;
		
	//	LogEvent_(kInfoEvent, @"reps: %@", reps );
		
		while(( rep = [iter nextObject]))
		{
			if([rep isKindOfClass:[NSPDFImageRep class]])
			{
				m_pdf = [(NSPDFImageRep*)rep retain];
				
			//	LogEvent_(kInfoEvent, @"PDF image cached");
				break;
			}
		}
	}
}


- (NSImage*)			image
{
	return m_image;
}


- (void)				setUpCache
{
	NSAssert( m_image != nil, @"no image to create cache with");
	NSAssert( m_cache == nil, @"expected cache to be NULL");

	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	
	NSAssert( context != NULL, @"bad current context entering setUpCache" );
	
	NSSize		iSize = [m_image size];
	m_cache = CGLayerCreateWithContext( context, *(CGSize*)&iSize, NULL );
	
	NSAssert1( m_cache != NULL, @"couldn't create the layer context for image; size = %@", NSStringFromSize( iSize ));
	
	context = CGLayerGetContext( m_cache );
	
	NSAssert( context != NULL, @"bad layer context in setUpCache" );
	
	// draw the pdf or image into the layer context
	
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext* cc = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:[m_image isFlipped]]; 
	
	NSAssert( cc != nil, @"NSGraphicsContext object was nil in setUpCache");
	
	[NSGraphicsContext setCurrentContext:cc];
	
	if ( m_pdf )
		[m_pdf drawAtPoint:NSZeroPoint];
	else
		[m_image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	
	[NSGraphicsContext restoreGraphicsState];
}


- (void)				setPDFImageRep:(NSPDFImageRep*) rep
{
	// archives preferentially store ONLY the pdf data as a raw PDF rep. On dearchiving, this uses the rep to reconstruct the
	// image as a whole
	
	NSAssert( rep != nil, @"pdf image rep was nil");
	
	NSSize size = [rep size];
	
	LogEvent_(kStateEvent, @"setting pdf rep, size = %@", NSStringFromSize( size ));
	
	if ( size.width > 0 && size.height > 0 )
	{
		NSImage* image = [[NSImage alloc] initWithSize:size];
	
		[image addRepresentation:rep];
		[self setImage:image];
		[image release];
	}
}


#pragma mark -
- (void)				setScale:(float) scale
{
	NSAssert( scale > 0.0, @"scale cannot be zero or negative");
	
	m_scale = scale;
}


- (float)				scale
{
	return m_scale;
}


#pragma mark -
- (void)				setInterval:(float) interval
{
	NSAssert( interval > 0.0, @"interval cannot be zero or negative");
	
	m_interval = interval;
}


- (float)				interval
{
	return m_interval;
}


#pragma mark -
- (void)				setLeaderDistance:(float) leader
{
	m_leader = leader;
}


- (float)				leaderDistance
{
	return m_leader;
}


#pragma mark -
- (void)				setNormalToPath:(BOOL) norml
{
	m_normalToPath = norml;
}


- (BOOL)				normalToPath
{
	return m_normalToPath;
}


#pragma mark -
- (void)				setPathClipping:(int) clipping
{
	m_pathClip = clipping;
}


- (int)					pathClipping
{
	return m_pathClip;
}


#pragma mark -
- (void)				setLeadInLength:(float) linLength
{
	m_leadInLength = linLength;
}


- (void)				setLeadOutLength:(float) loutLength
{
	m_leadOutLength = loutLength;
}


- (float)				leadInLength
{
	return m_leadInLength;
}


- (float)				leadOutLength
{
	return m_leadOutLength;
}


#pragma mark -
- (void)				setLeadInAndOutLengthProportion:(float) proportion
{
	m_liloProportion = proportion;
	
	if ( proportion <= 0.0 )
		m_leadInLength = m_leadOutLength = 0.0;
}


- (float)				leadInAndOutLengthProportion
{
	return m_liloProportion;
}


- (float)				rampFunction:(float) val
{
	// return a value in 0..1 given a value in 0..1 which is used to set the curvature of the leadin and lead out ramps
	// (for a linear ramp, return val)
	
	return 0.5 * ( 1 - cosf( fmodf( val, 1.0 ) * pi ));
}


#pragma mark -
- (void)				setUsesChainMethod:(BOOL) chain
{
	// experimental: allows use of "chain" callback which emulates links more accurately than image drawing - but really this ought to be
	// pushed out into another more specialised class.
	
	m_useChainMethod = chain;
}


- (BOOL)				usesChainMethod
{
	return m_useChainMethod;
}	


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)			observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"scale", @"interval",
																								@"normalToPath", @"image",
																								@"leaderDistance",
																								@"leadInAndOutLengthProportion",
																								@"pathClipping",
																								@"usesChainMethod", nil]];
}


- (void)				registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Image Scale" forKeyPath:@"scale"];
	[self setActionName:@"#kind# Image Spacing" forKeyPath:@"interval"];
	[self setActionName:@"#kind# Align To Path Curvature" forKeyPath:@"normalToPath"];
	[self setActionName:@"#kind# Image" forKeyPath:@"image"];
	[self setActionName:@"#kind# Leader Length" forKeyPath:@"leaderDistance"];
	[self setActionName:@"#kind# Ramp" forKeyPath:@"leadInAndOutLengthProportion"];
	[self setActionName:@"#kind# Clip To Path" forKeyPath:@"pathClipping"];
	[self setActionName:@"#kind# To Chain" forKeyPath:@"usesChainMethod"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	if (m_cache != nil)
	{
		CGLayerRelease( m_cache );
	}
	[m_pdf release];
	[m_image release];
	
	[super dealloc];
}


- (id)					init
{
	// default init method has no image - one needs to be added to get something rendered
	
	return [self initWithImage:nil];
}


#pragma mark -
#pragma mark As part of BezierPlacement Protocol
- (id)					placeObjectAtPoint:(NSPoint) p onPath:(NSBezierPath*) path position:(float) pos slope:(float) slope userInfo:(void*) userInfo
{
	#pragma unused(userInfo)
	
	NSImage* img = [self image];
	
	if ( img != nil )
	{
		NSSize	iSize = [img size];
		
		float	leadScale = 1.0;
		
		if ( path != nil )
		{
			float	loLen = [path length] - m_leadOutLength;
			
			if ( m_leadInLength != 0 && pos < m_leadInLength )
				leadScale = [self rampFunction:pos / m_leadInLength];
			else if ( m_leadOutLength != 0 && pos > loLen )
				leadScale = [self rampFunction:1.0 - ((pos - loLen) / m_leadOutLength)];
			
			// if size has reduced to zero, nothing to do
					
			if ( leadScale <= 0.0 )
				return nil;
		}
		
		NSAffineTransform* tfm = [NSAffineTransform transform];
		
		[tfm translateXBy:p.x yBy:p.y];
		[tfm scaleXBy:[self scale] * leadScale yBy:[self scale] * -1.0 * leadScale ];
		
		if( [self normalToPath])
			[tfm rotateByRadians:-slope];
		
		[tfm translateXBy:-(iSize.width / 2) yBy:-(iSize.height / 2)];

		// does it really need to be drawn at all?
		
		NSRect drawnRect;
		DKDrawingView*	cv = [DKDrawingView currentlyDrawingView];	// n.b. can be nil if drawing into image, etc
		
		drawnRect.origin = [tfm transformPoint:NSZeroPoint];
		NSPoint qp = [tfm transformPoint:NSMakePoint( iSize.width, iSize.height )];
		
		drawnRect = NSRectFromTwoPoints( drawnRect.origin, qp );
		
		float maxw = MAX( drawnRect.size.width, drawnRect.size.height );
		drawnRect.size.width = drawnRect.size.height = maxw * 1.4;
		drawnRect = CentreRectOnPoint( drawnRect, p );
		
		//[[NSColor blackColor] set];
		//NSFrameRectWithWidth( drawnRect, 1.0 );
		
		if( cv == nil || [cv needsToDrawRect:drawnRect])
		{
			NSAssert([NSGraphicsContext currentContext] != nil, @"no context for drawing path decorator motif");
			
			[NSGraphicsContext saveGraphicsState];
			[tfm concat];
			
			if (( m_cache != nil ) && m_lowQuality )
			{
				CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
				CGContextDrawLayerAtPoint( context, CGPointZero, m_cache );
			}
			else if ( m_pdf != nil  )
				[m_pdf draw];
			else
				[img drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
			
			[NSGraphicsContext restoreGraphicsState];
		}
	}
	return nil;
}


- (id)					placeLinkFromPoint:(NSPoint) pa toPoint:(NSPoint) pb onPath:(NSBezierPath*) path linkNumber:(int) lkn userInfo:(void*) userInfo
{
	#pragma unused(path)
	
	int pass = *(int*)userInfo;
	
	if (( lkn & 1 ) == pass ) 
	{
		NSBezierPath* linkPath = [NSBezierPath bezierPathWithStandardChainLinkFromPoint:pa toPoint:pb];
		
		[linkPath setLineWidth:0.5];
		
		if ( lkn & 1 )
			[[NSColor lightGrayColor] set];
		else
			[[NSColor grayColor] set];
		[linkPath fill];
		[[NSColor blackColor] set];
		[linkPath stroke];
	}
	return nil;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (NSSize)				extraSpaceNeeded
{
	NSSize es = [super extraSpaceNeeded];
	
	if ([self image] != nil && [self enabled])
	{
		NSSize ss = [[self image] size];
		
		float max = MAX( ss.width, ss.height ) * [self scale];
		float xtra = hypotf( max, max );
		
		es.width += xtra / 2.0;
		es.height += xtra / 2.0;
	}
	return es;
}


- (void)				render:(id) obj
{
	if([self enabled] && ([self image] != nil || [self usesChainMethod]))
	{
		if ( m_cache == NULL && [self image] != nil )
			[self setUpCache];
			
		m_lowQuality = [obj useLowQualityDrawing];

		NSBezierPath* path = [self renderingPathForObject:obj];
		
		if ([self leaderDistance] > 0 )
			path = [path bezierPathByTrimmingFromLength:[self leaderDistance]];
			
		if ([self leadInAndOutLengthProportion] != 0)
		{
			// set up lead in and out lengths as a proportion of path length - this will scale the image
			// proportional to length over that distance so that the effect tapers off at both ends of the path
			
			float	pathLength = [path length];
			float	lilo = pathLength * [self leadInAndOutLengthProportion];
			
			[self setLeadInLength:lilo];
			[self setLeadOutLength:lilo];
		}
		
		// apply clipping, if any
		
		if ( m_pathClip && path )
		{
			if ( m_pathClip == kGCPathDecoratorClipOutsidePath )
			{
				// clip to the area outside the path
				
				[path addInverseClip];
			}
			else
				[path addClip];
		}

		[self renderPath:path];
	}
}


- (void)				renderPath:(NSBezierPath*) path
{
	if([self usesChainMethod])
	{
		int pass = 0;
		
		[path placeLinksOnPathWithLinkLength:[self interval] factoryObject:self userInfo:&pass];
		
		++pass;
		[path placeLinksOnPathWithLinkLength:[self interval] factoryObject:self userInfo:&pass];
	}
	else
		[path placeObjectsOnPathAtInterval:[self interval] factoryObject:self userInfo:NULL];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	// save one representation only, whichever is better. On reload, the
	// lower quality version is recreated from the higher quality one on the fly
	
	if ( m_pdf != nil )
		[coder encodeObject:m_pdf forKey:@"pdf_rep"];
	else
		[coder encodeObject:[self image] forKey:@"image"];
		
	[coder encodeFloat:[self scale] forKey:@"scale"];
	[coder encodeFloat:[self interval] forKey:@"interval"];
	[coder encodeFloat:[self leaderDistance] forKey:@"leader"];
	[coder encodeFloat:[self leadInLength] forKey:@"lead_in_length"];
	[coder encodeFloat:[self leadOutLength] forKey:@"lead_out_length"];
	[coder encodeFloat:[self leadInAndOutLengthProportion] forKey:@"lead_inout_proportion"];
	
	[coder encodeBool:[self normalToPath] forKey:@"normal"];
	[coder encodeBool:[self usesChainMethod] forKey:@"chainmeth"];
	[coder encodeInt:[self pathClipping] forKey:@"clipping"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		// try to load the best representation - pdf first. If not then other image.
		// n.b. pdf also sets image so if this succeeds you have both after this.
		
		NSPDFImageRep* pdfRep = [coder decodeObjectForKey:@"pdf_rep"];
		if (pdfRep != nil)
			[self setPDFImageRep:pdfRep];
		
		// if the pdf was not able to set up the image, try using the image straight from the archive
		
		if([self image] == nil)
		{
			NSImage* image = [coder decodeObjectForKey:@"image"];
			
			if ( image != nil && [image isValid] && [[image representations] count] > 0 )
				[self setImage:image];
		}
		
		[self setScale:[coder decodeFloatForKey:@"scale"]];
		[self setInterval:[coder decodeFloatForKey:@"interval"]];
		[self setLeaderDistance:[coder decodeFloatForKey:@"leader"]];
		[self setLeadInLength:[coder decodeFloatForKey:@"lead_in_length"]];
		[self setLeadOutLength:[coder decodeFloatForKey:@"lead_out_length"]];
		[self setLeadInAndOutLengthProportion:[coder decodeFloatForKey:@"lead_inout_proportion"]];
		
		[self setNormalToPath:[coder decodeBoolForKey:@"normal"]];
		[self setUsesChainMethod:[coder decodeBoolForKey:@"chainmeth"]];
		[self setPathClipping:[coder decodeIntForKey:@"clipping"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)					copyWithZone:(NSZone*) zone
{
	DKPathDecorator* dc = [super copyWithZone:zone];
	
	if ( m_pdf )
	{
		NSPDFImageRep* pdfCopy = [m_pdf copyWithZone:zone];
		[dc setPDFImageRep:pdfCopy];
		[pdfCopy release];
	}
	else
	{
		NSImage* imgCopy = [[self image] copyWithZone:zone];
		[dc setImage:imgCopy];
		[imgCopy release];
	}
	
	[dc setScale:[self scale]];
	[dc setInterval:[self interval]];
	[dc setLeaderDistance:[self leaderDistance]];
	[dc setLeadInLength:[self leadInLength]];
	[dc setLeadOutLength:[self leadOutLength]];
	[dc setLeadInAndOutLengthProportion:[self leadInAndOutLengthProportion]];
	
	[dc setNormalToPath:[self normalToPath]];
	[dc setUsesChainMethod:[self usesChainMethod]];
	[dc setPathClipping:[self pathClipping]];
	
	return dc;
}


@end
