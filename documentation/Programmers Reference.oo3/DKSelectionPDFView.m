//
//  DKSelectionPDFView.m
//  DrawingArchitecture
//
//  Created by graham on 30/09/2006.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "DKSelectionPDFView.h"
#import "DKDrawing.h"
#import "DKObjectDrawingLayer.h"
#import "DKShapeGroup.h"


@implementation DKSelectionPDFView

- (void)		drawRect:(NSRect) rect
{
	#pragma unused(rect)
	
	[[NSColor clearColor] set];
	NSRectFill([self bounds]);
	
	unsigned mask = ( NSAlternateKeyMask | NSShiftKeyMask | NSCommandKeyMask );
	BOOL drawSelected = (([[NSApp currentEvent] modifierFlags] & mask) == mask );
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[[self controller] activeLayer];

	if ( [layer isKindOfClass:[DKObjectDrawingLayer class]])
		[layer drawSelectedObjectsWithSelectionState:drawSelected];
}


@end


#pragma mark -
@implementation DKGridLayerPDFView

- (void)		drawRect:(NSRect) rect
{
	[[NSColor clearColor] set];
	NSRectFill([self bounds]);
	
	DKGridLayer*	layer = [[self drawing] gridLayer];
	[layer drawRect:rect inView:self];
}


@end


#pragma mark -
@implementation DKObjectLayerPDFView : DKDrawingView


- (id)		initWithFrame:(NSRect) frame withLayer:(DKObjectOwnerLayer*) aLayer
{
	self = [super initWithFrame:frame];
	if( self != nil )
	{
		mLayerRef = aLayer;
	}
	
	return self;
}


- (BOOL)		isFlipped
{
	return YES;
}



- (void)		drawRect:(NSRect) rect
{
	#pragma unused(rect)
	
	[[NSColor clearColor] set];
	NSRectFill([self bounds]);
	
	if ( mLayerRef != nil )
		[mLayerRef drawVisibleObjects];
}

@end


#pragma mark -
@implementation DKGroupPDFView

- (id)		initWithFrame:(NSRect) frame withGroup:(DKShapeGroup*) aGroup
{
	self = [super initWithFrame:frame];
	if( self != nil )
	{
		mGroupRef = aGroup;
	}
	
	return self;
}


- (BOOL)		isFlipped
{
	return YES;
}


- (void)		drawRect:(NSRect) rect
{
	#pragma unused(rect)
	
	[[NSColor clearColor] set];
	NSRectFill([self bounds]);
	
	if ( mGroupRef != nil )
		[mGroupRef drawGroupContent];
}


@end


