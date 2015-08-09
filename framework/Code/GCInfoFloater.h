/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/**
This class provides a very simple tooltip-like window in which you can display a short piece of information, such
as a single numeric value.

By positioning this next to the mouse and supplying it with info, you can enhance the usability of some kinds of
user interaction.
*/
@interface GCInfoFloater : NSWindow {
@private
	NSControl* m_infoViewRef;
	NSSize m_wOffset;
}

/**  */
+ (GCInfoFloater*)infoFloater;

- (void)setFloatValue:(float)val;
- (void)setDoubleValue:(double)val;
- (void)setStringValue:(NSString*)str;

- (void)setFormat:(NSString*)fmt;
- (void)setWindowOffset:(NSSize)offset;
- (void)positionNearPoint:(NSPoint)p inView:(NSView*)v;
- (void)positionAtScreenPoint:(NSPoint)sp;

- (void)show;
- (void)hide;

@end
