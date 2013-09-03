//
//  DKGreekingLayoutManager.m
//  GCDrawKit
//
//  Created by graham on 13/05/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKGreekingLayoutManager.h"


@implementation DKGreekingLayoutManager


- (void)			setGreeking:(DKGreeking) greeking
{
	mGreeking = greeking;
}
 
 
- (DKGreeking)		greeking
{
	return mGreeking;
}


- (void)			setGreekingColour:(NSColor*) aColour
{
	[aColour retain];
	[mGreekingColour release];
	mGreekingColour = aColour;
}


- (NSColor*)		greekingColour
{
	return mGreekingColour;
}


#pragma mark - as a NSLayoutManager

- (void)			drawGlyphsForGlyphRange:(NSRange) glyphsToShow atPoint:(NSPoint) origin
{
	if([self greeking] == kDKGreekingNone )
		[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
	else
	{
		NSGlyph		glyph;
		NSFont*		font;
		NSRect		glyphBounds, lineRect;
		NSPoint		glyphLoc;
		NSUInteger	gli, characterIndex;
		
		[[self greekingColour] set];

		// draw blocks instead of glyphs, either the entire line fragment used rect or each glyph.
		// if the range to show is just a single glyph, handle it slightly differently so that the text on path
		// layout works as expected. In this mode, either greeking setting produces glyph-based greeking as we are
		// being called to lay out each glyph one by one.
		
		if( glyphsToShow.length == 1 )
		{
			glyph = [self glyphAtIndex:glyphsToShow.location];
			characterIndex = [self characterIndexForGlyphAtIndex:glyphsToShow.location];
			font = [[self textStorage] attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
			glyphLoc = [self locationForGlyphAtIndex:glyphsToShow.location];
			glyphBounds = [font boundingRectForGlyph:glyph];
			
			glyphBounds.origin.x = origin.x + glyphLoc.x;
			glyphBounds.origin.y = origin.y + glyphLoc.y - NSHeight( glyphBounds );
			
			NSRectFill( glyphBounds );
		}
		else
		{
			NSRange		glyphRange;
			NSRect		fragRect;
			NSUInteger	glyphIndex = glyphsToShow.location;
			
			while( glyphIndex < NSMaxRange( glyphsToShow ))
			{
				fragRect = [self lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:&glyphRange];
				
				if([self greeking] == kDKGreekingByLineRectangle)
					NSRectFill( NSOffsetRect( fragRect, origin.x, origin.y ));
				else
				{
					// greeking down to the glyph rects, so calculate them and draw them
					
					lineRect = [self lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
					
					for( gli = glyphRange.location; gli < NSMaxRange( glyphRange ); ++gli )
					{
						glyph = [self glyphAtIndex:gli];
						glyphLoc = [self locationForGlyphAtIndex:gli];
						characterIndex = [self characterIndexForGlyphAtIndex:gli];
						font = [[self textStorage] attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
						
						glyphBounds = [font boundingRectForGlyph:glyph];
						
						glyphBounds.origin.x = origin.x + lineRect.origin.x + glyphLoc.x;
						glyphBounds.origin.y = ( origin.y + lineRect.origin.y + glyphLoc.y ) - NSHeight( glyphBounds );
						
						NSRectFill( glyphBounds );
					}
				}
				
				glyphIndex = NSMaxRange( glyphRange );
			}
		}
	}
}


- (void)		drawBackgroundForGlyphRange:(NSRange) glyphsToShow atPoint:(NSPoint) origin
{
	if([self greeking] == kDKGreekingNone)
		[super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
}

#pragma mark - as a NSObject

- (id)				init
{
	self = [super init];
	if( self )
		[self setGreekingColour:[NSColor lightGrayColor]];
	
	return self;
}


- (void)			dealloc
{
	[mGreekingColour release];
	[super dealloc];
}

@end
