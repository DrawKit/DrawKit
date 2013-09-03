///**********************************************************************************************************************************
///  GCZoomView.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 1/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>


@class DKRetriggerableTimer;



@interface GCZoomView : NSView
{
@private
	CGFloat					m_scale;					// the zoom scale of the view (1.0 = 100%)
	CGFloat					mMinScale;
	CGFloat					mMaxScale;
	NSUInteger				mScrollwheelModifierMask;
	BOOL					mIsChangingScale;
	DKRetriggerableTimer*	mRT;
}

+ (void)				setScrollwheelZoomEnabled:(BOOL) enable;
+ (BOOL)				scrollwheelZoomEnabled;
+ (void)				setScrollwheelModiferKeyMask:(NSUInteger) aMask;
+ (NSUInteger)			scrollwheelModifierKeyMask;
+ (void)				setScrollwheelInverted:(BOOL) inverted;
+ (BOOL)				scrollwheelInverted;

- (IBAction)			zoomIn: (id) sender;
- (IBAction)			zoomOut: (id) sender;
- (IBAction)			zoomToActualSize: (id) sender;
- (IBAction)			zoomFitInWindow: (id) sender;
- (IBAction)			zoomToPercentageWithTag:(id) sender;
- (IBAction)			zoomMax:(id) sender;
- (IBAction)			zoomMin:(id) sender;

- (void)				zoomViewByFactor: (CGFloat) factor;
- (void)				zoomViewToAbsoluteScale: (CGFloat) scale;
- (void)				zoomViewToFitRect: (NSRect) aRect;
- (void)				zoomViewToRect: (NSRect) aRect;
- (void)				zoomViewByFactor: (CGFloat) factor andCentrePoint:(NSPoint) p;
- (void)				zoomWithScrollWheelDelta: (CGFloat) delta toCentrePoint:(NSPoint) cp;

- (NSPoint)				centredPointInDocView;
- (void)				scrollPointToCentre:(NSPoint) aPoint;

- (void)				setScale:(CGFloat) sc;
- (CGFloat)				scale;

- (BOOL)				isChangingScale;

- (void)				setMinimumScale:(CGFloat) scmin;
- (CGFloat)				minimumScale;
- (void)				setMaximumScale:(CGFloat) scmax;
- (CGFloat)				maximumScale;

@end

#define kDKZoomingRetriggerPeriod		0.5




extern NSString*	kDKDrawingViewWillChangeScale;
extern NSString*	kDKDrawingViewDidChangeScale;

extern NSString*	kDKScrollwheelModifierKeyMaskPreferenceKey;
extern NSString*	kDKDrawingDisableScrollwheelZoomPrefsKey;
extern NSString*	kDKDrawingScrollwheelSensePrefsKey;


/*
This is a very general-purpose view class that provides some handy high-level methods for doing zooming. Simply hook up
the action methods to suitable menu commands and away you go. The stuff you draw within drawRect: doesn't need to know or
care abut the zoom of the view - you can just draw as usual and it works.

NOTE: this class doesn't bother to support NSCoding and thereby encoding the view zoom, because it usually isn't important for this
value to persist. However, if your subclass wants to support coding, your initWithCoder method should reset _scale to 1.0. Otherwise
it will get initialized to 0.0 and NOTHING WILL BE DRAWN.

*/
