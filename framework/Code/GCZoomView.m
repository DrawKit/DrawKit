/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "GCZoomView.h"
#import "DKRetriggerableTimer.h"
#import "LogEvent.h"

@interface GCZoomView (Private)

- (void)stopScaleChange;
- (void)startScaleChange;

@end

#pragma mark Constants (Non-localized)

NSString* kDKDrawingViewDidChangeScale = @"kDKDrawingViewDidChangeScale";
NSString* kDKDrawingViewWillChangeScale = @"kDKDrawingViewWillChangeScale";

NSString* kDKScrollwheelModifierKeyMaskPreferenceKey = @"DK_SCROLLWHEEL_ZOOM_KEY_MASK";
NSString* kDKDrawingDisableScrollwheelZoomPrefsKey = @"kDKDrawingDisableScrollwheelZoom";
NSString* kDKDrawingScrollwheelSensePrefsKey = @"kDKDrawingcrollwheelSense"; // typo here, please leave

#pragma mark -
@implementation GCZoomView

/** @brief Set whether scroll-wheel zooming is enabled
 * @note
 * Default is YES
 * @param enable YES to enable, NO to disable
 * @public
 */
+ (void)setScrollwheelZoomEnabled:(BOOL)enable
{
    [[NSUserDefaults standardUserDefaults] setBool:!enable
                                            forKey:kDKDrawingDisableScrollwheelZoomPrefsKey];
}

/** @brief Return whether scroll-wheel zooming is enabled
 * @note
 * Default is YES
 * @return YES to enable, NO to disable
 * @public
 */
+ (BOOL)scrollwheelZoomEnabled
{
    return ![[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingDisableScrollwheelZoomPrefsKey];
}

/** @brief Set the modifier key(s) that will activate zooming using the scrollwheel
 * @note
 * Operating the given modifier keys along with the scroll wheel will zoom the view
 * @param aMask a modifier key mask value
 * @public
 */
+ (void)setScrollwheelModiferKeyMask:(NSUInteger)aMask
{
    [[NSUserDefaults standardUserDefaults] setInteger:aMask
                                               forKey:kDKScrollwheelModifierKeyMaskPreferenceKey];
}

/** @brief Return the default zoom key mask used by new instances of this class
 * @note
 * Reads the value from the prefs. If not set or set to zero, defaults to option key.
 * @return a modifier key mask value
 * @public
 */
+ (NSUInteger)scrollwheelModifierKeyMask
{
    NSUInteger mask = [[NSUserDefaults standardUserDefaults] integerForKey:kDKScrollwheelModifierKeyMaskPreferenceKey];

    if (mask == 0)
        mask = NSAlternateKeyMask;

    return mask;
}

/** @brief Set whether view zooms in or out for a given scrollwheel rotation direction
 * @note
 * Default sense is to zoom in when scrollwheel is rotated towards the user. Some apps (e.g. Google Earth)
 * use the opposite convention, which feels less natural but may become a defacto "standard".
 * @public
 */
+ (void)setScrollwheelInverted:(BOOL)inverted
{
    [[NSUserDefaults standardUserDefaults] setBool:inverted
                                            forKey:kDKDrawingScrollwheelSensePrefsKey];
}

/** @brief Return whether view zooms in or out for a given scrollwheel rotation direction
 * @note
 * Default sense is to zoom in when scrollwheel is rotated towards the user. Some apps (e.g. Google Earth)
 * use the opposite convention, which feels less natural but may become a defacto "standard".
 * @return whether scroll wheel inverted
 * @public
 */
+ (BOOL)scrollwheelInverted
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingScrollwheelSensePrefsKey];
}

#pragma mark -

/** @brief Zoom in (scale up) by a factor of 2
 * @param sender - the sender of the action
 * @public
 */
- (IBAction)zoomIn:(id)sender
{
#pragma unused(sender)

    [self zoomViewByFactor:2.0];
}

/** @brief Zoom out (scale down) by a factor of 2
 * @param sender - the sender of the action
 * @public
 */
- (IBAction)zoomOut:(id)sender
{
#pragma unused(sender)

    [self zoomViewByFactor:0.5];
}

/** @brief Restore the zoom to 100%
 * @param sender - the sender of the action
 * @public
 */
- (IBAction)zoomToActualSize:(id)sender
{
#pragma unused(sender)

    [self zoomViewToAbsoluteScale:1.0];
}

/** @brief Zoom so that the entire extent of the enclosing frame is visible
 * @param sender - the sender of the action
 * @public
 */
- (IBAction)zoomFitInWindow:(id)sender
{
#pragma unused(sender)

    // zooms the view to fit within the current window (command/action)
    NSRect sfr = [[self superview] frame];
    [self zoomViewToFitRect:sfr];
}

/** @brief Takes the senders tag value as the desired percentage
 * @param sender - the sender of the action
 * @public
 */
- (IBAction)zoomToPercentageWithTag:(id)sender
{
    NSInteger tag = [sender tag];
    CGFloat ns = (CGFloat)tag / 100.0f;

    [self zoomViewToAbsoluteScale:ns];
}

- (IBAction)zoomMax:(id)sender
{
#pragma unused(sender)
    [self zoomViewToAbsoluteScale:[self maximumScale]];
}

- (IBAction)zoomMin:(id)sender
{
#pragma unused(sender)
    [self zoomViewToAbsoluteScale:[self minimumScale]];
}

#pragma mark -

/** @brief Zoom by the desired scaling factor
 * @note
 * A factor of 2.0 will double the zoom scale, from 100% to 200% say, a factor of 0.5 will zoom out.
 * This also maintains the current visible centre point of the view so the zoom remains stable.
 * @param factor - how much to change the current scale by
 * @public
 */
- (void)zoomViewByFactor:(CGFloat)factor
{
    NSPoint p = [self centredPointInDocView];
    [self zoomViewByFactor:factor
            andCentrePoint:p];
}

/** @brief Zoom to a given absolute value
 * @note
 * A scale of 1.0 sets 100% zoom. Scale is pinned bwtween min and max limits. Same as -setScale:
 * @param newScale - the desired scaling factor
 * @public
 */
- (void)zoomViewToAbsoluteScale:(CGFloat)newScale
{
    [self setScale:newScale];
}

/** @brief Zooms so that the passed rect will fit in the view
 * @note
 * In general this should be used for a zoom OUT, such as a "fit to window" command, though it will
 * zoom in if the view is smaller than the current frame.
 * @param aRect - a rect
 * @public
 */
- (void)zoomViewToFitRect:(NSRect)aRect
{
    NSRect fr = [self frame];

    CGFloat sx, sy;

    sx = aRect.size.width / fr.size.width;
    sy = aRect.size.height / fr.size.height;

    [self zoomViewByFactor:MIN(sx, sy)];
}

/** @brief Zooms so that the passed rect fills the view
 * @note
 * The centre of the rect is centred in the view. In general this should be used for a zoom IN to a
 * specific smaller rectange. <aRect> is in current view coordinates. This is good for a dragged rect
 * zoom tool.
 * @param aRect - a rect
 * @public
 */
- (void)zoomViewToRect:(NSRect)aRect
{
    NSRect fr = [(NSClipView*)[self superview] documentVisibleRect];
    NSPoint cp;

    CGFloat sx, sy;

    sx = fr.size.width / aRect.size.width;
    sy = fr.size.height / aRect.size.height;

    cp.x = aRect.origin.x + aRect.size.width / 2.0;
    cp.y = aRect.origin.y + aRect.size.height / 2.0;

    [self zoomViewByFactor:MIN(sx, sy)
            andCentrePoint:cp];
}

/** @brief Zooms the view by the given factor and centres the passed point.
 * @param factor - relative zoom factor
 * @param p a point within the view that should be scrolled to the centre of the zoomed view.
 */
- (void)zoomViewByFactor:(CGFloat)factor andCentrePoint:(NSPoint)p
{
    if (factor != 1.0) {
        [self setScale:[self scale] * factor];
        [self scrollPointToCentre:p];
    }
}

/** @brief Converts the scrollwheel delta value into a zoom factor and performs the zoom.
 * @param delta - scrollwheel delta value
 * @param cp a point within the view that should be scrolled to the centre of the zoomed view.
 */
- (void)zoomWithScrollWheelDelta:(CGFloat)delta toCentrePoint:(NSPoint)cp
{
    CGFloat factor = (delta > 0) ? 0.9 : 1.1;

    [self zoomViewByFactor:factor
            andCentrePoint:cp];
}

#pragma mark -

/** @brief Calculates the coordinates of the point that is visually centred in the view at the current scroll
 * position and zoom.
 * @return the visually centred point
 */
- (NSPoint)centredPointInDocView
{
    NSRect fr;

    if ([[self superview] respondsToSelector:@selector(documentVisibleRect)])
        fr = [(NSClipView*)[self superview] documentVisibleRect];
    else
        fr = [self visibleRect];

    return NSMakePoint(NSMidX(fr), NSMidY(fr));
}

/** @brief Scrolls the view so that the point ends up visually centred
 * @param aPoint the desired centre point
 */
- (void)scrollPointToCentre:(NSPoint)aPoint
{
    // given a point in view coordinates, the view is scrolled so that the point is centred in the
    // current document view

    NSRect fr;

    if ([[self superview] respondsToSelector:@selector(documentVisibleRect)])
        fr = [(NSClipView*)[self superview] documentVisibleRect];
    else
        fr = [self visibleRect];

    NSPoint sp;

    sp.x = aPoint.x - (fr.size.width / 2.0);
    sp.y = aPoint.y - (fr.size.height / 2.0);

    [self scrollPoint:sp];
}

#pragma mark -

/** @brief Zooms the view to the given scale
 * @note
 * All zooms bottleneck through here. Scale passed is pinned within the min and max limits.
 * @param sc - the desired scale
 * @public
 */
- (void)setScale:(CGFloat)sc
{
    if (sc < [self minimumScale])
        sc = [self minimumScale];

    if (sc > [self maximumScale])
        sc = [self maximumScale];

    if (sc != [self scale]) {
        [self startScaleChange]; // stop is called by retriggerable timer

        NSSize newSize;
        NSRect fr;
        CGFloat factor = sc / [self scale];

        [[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewWillChangeScale
                                                            object:self];
        m_scale = sc;
        fr = [self frame];

        newSize.width = newSize.height = factor;

        [self scaleUnitSquareToSize:newSize];

        fr.size.width *= factor;
        fr.size.height *= factor;
        [self setFrameSize:fr.size];
        [self setNeedsDisplay:YES];

        LogEvent_(kReactiveEvent, @"new view scale = %f", m_scale);

        [[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewDidChangeScale
                                                            object:self];
    }
}

/** @brief Returns the current view scale (zoom)
 * @return the current scale
 * @public
 */
- (CGFloat)scale
{
    return m_scale;
}

/** @brief Returns whether the scale is being changed
 * @note
 * This property can be used to detect whether the user is rapidly changing the scale, for example using
 * the scrollwheel. When a scrollwheel change starts, this is set to YES and a timer is run which is
 * retriggered by further events. If it times out, this resets to NO. It can be used as one part of a
 * drawing strategy where rapid changes temporarily use a lower quality drawing mechanism for performance,
 * but reverts to a higher quality when things settle.
 * @return YES if the scale is changing, NO if not
 * @public
 */
- (BOOL)isChangingScale
{
    return mIsChangingScale;
}

/** @brief Sets the minimum permitted view scale (zoom)
 * @param scmin the minimum scale
 * @public
 */
- (void)setMinimumScale:(CGFloat)scmin
{
    mMinScale = scmin;
}

/** @brief Returns the minimum permitted view scale (zoom)
 * @return the minimum scale
 * @public
 */
- (CGFloat)minimumScale
{
    return mMinScale;
}

/** @brief Sets the maximum permitted view scale (zoom)
 * @param scmax the maximum scale
 * @public
 */
- (void)setMaximumScale:(CGFloat)scmax
{
    mMaxScale = scmax;
}

/** @brief Returns the maximum permitted view scale (zoom)
 * @return the maximum scale
 * @public
 */
- (CGFloat)maximumScale
{
    return mMaxScale;
}

#pragma mark -

- (void)stopScaleChange
{
    mIsChangingScale = NO;
    [self setNeedsDisplay:YES]; // redraw in high quality?

    LogEvent_(kReactiveEvent, @"view stopped changing scale (%f): %@", [self scale], self);
}

- (void)startScaleChange
{
    mIsChangingScale = YES;
    [mRT retrigger];
}

#pragma mark -
#pragma mark As an NSResponder

/** @brief Allows the scrollwheel to change the zoom.
 * @note
 * Overrides NSResponder. The scrollwheel works normally unless certain mofier keys are down, in which case
 * it performs a zoom. The modifer key mask can be set programatically.
 * @param theEvent - scrollwheel event
 */
- (void)scrollWheel:(NSEvent*)theEvent
{
    NSScrollView* scroller = [self enclosingScrollView];

    if ([[self class] scrollwheelZoomEnabled] && scroller != nil && ([theEvent modifierFlags] & [[self class] scrollwheelModifierKeyMask]) == [[self class] scrollwheelModifierKeyMask]) {
        // note to self - using the current mouse position here makes zooming really difficult, contrary
        // to what you might think. It's more intuitive if the centre point remains constant

        NSPoint p = [self centredPointInDocView];
        CGFloat delta = [theEvent deltaY];

        if ([[self class] scrollwheelInverted])
            delta = -delta;

        [self zoomWithScrollWheelDelta:delta
                         toCentrePoint:p];
    } else
        [super scrollWheel:theEvent];
}

#pragma mark -
#pragma mark As an NSView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
        m_scale = 1.0;
        mMinScale = 0.025;
        mMaxScale = 250.0;

        mRT = [[DKRetriggerableTimer retriggerableTimerWithPeriod:kDKZoomingRetriggerPeriod
                                                           target:self
                                                         selector:@selector(stopScaleChange)] retain];
    }
    return self;
}

- (void)dealloc
{
    [mRT release];
    [super dealloc];
}

#pragma mark -
#pragma mark As part of NSMenuValidation protocol

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    SEL action = [item action];

    if (action == @selector(zoomIn:) || action == @selector(zoomMax:))
        return [self scale] < [self maximumScale];

    if (action == @selector(zoomOut:) || action == @selector(zoomMin:))
        return [self scale] > [self minimumScale];

    if (action == @selector(zoomToActualSize:))
        return [self scale] != 1.0;

    if (action == @selector(zoomFitInWindow:) || action == @selector(zoomToPercentageWithTag:))
        return YES;

    return NO;
}

@end
