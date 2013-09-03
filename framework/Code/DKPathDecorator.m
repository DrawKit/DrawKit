///**********************************************************************************************************************************
///  DKPathDecorator.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 17/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKPathDecorator.h"

#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "LogEvent.h"
#import "NSBezierPath+Geometry.h"
#import "NSBezierPath+Text.h"
#import "NSBezierPath+Shapes.h"
#import "DKGeometryUtilities.h"
#import "DKDrawKitMacros.h"
#import "DKRandom.h"
#import "DKQuartzCache.h"


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
		m_normalToPath = YES;
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
	
	[mDKCache release];
	mDKCache = nil;

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



#define USE_DK_CACHE		1


- (void)				setUpCache
{
	NSAssert( m_image != nil, @"no image to create cache with");
	
#if USE_DK_CACHE
	if( mDKCache )
		[mDKCache release];
	mDKCache = [[DKQuartzCache cacheForImage:[self image]] retain];
#else
	NSAssert( m_cache == nil, @"expected cache to be NULL");

	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	
	NSAssert( context != NULL, @"bad current context entering setUpCache" );
	
	NSSize		iSize = [m_image size];
	m_cache = CGLayerCreateWithContext( context, *(CGSize*)&iSize, NULL );
	
	NSAssert1( m_cache != NULL, @"couldn't create the layer context for image; size = %@", NSStringFromSize( iSize ));
	
	context = CGLayerGetContext( m_cache );
	
	NSAssert( context != NULL, @"bad layer context in setUpCache" );
	
	// draw the pdf or image into the layer context
	
	SAVE_GRAPHICS_CONTEXT	//[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext* cc = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:[m_image isFlipped]]; 
	
	NSAssert( cc != nil, @"NSGraphicsContext object was nil in setUpCache");
	
	[NSGraphicsContext setCurrentContext:cc];
	
	if ( m_pdf )
		[m_pdf drawAtPoint:NSZeroPoint];
	else
		[m_image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	
	RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
#endif
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
- (void)				setScale:(CGFloat) scale
{
	NSAssert( scale > 0.0, @"scale cannot be zero or negative");
	
	m_scale = scale;
}


- (CGFloat)				scale
{
	return m_scale;
}


- (void)				setScaleRandomness:(CGFloat) scRand
{
	scRand = LIMIT( scRand, 0, 1.0 );
	
	if( scRand != mScaleRandomness )
	{
		mScaleRandomness = scRand;
		
		if(mScaleRandCache == nil )
			mScaleRandCache = [[NSMutableArray alloc] init];
		
		[mScaleRandCache removeAllObjects];
	}
}


- (CGFloat)				scaleRandomness
{
	return mScaleRandomness;
}


#pragma mark -
- (void)				setInterval:(CGFloat) interval
{
	m_interval = interval;
}


- (CGFloat)				interval
{
	return m_interval;
}


#pragma mark -
- (void)				setLeaderDistance:(CGFloat) leader
{
	m_leader = leader;
}


- (CGFloat)				leaderDistance
{
	return m_leader;
}


- (void)				setLateralOffset:(CGFloat) loff
{
	mLateralOffset = loff;
}


- (CGFloat)				lateralOffset
{
	return mLateralOffset;
}



- (void)				setLateralOffsetAlternates:(BOOL) alts
{
	mAlternateLateralOffsets = alts;
}


- (BOOL)				lateralOffsetAlternates
{
	return mAlternateLateralOffsets;
}


- (void)				setWobblyness:(CGFloat) wobble
{
	wobble = LIMIT( wobble, 0, 1 );
	
	if( wobble != mWobblyness )
	{
		mWobblyness = wobble;
		
		if( mWobbleCache == nil )
			mWobbleCache = [[NSMutableArray alloc] init];
		
		[mWobbleCache removeAllObjects];
	}
}


- (CGFloat)				wobblyness
{
	return mWobblyness;
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
- (void)				setLeadInLength:(CGFloat) linLength
{
	m_leadInLength = linLength;
}


- (void)				setLeadOutLength:(CGFloat) loutLength
{
	m_leadOutLength = loutLength;
}


- (CGFloat)				leadInLength
{
	return m_leadInLength;
}


- (CGFloat)				leadOutLength
{
	return m_leadOutLength;
}


#pragma mark -
- (void)				setLeadInAndOutLengthProportion:(CGFloat) proportion
{
	m_liloProportion = proportion;
	
	if ( proportion <= 0.0 )
		m_leadInLength = m_leadOutLength = 0.0;
}


- (CGFloat)				leadInAndOutLengthProportion
{
	return m_liloProportion;
}


- (CGFloat)				rampFunction:(CGFloat) val
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
																								@"usesChainMethod",
																								@"lateralOffset",
																								@"lateralOffsetAlternates",
																								@"wobblyness",
																								@"scaleRandomness",
																								nil]];
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
	[self setActionName:@"#kind# To Chain" forKeyPath:@"usesChainMethod"];
	[self setActionName:@"#kind# Alternating Offset" forKeyPath:@"lateralOffsetAlternates"];
	[self setActionName:@"#kind# Lateral Offset" forKeyPath:@"lateralOffset"];
	[self setActionName:@"#kind# Wobblyness" forKeyPath:@"wobblyness"];
	[self setActionName:@"#kind# Scale Randomness" forKeyPath:@"scaleRandomness"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	[m_pdf release];
	[m_image release];
	[mDKCache release];
	[mWobbleCache release];
	[mScaleRandCache release];
	[super dealloc];
}


- (id)					init
{
	// default init method has no image - one needs to be added to get something rendered
	
	return [self initWithImage:nil];
}


#pragma mark -
#pragma mark As part of BezierPlacement Protocol
- (id)					placeObjectAtPoint:(NSPoint) p onPath:(NSBezierPath*) path position:(CGFloat) pos slope:(CGFloat) slope userInfo:(void*) userInfo
{
	#pragma unused(userInfo)
	
	NSImage* img = [self image];
	
	if ( img != nil )
	{
		NSAssert([NSGraphicsContext currentContext] != nil, @"no context for drawing path decorator motif");
			
		NSSize	iSize = [img size];
		
		CGFloat	leadScale = 1.0;
		
		if ( path != nil )
		{
			CGFloat	loLen = [path length] - m_leadOutLength;
			
			if ( m_leadInLength != 0 && pos <= m_leadInLength )
				leadScale = [self rampFunction:pos / m_leadInLength];
			else if ( m_leadOutLength != 0 && pos >= loLen )
				leadScale = [self rampFunction:1.0 - ((pos - loLen) / m_leadOutLength)];
			
			// if size has reduced to zero, nothing to do
					
			if ( leadScale <= 0.0 )
				return nil;
		}
		
		NSAffineTransform* tfm = [NSAffineTransform transform];

		// displace the image to the side of the path by mLateralOffset in the direction normal to the slope. If the offset is 0,
		// this has no effect except if the alternating flag is also set it flips every other image.
		
		if(( mPlacementCount & 1 ) && mAlternateLateralOffsets)
			slope += pi;
		
		CGFloat dx = mLateralOffset * cosf( slope + HALF_PI );
		CGFloat dy = mLateralOffset * sinf( slope + HALF_PI );
		NSPoint wobblePoint = NSZeroPoint;
		
		if([self wobblyness] > 0.0 )
		{
			// wobblyness is a randomising positioning factor from 0..1 that is scaled by the spacing and offset by half. This is
			// cached so that the wobble positions are not recalculated unless the wobble factor itself changes.
			
			if( mPlacementCount < [mWobbleCache count])
				wobblePoint = [[mWobbleCache objectAtIndex:mPlacementCount] pointValue];
			else
			{
				wobblePoint.x = [DKRandom randomPositiveOrNegativeNumber] * [self interval] * [self wobblyness];
				wobblePoint.y = [DKRandom randomPositiveOrNegativeNumber] * [self interval] * [self wobblyness];
				[mWobbleCache addObject:[NSValue valueWithPoint:wobblePoint]];
			}
		}
		
		CGFloat randScale = 1.0;
		
		if([self scaleRandomness] > 0.0 )
		{
			// scale randomness is a randomising factor applied to the scale of the motif. Scale max is always
			// set to the normal scale, the randomising factor makes the scale relatively smaller
			
			if( mPlacementCount < [mScaleRandCache count])
				randScale = [[mScaleRandCache objectAtIndex:mPlacementCount] floatValue];
			else
			{
				randScale = 1.0 + ([DKRandom randomPositiveOrNegativeNumber] * [self scaleRandomness]);
				[mScaleRandCache addObject:[NSNumber numberWithFloat:randScale]];
			}
		}

		[tfm translateXBy:p.x + dx + wobblePoint.x yBy:p.y + dy + wobblePoint.y];
		[tfm scaleXBy:[self scale] * leadScale * randScale yBy:[self scale] * -1.0 * leadScale * randScale ];
		
		if( [self normalToPath])
			[tfm rotateByRadians:-slope];
		
		
		[tfm translateXBy:-(iSize.width / 2) yBy:-(iSize.height / 2)];

		// does it really need to be drawn at all?
		
		NSRect drawnRect;
		DKDrawingView*	cv = [DKDrawingView currentlyDrawingView];	// n.b. can be nil if drawing into image, etc
		
		drawnRect.origin = [tfm transformPoint:NSZeroPoint];
		NSPoint qp = [tfm transformPoint:NSMakePoint( iSize.width, iSize.height )];
		
		drawnRect = NSRectFromTwoPoints( drawnRect.origin, qp );
		
		CGFloat maxw = MAX( drawnRect.size.width, drawnRect.size.height );
		drawnRect.size.width = drawnRect.size.height = maxw * 1.4;
		drawnRect = CentreRectOnPoint( drawnRect, p );
		
		// debugging - show the bbox
		//[[NSColor blackColor] set];
		//NSFrameRectWithWidth( drawnRect, 1.0 );
		
		if( cv == nil || [cv needsToDrawRect:drawnRect])
		{
			SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
			[tfm concat];
			
			if (mDKCache && m_lowQuality )
			{
				[mDKCache drawAtPoint:NSZeroPoint];
			}
			else if ( m_pdf != nil  )
				[m_pdf draw];
			else
				[img drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:1.0];
			
			RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
		}
	}
	
	// increment the placement count - this is used to alternately offset items
	
	++mPlacementCount;
	
	return nil;
}


- (id)					placeLinkFromPoint:(NSPoint) pa toPoint:(NSPoint) pb onPath:(NSBezierPath*) path linkNumber:(NSInteger) lkn userInfo:(void*) userInfo
{
	#pragma unused(path)
	
	NSInteger pass = *(NSInteger*)userInfo;
	
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
		
		CGFloat max = MAX( ss.width, ss.height ) * [self scale];
		CGFloat xtra = hypotf( max, max );
		
		es.width += (xtra / 2.0) + ABS(mLateralOffset);
		es.height += (xtra / 2.0) + ABS(mLateralOffset);
	}
	return es;
}


- (void)				render:(id<DKRenderable>) obj
{
	if( ![obj conformsToProtocol:@protocol(DKRenderable)])
		return;

	if([self enabled] && ([self image] != nil || [self usesChainMethod]))
	{
		if ( mDKCache == nil && [self image] != nil )
			[self setUpCache];
			
		m_lowQuality = [obj useLowQualityDrawing];

		NSBezierPath* path = [self renderingPathForObject:obj];
		
		if ([self leaderDistance] > 0 )
			path = [path bezierPathByTrimmingFromLength:[self leaderDistance]];
			
		if ([self leadInAndOutLengthProportion] != 0)
		{
			// set up lead in and out lengths as a proportion of path length - this will scale the image
			// proportional to length over that distance so that the effect tapers off at both ends of the path
			
			CGFloat	pathLength = [path length];
			CGFloat	lilo = pathLength * [self leadInAndOutLengthProportion];
			
			[self setLeadInLength:lilo];
			[self setLeadOutLength:lilo];
		}
		
		// apply clipping, if any
		
		if ([self clipping] != kDKClippingNone && path )
		{
			if ([self clipping] == kDKClipOutsidePath )
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
	mPlacementCount = 0;
	
	if([self interval] <= 0.0 )
		return;
	
	if([self usesChainMethod])
	{
		NSInteger pass = 0;
		
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
		
	[coder encodeDouble:[self scale] forKey:@"scale"];
	[coder encodeDouble:[self interval] forKey:@"interval"];
	[coder encodeDouble:[self leaderDistance] forKey:@"leader"];
	[coder encodeDouble:[self leadInLength] forKey:@"lead_in_length"];
	[coder encodeDouble:[self leadOutLength] forKey:@"lead_out_length"];
	[coder encodeDouble:[self leadInAndOutLengthProportion] forKey:@"lead_inout_proportion"];
	
	[coder encodeBool:[self normalToPath] forKey:@"normal"];
	[coder encodeBool:[self usesChainMethod] forKey:@"chainmeth"];
	
	[coder encodeDouble:mLateralOffset forKey:@"DKPathDecorator_lateralOffset"];
	[coder encodeBool:mAlternateLateralOffsets forKey:@"DKPathDecorator_alternateLaterals"];
	[coder encodeDouble:mWobblyness forKey:@"DKPathDecorator_wobblyness"];
	[coder encodeDouble:mScaleRandomness forKey:@"DKPathDecorator_scaleRandomness"];
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
		
		[self setScale:[coder decodeDoubleForKey:@"scale"]];
		[self setInterval:[coder decodeDoubleForKey:@"interval"]];
		[self setLeaderDistance:[coder decodeDoubleForKey:@"leader"]];
		[self setLeadInLength:[coder decodeDoubleForKey:@"lead_in_length"]];
		[self setLeadOutLength:[coder decodeDoubleForKey:@"lead_out_length"]];
		[self setLeadInAndOutLengthProportion:[coder decodeDoubleForKey:@"lead_inout_proportion"]];
		
		[self setNormalToPath:[coder decodeBoolForKey:@"normal"]];
		[self setUsesChainMethod:[coder decodeBoolForKey:@"chainmeth"]];

		mLateralOffset = [coder decodeDoubleForKey:@"DKPathDecorator_lateralOffset"];
		mAlternateLateralOffsets = [coder decodeBoolForKey:@"DKPathDecorator_alternateLaterals"];
		mWobblyness = [coder decodeDoubleForKey:@"DKPathDecorator_wobblyness"];
		mScaleRandomness = [coder decodeDoubleForKey:@"DKPathDecorator_scaleRandomness"];
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
	[dc setWobblyness:[self wobblyness]];
	[dc setNormalToPath:[self normalToPath]];
	[dc setUsesChainMethod:[self usesChainMethod]];
	[dc setScaleRandomness:[self scaleRandomness]];
	
	dc->mLateralOffset = mLateralOffset;
	dc->mAlternateLateralOffsets = mAlternateLateralOffsets;
	
	return dc;
}


@end
