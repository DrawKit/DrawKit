/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"

@class DKQuartzCache;

/** @brief DKHandle is a base class for all handles, which are the knobs attached to shapes for interacting with them.

DKHandle is a base class for all handles, which are the knobs attached to shapes for interacting with them. This is an evolution of DKKnob
 which is still used as a central helper class for dispatching drawing to handles as needed.
 
 DKHandle is subclassed for each handle type, making it easier to customise and also add caching.
*/
@interface DKHandle : NSObject {
@private
	DKQuartzCache* mCache;
	NSSize mSize;
	NSColor* mColour;
}

+ (DKKnobType)type;
+ (DKHandle*)handleForType:(DKKnobType)type size:(NSSize)size colour:(NSColor*)colour;
+ (void)setHandleClass:(Class)hClass forType:(DKKnobType)type;

+ (NSColor*)fillColour;
+ (NSColor*)strokeColour;
+ (NSBezierPath*)pathWithSize:(NSSize)size;
+ (CGFloat)strokeWidth;
+ (CGFloat)scaleFactor;

- (id)initWithSize:(NSSize)size;
- (id)initWithSize:(NSSize)size colour:(NSColor*)colour;
- (NSSize)size;

- (void)setColour:(NSColor*)colour;
- (NSColor*)colour;

- (void)drawAtPoint:(NSPoint)point;
- (void)drawAtPoint:(NSPoint)point angle:(CGFloat)radians;
- (BOOL)hitTestPoint:(NSPoint)point inHandleAtPoint:(NSPoint)hp;

@end
