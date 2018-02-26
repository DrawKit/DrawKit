/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKPrintDrawingView.h"

#import "DKDrawing.h"
#import "LogEvent.h"

@implementation DKPrintDrawingView
#pragma mark As a DKPrintDrawingView
- (void)setPrintInfo:(NSPrintInfo*)ip
{
	[ip retain];
	[m_printInfo release];
	m_printInfo = ip;
}

- (NSPrintInfo*)printInfo
{
	return m_printInfo;
}

#pragma mark -
#pragma mark As an NSView
	/*
- (BOOL)			knowsPageRange:(NSRangePointer) rng
{
	int		pagesAcross, pagesDown;
	NSSize	ds = [[self drawing] drawingSize];
	NSSize	ps = [[self printInfo] paperSize];
	
	ps.width -= ([[self printInfo] leftMargin] + [[self printInfo] rightMargin]);
	ps.height -= ([[self printInfo] topMargin] + [[self printInfo] bottomMargin]);
	
	pagesAcross = MAX( 1, truncf( ds.width / ps.width ));
	pagesDown = MAX( 1, truncf( ds.height / ps.height ));
	
	if ( fmodf( ds.width, ps.width ) > 2.0 )
		++pagesAcross;
	
	if ( fmodf( ds.height, ps.height ) > 2.0 )
		++pagesDown;
	
	LogEvent_(kUserEvent, @"pages across, down = {%d, %d}", pagesAcross, pagesDown );
	
	rng->location = 1;
	rng->length = pagesAcross * pagesDown;
	
	return YES;
}

- (NSRect)			rectForPage:(int) pageNumber
{
	NSRect	pr;
	int		pagesAcross, pagesDown;
	NSSize	ds = [[self drawing] drawingSize];
	NSSize	ps = [[self printInfo] paperSize];
	
	ps.width -= ([[self printInfo] leftMargin] + [[self printInfo] rightMargin]);
	ps.height -= ([[self printInfo] topMargin] + [[self printInfo] bottomMargin]);

	pagesAcross = MAX( 1, truncf( ds.width / ps.width ));
	pagesDown = MAX( 1, truncf( ds.height / ps.height ));
	
	if ( fmodf( ds.width, ps.width ) > 2.0 )
		++pagesAcross;
	
	if ( fmodf( ds.height, ps.height ) > 2.0 )
		++pagesDown;

	pr.size = ps;
	
	pr.origin.y = (( pageNumber - 1 ) / pagesAcross ) * ps.height;
	pr.origin.x = (( pageNumber - 1 ) % pagesAcross ) * ps.width;
	
	return pr;
}
*/

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	[m_printInfo release];

	[super dealloc];
}

@end
