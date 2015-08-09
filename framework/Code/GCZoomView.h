/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
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
value to persist. However, if your subclass wants to support coding, your initWithCoder method should reset _scale to 1.0. Otherwise
it will get initialized to 0.0 and NOTHING WILL BE DRAWN.
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

/** @brief Set whether scroll-wheel zooming is enabled

 Default is YES
 @param enable YES to enable, NO to disable
 */
+ (void)setScrollwheelZoomEnabled:(BOOL)enable;

/** @brief Return whether scroll-wheel zooming is enabled

 Default is YES
 @return YES to enable, NO to disable
 */
+ (BOOL)scrollwheelZoomEnabled;

/** @brief Set the modifier key(s) that will activate zooming using the scrollwheel

 Operating the given modifier keys along with the scroll wheel will zoom the view
 @param aMask a modifier key mask value
 */
+ (void)setScrollwheelModiferKeyMask:(NSUInteger)aMask;

/** @brief Return the default zoom key mask used by new instances of this class

 Reads the value from the prefs. If not set or set to zero, defaults to option key.
 @return a modifier key mask value
 */
+ (NSUInteger)scrollwheelModifierKeyMask;

/** @brief Set whether view zooms in or out for a given scrollwheel rotation direction

 Default sense is to zoom in when scrollwheel is rotated towards the user. Some apps (e.g. Google Earth)
 use the opposite convention, which feels less natural but may become a defacto "standard".
 */
+ (void)setScrollwheelInverted:(BOOL)inverted;

/** @brief Return whether view zooms in or out for a given scrollwheel rotation direction

 Default sense is to zoom in when scrollwheel is rotated towards the user. Some apps (e.g. Google Earth)
 use the opposite convention, which feels less natural but may become a defacto "standard".
 @return whether scroll wheel inverted
 */
+ (BOOL)scrollwheelInverted;

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
 specific smaller rectange. <aRect> is in current view coordinates. This is good for a dragged rect
 zoom tool.
 @param aRect - a rect
 */
- (void)zoomViewToRect:(NSRect)aRect;

/** @brief Zooms the view by the given factor and centres the passed point.
 @param factor - relative zoom factor
 @param p a point within the view that should be scrolled to the centre of the zoomed view. */
- (void)zoomViewByFactor:(CGFloat)factor andCentrePoint:(NSPoint)p;
- (void)zoomWithScrollWheelDelta:(CGFloat)delta toCentrePoint:(NSPoint)cp;

/** @brief Calculates the coordinates of the point that is visually centred in the view at the current scroll
 position and zoom.
 @return the visually centred point */
- (NSPoint)centredPointInDocView;

/** @brief Scrolls the view so that the point ends up visually centred
 @param aPoint the desired centre point */
- (void)scrollPointToCentre:(NSPoint)aPoint;

/** @brief Zooms the view to the given scale

 All zooms bottleneck through here. Scale passed is pinned within the min and max limits.
 @param sc - the desired scale
 */
- (void)setScale:(CGFloat)sc;

/** @brief Returns the current view scale (zoom)
 @return the current scale
 */
- (CGFloat)scale;

/** @brief Returns whether the scale is being changed

 This property can be used to detect whether the user is rapidly changing the scale, for example using
 the scrollwheel. When a scrollwheel change starts, this is set to YES and a timer is run which is
 retriggered by further events. If it times out, this resets to NO. It can be used as one part of a
 drawing strategy where rapid changes temporarily use a lower quality drawing mechanism for performance,
 but reverts to a higher quality when things settle.
 @return YES if the scale is changing, NO if not
 */
- (BOOL)isChangingScale;

/** @brief Sets the minimum permitted view scale (zoom)
 @param scmin the minimum scale
 */
- (void)setMinimumScale:(CGFloat)scmin;

/** @brief Returns the minimum permitted view scale (zoom)
 @return the minimum scale
 */
- (CGFloat)minimumScale;

/** @brief Sets the maximum permitted view scale (zoom)
 @param scmax the maximum scale
 */
- (void)setMaximumScale:(CGFloat)scmax;

/** @brief Returns the maximum permitted view scale (zoom)
 @return the maximum scale
 */
- (CGFloat)maximumScale;

@end

#define kDKZoomingRetriggerPeriod 0.5

extern NSString* kDKDrawingViewWillChangeScale;
extern NSString* kDKDrawingViewDidChangeScale;

extern NSString* kDKScrollwheelModifierKeyMaskPreferenceKey;
extern NSString* kDKDrawingDisableScrollwheelZoomPrefsKey;
extern NSString* kDKDrawingScrollwheelSensePrefsKey;
