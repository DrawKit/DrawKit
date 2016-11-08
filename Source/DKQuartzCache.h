/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief Higher-level wrapper for CGLayer, used to cache graphics in numerous places in DK.

Higher-level wrapper for CGLayer, used to cache graphics in numerous places in DK.
*/
@interface DKQuartzCache : NSObject {
@private
	CGLayerRef mCGLayer;
	BOOL mFocusLocked;
	BOOL mFlipped;
	NSPoint mOrigin;
}

+ (DKQuartzCache*)cacheForCurrentContextWithSize:(NSSize)size;
+ (DKQuartzCache*)cacheForCurrentContextInRect:(NSRect)rect;
+ (DKQuartzCache*)cacheForImage:(NSImage*)image;
+ (DKQuartzCache*)cacheForImageRep:(NSImageRep*)imageRep;

- (id)initWithContext:(NSGraphicsContext*)context forRect:(NSRect)rect;
- (NSSize)size;
- (CGContextRef)context;

- (void)setFlipped:(BOOL)flipped;
- (BOOL)flipped;

- (void)drawAtPoint:(NSPoint)point;
- (void)drawAtPoint:(NSPoint)point operation:(CGBlendMode)op fraction:(CGFloat)frac;
- (void)drawInRect:(NSRect)rect;

- (void)lockFocus;
- (void)unlockFocus;

@end
