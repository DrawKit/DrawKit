///**********************************************************************************************************************************
///  DKToolController.m
///  DrawKit
///
///  Created by graham on 8/04/2008.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************


#import "DKToolController.h"
#import "DKSelectAndEditTool.h"
#import "DKObjectDrawingLayer.h"
#import "DKDrawableObject.h"
#import "DKDrawing.h"
#import "DKUndoManager.h"
#import "LogEvent.h"

#pragma mark Contants (Non-localized)

NSString*		kDKWillChangeToolNotification = @"kDKWillChangeToolNotification";
NSString*		kDKDidChangeToolNotification = @"kDKDidChangeToolNotification";


@interface DKToolController (Private)

+ (DKDrawingTool*)		drawingToolForDrawing:(NSString*) drawingKey;
+ (void)				setDrawingTool:(DKDrawingTool*) tool forDrawing:(NSString*) drawingKey;
+ (DKDrawingTool*)		globalDrawingTool;
+ (void)				setGlobalDrawingTool:(DKDrawingTool*) tool;

@end

#pragma mark -

#pragma mark Static Vars

static DKDrawingToolScope	sDrawingToolScope = kDKToolScopeLocalToDocument;
static NSMutableDictionary*	sDrawingToolDict = nil;
static DKDrawingTool*		sGlobalTool = nil;

@implementation DKToolController

#pragma mark - private class methods

///*********************************************************************************************************************
///
/// method:			drawingToolForDrawing:
/// scope:			private class method
/// description:	returns the drawing tool currently set for the given drawing
/// 
/// parameters:		<dwg> a key for the drawing object
/// result:			the current tool set for the drawing
///
/// notes:			this is used when the tool scope is per-document. In that case the tool is associated with the
///					document, not the individual view.
///
///********************************************************************************************************************

+ (DKDrawingTool*)		drawingToolForDrawing:(NSString*) drawingKey
{
	NSAssert( drawingKey != nil, @"drawing was nil trying to get per-document tool");
	
	if ( sDrawingToolDict == nil )
		return nil;
	else
		return [sDrawingToolDict objectForKey:drawingKey];
}


///*********************************************************************************************************************
///
/// method:			setDrawingTool:forDrawing:
/// scope:			private class method
/// description:	sets the drawing tool for the given drawing
/// 
/// parameters:		<tool> the tool to set
///					<dwg> a key for the drawing object
/// result:			none
///
/// notes:			this is used when the tool scope is per-document. In that case the tool is associated with the
///					document, not the individual view.
///
///********************************************************************************************************************

+ (void)				setDrawingTool:(DKDrawingTool*) tool forDrawing:(NSString*) drawingKey
{
	NSAssert( drawingKey != nil, @"attempt to set tool per drawing, but drawing key is nil");
	
	if( sDrawingToolDict == nil )
		sDrawingToolDict = [[NSMutableDictionary alloc] init];
		
	[sDrawingToolDict setObject:tool forKey:drawingKey];
}


///*********************************************************************************************************************
///
/// method:			globalDrawingTool
/// scope:			private class method
/// description:	get the tool for the entire application
/// 
/// parameters:		none
/// result:			the current tool set for the app
///
/// notes:			this is used when the tool scope is per-application.
///
///********************************************************************************************************************

+ (DKDrawingTool*)		globalDrawingTool
{
	return sGlobalTool;
}


///*********************************************************************************************************************
///
/// method:			setGlobalDrawingTool:
/// scope:			private class method
/// description:	get the tool for the entire application
/// 
/// parameters:		<tool> the tool to set
/// result:			none
///
/// notes:			this is used when the tool scope is per-application.
///
///********************************************************************************************************************

+ (void)				setGlobalDrawingTool:(DKDrawingTool*) tool
{
	[tool retain];
	[sGlobalTool release];
	sGlobalTool = tool;
}

#pragma mark -
#pragma mark - As a DKToolController

///*********************************************************************************************************************
///
/// method:			setDrawingToolOperatingScope:
/// scope:			public class method
/// description:	set the operating scope for tools for this application
/// 
/// parameters:		<scope> the operating scope for tools
/// result:			none
///
/// notes:			DK allows tools to be set per-view, per-document, or per-application. This is called the operating
///					scope. Generally your app should decide what is appropriate, set it at start up and stick to it.
///					It is not expected that this will be called during the subsequent use of the app - though it is
///					harmless to do so it's very likely to confuse the user.
///
///********************************************************************************************************************

+ (void)				setDrawingToolOperatingScope:(DKDrawingToolScope) scope
{
	sDrawingToolScope = scope;
}



///*********************************************************************************************************************
///
/// method:			drawingToolOperatingScope
/// scope:			public class method
/// description:	return the operating scope for tools for this application
/// 
/// parameters:		none
/// result:			the operating scope for tools
///
/// notes:			DK allows tools to be set per-view, per-document, or per-application. This is called the operating
///					scope. Generally your app should decide what is appropriate, set it at start up and stick to it.
///					The default is per-document scope.
///
///********************************************************************************************************************

+ (DKDrawingToolScope)	drawingToolOperatingScope
{
	return sDrawingToolScope;
}


///*********************************************************************************************************************
///
/// method:			setDrawingTool:
/// scope:			public instance method
/// description:	sets the current drawing tool
/// 
/// parameters:		<aTool> the tool to set
/// result:			none
///
/// notes:			the tool is set locally, for the drawing or globally according to the current scope.
///
///********************************************************************************************************************

- (void)				setDrawingTool:(DKDrawingTool*) aTool
{
	NSAssert( aTool != nil, @"attempt to set a nil tool");
	
	if( aTool != [self drawingTool])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKWillChangeToolNotification object:self];
		
		switch([[self class] drawingToolOperatingScope])
		{
			case kDKToolScopeLocalToView:
				[aTool retain];
				[mTool release];
				mTool = aTool;
				break;
			
			default:	
			case kDKToolScopeLocalToDocument:
				[[self class] setDrawingTool:aTool forDrawing:[[self drawing] uniqueKey]];
				break;
				
			case kDKToolScopeGlobal:
				[[self class] setGlobalDrawingTool:aTool];
				break;
		}
		[self invalidateCursors];
		
		// if the set tool was a select/edit tool, turn ON the reverts auto flag. This implements a very typical
		// behaviour where a non-select tool may have set the flag off - for example by being double-clicked - to
		// make the tool "sticky", but manually switching back to the select tool cancels the stickyness.
		// TO DO - maybe there should be a way to specify whether this is done or not?
		
		if([aTool isKindOfClass:[DKSelectAndEditTool class]])
			[self setAutomaticallyRevertsToSelectionTool:YES];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDidChangeToolNotification object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			setDrawingToolWithName:
/// scope:			public instance method
/// description:	select the tool using its registered name
/// 
/// parameters:		<name> the registered name of the required tool
/// result:			none
///
/// notes:			Tools must be registered in the DKDrawingTool registry with the given name before you can use this
///					method to set them.
///
///********************************************************************************************************************

- (void)				setDrawingToolWithName:(NSString*) name
{
	if( name != nil && [name length] > 0 )
	{
		DKDrawingTool* tool = [DKDrawingTool drawingToolWithName:name];
		
		LogEvent_( kStateEvent, @"tool controller selecting tool with name '%@', tool = %@", name, tool);
		
		if ( tool != nil )
			[self setDrawingTool:tool];
	}
}



///*********************************************************************************************************************
///
/// method:			drawingTool
/// scope:			public instance method
/// description:	return the current drawing tool
/// 
/// parameters:		none
/// result:			the current tool
///
/// notes:			the tool is set locally, for the drawing or globally according to the current scope.
///
///********************************************************************************************************************

- (DKDrawingTool*)		drawingTool
{
	switch([[self class] drawingToolOperatingScope])
	{
		case kDKToolScopeLocalToView:
			return mTool;
		
		default:	
		case kDKToolScopeLocalToDocument:
			return [[self class] drawingToolForDrawing:[[self drawing] uniqueKey]];
			
		case kDKToolScopeGlobal:
			return [[self class] globalDrawingTool];
	}
}

///*********************************************************************************************************************
///
/// method:			setAutomaticallyRevertsToSelectionTool:
/// scope:			public instance method
/// description:	set whether the tool should automatically "spring back" to the selection tool after each application
/// 
/// parameters:		<reverts> YES to spring back, NO to leave the present tool active after each use
/// result:			none
///
/// notes:			the default is YES
///
///********************************************************************************************************************

- (void)				setAutomaticallyRevertsToSelectionTool:(BOOL) reverts
{
	mAutoRevert = reverts;
	
	LogEvent_( kInfoEvent, @"tool controller setting sticky tools = %d", !mAutoRevert);
}


///*********************************************************************************************************************
///
/// method:			automaticallyRevertsToSelectionTool
/// scope:			public instance method
/// description:	whether the tool should automatically "spring back" to the selection tool after each application
/// 
/// parameters:		none
/// result:			YES to spring back, NO to leave the present tool active after each use
///
/// notes:			the default is YES
///
///********************************************************************************************************************

- (BOOL)				automaticallyRevertsToSelectionTool
{
	return mAutoRevert;
}


///*********************************************************************************************************************
///
/// method:			drawRect:
/// scope:			public instance method
/// description:	draw any tool graphic content into the view
/// 
/// parameters:		<rect> the update rect in the view
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				drawRect:(NSRect) rect
{
	DKDrawingTool*		ct = [self drawingTool];
	NSAssert( ct != nil , @"nil drawing tool for drawRect:");

	[ct drawRect:rect inView:[self view]];
}


///*********************************************************************************************************************
///
/// method:			selectDrawingToolByName:
/// scope:			public action method
/// description:	select the tool using its registered name based on the title of a UI control, etc.
/// 
/// parameters:		<sender> the sender of the action - it should implement -title (e.g. a button, menu item)
/// result:			none
///
/// notes:			This is a convenience for hooking up a UI for picking a tool. You can set the title of a button to
///					be the tool's name and target first responder using this action, and it will select the tool if it
///					has been registered using the name. This makes UI such as a palette of tools trivial to implement,
///					but doesn't preclude you from using any other UI as you see fit.
///
///********************************************************************************************************************

- (IBAction)			selectDrawingToolByName:(id) sender
{
	NSString* toolName = [sender title];
	[self setDrawingToolWithName:toolName];
}


///*********************************************************************************************************************
///
/// method:			selectDrawingToolByRepresentedObject:
/// scope:			public action method
/// description:	select the tool using the represented object of a UI control, etc.
/// 
/// parameters:		<sender> the sender of the action - it should implement -representedObject (e.g. a button, menu item)
/// result:			none
///
/// notes:			This is a convenience for hooking up a UI for picking a tool. You can set the rep. object of a button to
///					be the tool and target first responder using this action, and it will set the tool to the button's
///					represented object.
///
///********************************************************************************************************************

- (IBAction)			selectDrawingToolByRepresentedObject:(id) sender
{
	if( sender != nil && [sender respondsToSelector:@selector(representedObject)])
	{
		DKDrawingTool* tool = [sender representedObject];
		
		if( tool != nil && [tool isKindOfClass:[DKDrawingTool class]])
		{
			LogEvent_( kStateEvent, @"tool controller selecting tool (represented object) = %@", tool);
			
			[self setDrawingTool:tool];
		}
		else
			[NSException raise:NSInternalInconsistencyException format:@"represented object of sender %@ was not a valid DKDrawingTool", [sender description]];
	}
}


///*********************************************************************************************************************
///
/// method:			toggleAutoRevertAction:
/// scope:			public action method
/// description:	toggle the state of the automatic tool "spring" behaviour.
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			flips the state of the auto-revert flag. A UI can make use of this to control the flag in order to
///					make a tool "sticky". Often this is done by double-clicking the tool button.
///
///********************************************************************************************************************

- (IBAction)			toggleAutoRevertAction:(id) sender
{
	#pragma unused(sender)
	
	[self setAutomaticallyRevertsToSelectionTool:![self automaticallyRevertsToSelectionTool]];
}


- (DKUndoManager*)		undoManager
{
	return (DKUndoManager*)[[self drawing] undoManager];
}


#pragma mark -
#pragma mark - As a DKViewController

///*********************************************************************************************************************
///
/// method:			initWithView:
/// scope:			public instance method, designated initializer
/// overrides:		DKViewController
/// description:	initialize the controller.
/// 
/// parameters:		<aView> the view associated with the controller
/// result:			the controller object
///
/// notes:			does not set an initial tool because the objects needed for the document scope are not available.
///					The initial tool is set when the controller is added to a drawing (see setDrawing:)
///
///********************************************************************************************************************

- (id)					initWithView:(NSView*) aView
{
	self = [super initWithView:aView];
	if( self != nil )
	{
		[self setAutomaticallyRevertsToSelectionTool:YES];
	}
	
	LogEvent_( kInfoEvent, @"created tool controller, current scope = %d", [[self class] drawingToolOperatingScope]);
	
	return self;
}


///*********************************************************************************************************************
///
/// method:			setDrawing:
/// scope:			public instance method
/// overrides:		DKViewController
/// description:	the controller is being added to a drawing
/// 
/// parameters:		<aDrawing> the drawing to which the tool is being added
/// result:			none
///
/// notes:			if no tool is set, set it initially to the select & edit tool
///
///********************************************************************************************************************

- (void)				setDrawing:(DKDrawing*) aDrawing
{
	[super setDrawing:aDrawing];
	
	// set the default tool if there isn't yet one set. This is done at this point so that if the scope is per-document,
	// the drawing is valid. This also works as is should for both local and global scope.
	
	if( aDrawing != nil && [self drawingTool] == nil )
	{
		DKDrawingTool* se = [[DKSelectAndEditTool alloc] init];
		[self setDrawingTool:se];
		[se release];
	}
}



///*********************************************************************************************************************
///
/// method:			mouseDown:
/// scope:			public instance method
/// overrides:		DKViewController
/// description:	handle the mouse down event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			calls the mouse down method of the current tool, if the layer is an object layer. Calls super to
///					ensure that autscrolling and targeting of other layer types works normally.
///
///********************************************************************************************************************

- (void)				mouseDown:(NSEvent*) event
{
	LogEvent_( kInfoEvent, @"tool controller mouse down");
	
	mOpenedUndoGroup = NO;
	
	DKDrawableObject*	target = nil;
	DKDrawingTool*		ct = [self drawingTool];
	NSPoint				p = [[self view] convertPoint:[event locationInWindow] fromView:nil];
	
	NSAssert( ct != nil , @"nil drawing tool for mouse down");
	
	// should the layer be auto-activated? Only do this if the tool is set to the selection tool, because
	// otherwise drawing a shape on top of another in another layer can cause the layer to switch unexpectedly.
	
	if([ct isKindOfClass:[DKSelectAndEditTool class]])
		[self autoActivateLayerWithEvent:event];

	// set the layer's current view
	
	[[self activeLayer] setCurrentView:[self view]];
	
	// can the tool be used in this layer anyway?

	if ([ct isValidTargetLayer:[self activeLayer]])
	{
		[self startAutoscrolling];
		
		BOOL isObjectLayer = [[self activeLayer] isKindOfClass:[DKObjectDrawingLayer class]];
		
		if( isObjectLayer )
		{
			// the operation we are about to do may change the selection, so record its current state so it can be undone if needed.
			
			[(DKObjectDrawingLayer*)[self activeLayer] recordSelectionForUndo];
			
			// see if there is a target object
			
			target = [(DKObjectDrawingLayer*)[self activeLayer] hitTest:p];
		}
		// start the tool:
		
		mPartcode = [ct mouseDownAtPoint:p targetObject:target layer:[self activeLayer] event:event delegate:self];
	}
	else
		[super mouseDown:event];
}



///*********************************************************************************************************************
///
/// method:			mouseDragged:
/// scope:			public instance method
/// overrides:		DKViewController
/// description:	handle the mouse dragged event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			calls the mouse dragged method of the current tool, if the layer is an object layer. Calls super to
///					ensure that other layer types work normally.
///
///********************************************************************************************************************

- (void)				mouseDragged:(NSEvent*) event
{
	NSAutoreleasePool*	pool = [NSAutoreleasePool new];
	DKDrawingTool*		ct = [self drawingTool];
	
	NSAssert( ct != nil , @"nil drawing tool for mouse drag");
	
	NSPoint				p = [[self view] convertPoint:[event locationInWindow] fromView:nil];
	
	if ([ct isValidTargetLayer:[self activeLayer]])
		[ct mouseDraggedToPoint:p partCode:mPartcode layer:[self activeLayer] event:event delegate:self];
	else
		[super mouseDragged:event];
		
	[pool drain];
}



///*********************************************************************************************************************
///
/// method:			mouseUp:
/// scope:			public instance method
/// overrides:		DKViewController
/// description:	handle the mouse up event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			calls the mouse up method of the current tool, if the layer is an object layer. Calls super to
///					ensure that other layer types work normally.
///
///********************************************************************************************************************

- (void)				mouseUp:(NSEvent*) event
{
	LogEvent_( kInfoEvent, @"tool controller mouse up");

	DKDrawingTool*		ct = [self drawingTool];
	NSPoint				p = [[self view] convertPoint:[event locationInWindow] fromView:nil];
	
	NSAssert( ct != nil , @"nil drawing tool for mouse up");

	if ([ct isValidTargetLayer:[self activeLayer]])
	{
		BOOL undo = [ct mouseUpAtPoint:p partCode:mPartcode layer:[self activeLayer] event:event delegate:self];
		
		BOOL isObjectLayer = [[self activeLayer] isKindOfClass:[DKObjectDrawingLayer class]];
		
		if( isObjectLayer && undo )
		{
			// if the tool did something undoable, get the undo action and commit it in the active layer. This also
			// commits the recorded selection to the undo stack if the layer treats selection changes as undoable.
			
			NSString* action = [ct actionName];
			[(DKObjectDrawingLayer*)[self activeLayer] commitSelectionUndoWithActionName:action];
		}
		// close the undo group if one was opened applying the tool

		if( mOpenedUndoGroup )
		{
			LogEvent_( kReactiveEvent, @"tool controller will close undo group");
			
			[[[self drawing] undoManager] endUndoGrouping];
			mOpenedUndoGroup = NO;
		}
		
		[self stopAutoscrolling];
	}
	else
		[super mouseUp:event];
	
	// after handling mouse up, we may wish to spring back to the selection tool
	
	if([self automaticallyRevertsToSelectionTool] && ![ct isKindOfClass:[DKSelectAndEditTool class]])
	{
		DKDrawingTool* se;
		
		se = [DKDrawingTool drawingToolWithName:kDKStandardSelectionToolName];
		
		if( se == nil )
			se = [[[DKSelectAndEditTool alloc] init] autorelease];
			
		[self setDrawingTool:se];
	}
}



///*********************************************************************************************************************
///
/// method:			flagsChanged:
/// scope:			public instance method
/// overrides:		DKViewController
/// description:	handle the flags changed up event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			passes the event to the current tool
///
///********************************************************************************************************************

- (void)				flagsChanged:(NSEvent*) event
{
	if ([self drawingTool] != nil && [[self drawingTool] isValidTargetLayer:[self activeLayer]])
		[[self drawingTool] flagsChanged:event inLayer:[self activeLayer]];
	else
		[super flagsChanged:event];
}


///*********************************************************************************************************************
///
/// method:			mouseMoved:
/// scope:			public instance method
/// overrides:		DKViewController
/// description:	handle the mouse moved event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			passes the event to the current tool
///
///********************************************************************************************************************

- (void)				mouseMoved:(NSEvent*) event
{
	#pragma unused(event)
	/*
	NSPoint mp = [[self view] convertPoint:[event locationInWindow] fromView:nil];
	
	if ([self drawingTool] != nil && [[self drawingTool] isValidTargetLayer:[self activeLayer]])
	{
		DKDrawableObject* target = [(DKObjectDrawingLayer*)[self activeLayer] hitTest:mp];
		[[self drawingTool] setCursorForPoint:mp targetObject:target inLayer:[self activeLayer] event:event];
	}
	*/
}


///*********************************************************************************************************************
///
/// method:			cursor
/// scope:			public instance method
/// overrides:		DKViewController
/// description:	returns the current tool's cursor
/// 
/// parameters:		none
/// result:			a cursor
///
/// notes:			
///
///********************************************************************************************************************

- (NSCursor*)			cursor
{
	if ([self drawingTool] != nil && [[self drawingTool] isValidTargetLayer:[self activeLayer]])
		return [[self drawingTool] cursor];
	else
		return [super cursor];
}


#pragma mark -
#pragma mark - As an NSResponder

///*********************************************************************************************************************
///
/// method:			keyDown:
/// scope:			public instance method
/// overrides:		NSResponder
/// description:	responds to a keyDown event by selecting a tool having a matching key equivalent, if any
/// 
/// parameters:		<event> the key down event
/// result:			none
///
/// notes:			if a tool exists that matches the key equivalent, select it. Otherwise just pass the event
///					to the layer.
///
///********************************************************************************************************************

- (void)				keyDown:(NSEvent*) event
{
	DKDrawingTool* tool = [DKDrawingTool drawingToolWithKeyboardEquivalent:event];
	
	if( tool != nil )
		[self setDrawingTool:tool];
	else
		[[self view] interpretKeyEvents:[NSArray arrayWithObject:event]];
}


#pragma mark -
#pragma mark - As part of the NSObject (DKToolDelegate) protocol 


///*********************************************************************************************************************
///
/// method:			toolWillPerformUndoableAction:
/// scope:			delegate callback method
/// overrides:		NSObject (DKToolDelegate)
/// description:	opens an undo group to receive subsequent undo tasks
/// 
/// parameters:		<aTool> the tool making the request
/// result:			none
///
/// notes:			this is needed to work around an NSUndoManager bug where empty groups create a bogus task on the stack.
///					A group is only opened when a real task is coming. This isn't really very elegant right now - a
///					better solution is sought, perhaps subclassing NSUndoManager itself.
///
///********************************************************************************************************************

- (void)				toolWillPerformUndoableAction:(DKDrawingTool*) aTool
{
	#pragma unused(aTool)
	
	if ( !mOpenedUndoGroup )
	{
		LogEvent_( kReactiveEvent, @"tool controller will open undo group");

		[[[self drawing] undoManager] beginUndoGrouping];
		mOpenedUndoGroup = YES;
	}
}

#pragma mark -
#pragma mark - As an NSObject 


///*********************************************************************************************************************
///
/// method:			dealloc
/// scope:			public instance method
/// overrides:		NSObject
/// description:	deallocate the controller
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				dealloc
{
	[mTool release];
	[super dealloc];
}

@end
