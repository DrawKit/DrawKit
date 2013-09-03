///**********************************************************************************************************************************
///  DKDrawkitInspectorBase.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 06/05/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawkitInspectorBase.h"
#import "DKDrawableObject.h"
#import "DKDrawingDocument.h"
#import "DKDrawing.h"
#import "DKObjectDrawingLayer.h"
#import "DKDrawingView.h"
#import "LogEvent.h"

@implementation DKDrawkitInspectorBase
#pragma mark As a DKDrawkitInspectorBase


- (void)				documentDidChange:(NSNotification*) note
{
	LogEvent_(kReactiveEvent, @"document did change (%@), window = %@", [note name], [note object]);
	
	if([[note name] isEqualToString:NSWindowDidResignMainNotification])
		[self redisplayContentForSelection:nil];
	else
		[self redisplayContentForSelection:[self selectedObjectForTargetWindow:[note object]]];
}


- (void)				layerDidChange:(NSNotification*) note
{
	#pragma unused(note)
	
	LogEvent_(kReactiveEvent, @"%@ received layer change (%@), layer = %@", self, [note name], [note object]);

	[self redisplayContentForSelection:[self selectedObjectForCurrentTarget]];
}


- (void)				selectedObjectDidChange:(NSNotification*) note
{
	if([[note object] respondsToSelector:@selector(selection)])
	{
		LogEvent_(kReactiveEvent, @"selection did change (%@), selected = %@", [note name], [[note object] selection]);
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:kDKDrawableSubselectionChangedNotification object:nil];
		
		NSArray* sel = [self selectedObjectForCurrentTarget];
		[self redisplayContentForSelection:sel];
		
		NSEnumerator* iter = [sel objectEnumerator];
		id				obj;
		
		while(( obj = [iter nextObject]))
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subSelectionDidChange:) name:kDKDrawableSubselectionChangedNotification object:obj];

	}
}


- (void)				subSelectionDidChange:(NSNotification*) note
{
	
	DKDrawableObject* obj = (DKDrawableObject*)[note object];
	NSSet* subsel = [obj subSelection];
	
	[self redisplayContentForSubSelection:subsel ofObject:obj];
}


#pragma mark -
- (void)				redisplayContentForSelection:(NSArray*) selection
{
	#pragma unused(selection)
	
	// override to do something useful
}


- (void)				redisplayContentForSubSelection:(NSSet*) subsel ofObject:(DKDrawableObject*) object
{
#pragma unused(subsel, object )
	
	NSLog(@"subselection of <%@ 0x%x> changed: %@", NSStringFromClass([object class]), object, subsel );
	
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
		// yes - so just return its current selection, including locked objects but not hidden ones.
		
		NSArray* sel = [(DKObjectDrawingLayer*)layer selectedVisibleObjects];
		return sel;
	}

	return nil;
}


- (DKDrawing*)			drawingForTargetWindow:(NSWindow*) window
{
	NSDocument* cd = [[NSDocumentController sharedDocumentController] documentForWindow:window];
	DKDrawing*	drawing = nil;
	
	// contains a drawing? (Note - if you implement your own drawing document type you may need to modify this)
	
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


- (void)				dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


- (void)				windowDidLoad
{
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedObjectDidChange:) name:kDKLayerSelectionDidChange object:nil];
}


@end
