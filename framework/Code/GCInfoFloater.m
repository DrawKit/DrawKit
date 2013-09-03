//
//  GCInfoFloater.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 02/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "GCInfoFloater.h"
#import "GCOneShotEffectTimer.h"
#import "NSColor+DKAdditions.h"

@implementation GCInfoFloater
#pragma mark As a GCInfoFloater
+ (GCInfoFloater*)	infoFloater
{
	GCInfoFloater* fi = [[[GCInfoFloater alloc]  initWithContentRect:NSZeroRect
												styleMask:NSBorderlessWindowMask
												backing:NSBackingStoreBuffered
												defer:YES] autorelease];
	
	// note - because windows are all sent a -close message at quit time, set it
	// not to be released at that time, otherwise the release from the autorelease pool
	// will cause a crash due to the stale reference

	[fi setReleasedWhenClosed:NO];	// **** important!! ****
	
	return fi;
}


#pragma mark -
- (id)	initWithContentRect:(NSRect) contentRect
		styleMask:(NSUInteger) styleMask
		backing:(NSBackingStoreType) bufferingType
		defer:(BOOL) deferCreation
{
	self = [super initWithContentRect:contentRect
			styleMask:styleMask
			backing:bufferingType
			defer:deferCreation];
	if (self != nil)
	{
		// add a control view that displays the actual info value
		
		NSTextField* di = [[[NSTextField alloc] initWithFrame:contentRect] autorelease];
		
		if (di != nil)
		{
			//[di setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
			[di setBezeled:NO];
			[di setDrawsBackground:NO];
			[di setEditable:NO];
			[di setSelectable:NO];
			[di setFont:[NSFont fontWithName:@"Helvetica" size:10]];
			
			m_infoViewRef = di;
			[[self contentView] addSubview:di];
		}
		
		// add a formatter that will give us the value display we need. The default formatter is useful for
		// typical numeric float values but the particular user of the class may prefer to set a different formatter
		// which can be simply done using setFormat:
		
		[self setFormat:@",0.000"];
		
		if (m_infoViewRef == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		[self setBackgroundColor:[NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.6 alpha:1.0]];
		[self setLevel:NSFloatingWindowLevel];
		[self setHasShadow:YES];
		[self setOpaque:YES];
		[self setReleasedWhenClosed:YES];
		[self setWindowOffset:NSMakeSize( 1.0, 4.0 )];
		[self setDoubleValue:0.0];
	}
	
	return self;
}


#pragma mark -
- (void)			setFloatValue:(float) val
{
	[self setDoubleValue:(double) val];
}


- (void)			setDoubleValue:(double) val
{
	NSColor* textColor = [[self backgroundColor] contrastingColor];
	[(NSTextField*)m_infoViewRef setTextColor:textColor];
	
	[m_infoViewRef setDoubleValue:val];
	[m_infoViewRef sizeToFit];
	
	NSRect fr = [m_infoViewRef frame];
	fr.origin = [self frame].origin;
	
	[self setFrame:fr display:YES];
}


- (void)			setStringValue:(NSString*) str
{
	NSColor* textColor = [[self backgroundColor] contrastingColor];
	[(NSTextField*)m_infoViewRef setTextColor:textColor];

	[m_infoViewRef setStringValue:str];
	[m_infoViewRef sizeToFit];
	
	NSRect fr = [m_infoViewRef frame];
	fr.origin = [self frame].origin;
	
	[self setFrame:fr display:YES];
}


#pragma mark -
- (void)			setFormat:(NSString*) fmt
{
	// sets the format of the formatter to <fmt>. If <fmt> is nil, removes the formatter.
	
	if( fmt == nil )
		[m_infoViewRef setFormatter:nil];
	else
	{
		if([m_infoViewRef formatter] == nil)
		{
			NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];		
			[m_infoViewRef setFormatter:formatter];
			[formatter release];
		}
			
		[[m_infoViewRef formatter] setFormat:fmt];
	}
}


- (void)			setWindowOffset:(NSSize) offset;
{
	m_wOffset = offset;
}


- (void)			positionNearPoint:(NSPoint) p inView:(NSView*) v
{
	// places the window just to the right and above the point p as expressed in the coordinate system of view v.
	
	p = [v convertPoint:p toView:nil];
	
	NSPoint gp = [[v window] convertBaseToScreen:p];
		
	gp.x += m_wOffset.width;
	gp.y += m_wOffset.height;
	[self positionAtScreenPoint:gp];
}



- (void)			positionAtScreenPoint:(NSPoint) sp
{
	[self setFrameOrigin:sp];
}

#pragma mark -
- (void)			show
{
	[self setAlphaValue:0.95];
	[self orderFront:self];
}


- (void)			hide
{
	if([self isVisible])
		[GCOneShotEffectTimer oneShotWithStandardFadeTimeForDelegate:self];
}


#pragma mark -
#pragma mark - As a NSWindow

- (void)			setBackgroundColor:(NSColor*) colour
{
	// needs to be an RGB colour as floater uses -contrastingColor method that assumes this
	
	colour = [colour colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	[super setBackgroundColor:colour];
}


#pragma mark -
#pragma mark - As a GCOneShotEffect delegate
- (void)			oneShotHasReached:(CGFloat) relpos
{
	[self setAlphaValue:1.0 - relpos];
}


- (void)			oneShotComplete
{
	[self orderOut:self];
}



@end
