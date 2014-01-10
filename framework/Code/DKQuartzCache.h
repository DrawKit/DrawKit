/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
