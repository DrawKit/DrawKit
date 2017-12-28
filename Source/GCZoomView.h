/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@class DKRetriggerableTimer;

/** @brief This is a very general-purpose view class that provides some handy high-level methods for doing zooming.

 This is a very general-purpose view class that provides some handy high-level methods for doing zooming. Simply hook up
 the action methods to suitable menu commands and away you go. The stuff you draw within drawRect: doesn't need to know or
 care abut the zoom of the view - you can just draw as usual and it works.

 @note
 this class doesn't bother to support NSCoding and thereby encoding the view zoom, because it usually isn't important for this
 value to persist. However, if your subclass wants to support coding, your initWithCoder method should reset \c _scale to <code>1.0</code>. Otherwise
 it will get initialized to \c 0.0 and \b NOTHING \b WILL \b BE \b DRAWN.
*/
@interface GCZoomView : NSView {
@private
	CGFloat m_scale; // the zoom scale of the view (1.0 = 100%)
	CGFloat mMinScale;
	CGFloat mMaxScale;
	NSUInteger mScrollwheelModifierMask;
	BOOL mIsChangingScale;
	DKRetriggerableTimer* mRT;
}

/** @brief Return whether scroll-wheel zooming is enabled
 
 \c YES to enable, \c NO to disable.
 Default is <code>YES</code>
 */
@property (class) BOOL scrollwheelZoomEnabled;

/** @brief Set the modifier key(s) that will activate zooming using the scrollwheel

 Operating the given modifier keys along with the scroll wheel will zoom the view
 @param aMask a modifier key mask value
 @deprecated This class method is misspelled. Use \c +setScrollwheelModifierKeyMask: instead.
 */
+ (void)setScrollwheelModiferKeyMask:(NSEventModifierFlags)aMask API_DEPRECATED_WITH_REPLACEMENT("setScrollwheelModifierKeyMask", macosx(10.0, 10.6));

/** @brief Return the default zoom key mask used by new instances of this class

 Reads the value from the prefs. If not set or set to zero, defaults to option key.
 Operating the given modifier keys along with the scroll wheel will zoom the view
 */
@property (class) NSEventModifierFlags scrollwheelModifierKeyMask;

/** @brief Return whether view zooms in or out for a given scrollwheel rotation direction

 Default sense is to zoom in when scrollwheel is rotated towards the user. Some apps (e.g. Google Earth)
 use the opposite convention, which feels less natural but may become a defacto "standard".
 */
@property (class) BOOL scrollwheelInverted;

/** @brief Zoom in (scale up) by a factor of 2
 @param sender - the sender of the action
 */
- (IBAction)zoomIn:(id)sender;

/** @brief Zoom out (scale down) by a factor of 2
 @param sender - the sender of the action
 */
- (IBAction)zoomOut:(id)sender;

/** @brief Restore the zoom to 100%
 @param sender - the sender of the action
 */
- (IBAction)zoomToActualSize:(id)sender;

/** @brief Zoom so that the entire extent of the enclosing frame is visible
 @param sender - the sender of the action
 */
- (IBAction)zoomFitInWindow:(id)sender;

/** @brief Takes the senders tag value as the desired percentage
 @param sender - the sender of the action
 */
- (IBAction)zoomToPercentageWithTag:(id)sender;
- (IBAction)zoomMax:(id)sender;
- (IBAction)zoomMin:(id)sender;

/** @brief Zoom by the desired scaling factor

 A factor of 2.0 will double the zoom scale, from 100% to 200% say, a factor of 0.5 will zoom out.
 This also maintains the current visible centre point of the view so the zoom remains stable.
 @param factor - how much to change the current scale by
 */
- (void)zoomViewByFactor:(CGFloat)factor;
- (void)zoomViewToAbsoluteScale:(CGFloat)scale;

/** @brief Zooms so that the passed rect will fit in the view

 In general this should be used for a zoom OUT, such as a "fit to window" command, though it will
 zoom in if the view is smaller than the current frame.
 @param aRect - a rect
 */
- (void)zoomViewToFitRect:(NSRect)aRect;

/** @brief Zooms so that the passed rect fills the view

 The centre of the rect is centred in the view. In general this should be used for a zoom IN to a
 specific smaller rectange. \c aRect is in current view coordinates. This is good for a dragged rect
 zoom tool.
 @param aRect - a rect
 */
- (void)zoomViewToRect:(NSRect)aRect;

/** @brief Zooms the view by the given factor and centres the passed point.
 @param factor - relative zoom factor
 @param p a point within the view that should be scrolled to the centre of the zoomed view. */
- (void)zoomViewByFactor:(CGFloat)factor andCentrePoint:(NSPoint)p;
/** @brief Converts the scrollwheel delta value into a zoom factor and performs the zoom.
 @param delta - scrollwheel delta value
 @param cp a point within the view that should be scrolled to the centre of the zoomed view. */
- (void)zoomWithScrollWheelDelta:(CGFloat)delta toCentrePoint:(NSPoint)cp;

/** @brief Calculates the coordinates of the point that is visually centred in the view at the current scroll
 position and zoom.
 */
@property (readonly) NSPoint centredPointInDocView;

/** @brief Scrolls the view so that the point ends up visually centred
 @param aPoint the desired centre point */
- (void)scrollPointToCentre:(NSPoint)aPoint;

/** @brief The current view scale (zoom).
 
 The zoom scale of the view (1.0 = 100%).

 All zooms bottleneck through here. Scale passed is pinned within the min and max limits.
 */
@property (nonatomic) CGFloat scale;

/** @brief Returns whether the scale is being changed

 This property can be used to detect whether the user is rapidly changing the scale, for example using
 the scrollwheel. When a scrollwheel change starts, this is set to YES and a timer is run which is
 retriggered by further events. If it times out, this resets to NO. It can be used as one part of a
 drawing strategy where rapid changes temporarily use a lower quality drawing mechanism for performance,
 but reverts to a higher quality when things settle.
 @return YES if the scale is changing, NO if not
 */
@property (readonly, getter=isChangingScale) BOOL changingScale;

/** @brief The minimum permitted view scale (zoom).
 */
@property CGFloat minimumScale;

/** @brief The maximum permitted view scale (zoom).
 */
@property CGFloat maximumScale;

@end

#define kDKZoomingRetriggerPeriod 0.5

extern NSNotificationName kDKDrawingViewWillChangeScale;
extern NSNotificationName kDKDrawingViewDidChangeScale;

extern NSString* kDKScrollwheelModifierKeyMaskPreferenceKey;
extern NSString* kDKDrawingDisableScrollwheelZoomPrefsKey;
extern NSString* kDKDrawingScrollwheelSensePrefsKey;
