//
//  DKQuartzCache.m
//  GCDrawKit
//
//  Created by graham on 4/09/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKQuartzCache.h"


@implementation DKQuartzCache


+ (DKQuartzCache*)	cacheForCurrentContextWithSize:(NSSize) size
{
	DKQuartzCache* cache = [[self alloc] initWithContext:[NSGraphicsContext currentContext] forRect:NSMakeRect( 0, 0, size.width, size.height )];
	return [cache autorelease];
}


+ (DKQuartzCache*)	cacheForCurrentContextInRect:(NSRect) rect
{
	DKQuartzCache* cache = [[self alloc] initWithContext:[NSGraphicsContext currentContext] forRect:rect];
	return [cache autorelease];
}


+ (DKQuartzCache*)	cacheForImage:(NSImage*) image
{
	NSAssert( image != nil, @"cannot create cache for nil image");
	
	DKQuartzCache* cache = [[self alloc] initWithContext:[NSGraphicsContext currentContext] forRect:NSMakeRect( 0, 0, [image size].width, [image size].height )];
	[cache setFlipped:[image isFlipped]];
	[cache lockFocus];
	[image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	[cache unlockFocus];
	
	return [cache autorelease];
}


+ (DKQuartzCache*)	cacheForImageRep:(NSImageRep*) imageRep
{
	NSAssert( imageRep != nil, @"cannot create cache for nil image rep");
	
	DKQuartzCache* cache = [[self alloc] initWithContext:[NSGraphicsContext currentContext] forRect:NSMakeRect( 0, 0, [imageRep size].width, [imageRep size].height )];
	[cache lockFocus];
	[imageRep drawAtPoint:NSZeroPoint];
	[cache unlockFocus];
	
	return [cache autorelease];
}




#pragma mark -


- (id)				initWithContext:(NSGraphicsContext*) context forRect:(NSRect) rect
{
	NSAssert( context != nil, @"attempt to init cache with a nil context");
	NSAssert( !NSEqualSizes( rect.size, NSZeroSize ), @"cannot init cache with zero size" );
	
	self = [super init];
	if( self )
	{
		CGContextRef port = [context graphicsPort];
		CGSize cg_size = CGSizeMake( NSWidth( rect ), NSHeight( rect ));
		mCGLayer = CGLayerCreateWithContext( port, cg_size, NULL );
		mOrigin = rect.origin;
		[self setFlipped:[context isFlipped]];
	}
	
	return self;
}



- (NSSize)			size
{
	CGSize cg_size = CGLayerGetSize( mCGLayer );
	return NSMakeSize( cg_size.width, cg_size.height );
}



- (CGContextRef)	context
{
	return CGLayerGetContext( mCGLayer );
}


- (void)			setFlipped:(BOOL) flipped
{
	mFlipped = flipped;
}


- (BOOL)			flipped
{
	return mFlipped;
}



- (void)			drawAtPoint:(NSPoint) point
{
	[self drawAtPoint:point operation:kCGBlendModeNormal fraction:1.0];
}


- (void)			drawAtPoint:(NSPoint) point operation:(CGBlendMode) op fraction:(CGFloat) frac
{
	CGPoint cg_point = CGPointMake( point.x, point.y );
	CGContextRef port = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSetAlpha(port, frac);
	CGContextSetBlendMode(port, op);
	CGContextDrawLayerAtPoint( port, cg_point, mCGLayer );
}



- (void)			drawInRect:(NSRect) rect
{
	CGRect cg_rect = CGRectMake( rect.origin.x, rect.origin.y, rect.size.width, rect.size.height );
	CGContextRef port = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextDrawLayerInRect( port, cg_rect, mCGLayer );
}




- (void)			lockFocus
{
	// bracket drawing calls to establish what is cached by -lockFocus and -unlockFocus. The drawing must be done at {0,0}
	
	NSAssert( mFocusLocked == NO , @"lockFocus called while already locked");
	
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext* newContext = [NSGraphicsContext graphicsContextWithGraphicsPort:[self context] flipped:[self flipped]];
	[NSGraphicsContext setCurrentContext:newContext];
	
	NSAffineTransform* transform = [NSAffineTransform transform];
	[transform translateXBy:-mOrigin.x yBy:-mOrigin.y];
	[transform concat];
	
	mFocusLocked = YES;
}



- (void)			unlockFocus
{
	NSAssert( mFocusLocked == YES, @"unlockFocus called without a matching lockFocus");
	
	[NSGraphicsContext restoreGraphicsState];
	mFocusLocked = NO;
}


#pragma mark -
#pragma mark - as a NSObject

- (void)			dealloc
{
	if( mFocusLocked )
		[self unlockFocus];
	
	CGLayerRelease( mCGLayer );
	[super dealloc];
}



@end
