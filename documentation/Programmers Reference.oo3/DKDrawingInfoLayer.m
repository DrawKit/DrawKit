///**********************************************************************************************************************************
///  DKDrawingInfoLayer.m
///  DrawKit
///
///  Created by graham on 27/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKDrawingInfoLayer.h"

#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKGridLayer.h"


#pragma mark Contants (Non-localized)
NSString*	kGCDrawingInfoTextLabelAttributes = @"kGCDrawingInfoTextLabelAttributes";


#pragma mark -
@implementation DKDrawingInfoLayer
#pragma mark As a DKDrawingInfoLayer

- (void)		setSize:(NSSize) size
{
	// sets the size of the drawing info box
	
	if( ! NSEqualSizes( m_size, size ))
	{
		m_size = size;
		[self setNeedsDisplay:YES];
	}
}


- (NSSize)		size
{
	return m_size;
}


#pragma mark -
- (void)		setPlacement:(DKInfoBoxPlacement) placement
{
	if( placement != m_placement )
	{
		m_placement = placement;
		[self setNeedsDisplay:YES];
	}
}


- (DKInfoBoxPlacement)	placement
{
	return m_placement;
}


#pragma mark -
- (void)		setBackgroundColour:(NSColor*) colour
{
	[self setSelectionColour:colour];
}


- (NSColor*)	backgroundColour
{
	return [self selectionColour];
}


#pragma mark -
- (void)		setDrawsBorder:(BOOL) border
{
	if( border != m_drawBorder )
	{
		m_drawBorder = border;
		[self setNeedsDisplay:YES];
	}
}


- (BOOL)		drawsBorder
{
	return m_drawBorder;
}


#pragma mark -
- (NSRect)		infoBoxRect
{
	// returns the bounds of the info box relative to the layer. This will take into account the size, placement and margins of the drawing.
	
	NSRect r, ir;
	
	r.size = [self size];
	ir = [[self drawing] interior];
	
	switch ([self placement])
	{
		case kGCDrawingInfoPlaceBottomRight:
			r.origin.x = NSMaxX( ir ) - [self size].width;
			r.origin.y = NSMaxY( ir ) - [self size].height;
			break;
			
		default:
		case kGCDrawingInfoPlaceBottomLeft:
			r.origin.x = NSMinX( ir );
			r.origin.y = NSMaxY( ir ) - [self size].height;
			break;
		
		case kGCDrawingInfoPlaceTopLeft:
			r.origin.x = NSMinX( ir );
			r.origin.y = NSMinY( ir );
			break;
		
		case kGCDrawingInfoPlaceTopRight:
			r.origin.x = NSMaxX( ir ) - [self size].width;
			r.origin.y = NSMinY( ir );
			break;
	}
	
	return r;
}


- (void)		drawInfoInRect:(NSRect) br
{
	// draws the info, labels, subdivisions, etc. <br> is the bounds of the info box. The border and background are drawn by the time
	// this is called.
	
	NSDictionary*			di = [[self drawing] drawingInfo];
	NSString*				infos;
	NSAttributedString*		label;
	NSRect					r, lr;
	NSDate*					dt;
	NSBezierPath*			bp;
	NSArray*				mods;
	
	bp = [NSBezierPath bezierPath];
	[bp setLineWidth:0.5];
	
	r = [self layoutRectForDrawingInfoItem:kDKDrawingInfoDrawingNumber inRect:br];
	label = [self labelForDrawingInfoItem:kDKDrawingInfoDrawingNumber];
	lr = [self labelRectInRect:r forLabel:label];
	[bp appendBezierPathWithRect:r];
	[bp appendBezierPathWithRect:lr];
	r.origin.x += lr.size.width;
	infos = [di objectForKey:kDKDrawingInfoDrawingNumber];
	//if ( _editingKey != kGCDrawingInfoDrawingNumber )
		[self drawString:infos inRect:r withAttributes:[self attributesForDrawingInfoItem:kDKDrawingInfoDrawingNumber]];
	[label drawInRect:NSOffsetRect( lr, 1.5, 0 )];
	
	r = [self layoutRectForDrawingInfoItem:kDKDrawingInfoDrawingRevision inRect:br];
	label = [self labelForDrawingInfoItem:kDKDrawingInfoDrawingRevision];
	lr = [self labelRectInRect:r forLabel:label];
	[bp appendBezierPathWithRect:r];
	[bp appendBezierPathWithRect:lr];
	r.origin.x += lr.size.width;
	infos = [di objectForKey:kDKDrawingInfoDrawingRevision];
	//if ( _editingKey != kGCDrawingInfoDrawingRevision )
		[self drawString:infos inRect:r withAttributes:[self attributesForDrawingInfoItem:kDKDrawingInfoDrawingRevision]];
	[label drawInRect:NSOffsetRect( lr, 1.5, 0 )];
	
	r = [self layoutRectForDrawingInfoItem:kDKDrawingInfoDraughter  inRect:br];
	label = [self labelForDrawingInfoItem:kDKDrawingInfoDraughter];
	lr = [self labelRectInRect:r forLabel:label];
	[bp appendBezierPathWithRect:r];
	[bp appendBezierPathWithRect:lr];
	r.origin.x += lr.size.width;
	infos = [di objectForKey:kDKDrawingInfoDraughter];
	//if ( _editingKey != kGCDrawingInfoDraughter )
		[self drawString:infos inRect:r withAttributes:[self attributesForDrawingInfoItem:kDKDrawingInfoDraughter]];
	[label drawInRect:NSOffsetRect( lr, 1.5, 0 )];
	
	r = [self layoutRectForDrawingInfoItem:kDKDrawingInfoCreationDate inRect:br];
	label = [self labelForDrawingInfoItem:kDKDrawingInfoCreationDate];
	lr = [self labelRectInRect:r forLabel:label];
	[bp appendBezierPathWithRect:r];
	[bp appendBezierPathWithRect:lr];
	r.origin.x += lr.size.width;
	dt = [di objectForKey:kDKDrawingInfoCreationDate];
	infos = [dt descriptionWithCalendarFormat:@"%B %e, %Y" timeZone:nil locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	//if ( _editingKey != kGCDrawingInfoCreationDate )
		[self drawString:infos inRect:r withAttributes:[self attributesForDrawingInfoItem:kDKDrawingInfoCreationDate]];
	[label drawInRect:NSOffsetRect( lr, 1.5, 0 )];

	r = [self layoutRectForDrawingInfoItem:kDKDrawingInfoModificationHistory inRect:br];
	label = [self labelForDrawingInfoItem:kDKDrawingInfoModificationHistory];
	lr = [self labelRectInRect:r forLabel:label];
	[bp appendBezierPathWithRect:r];
	[bp appendBezierPathWithRect:lr];
	r.origin.x += lr.size.width;
	mods = [di objectForKey:kDKDrawingInfoModificationHistory];
	//[self drawString:infos inRect:r withAttributes:[self attributesForDrawingInfoItem:kGCDrawingInfoModificationHistory]];
	[label drawInRect:NSOffsetRect( lr, 1.5, 0 )];

	[[DKGridLayer defaultMajorColour] set];
	[bp stroke];
}


- (NSDictionary*)	attributesForDrawingInfoItem:(NSString*) key
{
	// given the key of an item in the drawign info, this returns som etext drawign attributes suitable for drawing that item. You
	// can overrid ethis to supply attributes for other deined items or to change the defaults.
	
	NSMutableDictionary* ad = nil;
	
	if ([key isEqualToString:kDKDrawingInfoDrawingNumber])
	{
		ad = [[[NSMutableDictionary alloc] init] autorelease];
		[ad setObject:[NSFont fontWithName:@"Helvetica" size:24 ] forKey:NSFontAttributeName];
	}
	else if ([key isEqualToString:kDKDrawingInfoDrawingRevision])
	{
		ad = [[[NSMutableDictionary alloc] init] autorelease];
		[ad setObject:[NSFont fontWithName:@"Helvetica" size:24 ] forKey:NSFontAttributeName];
	}
	else if ([key isEqualToString:kGCDrawingInfoTextLabelAttributes])
	{
		ad = [[[NSMutableDictionary alloc] init] autorelease];
		[ad setObject:[NSFont fontWithName:@"Helvetica" size:7 ] forKey:NSFontAttributeName];
	}
	
	return ad;
}


- (void)		drawString:(NSString*) str inRect:(NSRect) r withAttributes:(NSDictionary*) attr
{
	// draws the given string into the rect <r>, applying the attributes <attr> and the alignment <align>.
	
	NSAttributedString* as = [[NSAttributedString alloc] initWithString:str attributes:attr];
	
	[as drawInRect:NSOffsetRect( r, 4, 2 )];
	[as release];
}


- (NSAttributedString*)	labelForDrawingInfoItem:(NSString*) key;
{
	// returns the infobox label for the given drawing info item. The string is localisable.
	
	NSAttributedString* s = nil;
	NSDictionary*		attr;
	
	attr = [self attributesForDrawingInfoItem:kGCDrawingInfoTextLabelAttributes];
	
	if ([key isEqualToString:kDKDrawingInfoDrawingNumber])
		s = [[NSAttributedString alloc] initWithString:NSLocalizedString( @"dwg #:", @"drawing info number label" ) attributes:attr];
	else if ([key isEqualToString:kDKDrawingInfoDrawingRevision])
		s = [[NSAttributedString alloc] initWithString:NSLocalizedString( @"rev:", @"drawing info revision label") attributes:attr];
	else if ([key isEqualToString:kDKDrawingInfoDraughter])
		s = [[NSAttributedString alloc] initWithString:NSLocalizedString( @"by:", @"drawing info draughter label") attributes:attr];
	else if ([key isEqualToString:kDKDrawingInfoCreationDate])
		s = [[NSAttributedString alloc] initWithString:NSLocalizedString( @"date:", @"drawing info creation date label") attributes:attr];
	else if ([key isEqualToString:kDKDrawingInfoModificationHistory])
		s = [[NSAttributedString alloc] initWithString:NSLocalizedString( @"mods:", @"drawing info modification history label") attributes:attr];
		
	return [s autorelease];
}


- (NSRect)			layoutRectForDrawingInfoItem:(NSString*) key inRect:(NSRect) bounds
{
	// returns the rect within <bounds> that the given item is to be laid out in. This rect will also be framed so add margins etc
	// for positioning text as required.
	
	NSRect r;
	
	r = NSInsetRect( bounds, 3, 3 );
	
	if ([key isEqualToString:kDKDrawingInfoDrawingNumber])
	{
		r.size.height /= 3.0;
		r.size.width -= ( r.size.width / 7.0 );
	}
	else if ([key isEqualToString:kDKDrawingInfoDrawingRevision])
	{
		r.size.height /= 3.0;
		r.size.width /= 7.0;
		r.origin.x = NSMaxX( bounds ) - r.size.width - 3.0;
	}
	else if ([key isEqualToString:kDKDrawingInfoDraughter])
	{
		r.size.height /= 5.0;
		r.size.width /= 2.0;
		r.origin.y += bounds.size.height / 3.0 - 2.0; 
	}
	else if ([key isEqualToString:kDKDrawingInfoCreationDate])
	{
		r.size.height /= 5.0;
		r.size.width /= 2.0;
		r.origin.y += bounds.size.height / 3.0 - 2.0; 
		r.origin.x += bounds.size.width / 2.0 - 3.0;
	}
	else if ([key isEqualToString:kDKDrawingInfoModificationHistory])
	{
		r.origin.y += ( bounds.size.height / 3.0 ) - 2.0 + ( r.size.height / 5.0 ); 
		r.size.height = NSMaxY( bounds) - 3.0 - r.origin.y;
	}
	else
		r = NSZeroRect;
		
	return r;
}


- (NSRect)			labelRectInRect:(NSRect) itemRect forLabel:(NSAttributedString*) ls
{
	NSRect r = itemRect;
	
	r.size = [ls size];
	r.size.width += 4.0;
	
	return r;
}


#pragma mark -
- (NSString*)			keyForEditableRegionUnderMouse:(NSPoint) p
{
	// tests whether any of the editable regions is hit by <p>. If so, the info key for that region is returned, otherwise nil.
	
	NSDictionary*	di = [[self drawing] drawingInfo];
	NSArray*		keys = [di allKeys];
	NSEnumerator*	iter = [keys reverseObjectEnumerator];
	NSString*		key;
	NSRect			r, br = [self infoBoxRect];
	
	while(( key = [iter nextObject]))
	{
		r = [self layoutRectForDrawingInfoItem:key inRect:br];

		if ( NSPointInRect( p, r ))
			return key;
	}

	return nil;
}


- (void)				textViewDidChangeSelection:(NSNotification*) aNotification
{
	// the editable text changed. Get the text from the editor and set the dictionary's entry for the current key
	
	NSTextView*		tv = [aNotification object];
	NSTextStorage*	text = [[tv layoutManager] textStorage]; 
	NSString*		str = [text string];
	
	//LogEvent_(kReactiveEvent, @"typed text = %@", str);
	
	NSMutableDictionary*	di = [[self drawing] drawingInfo];
	
	[di setObject:str forKey:m_editingKeyRef];
	NSRect r = [self layoutRectForDrawingInfoItem:m_editingKeyRef inRect:[self infoBoxRect]];
	[self setNeedsDisplayInRect:r];
}


#pragma mark -
#pragma mark As a DKLayer
- (NSRect)			activeCursorRect
{
	// return the rect that the layer's cursor will be set when the mouse is within.
	
	return [self infoBoxRect];
}


- (NSCursor*)		cursor
{
	return [NSCursor IBeamCursor];
}


- (void)		drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	#pragma unused(rect)
	
	NSRect diRect = [self infoBoxRect];
	
	if ( aView == nil || [aView needsToDrawRect:diRect])
	{
		// draw the info box
		
		[[self backgroundColour] set];
		NSRectFillUsingOperation( diRect, NSCompositeSourceAtop );
		
		// draw the box border using the major grid colour:
		
		[[DKGridLayer defaultMajorColour] set];
		NSFrameRectWithWidth( diRect, 0.6 );
		
		// divide up the box and label each one:
		
		[self drawInfoInRect:diRect];
	}
	
	if ([self drawsBorder])
	{
		[[DKGridLayer defaultMajorColour] set];
		NSFrameRectWithWidth([[self drawing] interior], 0.6 );
	}
}


- (BOOL)			hitLayer:(NSPoint) p
{
	return NSPointInRect( p, [self infoBoxRect]);
}


- (void)			layerDidResignActiveLayer
{
	if ( m_editingKeyRef != nil )
	{
		[[self drawing] exitTemporaryTextEditingMode];
		m_editingKeyRef = nil;
	}
}


- (void)			mouseDown:(NSEvent*) event inView:(NSView*) view
{
	// if we are not locked, we can edit the drawing info. This is handled by the view's text editing utility methods which
	// can be used by any object as required.
	
	if( ![self locked])
	{
		NSPoint		p = [view convertPoint:[event locationInWindow] fromView:nil];
		NSString*	key = [self keyForEditableRegionUnderMouse:p];
		
		if ( key != nil )
		{
			NSDictionary*	di = [[self drawing] drawingInfo];
			NSRect			fr = [self layoutRectForDrawingInfoItem:key inRect:[self infoBoxRect]];
			NSRect			lr = [self labelRectInRect:fr forLabel:[self labelForDrawingInfoItem:key]];
			NSTextStorage*	str;
			
			fr.origin.x += lr.size.width;
			
			str = [[NSTextStorage alloc] initWithString:[di objectForKey:key] attributes:[self attributesForDrawingInfoItem:key]];
			
			[(DKDrawingView*)view editText:str inRect: NSOffsetRect( fr, -1.5, 2.5 ) delegate:self];
			m_editingKeyRef = key;
		}
		else
		{
			[[self drawing] exitTemporaryTextEditingMode];
			m_editingKeyRef = nil;
		}
	}
}


- (NSColor*)	selectionColour
{
	// override to ignore inactive state
	
	return m_selectionColour;
}


#pragma mark -
#pragma mark As an NSObject
- (id)			init
{
	self = [super init];
	if (self != nil)
	{
		NSSize sz = NSMakeSize( kGCGridDrawingLayerMetricInterval * 10.0, kGCGridDrawingLayerMetricInterval * 4.0	);
		
		[self setPlacement:kGCDrawingInfoPlaceBottomLeft];
		[self setSize:sz];
		NSAssert(m_editingKeyRef == nil, @"Expected init to zero");
		[self setBackgroundColour:[NSColor whiteColor]];
		m_drawBorder = YES;
	}
	if (self != nil)
	{
		[self setName:NSLocalizedString(@"Info", @"default name for info layer")];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeInt:[self placement] forKey:@"infoBoxPlacement"];
	[coder encodeSize:[self size] forKey:@"infoBoxSize"];
	[coder encodeBool:[self drawsBorder] forKey:@"drawBorder"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setPlacement:[coder decodeIntForKey:@"infoBoxPlacement"]];
		[self setSize:[coder decodeSizeForKey:@"infoBoxSize"]];
		NSAssert(m_editingKeyRef == nil, @"Expected init to zero");
		[self setDrawsBorder:[coder decodeBoolForKey:@"drawBorder"]];
	}
	if (self != nil)
	{
	}
	return self;
}


@end
