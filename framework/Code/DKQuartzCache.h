//
//  DKQuartzCache.h
//  GCDrawKit
//
//  Created by graham on 4/09/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DKQuartzCache : NSObject
{
@private
	CGLayerRef		mCGLayer;
	BOOL			mFocusLocked;
	BOOL			mFlipped;
	NSPoint			mOrigin;
}

+ (DKQuartzCache*)	cacheForCurrentContextWithSize:(NSSize) size;
+ (DKQuartzCache*)	cacheForCurrentContextInRect:(NSRect) rect;
+ (DKQuartzCache*)	cacheForImage:(NSImage*) image;
+ (DKQuartzCache*)	cacheForImageRep:(NSImageRep*) imageRep;


- (id)				initWithContext:(NSGraphicsContext*) context forRect:(NSRect) rect;
- (NSSize)			size;
- (CGContextRef)	context;

- (void)			setFlipped:(BOOL) flipped;
- (BOOL)			flipped;

- (void)			drawAtPoint:(NSPoint) point;
- (void)			drawAtPoint:(NSPoint) point operation:(CGBlendMode) op fraction:(CGFloat) frac;
- (void)			drawInRect:(NSRect) rect;

- (void)			lockFocus;
- (void)			unlockFocus;


@end


/*

Higher-level wrapper for CGLayer, used to cache graphics in numerous places in DK.


*/

