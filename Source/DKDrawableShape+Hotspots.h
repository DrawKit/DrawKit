/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawableShape.h"

NS_ASSUME_NONNULL_BEGIN

@class DKHotspot;
@protocol DKHotspotDelegate;

typedef NS_ENUM(NSInteger, DKHotspotState) {
	kDKHotspotStateOff = 0,
	kDKHotspotStateOn = 1,
	kDKHotspotStateDisabled = 2
};

/** @brief A HOTSPOT is an object attached to a shape to provide a direct user-interface for implementing custom actions, etc.

 A HOTSPOT is an object attached to a shape to provide a direct user-interface for implementing custom actions, etc.

 Hotspots are clickable areas on a shape indicated by a special "knob" appearance. They can appear anywhere within the bounds. When clicked,
 they will be tracked and can do any useful thing they wish. The original purpose is to allow the direct manipulation of certain shape parameters
 such as radius of round corners, and so on, but the design is completely general-purpose.

 The action of a hotspot is handled by default by its delegate, though you could also subclass it and implement the action directly if you wish.

 The appearance of a hotspot is drawn by default by a method of DKKnob.
*/
@interface DKDrawableShape (Hotspots)

- (NSInteger)addHotspot:(DKHotspot*)hspot;
- (void)removeHotspot:(DKHotspot*)hspot;
- (void)setHotspots:(NSArray<DKHotspot*>*)spots;
- (NSArray<DKHotspot*>*)hotspots;

- (nullable DKHotspot*)hotspotForPartCode:(NSInteger)pc;
- (nullable DKHotspot*)hotspotUnderMouse:(NSPoint)mp;
- (NSPoint)hotspotPointForPartcode:(NSInteger)pc;

- (NSRect)hotspotRect:(DKHotspot*)hs;
- (void)drawHotspotAtPoint:(NSPoint)hp inState:(DKHotspotState)state;
- (void)drawHotspotsInState:(DKHotspotState)state;

@end

enum {
	kDKHotspotBasePartcode = 32768
};

#pragma mark -

@interface DKHotspot : NSObject <NSCoding, NSCopying> {
	DKDrawableShape* __weak m_owner;
	NSInteger m_partcode;
	NSPoint m_relLoc;
	__weak id<DKHotspotDelegate> m_delegate;
}

- (instancetype)init;
- (instancetype)initHotspotWithOwner:(nullable DKDrawableShape*)shape partcode:(NSInteger)pc delegate:(nullable id<DKHotspotDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;

@property (weak) DKDrawableShape *owner;
- (void)setOwner:(nullable DKDrawableShape*)shape withPartcode:(NSInteger)pc;

@property NSInteger partcode;

@property NSPoint relativeLocation;

- (void)drawHotspotAtPoint:(NSPoint)p inState:(DKHotspotState)state;

@property (weak, nullable) id<DKHotspotDelegate> delegate;

- (void)startMouseTracking:(NSEvent*)event inView:(NSView*)view;
- (void)continueMouseTracking:(NSEvent*)event inView:(NSView*)view;
- (void)endMouseTracking:(NSEvent*)event inView:(NSView*)view;

@end

#define kDKDefaultHotspotSize NSMakeSize(6, 6)

#pragma mark -

@protocol DKHotspotDelegate <NSObject>
@optional

- (void)hotspot:(DKHotspot*)hs willBeginTrackingWithEvent:(NSEvent*)event inView:(NSView*)view;
- (void)hotspot:(DKHotspot*)hs isTrackingWithEvent:(NSEvent*)event inView:(NSView*)view;
- (void)hotspot:(DKHotspot*)hs didEndTrackingWithEvent:(NSEvent*)event inView:(NSView*)view;

@end

NS_ASSUME_NONNULL_END
