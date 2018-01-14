/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

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

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithContext:(NSGraphicsContext*)context forRect:(NSRect)rect NS_DESIGNATED_INITIALIZER;
@property (readonly) NSSize size;
@property (readonly) CGContextRef context CF_RETURNS_NOT_RETAINED;

@property (getter=isFlipped) BOOL flipped;
- (BOOL)flipped API_DEPRECATED_WITH_REPLACEMENT("isFlipped", macosx(10.0, 10.6));

- (void)drawAtPoint:(NSPoint)point;
- (void)drawAtPoint:(NSPoint)point operation:(CGBlendMode)op fraction:(CGFloat)frac;
- (void)drawInRect:(NSRect)rect;

/** @brief bracket drawing calls to establish what is cached by -lockFocus and -unlockFocus.
 @discussion The drawing must be done at {0,0}
 */
- (void)lockFocus;
- (void)lockFocusFlipped:(BOOL)flip;
- (void)unlockFocus;

@end

NS_ASSUME_NONNULL_END
