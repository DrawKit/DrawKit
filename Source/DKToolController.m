/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKToolController.h"
#import "DKToolRegistry.h"
#import "DKSelectAndEditTool.h"
#import "DKObjectDrawingLayer.h"
#import "DKDrawableObject.h"
#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKUndoManager.h"
#import "LogEvent.h"

#pragma mark Contants(Non - localized)

NSString* kDKWillChangeToolNotification = @"kDKWillChangeToolNotification";
NSString* kDKDidChangeToolNotification = @"kDKDidChangeToolNotification";
NSString* kDKDidChangeToolAutoRevertStateNotification = @"kDKDidChangeToolAutoRevertStateNotification";

NSString* kDKDrawingToolAutoActivatesLayerDefaultsKey = @"DKDrawingToolAutoActivatesLayer";

@interface DKToolController ()

/** @brief Returns the drawing tool currently set for the given drawing

 This is used when the tool scope is per-document. In that case the tool is associated with the
 drawing, not the individual view.
 @param drawingKey a key for the drawing object
 @return the current tool set for the drawing
 */
+ (DKDrawingTool*)drawingToolForDrawing:(NSString*)drawingKey;

/** @brief Sets the drawing tool for the given drawing

 This is used when the tool scope is per-document. In that case the tool is associated with the
 document, not the individual view.
 @param tool the tool to set
 @param drawingKey a key for the drawing object
 */
+ (void)setDrawingTool:(DKDrawingTool*)tool forDrawing:(NSString*)drawingKey;

/** @brief Get the tool for the entire application

 This is used when the tool scope is per-application.
 @return the current tool set for the app
 */
+ (DKDrawingTool*)globalDrawingTool;

/** @brief Get the tool for the entire application

 This is used when the tool scope is per-application.
 @param tool the tool to set
 */
+ (void)setGlobalDrawingTool:(DKDrawingTool*)tool;

@property (class, retain) DKDrawingTool *globalDrawingTool;

/** @brief Search for a layer usable with a given tool.

 This is used when tools are set to auto-activate layers and the current active layer can't be
 used. It returns an alternative layer that can be activated for use with the tool. Called by
 -setDrawingTool:
 @param tool the tool in question
 @return a usable layer, or nil
 */
- (DKLayer*)findEligibleLayerForTool:(DKDrawingTool*)tool;

@end

#pragma mark -

#pragma mark Static Vars

static DKDrawingToolScope sDrawingToolScope = kDKToolScopeLocalToDocument;
static NSMutableDictionary* sDrawingToolDict = nil;
static DKDrawingTool* sGlobalTool = nil;

#define DK_ENABLE_UNDO_GROUPING 1
#define DK_ALWAYS_OPEN_UNDO_GROUP 1

@implementation DKToolController

#pragma mark - private class methods

+ (DKDrawingTool*)drawingToolForDrawing:(NSString*)drawingKey
{
	NSAssert(drawingKey != nil, @"drawing was nil trying to get per-document tool");

	if (sDrawingToolDict == nil)
		return nil;
	else
		return [sDrawingToolDict objectForKey:drawingKey];
}

+ (void)setDrawingTool:(DKDrawingTool*)tool forDrawing:(NSString*)drawingKey
{
	NSAssert(drawingKey != nil, @"attempt to set tool per drawing, but drawing key is nil");

	if (sDrawingToolDict == nil)
		sDrawingToolDict = [[NSMutableDictionary alloc] init];

	[sDrawingToolDict setObject:tool
						 forKey:drawingKey];
}

+ (DKDrawingTool*)globalDrawingTool
{
	return sGlobalTool;
}

+ (void)setGlobalDrawingTool:(DKDrawingTool*)tool
{
	sGlobalTool = tool;
}

#pragma mark -
#pragma mark - As a DKToolController

/** @brief Set the operating scope for tools for this application

 DK allows tools to be set per-view, per-document, or per-application. This is called the operating
 scope. Generally your app should decide what is appropriate, set it at start up and stick to it.
 It is not expected that this will be called during the subsequent use of the app - though it is
 harmless to do so it's very likely to confuse the user.
 @param scope the operating scope for tools
 */
+ (void)setDrawingToolOperatingScope:(DKDrawingToolScope)scope
{
	sDrawingToolScope = scope;
}

/** @brief Return the operating scope for tools for this application

 DK allows tools to be set per-view, per-document, or per-application. This is called the operating
 scope. Generally your app should decide what is appropriate, set it at start up and stick to it.
 The default is per-document scope.
 @return the operating scope for tools
 */
+ (DKDrawingToolScope)drawingToolOperatingScope
{
	return sDrawingToolScope;
}

/** @brief Set whether setting a tool will auto-activate a layer appropriate to the tool

 Default is NO. If YES, when a tool is set but the active layer is not valid for the tool, the
 layers are searched top down until one is found that the tool validates, which is then made
 active. Layers which are locked, hidden or refuse active status are skipped. Persistent.
 @param autoActivate YES to autoactivate, NO otherwise
 */
+ (void)setToolsAutoActivateValidLayer:(BOOL)autoActivate
{
	[[NSUserDefaults standardUserDefaults] setBool:autoActivate
											forKey:kDKDrawingToolAutoActivatesLayerDefaultsKey];
}

/** @brief Return whether setting a tool will auto-activate a layer appropriate to the tool

 Default is NO. If YES, when a tool is set but the active layer is not valid for the tool, the
 layers are searched top down until one is found that the tool validates, which is then made
 active. Layers which are locked, hidden or refuse active status are skipped. Persistent.
 @return YES if tools auto-activate appropriate layer, NO if not
 */
+ (BOOL)toolsAutoActivateValidLayer
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingToolAutoActivatesLayerDefaultsKey];
}

#pragma mark -

/** @brief Sets the current drawing tool

 The tool is set locally, for the drawing or globally according to the current scope.
 @param aTool the tool to set
 */
- (void)setDrawingTool:(DKDrawingTool*)aTool
{
	NSAssert(aTool != nil, @"attempt to set a nil tool");

	if (aTool != [self drawingTool]) {
		DKDrawingTool* oldTool = [self drawingTool];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKWillChangeToolNotification
															object:self];
		[oldTool toolControllerWillUnsetTool:self];

		switch ([[self class] drawingToolOperatingScope]) {
		case kDKToolScopeLocalToView:
			mTool = aTool;
			break;

		default:
		case kDKToolScopeLocalToDocument:
			[[self class] setDrawingTool:aTool
							  forDrawing:[[self drawing] uniqueKey]];
			break;

		case kDKToolScopeGlobal:
			[[self class] setGlobalDrawingTool:aTool];
			break;
		}

		[self invalidateCursors];
		[oldTool toolControllerDidUnsetTool:self];
		[aTool toolControllerDidSetTool:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDidChangeToolNotification
															object:self];

		// check if the current layer is usable with the tool and the class enables auto-activation. If it does,
		// find an alternative layer and make it active

		if ([[self class] toolsAutoActivateValidLayer]) {
			if (![aTool isValidTargetLayer:[self activeLayer]]) {
				DKLayer* alternative = [self findEligibleLayerForTool:aTool];

				if (alternative)
					[[self drawing] setActiveLayer:alternative];
			}
		}
	}
}

/** @brief Select the tool using its registered name

 Tools must be registered in the DKDrawingTool registry with the given name before you can use this
 method to set them, otherwise an exception is thrown.
 @param name the registered name of the required tool
 */
- (void)setDrawingToolWithName:(NSString*)name
{
	if (name != nil && [name length] > 0) {
		DKDrawingTool* tool = [[DKToolRegistry sharedToolRegistry] drawingToolWithName:name];

		LogEvent_(kStateEvent, @"tool controller selecting tool with name '%@', tool = %@", name, tool);

		if (tool != nil)
			[self setDrawingTool:tool];
		else
			[NSException raise:NSInternalInconsistencyException
						format:@"tool name '%@' could not be found", name];
	}
}

/** @brief Return the current drawing tool

 The tool is set locally, for the drawing or globally according to the current scope.
 @return the current tool
 */
- (DKDrawingTool*)drawingTool
{
	switch ([[self class] drawingToolOperatingScope]) {
	case kDKToolScopeLocalToView:
		return mTool;

	default:
	case kDKToolScopeLocalToDocument:
		return [[self class] drawingToolForDrawing:[[self drawing] uniqueKey]];

	case kDKToolScopeGlobal:
		return [[self class] globalDrawingTool];
	}
}

@synthesize drawingTool=mTool;

/** @brief Check if the tool can be set for the current active layer

 Can be used to test whether a tool is able to be selected in the current context. There is no
 requirement to use this - you can set the drawing tool anyway and if an attempt to use it in
 an invalid layer is made, the tool controller will handle it anyway. A UI might want to use this
 to prevent the selection of a tool before it gets to that point however.
 @param aTool the propsed drawing tool
 @return YES if the tool can be applied to the current active layer, NO if not
 */
- (BOOL)canSetDrawingTool:(DKDrawingTool*)aTool
{
	NSAssert(aTool != nil, @"tool is nil in -canSetDrawingTool:");

	return [aTool isValidTargetLayer:[self activeLayer]];
}

/** @brief Set whether the tool should automatically "spring back" to the selection tool after each application

 The default is YES
 @param reverts YES to spring back, NO to leave the present tool active after each use
 */
- (void)setAutomaticallyRevertsToSelectionTool:(BOOL)reverts
{
	if (reverts != mAutoRevert) {
		mAutoRevert = reverts;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDidChangeToolAutoRevertStateNotification
															object:self];

		LogEvent_(kInfoEvent, @"tool controller setting sticky tools = %d", !mAutoRevert);
	}
}

@synthesize automaticallyRevertsToSelectionTool=mAutoRevert;

/** @brief Draw any tool graphic content into the view
 @param rect the update rect in the view
 */
- (void)drawRect:(NSRect)rect
{
	DKDrawingTool* ct = [self drawingTool];
	NSAssert(ct != nil, @"nil drawing tool for drawRect:");

	if ([ct respondsToSelector:@selector(drawRect:
										   inView:)])
		[ct drawRect:rect
			  inView:[self view]];
}

/** @brief Select the tool using its registered name based on the title of a UI control, etc.

 This is a convenience for hooking up a UI for picking a tool. You can set the title of a button to
 be the tool's name and target first responder using this action, and it will select the tool if it
 has been registered using the name. This makes UI such as a palette of tools trivial to implement,
 but doesn't preclude you from using any other UI as you see fit.
 @param sender the sender of the action - it should implement -title (e.g. a button, menu item)
 */
- (IBAction)selectDrawingToolByName:(id)sender
{
	NSString* toolName = [sender title];
	[self setDrawingToolWithName:toolName];
}

/** @brief Select the tool using the represented object of a UI control, etc.

 This is a convenience for hooking up a UI for picking a tool. You can set the rep. object of a button to
 be the tool and target first responder using this action, and it will set the tool to the button's
 represented object.
 @param sender the sender of the action - it should implement -representedObject (e.g. a button, menu item)
 */
- (IBAction)selectDrawingToolByRepresentedObject:(id)sender
{
	if (sender != nil && [sender respondsToSelector:@selector(representedObject)]) {
		DKDrawingTool* tool = [sender representedObject];

		if (tool != nil && [tool isKindOfClass:[DKDrawingTool class]]) {
			LogEvent_(kStateEvent, @"tool controller selecting tool (represented object) = %@", tool);

			[self setDrawingTool:tool];
		} else
			[NSException raise:NSInternalInconsistencyException
						format:@"represented object of sender %@ was not a valid DKDrawingTool", [sender description]];
	}
}

/** @brief Toggle the state of the automatic tool "spring" behaviour.

 Flips the state of the auto-revert flag. A UI can make use of this to control the flag in order to
 make a tool "sticky". Often this is done by double-clicking the tool button.
 @param sender the sender of the action
 */
- (IBAction)toggleAutoRevertAction:(id)sender
{
#pragma unused(sender)

	[self setAutomaticallyRevertsToSelectionTool:![self automaticallyRevertsToSelectionTool]];
}

/** @brief Return the undo manager
 @return the drawing's undo manager
 */
- (id)undoManager
{
	return (id)[[self drawing] undoManager];
}

/** @brief Opens a new undo manager group if one has not already been opened
 */
- (void)openUndoGroup
{
#if DK_ENABLE_UNDO_GROUPING
	if (!mOpenedUndoGroup) {
		LogEvent_(kReactiveEvent, @"tool controller will open undo group");

		[[self undoManager] beginUndoGrouping];
		mOpenedUndoGroup = YES;
	}
#endif
}

/** @brief Closes the current undo manager group if one has been opened

 When the controller is set up to always open a group, this also deals with the bogus task bug in
 NSUndoManager, where opening and closig a group creates an empty undo task. If that case is detected,
 the erroneous task is removed from the stack by invoking undo while temporarily disabling the UM.
 */
- (void)closeUndoGroup
{
#if DK_ENABLE_UNDO_GROUPING
	if (mOpenedUndoGroup) {
		LogEvent_(kReactiveEvent, @"tool controller will close undo group");

		[[self undoManager] endUndoGrouping];
		mOpenedUndoGroup = NO;

#if DK_ALWAYS_OPEN_UNDO_GROUP

		// clean up empty undo task if nothing was actually done (NSUndoManager bug workaround)
		/*
		NSInteger    groupLevel = [[self undoManager] groupingLevel];
		NSUInteger    taskCount = [[self undoManager] numberOfTasksInLastGroup];
		
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

- (DKLayer*)findEligibleLayerForTool:(DKDrawingTool*)tool
{
	NSAssert(tool != nil, @"tool passed to findEligibleLayer was nil");

	for (DKLayer* layer in [[self drawing] flattenedLayers]) {
		if (![layer lockedOrHidden] && [layer layerMayBecomeActive] && [tool isValidTargetLayer:layer])
			return layer;
	}

	return nil;
}

#pragma mark -
#pragma mark - As a DKViewController

/** @brief Initialize the controller.

 Does not set an initial tool because the objects needed for the document scope are not available.
 The initial tool is set when the controller is added to a drawing (see setDrawing:)
 @param aView the view associated with the controller
 @return the controller object
 */
- (instancetype)initWithView:(NSView*)aView
{
	self = [super initWithView:aView];
	if (self != nil) {
		[self setAutomaticallyRevertsToSelectionTool:NO];
	}

	LogEvent_(kInfoEvent, @"created tool controller, current scope = %ld", (long)[[self class] drawingToolOperatingScope]);

	return self;
}

/** @brief The controller is being added to a drawing

 If no tool is set, set it initially to the select & edit tool. Note that this method is invoked as
 necessary when a controller is added to a drawing - you should not call it directly nor at any time
 while a controller is owned by the drawing.
 @param aDrawing the drawing to which the tool is being added
 */
- (void)setDrawing:(DKDrawing*)aDrawing
{
	[super setDrawing:aDrawing];

	// set the default tool if there isn't yet one set. This is done at this point so that if the scope is per-document,
	// the drawing is valid. This also works as it should for both local and global scope.

	if (aDrawing != nil && [self drawingTool] == nil) {
		DKDrawingTool* se;

		se = [[DKToolRegistry sharedToolRegistry] drawingToolWithName:kDKStandardSelectionToolName];

		if (se == nil)
			se = [[DKSelectAndEditTool alloc] init];

		[self setDrawingTool:se];
	}
}

/** @brief Handle the mouse down event

 Calls the mouse down method of the current tool, if the layer is an object layer. Calls super to
 ensure that autscrolling and targeting of other layer types works normally.
 @param event the event
 */
- (void)mouseDown:(NSEvent*)event
{
	LogEvent_(kInfoEvent, @"tool controller mouse down");

	mOpenedUndoGroup = NO;
	mAbortiveMouseDown = NO;

	DKDrawableObject* target = nil;
	DKDrawingTool* ct = [self drawingTool];
	NSPoint p = [[self view] convertPoint:[event locationInWindow]
								 fromView:nil];

	NSAssert(ct != nil, @"nil drawing tool for mouse down");

	// should the layer be auto-activated? Only do this if the tool is some kind of selection tool, because
	// otherwise drawing a shape on top of another in another layer can cause the layer to switch unexpectedly.

	if ([ct isSelectionTool])
		[self autoActivateLayerWithEvent:event];

	// can the tool be used in this layer anyway?

	if ([ct isValidTargetLayer:[self activeLayer]]) {
		[self startAutoscrolling];

		BOOL isObjectLayer = [[self activeLayer] isKindOfClass:[DKObjectDrawingLayer class]];

		if (isObjectLayer) {
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
			mPartcode = [ct mouseDownAtPoint:p
								targetObject:target
									   layer:[self activeLayer]
									   event:event
									delegate:self];
		}
		@catch (NSException* excp)
		{
			NSLog(@"caught exception on mouse down with tool - ignored (tool = %@, exception = %@)", ct, excp);

			[self closeUndoGroup];
			[self stopAutoscrolling];

			// set flag to reject drag and up events - cleared on new mouse down. This prevents an error condition from developing
			// if the initial mouse down is mishandled.

			mAbortiveMouseDown = YES;
		}
	} else {
		// tool not applicable to the active layer - defer to the view controller. Some layers (e.g. guides) will
		// always cause this to occur as they work the same way regardless of the current tool. So don't beep here.

		[super mouseDown:event];
	}
}

/** @brief Handle the mouse dragged event

 Calls the mouse dragged method of the current tool, if the layer is an object layer. Calls super to
 ensure that other layer types work normally.
 @param event the event
 */
- (void)mouseDragged:(NSEvent*)event
{
	if (mAbortiveMouseDown)
		return;

	DKDrawingTool* ct = [self drawingTool];

	if (event != mDragEvent) {
		mDragEvent = event;
	}

	if ([event clickCount] <= 1) {
		NSAssert(ct != nil, @"nil drawing tool for mouse drag");

		NSPoint p = [[self view] convertPoint:[event locationInWindow]
									 fromView:nil];

		@try
		{
			if ([ct isValidTargetLayer:[self activeLayer]])
				[ct mouseDraggedToPoint:p
							   partCode:mPartcode
								  layer:[self activeLayer]
								  event:event
							   delegate:self];
			else
				[super mouseDragged:event];
		}
		@catch (NSException* excp)
		{
			NSLog(@"caught exception when dragging with tool - ignored (tool = %@, exception = %@)", ct, excp);

			[self closeUndoGroup];
			[self stopAutoscrolling];
		}
	}
}

/** @brief Handle the mouse up event

 Calls the mouse up method of the current tool, if the layer is an object layer. Calls super to
 ensure that other layer types work normally.
 @param event the event
 */
- (void)mouseUp:(NSEvent*)event
{
	if (mAbortiveMouseDown)
		return;

	LogEvent_(kInfoEvent, @"tool controller mouse up");

	DKDrawingTool* ct = [self drawingTool];
	NSPoint p = [[self view] convertPoint:[event locationInWindow]
								 fromView:nil];

	NSAssert(ct != nil, @"nil drawing tool for mouse up");

	if ([ct isValidTargetLayer:[self activeLayer]]) {
		BOOL undo = NO;

		@try
		{
			undo = [ct mouseUpAtPoint:p
							 partCode:mPartcode
								layer:[self activeLayer]
								event:event
							 delegate:self];
		}
		@catch (NSException* excp)
		{
			NSLog(@"caught exception on mouse up with tool - ignored (tool = %@, exception = %@)", ct, excp);
			undo = NO;
		}

		BOOL isObjectLayer = [[self activeLayer] isKindOfClass:[DKObjectDrawingLayer class]];

		if (isObjectLayer && undo) {
			// if the tool did something undoable, get the undo action and commit it in the active layer. This also
			// commits the recorded selection to the undo stack if the layer treats selection changes as undoable.

			NSString* action = [ct actionName];
			[(DKObjectDrawingLayer*)[self activeLayer] commitSelectionUndoWithActionName:action];
		}
		// close the undo group if one was opened applying the tool

		[self closeUndoGroup];
		[self stopAutoscrolling];
	} else
		[super mouseUp:event];

	// after handling mouse up, we may wish to spring back to the selection tool. This first attempts to
	// select a registered tool with the name "Select" so if you have replaced it, that is the new default tool.
	// Otherwise it creates an instance of the standard selection tool and sets that.

	if ([self automaticallyRevertsToSelectionTool] && ![ct isKindOfClass:[DKSelectAndEditTool class]]) {
		DKDrawingTool* se;

		se = [[DKToolRegistry sharedToolRegistry] drawingToolWithName:kDKStandardSelectionToolName];

		if (se == nil)
			se = [[DKSelectAndEditTool alloc] init];

		[self setDrawingTool:se];
	}

	mDragEvent = nil;
}

/** @brief Handle the flags changed up event

 Passes the event to the current tool
 @param event the event
 */
- (void)flagsChanged:(NSEvent*)event
{
	if ([self drawingTool] != nil && [[self drawingTool] isValidTargetLayer:[self activeLayer]])
		[[self drawingTool] flagsChanged:event
								 inLayer:[self activeLayer]];
	else
		[super flagsChanged:event];
}

/** @brief Handle the mouse moved event

 Passes the event to the current tool or active layer, depending on which, if any, can respond.
 @param event the event
 */
- (void)mouseMoved:(NSEvent*)event
{
	if ([[self drawingTool] respondsToSelector:@selector(mouseMoved:
															 inView:)])
		[(id)[self drawingTool] mouseMoved:event
									inView:[self view]];
	else {
		if ([[self activeLayer] respondsToSelector:@selector(mouseMoved:
																 inView:)])
			[[self activeLayer] mouseMoved:event
									inView:[self view]];
	}
}

/** @brief Returns the current tool's cursor
 @return a cursor
 */
- (NSCursor*)cursor
{
	if ([self drawingTool] != nil && [[self drawingTool] isValidTargetLayer:[self activeLayer]])
		return [[self drawingTool] cursor];
	else
		return [super cursor];
}

#pragma mark -
#pragma mark - As an NSResponder

/** @brief Responds to a keyDown event by selecting a tool having a matching key equivalent, if any

 If a tool exists that matches the key equivalent, select it. Otherwise just pass the event
 to the layer.
 @param event the key down event
 */
- (void)keyDown:(NSEvent*)event
{
	DKDrawingTool* tool = [[DKToolRegistry sharedToolRegistry] drawingToolWithKeyboardEquivalent:event];

	if (tool) {
		[self setAutomaticallyRevertsToSelectionTool:NO];
		[self setDrawingTool:tool];
	} else {
		@try
		{
			[[self view] interpretKeyEvents:@[event]];
		}
		@catch (NSException* excp)
		{
			NSLog(@"caught exception from keyDown handler (ignored), event = %@, exception = %@", event, excp);

			[self closeUndoGroup];
		}
	}
}

/** @brief Forward an invocation to the active layer if it implements it

 DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
 to the active layer, which may forward to selected objects within the layer. This allows objects
 to respond to action methods and so forth at their own level.
 @param invocation the invocation to forward
 */
- (void)forwardInvocation:(NSInvocation*)invocation
{
	// commands can be implemented by the layer that wants to make use of them - this makes it happen by forwarding unrecognised
	// method calls to the active layer if possible.

	SEL aSelector = [invocation selector];

	if ([[self activeLayer] respondsToSelector:aSelector]) {
		@try
		{
			[invocation invokeWithTarget:[self activeLayer]];
		}
		@catch (NSException* excp)
		{
			NSLog(@"caught exception from forwarded invocation (ignored), inv = %@, exception = %@", invocation, excp);
			[self closeUndoGroup];
		}
	} else
		[self doesNotRecognizeSelector:aSelector];
}

#pragma mark -
#pragma mark - As part of the NSObject(DKToolDelegate) protocol

/** @brief Opens an undo group to receive subsequent undo tasks

 This is needed to work around an NSUndoManager bug where empty groups create a bogus task on the stack.
 A group is only opened when a real task is coming. This isn't really very elegant right now - a
 better solution is sought, perhaps subclassing NSUndoManager itself.
 @param aTool the tool making the request */
- (void)toolWillPerformUndoableAction:(DKDrawingTool*)aTool
{
#pragma unused(aTool)
	[self openUndoGroup];
}

#pragma mark -
#pragma mark - As an NSObject

#pragma mark -
#pragma mark As part of NSMenuValidation protocol

/** @brief Enable and set menu item state for actions implemented by the controller
 @param item the menu item to validate
 @return YES or NO
 */
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	if ([item action] == @selector(toggleAutoRevertAction:)) {
		[item setState:[self automaticallyRevertsToSelectionTool] ? NSOffState : NSOnState];
		return YES;
	}

	if ([item action] == @selector(selectDrawingToolByName:)) {
		return [[DKToolRegistry sharedToolRegistry] drawingToolWithName:[item title]] != nil;
	}

	if ([item action] == @selector(selectDrawingToolByRepresentedObject:))
		return [[item representedObject] isKindOfClass:[DKDrawingTool class]];

	return [super validateMenuItem:item];
}

@end
