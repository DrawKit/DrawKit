///**********************************************************************************************************************************
///  DKToolController.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 8/04/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKToolController.h"
#import "DKToolRegistry.h"
#import "DKSelectAndEditTool.h"
#import "DKObjectDrawingLayer.h"
#import "DKDrawableObject.h"
#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKUndoManager.h"
#import "LogEvent.h"

#pragma mark Contants (Non-localized)

NSString*		kDKWillChangeToolNotification				= @"kDKWillChangeToolNotification";
NSString*		kDKDidChangeToolNotification				= @"kDKDidChangeToolNotification";
NSString*		kDKDidChangeToolAutoRevertStateNotification = @"kDKDidChangeToolAutoRevertStateNotification";

NSString*		kDKDrawingToolAutoActivatesLayerDefaultsKey = @"DKDrawingToolAutoActivatesLayer";

@interface DKToolController (Private)

+ (DKDrawingTool*)		drawingToolForDrawing:(NSString*) drawingKey;
+ (void)				setDrawingTool:(DKDrawingTool*) tool forDrawing:(NSString*) drawingKey;
+ (DKDrawingTool*)		globalDrawingTool;
+ (void)				setGlobalDrawingTool:(DKDrawingTool*) tool;

- (DKLayer*)			findEligibleLayerForTool:(DKDrawingTool*) tool;

@end

#pragma mark -

#pragma mark Static Vars

static DKDrawingToolScope	sDrawingToolScope = kDKToolScopeLocalToDocument;
static NSMutableDictionary*	sDrawingToolDict = nil;
static DKDrawingTool*		sGlobalTool = nil;


#define DK_ENABLE_UNDO_GROUPING			1
#define DK_ALWAYS_OPEN_UNDO_GROUP		1


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
///					drawing, not the individual view.
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
/// method:			setToolsAutoActivateValidLayer:
/// scope:			public class method
/// description:	set whether setting a tool will auto-activate a layer appropriate to the tool
/// 
/// parameters:		<autoActivate> YES to autoactivate, NO otherwise
/// result:			none
///
/// notes:			Default is NO. If YES, when a tool is set but the active layer is not valid for the tool, the
///					layers are searched top down until one is found that the tool validates, which is then made
///					active. Layers which are locked, hidden or refuse active status are skipped. Persistent.
///
///********************************************************************************************************************

+ (void)				setToolsAutoActivateValidLayer:(BOOL) autoActivate
{
	[[NSUserDefaults standardUserDefaults] setBool:autoActivate forKey:kDKDrawingToolAutoActivatesLayerDefaultsKey];
}


///*********************************************************************************************************************
///
/// method:			toolsAutoActivateValidLayer
/// scope:			public class method
/// description:	return whether setting a tool will auto-activate a layer appropriate to the tool
/// 
/// parameters:		none
/// result:			YES if tools auto-activate appropriate layer, NO if not
///
/// notes:			Default is NO. If YES, when a tool is set but the active layer is not valid for the tool, the
///					layers are searched top down until one is found that the tool validates, which is then made
///					active. Layers which are locked, hidden or refuse active status are skipped. Persistent.
///
///********************************************************************************************************************

+ (BOOL)				toolsAutoActivateValidLayer
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingToolAutoActivatesLayerDefaultsKey];
}


#pragma mark -



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
		DKDrawingTool* oldTool = [[self drawingTool] retain];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKWillChangeToolNotification object:self];
		[oldTool toolControllerWillUnsetTool:self];
		
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
		[oldTool toolControllerDidUnsetTool:self];
		[aTool toolControllerDidSetTool:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDidChangeToolNotification object:self];
		
		[oldTool release];
		
		// check if the current layer is usable with the tool and the class enables auto-activation. If it does,
		// find an alternative layer and make it active
		
		if([[self class] toolsAutoActivateValidLayer])
		{
			if( ![aTool isValidTargetLayer:[self activeLayer]])
			{
				DKLayer* alternative = [self findEligibleLayerForTool:aTool];
				
				if( alternative )
					[[self drawing] setActiveLayer:alternative];
			}
		}
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
///					method to set them, otherwise an exception is thrown.
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
		else
			[NSException raise:NSInternalInconsistencyException format:@"tool name '%@' could not be found", name];
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
/// method:			canSetDrawingTool:
/// scope:			public instance method
/// description:	check if the tool can be set for the current active layer
/// 
/// parameters:		<aTool> the propsed drawing tool
/// result:			YES if the tool can be applied to the current active layer, NO if not
///
/// notes:			can be used to test whether a tool is able to be selected in the current context. There is no
///					requirement to use this - you can set the drawing tool anyway and if an attempt to use it in
///					an invalid layer is made, the tool controller will handle it anyway. A UI might want to use this
///					to prevent the selection of a tool before it gets to that point however.
///
///********************************************************************************************************************

- (BOOL)				canSetDrawingTool:(DKDrawingTool*) aTool
{
	NSAssert( aTool != nil, @"tool is nil in -canSetDrawingTool:");
	
	return [aTool isValidTargetLayer:[self activeLayer]];
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
	if( reverts != mAutoRevert )
	{
		mAutoRevert = reverts;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDidChangeToolAutoRevertStateNotification object:self];
		
		LogEvent_( kInfoEvent, @"tool controller setting sticky tools = %d", !mAutoRevert);
	}
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
	
	if([ct respondsToSelector:@selector(drawRect:inView:)])
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


///*********************************************************************************************************************
///
/// method:			undoManager
/// scope:			public instance method
/// description:	return the undo manager
/// 
/// parameters:		none
/// result:			the drawing's undo manager
///
/// notes:			
///
///********************************************************************************************************************

- (id)		undoManager
{
	return (id)[[self drawing] undoManager];
}


///*********************************************************************************************************************
///
/// method:			openUndoGroup
/// scope:			public instance method
/// description:	opens a new undo manager group if one has not already been opened
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				openUndoGroup
{
#if DK_ENABLE_UNDO_GROUPING
	if( !mOpenedUndoGroup )
	{
		LogEvent_( kReactiveEvent, @"tool controller will open undo group");
		
		[[self undoManager] beginUndoGrouping];
		mOpenedUndoGroup = YES;
	}
#endif
}


///*********************************************************************************************************************
///
/// method:			closeUndoGroup
/// scope:			public instance method
/// description:	closes the current undo manager group if one has been opened
/// 
/// parameters:		none
/// result:			none
///
/// notes:			When the controller is set up to always open a group, this also deals with the bogus task bug in
///					NSUndoManager, where opening and closig a group creates an empty undo task. If that case is detected,
///					the erroneous task is removed from the stack by invoking undo while temporarily disabling the UM.
///
///********************************************************************************************************************

- (void)				closeUndoGroup
{
#if DK_ENABLE_UNDO_GROUPING
	if( mOpenedUndoGroup )
	{
		LogEvent_( kReactiveEvent, @"tool controller will close undo group");
		
		[[self undoManager] endUndoGrouping];
		mOpenedUndoGroup = NO;
	
#if DK_ALWAYS_OPEN_UNDO_GROUP
	
		// clean up empty undo task if nothing was actually done (NSUndoManager bug workaround)
		/*
		NSInteger	groupLevel = [[self undoManager] groupingLevel];
		NSUInteger	taskCount = [[self undoManager] numberOfTasksInLastGroup];
		
		if( groupLevel == 0 && taskCount == 0 )
		{
			[[self undoManager] disableUndoRegistration];
			[[self undoManager] undoNestedGroup];
			[[self undoManager] enableUndoRegistration];
		}
		*/
		[[self undoManager] setGroupsByEvent:YES];
#endif
	}
#endif
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			findEligibleLayerForTool:
/// scope:			private method
/// description:	search for a layer usable with a given tool.
/// 
/// parameters:		<tool> the tool in question
/// result:			a usable layer, or nil
///
/// notes:			this is used when tools are set to auto-activate layers and the current active layer can't be
///					used. It returns an alternative layer that can be activated for use with the tool. Called by
///					-setDrawingTool:
///
///********************************************************************************************************************

- (DKLayer*)			findEligibleLayerForTool:(DKDrawingTool*) tool
{
	NSAssert( tool != nil, @"tool passed to findEligibleLayer was nil");
	
	NSEnumerator*	iter = [[[self drawing] flattenedLayers] objectEnumerator];
	DKLayer*		layer;
	
	while(( layer = [iter nextObject]))
	{
		if(![layer lockedOrHidden] && [layer layerMayBecomeActive] && [tool isValidTargetLayer:layer])
			return layer;
	}
		
	return nil;
}

#pragma mark -
#pragma mark - As a DKViewController

///*********************************************************************************************************************
///
/// method:			initWithView:
/// scope:			public instance method; designated initializer
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
		[self setAutomaticallyRevertsToSelectionTool:NO];
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
/// notes:			if no tool is set, set it initially to the select & edit tool. Note that this method is invoked as
///					necessary when a controller is added to a drawing - you should not call it directly nor at any time
///					while a controller is owned by the drawing.
///
///********************************************************************************************************************

- (void)				setDrawing:(DKDrawing*) aDrawing
{
	[super setDrawing:aDrawing];
	
	// set the default tool if there isn't yet one set. This is done at this point so that if the scope is per-document,
	// the drawing is valid. This also works as it should for both local and global scope.
	
	if( aDrawing != nil && [self drawingTool] == nil )
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
	mAbortiveMouseDown = NO;
	
	DKDrawableObject*	target = nil;
	DKDrawingTool*		ct = [self drawingTool];
	NSPoint				p = [[self view] convertPoint:[event locationInWindow] fromView:nil];
	
	NSAssert( ct != nil , @"nil drawing tool for mouse down");
	
	// should the layer be auto-activated? Only do this if the tool is some kind of selection tool, because
	// otherwise drawing a shape on top of another in another layer can cause the layer to switch unexpectedly.
	
	if([ct isSelectionTool])
		[self autoActivateLayerWithEvent:event];
	
	// can the tool be used in this layer anyway?

	if ([ct isValidTargetLayer:[self activeLayer]])
	{
		[self startAutoscrolling];
		
		BOOL isObjectLayer = [[self activeLayer] isKindOfClass:[DKObjectDrawingLayer class]];
		
		if( isObjectLayer )
		{
			// the operation we are about to do may change the selection, so record its current state so it can be undone if needed.
			
			[(DKObjectDrawingLayer*)[self activeLayer] recordSelectionForUndo];
		}	
		
		// see if there is a target object
			
		target = [(DKObjectDrawingLayer*)[self activeLayer] hitTest:p];

		// start the tool:
		
		@try
		{
#if DK_ALWAYS_OPEN_UNDO_GROUP
			[[self undoManager] setGroupsByEvent:NO];
			[self openUndoGroup];
#endif
			mPartcode = [ct mouseDownAtPoint:p targetObject:target layer:[self activeLayer] event:event delegate:self];
		}
		@catch( NSException* excp )
		{
			NSLog(@"caught exception on mouse down with tool - ignored (tool = %@, exception = %@)", ct, excp );
			
			[self closeUndoGroup];
			[self stopAutoscrolling];
			
			// set flag to reject drag and up events - cleared on new mouse down. This prevents an error condition from developing
			// if the initial mouse down is mishandled.
			
			mAbortiveMouseDown = YES;
		}
	}
	else
	{
		// tool not applicable to the active layer - defer to the view controller. Some layers (e.g. guides) will
		// always cause this to occur as they work the same way regardless of the current tool. So don't beep here.
		
		[super mouseDown:event];
	}
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
	if( mAbortiveMouseDown )
		return;
	
	DKDrawingTool*		ct = [self drawingTool];
	
	if( event != mDragEvent )
	{
		[mDragEvent release];
		mDragEvent = [event retain];
	}
	
	if([event clickCount] <= 1 )
	{
		NSAssert( ct != nil , @"nil drawing tool for mouse drag");
		
		NSPoint	p = [[self view] convertPoint:[event locationInWindow] fromView:nil];
		
		@try
		{
			if ([ct isValidTargetLayer:[self activeLayer]])
				[ct mouseDraggedToPoint:p partCode:mPartcode layer:[self activeLayer] event:event delegate:self];
			else
				[super mouseDragged:event];
		}
		@catch( NSException* excp )
		{
			NSLog(@"caught exception when dragging with tool - ignored (tool = %@, exception = %@)", ct, excp );
			
			[self closeUndoGroup];
			[self stopAutoscrolling];
		}
	}
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
	if( mAbortiveMouseDown )
		return;

	LogEvent_( kInfoEvent, @"tool controller mouse up");

	DKDrawingTool*		ct = [self drawingTool];
	NSPoint				p = [[self view] convertPoint:[event locationInWindow] fromView:nil];
	
	NSAssert( ct != nil , @"nil drawing tool for mouse up");

	if ([ct isValidTargetLayer:[self activeLayer]])
	{
		BOOL undo = NO;
		
		@try
		{
			undo = [ct mouseUpAtPoint:p partCode:mPartcode layer:[self activeLayer] event:event delegate:self];
		}
		@catch( NSException* excp )
		{
			NSLog(@"caught exception on mouse up with tool - ignored (tool = %@, exception = %@)", ct, excp );
			undo = NO;
		}
		
		BOOL isObjectLayer = [[self activeLayer] isKindOfClass:[DKObjectDrawingLayer class]];
		
		if( isObjectLayer && undo )
		{
			// if the tool did something undoable, get the undo action and commit it in the active layer. This also
			// commits the recorded selection to the undo stack if the layer treats selection changes as undoable.
			
			NSString* action = [ct actionName];
			[(DKObjectDrawingLayer*)[self activeLayer] commitSelectionUndoWithActionName:action];
		}
		// close the undo group if one was opened applying the tool
		
		[self closeUndoGroup];
		[self stopAutoscrolling];
	}
	else
		[super mouseUp:event];
	
	// after handling mouse up, we may wish to spring back to the selection tool. This first attempts to
	// select a registered tool with the name "Select" so if you have replaced it, that is the new default tool.
	// Otherwise it creates an instance of the standard selection tool and sets that.
	
	if([self automaticallyRevertsToSelectionTool] && ![ct isKindOfClass:[DKSelectAndEditTool class]])
	{
		DKDrawingTool* se;
		
		se = [DKDrawingTool drawingToolWithName:kDKStandardSelectionToolName];
		
		if( se == nil )
			se = [[[DKSelectAndEditTool alloc] init] autorelease];
			
		[self setDrawingTool:se];
	}
	
	[mDragEvent release];
	mDragEvent = nil;
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
/// notes:			passes the event to the current tool or active layer, depending on which, if any, can respond.
///
///********************************************************************************************************************

- (void)				mouseMoved:(NSEvent*) event
{
	if([[self drawingTool] respondsToSelector:@selector(mouseMoved:inView:)])
		[(id)[self drawingTool] mouseMoved:event inView:[self view]];
	else
	{
		if([[self activeLayer] respondsToSelector:@selector(mouseMoved:inView:)])
			[[self activeLayer] mouseMoved:event inView:[self view]];
	}
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
	
	if( tool )
	{
		[self setAutomaticallyRevertsToSelectionTool:NO];
		[self setDrawingTool:tool];
	}
	else
	{
		@try
		{
			[[self view] interpretKeyEvents:[NSArray arrayWithObject:event]];
		}
		@catch( NSException* excp )
		{
			NSLog(@"caught exception from keyDown handler (ignored), event = %@, exception = %@", event, excp );
			
			[self closeUndoGroup];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			forwardInvocation
/// scope:			public instance method
/// overrides:		NSObject
/// description:	forward an invocation to the active layer if it implements it
/// 
/// parameters:		<invocation> the invocation to forward
/// result:			none
///
/// notes:			DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
///					to the active layer, which may forward to selected objects within the layer. This allows objects
///					to respond to action methods and so forth at their own level.
///
///********************************************************************************************************************

- (void)				forwardInvocation:(NSInvocation*) invocation
{
    // commands can be implemented by the layer that wants to make use of them - this makes it happen by forwarding unrecognised
	// method calls to the active layer if possible.
	
	SEL aSelector = [invocation selector];
	
    if ([[self activeLayer] respondsToSelector:aSelector])
	{
		@try
		{
			[invocation invokeWithTarget:[self activeLayer]];
		}
		@catch( NSException* excp )
		{
			NSLog(@"caught exception from forwarded invocation (ignored), inv = %@, exception = %@", invocation, excp );
			[self closeUndoGroup];
		}
	}
    else
        [self doesNotRecognizeSelector:aSelector];
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
	[self openUndoGroup];
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


#pragma mark -
#pragma mark As part of NSMenuValidation protocol

///*********************************************************************************************************************
///
/// method:			validateMenuItem:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	enable and set menu item state for actions implemented by the controller
/// 
/// parameters:		<item> the menu item to validate
/// result:			YES or NO
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	if([item action] == @selector(toggleAutoRevertAction:))
	{
		[item setState:[self automaticallyRevertsToSelectionTool]? NSOffState : NSOnState];
		return YES;
	}
	
	if([item action] == @selector(selectDrawingToolByName:))
	{
		return [[DKToolRegistry sharedToolRegistry] drawingToolWithName:[item title]] != nil;
	}
	
	if([item action] == @selector(selectDrawingToolByRepresentedObject:))
		return [[item representedObject] isKindOfClass:[DKDrawingTool class]];
	
	return [super validateMenuItem:item];
}

@end
