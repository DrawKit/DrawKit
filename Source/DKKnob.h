/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"

// visual flags, used internally

typedef enum {
	kDKKnobDrawsStroke = (1 << 0),
	kDKKnobDrawsFill = (1 << 1)
} DKKnobDrawingFlags;

@class DKHandle;

/** @brief simple class used to provide the drawing of knobs for object selection.

simple class used to provide the drawing of knobs for object selection. You can override this and replace it (attached to any layer)
to customise the appearance of the selection knobs for all drawn objects in that layer.

The main method a drawable will call is drawKnobAtPoint:ofType:userInfo:

The type (DKKnobType) is a functional description of the knob only - this class maps that functional description to a consistent appearance taking
into account the basic type and a couple of generic state flags. Clients should generally avoid trying to do drawing themselves of knobs, but if they do,
should use the lower level methods here to get consistent results.

Subclasses may want to customise many aspects of a knob's appearance, and can override any suitable factored methods according to their needs. Customisations
might include the shape of a knob, its colours, whether stroked or filled or both, etc.
*/
@interface DKKnob : NSObject <NSCoding, NSCopying> {
@private
	id m_ownerRef; // the object that owns (and hence retains) this - typically a DKLayer
	NSSize m_knobSize; // the currently cached knob size
	CGFloat mScaleRatio; // ratio to zoom factor used to scale knob size (default = 0.3)
	NSColor* mControlKnobColour; // colour of square knobs
	NSColor* mRotationKnobColour; // colour of rotation knobs
	NSColor* mControlOnPathPointColour; // colour of on-path control points
	NSColor* mControlOffPathPointColour; // colour of off-path control points
	NSColor* mControlBarColour; // colour of control bars
	NSSize mControlKnobSize; // control knob size
	CGFloat mControlBarWidth; // control bar width
}

/**  */
+ (id)standardKnobs;

// main high-level methods that will be called by clients

- (void)setOwner:(id<DKKnobOwner>)owner;
- (id<DKKnobOwner>)owner;

- (void)drawKnobAtPoint:(NSPoint)p ofType:(DKKnobType)knobType userInfo:(id)userInfo;
- (void)drawKnobAtPoint:(NSPoint)p ofType:(DKKnobType)knobType angle:(CGFloat)radians userInfo:(id)userInfo;
- (void)drawKnobAtPoint:(NSPoint)p ofType:(DKKnobType)knobType angle:(CGFloat)radians highlightColour:(NSColor*)aColour;

- (void)drawControlBarFromPoint:(NSPoint)a toPoint:(NSPoint)b;
- (void)drawControlBarWithKnobsFromPoint:(NSPoint)a toPoint:(NSPoint)b;
- (void)drawControlBarWithKnobsFromPoint:(NSPoint)a ofType:(DKKnobType)typeA toPoint:(NSPoint)b ofType:(DKKnobType)typeB;
- (void)drawRotationBarWithKnobsFromCentre:(NSPoint)centre toPoint:(NSPoint)p;
- (void)drawPartcode:(NSInteger)code atPoint:(NSPoint)p fontSize:(CGFloat)fontSize;

- (BOOL)hitTestPoint:(NSPoint)p inKnobAtPoint:(NSPoint)kp ofType:(DKKnobType)knobType userInfo:(id)userInfo;

- (void)setControlBarColour:(NSColor*)clr;
- (NSColor*)controlBarColour;
- (void)setControlBarWidth:(CGFloat)width;
- (CGFloat)controlBarWidth;

- (void)setScalingRatio:(CGFloat)scaleRatio;
- (CGFloat)scalingRatio;

// low-level methods (mostly internal and overridable)

- (void)setControlKnobSize:(NSSize)cks;
- (void)setControlKnobSizeForViewScale:(CGFloat)scale;
- (NSSize)controlKnobSize;

// new model APIs

- (DKHandle*)handleForType:(DKKnobType)knobType;
- (DKHandle*)handleForType:(DKKnobType)knobType colour:(NSColor*)colour;
- (NSSize)actualHandleSize;

@end

#pragma mark -

@interface DKKnob (Deprecated)

+ (void)setControlKnobColour:(NSColor*)clr;
+ (NSColor*)controlKnobColour;

+ (void)setRotationKnobColour:(NSColor*)clr;
+ (NSColor*)rotationKnobColour;

+ (void)setControlOnPathPointColour:(NSColor*)clr;
+ (NSColor*)controlOnPathPointColour;
+ (void)setControlOffPathPointColour:(NSColor*)clr;
+ (NSColor*)controlOffPathPointColour;

+ (void)setControlBarColour:(NSColor*)clr;
+ (NSColor*)controlBarColour;

+ (void)setControlKnobSize:(NSSize)size;
+ (NSSize)controlKnobSize;

+ (void)setControlBarWidth:(CGFloat)width;
+ (CGFloat)controlBarWidth;

+ (NSRect)controlKnobRectAtPoint:(NSPoint)kp;

- (NSColor*)fillColourForKnobType:(DKKnobType)knobType;
- (NSColor*)strokeColourForKnobType:(DKKnobType)knobType;
- (CGFloat)strokeWidthForKnobType:(DKKnobType)knobType;

// setting colours and sizes per-DKKnob instance

- (void)setControlKnobColour:(NSColor*)clr;
- (NSColor*)controlKnobColour;
- (void)setRotationKnobColour:(NSColor*)clr;
- (NSColor*)rotationKnobColour;

- (void)setControlOnPathPointColour:(NSColor*)clr;
- (NSColor*)controlOnPathPointColour;
- (void)setControlOffPathPointColour:(NSColor*)clr;
- (NSColor*)controlOffPathPointColour;

- (NSRect)controlKnobRectAtPoint:(NSPoint)kp;
- (NSRect)controlKnobRectAtPoint:(NSPoint)kp ofType:(DKKnobType)knobType;

- (NSBezierPath*)knobPathAtPoint:(NSPoint)p ofType:(DKKnobType)knobType angle:(CGFloat)radians userInfo:(id)userInfo;
- (void)drawKnobPath:(NSBezierPath*)path ofType:(DKKnobType)knobType userInfo:(id)userInfo;
- (DKKnobDrawingFlags)drawingFlagsForKnobType:(DKKnobType)knobType;

@end

// keys in the userInfo that can be used to pass additional information to the knob drawing methods

extern NSString* kDKKnobPreferredHighlightColour; // references an NSColor
