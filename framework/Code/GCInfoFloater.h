//
//  GCInfoFloater.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 02/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>


@interface GCInfoFloater : NSWindow
{
@private
	NSControl*		m_infoViewRef;
	NSSize			m_wOffset;
}


+ (GCInfoFloater*)	infoFloater;

- (void)			setFloatValue:(float) val;
- (void)			setDoubleValue:(double) val;
- (void)			setStringValue:(NSString*) str;

- (void)			setFormat:(NSString*) fmt;
- (void)			setWindowOffset:(NSSize) offset;
- (void)			positionNearPoint:(NSPoint) p inView:(NSView*) v;
- (void)			positionAtScreenPoint:(NSPoint) sp;

- (void)			show;
- (void)			hide;

@end


/*

This class provides a very simple tooltip-like window in which you can display a short piece of information, such
as a single numeric value.

By positioning this next to the mouse and supplying it with info, you can enhance the usability of some kinds of
user interaction.

*/

