///**********************************************************************************************************************************
///  GCZoomView.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 1/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "GCZoomView.h"
#import "DKRetriggerableTimer.h"
#import "LogEvent.h"

@interface GCZoomView (Private)

- (void)	stopScaleChange;
- (void)	startScaleChange;

@end


#pragma mark Constants (Non-localized)

NSString*	kDKDrawingViewDidChangeScale					= @"kDKDrawingViewDidChangeScale";
NSString*	kDKDrawingViewWillChangeScale					= @"kDKDrawingViewWillChangeScale";

NSString*	kDKScrollwheelModifierKeyMaskPreferenceKey		= @"DK_SCROLLWHEEL_ZOOM_KEY_MASK";
NSString*	kDKDrawingDisableScrollwheelZoomPrefsKey		= @"kDKDrawingDisableScrollwheelZoom";
NSString*	kDKDrawingScrollwheelSensePrefsKey				= @"kDKDrawingcrollwheelSense";			// typo here, please leave


#pragma mark -
@implementation GCZoomView


///*********************************************************************************************************************
///
/// method:			setScrollwheelZoomEnabled:
/// scope:			public class method
/// description:	set whether scroll-wheel zooming is enabled
/// 
/// parameters:		<enable> YES to enable, NO to disable
/// result:			none
///
/// notes:			default is YES
///
///********************************************************************************************************************

+ (void)				setScrollwheelZoomEnabled:(BOOL) enable
{
	[[NSUserDefaults standardUserDefaults] setBool:!enable forKey:kDKDrawingDisableScrollwheelZoomPrefsKey];
}


///*********************************************************************************************************************
///
/// method:			scrollwheelZoomEnabled
/// scope:			public class method
/// description:	return whether scroll-wheel zooming is enabled
/// 
/// parameters:		none
/// result:			YES to enable, NO to disable
///
/// notes:			default is YES
///
///********************************************************************************************************************

+ (BOOL)				scrollwheelZoomEnabled
{
	return ![[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingDisableScrollwheelZoomPrefsKey];
}


///*********************************************************************************************************************
///
/// method:			setScrollwheelModiferKeyMask:
/// scope:			public class method
/// description:	set the modifier key(s) that will activate zooming using the scrollwheel
/// 
/// parameters:		<aMask> a modifier key mask value
/// result:			none
///
/// notes:			operating the given modifier keys along with the scroll wheel will zoom the view
///
///********************************************************************************************************************

+ (void)				setScrollwheelModiferKeyMask:(NSUInteger) aMask
{
	[[NSUserDefaults standardUserDefaults] setInteger:aMask forKey:kDKScrollwheelModifierKeyMaskPreferenceKey];
}


///*********************************************************************************************************************
///
/// method:			scrollwheelModifierKeyMask
/// scope:			public class method
/// description:	return the default zoom key mask used by new instances of this class
/// 
/// parameters:		none
/// result:			a modifier key mask value
///
/// notes:			reads the value from the prefs. If not set or set to zero, defaults to option key.
///
///********************************************************************************************************************

+ (NSUInteger)			scrollwheelModifierKeyMask
{
	NSUInteger mask = [[NSUserDefaults standardUserDefaults] integerForKey:kDKScrollwheelModifierKeyMaskPreferenceKey];
	
	if( mask == 0 )
		mask = NSAlternateKeyMask;
	
	return mask;
}


///*********************************************************************************************************************
///
/// method:			setScrollwheelInverted:
/// scope:			public method
/// description:	set whether view zooms in or out for a given scrollwheel rotation direction
/// 
/// parameters:		whether scroll wheel inverted
/// result:			none
///
/// notes:			default sense is to zoom in when scrollwheel is rotated towards the user. Some apps (e.g. Google Earth)
///					use the opposite convention, which feels less natural but may become a defacto "standard".
///
///********************************************************************************************************************

+ (void)				setScrollwheelInverted:(BOOL) inverted
{
	[[NSUserDefaults standardUserDefaults] setBool:inverted forKey:kDKDrawingScrollwheelSensePrefsKey];
}


///*********************************************************************************************************************
///
/// method:			scrollwheelInverted
/// scope:			public method
/// description:	return whether view zooms in or out for a given scrollwheel rotation direction
/// 
/// parameters:		none
/// result:			whether scroll wheel inverted
///
/// notes:			default sense is to zoom in when scrollwheel is rotated towards the user. Some apps (e.g. Google Earth)
///					use the opposite convention, which feels less natural but may become a defacto "standard".
///
///********************************************************************************************************************

+ (BOOL)				scrollwheelInverted
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingScrollwheelSensePrefsKey];
}




#pragma mark -


///*********************************************************************************************************************
///
/// method:			zoomIn:
/// scope:			public action method
/// description:	zoom in (scale up) by a factor of 2
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomIn: (id) sender
{
	#pragma unused(sender)
	
	[self zoomViewByFactor:2.0];
}


///*********************************************************************************************************************
///
/// method:			zoomOut:
/// scope:			public action method
/// description:	zoom out (scale down) by a factor of 2
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomOut: (id) sender
{
	#pragma unused(sender)
	
	[self zoomViewByFactor:0.5];
}


///*********************************************************************************************************************
///
/// method:			zoomToActualSize:
/// scope:			public action method
/// description:	restore the zoom to 100%
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomToActualSize: (id) sender
{
	#pragma unused(sender)
	
	[self zoomViewToAbsoluteScale:1.0];
}


///*********************************************************************************************************************
///
/// method:			zoomFitInWindow:
/// scope:			public action method
/// description:	zoom so that the entire extent of the enclosing frame is visible
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomFitInWindow: (id) sender
{
	#pragma unused(sender)
	
	// zooms the view to fit within the current window (command/action)
	NSRect  sfr = [[self superview] frame];
	[self zoomViewToFitRect:sfr];
}


///*********************************************************************************************************************
///
/// method:			zoomToPercentageWithTag:
/// scope:			public action method
/// description:	takes the senders tag value as the desired percentage
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomToPercentageWithTag:(id) sender
{
	NSInteger tag = [sender tag];
	CGFloat ns = (CGFloat) tag / 100.0f;
	
	[self zoomViewToAbsoluteScale:ns];
}


- (IBAction)			zoomMax:(id) sender
{
	#pragma unused(sender)
	[self zoomViewToAbsoluteScale:[self maximumScale]];
}


- (IBAction)			zoomMin:(id) sender
{
	#pragma unused(sender)
	[self zoomViewToAbsoluteScale:[self minimumScale]];
}



#pragma mark -
///*********************************************************************************************************************
///
/// method:			zoomViewByFactor:
/// scope:			public method
/// description:	zoom by the desired scaling factor
/// 
/// parameters:		<factor> - how much to change the current scale by
/// result:			none
///
/// notes:			a factor of 2.0 will double the zoom scale, from 100% to 200% say, a factor of 0.5 will zoom out.
///					This also maintains the current visible centre point of the view so the zoom remains stable.
///
///********************************************************************************************************************

- (void)				zoomViewByFactor: (CGFloat) factor
{
	NSPoint p = [self centredPointInDocView];
	[self zoomViewByFactor:factor andCentrePoint:p];
}


///*********************************************************************************************************************
///
/// method:			zoomViewToAbsoluteScale:
/// scope:			public method
/// description:	zoom to a given absolute value
/// 
/// parameters:		<newScale> - the desired scaling factor
/// result:			none
///
/// notes:			a scale of 1.0 sets 100% zoom. Scale is pinned bwtween min and max limits. Same as -setScale:
///
///********************************************************************************************************************

- (void)				zoomViewToAbsoluteScale: (CGFloat) newScale
{
	[self setScale:newScale];
}


///*********************************************************************************************************************
///
/// method:			zoomViewToFitRect:
/// scope:			public method
/// description:	zooms so that the passed rect will fit in the view
/// 
/// parameters:		<aRect> - a rect
/// result:			none
///
/// notes:			In general this should be used for a zoom OUT, such as a "fit to window" command, though it will
///					zoom in if the view is smaller than the current frame.
///
///********************************************************************************************************************

- (void)				zoomViewToFitRect: (NSRect) aRect
{
	NSRect  fr = [self frame];
	
	CGFloat sx, sy;
	
	sx = aRect.size.width / fr.size.width;
	sy = aRect.size.height / fr.size.height;
	
	[self zoomViewByFactor:MIN( sx, sy )];
}


///*********************************************************************************************************************
///
/// method:			zoomViewToRect:
/// scope:			public method
/// description:	zooms so that the passed rect fills the view
/// 
/// parameters:		<aRect> - a rect
/// result:			none
///
/// notes:			The centre of the rect is centred in the view. In general this should be used for a zoom IN to a
///					specific smaller rectange. <aRect> is in current view coordinates. This is good for a dragged rect
///					zoom tool.
///
///********************************************************************************************************************

- (void)				zoomViewToRect: (NSRect) aRect
{
	NSRect  fr = [(NSClipView*)[self superview] documentVisibleRect];
	NSPoint cp;
	
	CGFloat sx, sy;
	
	sx = fr.size.width / aRect.size.width;
	sy = fr.size.height / aRect.size.height;
	
	cp.x = aRect.origin.x + aRect.size.width / 2.0;
	cp.y = aRect.origin.y + aRect.size.height / 2.0;
	
	[self zoomViewByFactor:MIN( sx, sy ) andCentrePoint:cp];
}


///*********************************************************************************************************************
///
/// method:			zoomViewToRect:
/// scope:			protected method
/// description:	zooms the view by the given factor and centres the passed point.
/// 
/// parameters:		<factor> - relative zoom factor
///					<p> a point within the view that should be scrolled to the centre of the zoomed view.
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				zoomViewByFactor: (CGFloat) factor andCentrePoint:(NSPoint) p
{
	if ( factor != 1.0 )
	{
		[self setScale:[self scale] * factor];
		[self scrollPointToCentre:p];
	}
}


///*********************************************************************************************************************
///
/// method:			zoomWithScrollWheelDelta:
/// scope:			protected method
/// description:	converts the scrollwheel delta value into a zoom factor and performs the zoom.
/// 
/// parameters:		<delta> - scrollwheel delta value
///					<cp> a point within the view that should be scrolled to the centre of the zoomed view.
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				zoomWithScrollWheelDelta:(CGFloat) delta toCentrePoint:(NSPoint) cp
{
	CGFloat factor = ( delta > 0 )? 0.9 : 1.1;
	
	[self zoomViewByFactor:factor andCentrePoint:cp ];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			centredPointInDocView
/// scope:			protected method
/// description:	calculates the coordinates of the point that is visually centred in the view at the current scroll
///					position and zoom.
/// 
/// parameters:		none
/// result:			the visually centred point
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)				centredPointInDocView
{
	NSRect  fr;

	if([[self superview] respondsToSelector:@selector(documentVisibleRect)])
		fr = [(NSClipView*)[self superview] documentVisibleRect];
	else
		fr = [self visibleRect];
		
	return NSMakePoint(NSMidX( fr ), NSMidY( fr ));
}


///*********************************************************************************************************************
///
/// method:			scrollPointToCentre:
/// scope:			protected method
/// description:	scrolls the view so that the point ends up visually centred
/// 
/// parameters:		<aPoint> the desired centre point
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				scrollPointToCentre:(NSPoint) aPoint
{
	// given a point in view coordinates, the view is scrolled so that the point is centred in the
	// current document view
	
	NSRect  fr;
	
	if([[self superview] respondsToSelector:@selector(documentVisibleRect)])
		fr = [(NSClipView*)[self superview] documentVisibleRect];
	else
		fr = [self visibleRect];
	 
	NSPoint sp;
	
	sp.x = aPoint.x - ( fr.size.width / 2.0 );
	sp.y = aPoint.y - ( fr.size.height / 2.0 );
	
	[self scrollPoint:sp];
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			setScale:
/// scope:			public method
/// description:	zooms the view to the given scale
/// 
/// parameters:		<sc> - the desired scale
/// result:			none
///
/// notes:			all zooms bottleneck through here. Scale passed is pinned within the min and max limits.
///
///********************************************************************************************************************

- (void)				setScale:(CGFloat) sc
{
	if ( sc < [self minimumScale])
		sc = [self minimumScale];
	
	if ( sc > [self maximumScale])
		sc = [self maximumScale];
	
	if ( sc != [self scale])
	{
		[self startScaleChange];	// stop is called by retriggerable timer
		
		NSSize  newSize;
		NSRect  fr;
		CGFloat	factor = sc / [self scale];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewWillChangeScale object:self];
		m_scale = sc;
		fr = [self frame];
		
		newSize.width = newSize.height = factor;
		
		[self scaleUnitSquareToSize:newSize];
		
		fr.size.width *= factor;
		fr.size.height *= factor;
		[self setFrameSize:fr.size];
		[self setNeedsDisplay:YES];
		
		LogEvent_( kReactiveEvent, @"new view scale = %f", m_scale );
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewDidChangeScale object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			scale
/// scope:			public method
/// description:	returns the current view scale (zoom)
/// 
/// parameters:		none
/// result:			the current scale
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				scale
{
	return m_scale;
}


///*********************************************************************************************************************
///
/// method:			isChangingScale
/// scope:			public method
/// description:	returns whether the scale is being changed
/// 
/// parameters:		none
/// result:			YES if the scale is changing, NO if not
///
/// notes:			This property can be used to detect whether the user is rapidly changing the scale, for example using
///					the scrollwheel. When a scrollwheel change starts, this is set to YES and a timer is run which is
///					retriggered by further events. If it times out, this resets to NO. It can be used as one part of a
///					drawing strategy where rapid changes temporarily use a lower quality drawing mechanism for performance,
///					but reverts to a higher quality when things settle.
///
///********************************************************************************************************************

- (BOOL)				isChangingScale
{
	return mIsChangingScale;
}


///*********************************************************************************************************************
///
/// method:			setMinimumScale
/// scope:			public method
/// description:	sets the minimum permitted view scale (zoom)
/// 
/// parameters:		<scmin> the minimum scale
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setMinimumScale:(CGFloat) scmin
{
	mMinScale = scmin;
}


///*********************************************************************************************************************
///
/// method:			minimumScale
/// scope:			public method
/// description:	returns the minimum permitted view scale (zoom)
/// 
/// parameters:		none
/// result:			the minimum scale
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				minimumScale
{
	return mMinScale;
}


///*********************************************************************************************************************
///
/// method:			setMaximumScale
/// scope:			public method
/// description:	sets the maximum permitted view scale (zoom)
/// 
/// parameters:		<scmax> the maximum scale
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setMaximumScale:(CGFloat) scmax
{
	mMaxScale = scmax;
}


///*********************************************************************************************************************
///
/// method:			maximumScale
/// scope:			public method
/// description:	returns the maximum permitted view scale (zoom)
/// 
/// parameters:		none
/// result:			the maximum scale
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				maximumScale
{
	return mMaxScale;
}


#pragma mark -

- (void)				stopScaleChange
{
	mIsChangingScale = NO;
	[self setNeedsDisplay:YES];	// redraw in high quality?
	
	LogEvent_( kReactiveEvent, @"view stopped changing scale (%f): %@", [self scale], self );
}


- (void)				startScaleChange
{
	mIsChangingScale = YES;
	[mRT retrigger];
}



#pragma mark -
#pragma mark As an NSResponder
///*********************************************************************************************************************
///
/// method:			scrollWheel:
/// scope:			overidden method
/// description:	allows the scrollwheel to change the zoom.
/// 
/// parameters:		<theEvent> - scrollwheel event
/// result:			none
///
/// notes:			overrides NSResponder. The scrollwheel works normally unless certain mofier keys are down, in which case
///					it performs a zoom. The modifer key mask can be set programatically.
///
///********************************************************************************************************************

- (void)				scrollWheel:(NSEvent*) theEvent
{
	NSScrollView* scroller = [self enclosingScrollView];
	
	if ([[self class] scrollwheelZoomEnabled] && scroller != nil && ([theEvent modifierFlags] & [[self class] scrollwheelModifierKeyMask]) == [[self class] scrollwheelModifierKeyMask])
	{   
		// note to self - using the current mouse position here makes zooming really difficult, contrary
		// to what you might think. It's more intuitive if the centre point remains constant
		
		NSPoint p = [self centredPointInDocView];
		CGFloat delta = [theEvent deltaY];
		
		if([[self class] scrollwheelInverted])
			delta = -delta;
		
		[self zoomWithScrollWheelDelta:delta toCentrePoint:p];
	}
	else
		[super scrollWheel: theEvent];
}


#pragma mark -
#pragma mark As an NSView

- (id)					initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil)
    {
		m_scale = 1.0;
		mMinScale = 0.025;
		mMaxScale = 250.0;
		
		mRT = [[DKRetriggerableTimer retriggerableTimerWithPeriod:kDKZoomingRetriggerPeriod target:self selector:@selector(stopScaleChange)] retain];
	}
    return self;
}


- (void)				dealloc
{
	[mRT release];
	[super dealloc];
}


#pragma mark -
#pragma mark As part of NSMenuValidation protocol

- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	SEL		action = [item action];
	
	if( action == @selector( zoomIn: ) ||
		action == @selector( zoomMax: ))
		return [self scale] < [self maximumScale];
	
	if( action == @selector( zoomOut: ) ||
		action == @selector( zoomMin:))
		return [self scale] > [self minimumScale];
	
	if( action == @selector( zoomToActualSize: ))
		return [self scale] != 1.0;
	
	if ( action == @selector( zoomFitInWindow: ) ||
		 action == @selector( zoomToPercentageWithTag:))
		return YES;
		
	return NO;
}


@end
