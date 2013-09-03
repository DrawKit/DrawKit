//
//  DKBezierTextContainer.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 09/05/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKBezierTextContainer.h"
#import "NSBezierPath+Text.h"



@implementation DKBezierTextContainer


- (void)			setBezierPath:(NSBezierPath*) aPath
{
	// copy the path and store it offset to its top, left corner - this saves
	// having to adjust the line fragment rects to the path for every call.
	
	NSRect pb = [aPath bounds];
	NSAffineTransform* tfm = [NSAffineTransform transform];
	
	[tfm translateXBy:-pb.origin.x yBy:-pb.origin.y];
	aPath = [tfm transformBezierPath:aPath];
	
	[aPath retain];
	[mPath release];
	mPath = aPath;
}


- (BOOL)			isSimpleRegularTextContainer
{
	return (mPath == nil);
}


- (NSRect)			lineFragmentRectForProposedRect:(NSRect) proposedRect
					sweepDirection:(NSLineSweepDirection) sweepDirection
					movementDirection:(NSLineMovementDirection) movementDirection
					remainingRect:(NSRectPointer) remainingRect
{
	if( mPath == nil )
		return [super lineFragmentRectForProposedRect:proposedRect sweepDirection:sweepDirection movementDirection:movementDirection remainingRect:remainingRect];
	else
		return [mPath lineFragmentRectForProposedRect:proposedRect remainingRect:remainingRect];
}


- (void)			dealloc
{
	[mPath release];
	[super dealloc];
}


@end
