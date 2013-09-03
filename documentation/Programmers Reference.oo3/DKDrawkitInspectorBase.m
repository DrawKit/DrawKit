///**********************************************************************************************************************************
///  DKDrawkitInspectorBase.m
///  DrawKit
///
///  Created by graham on 06/05/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKDrawkitInspectorBase.h"

#import "DKDrawingDocument.h"
#import "DKDrawing.h"
#import "DKObjectDrawingLayer.h"
#import "DKDrawingView.h"
#import "LogEvent.h"

@implementation DKDrawkitInspectorBase
#pragma mark As a DKDrawkitInspectorBase


- (void)				documentDidChange:(NSNotification*) note
{
	LogEvent_(kReactiveEvent, @"document did change, window = %@", [note object]);
	
	[self redisplayContentForSelection:[self selectedObjectForTargetWindow:[note object]]];
}


- (void)				layerDidChange:(NSNotification*) note
{
	#pragma unused(note)
	
	//LogEvent_(kReactiveEvent, @"layer did change, layer = %@", [note object]);

	[self redisplayContentForSelection:[self selectedObjectForCurrentTarget]];
}


- (void)				selectedObjectDidChange:(NSNotification*) note
{
	#pragma unused(note)
	
	//LogEvent_(kReactiveEvent, @"selection did change, selected = %@", [[note object] selection]);

	[self redisplayContentForSelection:[self selectedObjectForCurrentTarget]];
}


#pragma mark -
- (void)				redisplayContentForSelection:(NSArray*) selection
{
	#pragma unused(selection)
	
	// override to do something useful
}


#pragma mark -
- (id)					selectedObjectForCurrentTarget
{
	// this determines what object in the currently active document is selected. It can return different things:
	// 1. nil, meaning that nothing available is selected or that the current document isn't a drawing
	// 2. an array of drawable objects, being the available selected objects. Array may only contain 1 item. 
	
	DKDrawing* drawing = [self currentDrawing];
	DKLayer* layer = [drawing activeLayerOfClass:[DKObjectDrawingLayer class]];
			
	if ( layer != nil )
	{
		// yes - so just return its current selection
		
		return [(DKObjectDrawingLayer*)layer selectedAvailableObjects];
	}

	return nil;
}


- (DKDrawing*)			drawingForTargetWindow:(NSWindow*) window
{
	NSDocument* cd = [[NSDocumentController sharedDocumentController] documentForWindow:window];
	DKDrawing*	drawing = nil;
	
	// contains a drawing? (Note - if you implememt your own drawing document type you may need to modify this)
	
	if ([cd respondsToSelector:@selector(drawing)])
		drawing = [(id)cd drawing];
		
	if ( drawing != nil && [drawing isKindOfClass:[DKDrawing class]])
		return drawing;
		
	return nil;
}


- (id)					selectedObjectForTargetWindow:(NSWindow*) window
{
	DKDrawing*	drawing = [self drawingForTargetWindow:window];
	
	if ( drawing != nil)
	{
		DKLayer* layer = [drawing activeLayerOfClass:[DKObjectDrawingLayer class]];
			
		if ( layer != nil )
		{
			// yes - so just return its current selection
			
			return [(DKObjectDrawingLayer*)layer selectedAvailableObjects];
		}
	}
	return nil;
}


#pragma mark -
- (DKDrawingDocument*)	currentDocument
{
	NSDocument* cd = [[NSDocumentController sharedDocumentController] currentDocument];
	
	if([cd isKindOfClass:[DKDrawingDocument class]])
		return (DKDrawingDocument*) cd;
	else
		return nil;
}


- (DKDrawing*)			currentDrawing
{
	DKDrawingDocument* cd = [self currentDocument];
	
	if ( cd )
		return [cd drawing];
	else
		return nil;
}


- (DKLayer*)			currentActiveLayer
{
	return [[self currentDrawing] activeLayer];
}



- (DKViewController*)	currentMainViewController
{
	// returns the controller for the current main view IFF it is a DKDrawingView, otherwise nil
	
	id firstR = [[NSApp mainWindow] firstResponder];
	
	if([firstR isKindOfClass:[DKDrawingView class]])
		return [(DKDrawingView*)firstR controller];
	
	return nil;
}


#pragma mark -
#pragma mark As an NSWindowController
- (void)				showWindow:(id) sender
{
	[super showWindow:sender];
	[self redisplayContentForSelection:[self selectedObjectForCurrentTarget]];
}


#pragma mark -
#pragma mark As part of NSNibAwaking Protocol
- (void)				awakeFromNib
{
	// sets up the notifications - call super if you override it

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentDidChange:) name:NSWindowDidBecomeMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentDidChange:) name:NSWindowDidResignMainNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerDidChange:) name:kDKDrawingActiveLayerDidChange object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedObjectDidChange:) name:kGCLayerSelectionDidChange object:nil];
}


@end
