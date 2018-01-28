/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/**
This class provides a very simple tooltip-like window in which you can display a short piece of information, such
as a single numeric value.

By positioning this next to the mouse and supplying it with info, you can enhance the usability of some kinds of
user interaction.
*/
@interface GCInfoFloater : NSWindow {
@private
	__unsafe_unretained NSControl* m_infoViewRef;
	NSSize m_wOffset;
}

/**  */
+ (GCInfoFloater*)infoFloater;

- (void)setFloatValue:(float)val;
- (void)setDoubleValue:(double)val;
- (void)setStringValue:(NSString*)str;

- (void)setFormat:(nullable NSString*)fmt;
@property NSSize windowOffset;

/** places the window just to the right and above the point \c p as expressed in the coordinate system of view <code>v</code>.
*/
- (void)positionNearPoint:(NSPoint)p inView:(NSView*)v;
- (void)positionAtScreenPoint:(NSPoint)sp;

- (void)show;
- (void)hide;

@end

NS_ASSUME_NONNULL_END
