/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKObjectCreationTool.h"
#import "DKLayer.h"
#import "DKDrawablePath.h"
#import "DKReshapableShape.h"
#import "DKPathInsertDeleteTool.h"
#import "DKShapeFactory.h"
#import "DKTextShape.h"
#import "DKZoomTool.h"
#import "DKSelectAndEditTool.h"
#import "DKToolController.h"
#import "LogEvent.h"
#import "DKCropTool.h"
#import "DKArcPath.h"
#import "DKStyle.h"
#import "DKRegularPolygonPath.h"
#import "DKTextPath.h"
#import "LogEvent.h"
#import "DKToolRegistry.h"

#pragma mark constants

NSString*		kDKDrawingToolUserDefaultsKey			= @"DK_DrawingTool_Defaults";

#pragma mark -
@implementation DKDrawingTool
#pragma mark As a DKDrawingTool

/** @brief Return the shared instance of the tool registry
 * @note
 * Creates a new empty registry if it doesn't yet exist
 * @return a dictionary - contains drawing tool objects keyed by name
 * @public
 */
+ (NSDictionary*)		sharedToolRegistry
{
	NSLog(@"+[DKDrawingTool sharedToolRegistry] is deprecated and is a no-op");
	
	return nil;
}

/** @brief Retrieve a tool from the registry with the given name
 * @note
 * Registered tools may be conveniently set by name - see DKToolController
 * @param name the registry name of the tool required.
 * @return the tool if it exists, or nil
 * @public
 */
+ (DKDrawingTool*)		drawingToolWithName:(NSString*) name
{
	return [[DKToolRegistry sharedToolRegistry] drawingToolWithName:name];
}

/** @brief Retrieve a tool from the registry matching the key equivalent indicated by the key event passed
 * @note
 * See DKToolController
 * @param keyEvent a keyDown event.
 * @return the tool if it can be matched, or nil
 * @public
 */
+ (DKDrawingTool*)		drawingToolWithKeyboardEquivalent:(NSEvent*) keyEvent
{
	return [[DKToolRegistry sharedToolRegistry] drawingToolWithKeyboardEquivalent:keyEvent];
}

/** @brief Register a tool in th eregistry with the given name
 * @note
 * Registered tools may be conveniently set by name - see DKToolController
 * @param tool a tool object to register
 * @param name a name to register it against.
 * @public
 */
+ (void)				registerDrawingTool:(DKDrawingTool*) tool withName:(NSString*) name
{
	[[DKToolRegistry sharedToolRegistry] registerDrawingTool:tool withName:name];
}

/** @brief Set a "standard" set of tools in the registry
 * @note
 * "Standard" tools are creation tools for various basic shapes, the selection tool, zoom tool and
 * launch time, may be safely called more than once - subsequent calls are no-ops.
 * If the conversion table has been set up prior to this, the tools will automatically pick up
 * the class from the table, so that apps don't need to swap out all the tools for subclasses, but
 * can simply set up the table.
 * @public
 */
+ (void)				registerStandardTools
{
	// no longer needs to do anything - the shared tool registry registers standard tools by default the first time it is
	// referenced.
}

/** @brief Return a list of registered tools' names, sorted alphabetically
 * @note
 * May be useful for supporting a UI
 * @return an array, a list of NSStrings
 * @public
 */
+ (NSArray*)			toolNames
{
	return [[DKToolRegistry sharedToolRegistry] toolNames];
}

/** @brief Load tool defaults from the user defaults
 * @note
 * If used, this sets up the state of the tools and the styles they are set to to whatever was saved
 * by the saveDefaults method in an earlier session. Someone (such as the app delegate) needs to call this
 * on app launch after the tools have all been set up and registered.
 * @public
 */
+ (void)				loadDefaults
{
	LogEvent_( kInfoEvent, @"restoring tools persistent data");
	
	NSDictionary* toolInfo = [[NSUserDefaults standardUserDefaults] objectForKey:kDKDrawingToolUserDefaultsKey];
	
	if( toolInfo )
	{
		NSEnumerator*	iter = [toolInfo keyEnumerator];
		NSString*		key;
		
		while(( key = [iter nextObject]))
		{
			NSData* data = [toolInfo objectForKey:key];
			
			if( data )
			{
				DKDrawingTool* tool = [self drawingToolWithName:key];
				[tool shouldLoadPersistentData:data];
			}
		}
	}
}

/** @brief Save tool defaults to the user defaults
 * @note
 * Saves the persistent data, if any, of each registered tool. The main use for this is to
 * restore the styles associated with each tool when the app is next launched.
 * @public
 */
+ (void)				saveDefaults
{
	NSMutableDictionary*	toolInfo = [NSMutableDictionary dictionary];
	NSEnumerator*			iter = [[self toolNames] objectEnumerator];
	NSString*				key;
	
	while(( key = [iter nextObject]))
	{
		DKDrawingTool* tool = [self drawingToolWithName:key];
		NSData* pd = [tool persistentData];
		
		if( pd )
			[toolInfo setObject:pd forKey:key];
	}
	
	if([toolInfo count] > 0 )
		[[NSUserDefaults standardUserDefaults] setObject:toolInfo forKey:kDKDrawingToolUserDefaultsKey];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kDKDrawingToolUserDefaultsKey];
}

/** @brief Return the first responder in the current responder chain able to respond to -setDrawingTool:
 * @note
 * This searches upwards from the current first responder. If that fails, it also checks the
 * current document. Used by -set and other code that needs to know whether -set will succeed.
 * @return a responder, or nil
 * @public
 */
+ (id)			firstResponderAbleToSetTool
{
	NSResponder* firstResponder = [[NSApp mainWindow] firstResponder];
	
	// follow responder chain until we find one that can respond, or we hit the end of the chain
	
	while( firstResponder && ![firstResponder respondsToSelector:@selector(setDrawingTool:)])
		firstResponder = [firstResponder nextResponder];
	
	if( firstResponder )
		return firstResponder;
	else
	{
		// before giving up, check if the active document implements -setDrawingTool: - subclasses of DKDrawingDocument do
		
		NSDocument* curDoc = [[NSDocumentController sharedDocumentController] currentDocument];
		
		if([curDoc respondsToSelector:@selector(setDrawingTool:)])
			return curDoc;
	}
	
	return nil;
}

/** @brief Does the tool ever implement undoable actions?
 * @note
 * Classes must override this and say YES if the tool does indeed perform an undoable action
 * (i.e. it does something to an object)
 * @return NO
 * @public
 */
+ (BOOL)				toolPerformsUndoableAction
{
	return NO;
}

#pragma mark -

/** @brief Return the registry name for this tool
 * @note
 * If the tool isn't registered, returns nil
 * @return a string, the name this tool is registerd under, if any:
 * @public
 */
- (NSString*)			registeredName
{
	NSArray* keys = [[DKToolRegistry sharedToolRegistry] allKeysForTool:self];
		
	if ([keys count] > 0 )
		return [keys lastObject];

	return nil;
}

/** @brief Sets the tool as the current tool for the key view in the main window, if possible
 * @note
 * This follows the -set approach that cocoa uses for many objects. It looks for the key view in the
 * main window. If it's a DKDrawingView that has a tool controller, it sets itself as the controller's
 * current tool. This might be more convenient than other ways of setting a tool.
 * @public
 */
- (void)				set
{
	LogEvent_( kReactiveEvent, @"drawing tool %@ received the 'set' message - will attempt to set this tool", [self description]);
	
	id fr = [[self class] firstResponderAbleToSetTool];
	
	if( fr )
		[fr setDrawingTool:self];
	else
		[NSException raise:NSDestinationInvalidException format:@"The tool could not be set because first responder doesn't respond to -setDrawingTool:"];
}

/** @brief Called when this tool is set by a tool controller
 * @note
 * Subclasses can make use of this message to prepare themselves when they are set if necessary
 * @param aController the controller that set this tool
 * @public
 */
- (void)				toolControllerDidSetTool:(DKToolController*) aController
{
	#pragma unused(aController)
	
	// override to make use of this notification
	
	LogEvent_( kReactiveEvent, @"tool set: %@ by controller: %@", self, aController );
}

/** @brief Called when this tool is about to be unset by a tool controller
 * @note
 * Subclasses can make use of this message to prepare themselves when they are unset if necessary, for
 * example by finishing the work they were doing and cleaning up.
 * @param aController the controller that set this tool
 * @public
 */
- (void)				toolControllerWillUnsetTool:(DKToolController*) aController
{
#pragma unused(aController)
	
	// override to make use of this notification
}

/** @brief Called when this tool is unset by a tool controller
 * @note
 * Subclasses can make use of this message to prepare themselves when they are unset if necessary
 * @param aController the controller that set this tool
 * @public
 */
- (void)				toolControllerDidUnsetTool:(DKToolController*) aController
{
#pragma unused(aController)
	
	// override to make use of this notification
	
	LogEvent_( kReactiveEvent, @"tool unset: %@ by controller: %@", self, aController );
}

#pragma mark -
#pragma mark - As part of DKDrawingTool Protocol

/** @brief Returns the undo action name for the tool
 * @note
 * Override to return something useful
 * @return a string
 * @public
 */
- (NSString*)		actionName
{
	return nil;
}

/** @brief Return the tool's cursor
 * @note
 * Override to return a cursor appropriate to the tool
 * @return the arrow cursor
 * @public
 */
- (NSCursor*)		cursor
{
	return [NSCursor arrowCursor];
}

/** @brief Handle the initial mouse down
 * @note
 * Override to do something useful
 * @param p the local point where the mouse went down
 * @param obj the target object, if there is one
 * @param layer the layer in which the tool is being applied
 * @param event the original event
 * @param aDel an optional delegate
 * @return the partcode of the target that was hit, or 0 (no object)
 * @public
 */
- (NSInteger)				mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(p)
	#pragma unused(obj)
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)

	return kDKDrawingNoPart;
}

/** @brief Handle the mouse dragged event
 * @note
 * Override to do something useful
 * @param p the local point where the mouse has been dragged to
 * @param partCode the partcode returned by the mouseDown method
 * @param layer the layer in which the tool is being applied
 * @param event the original event
 * @param aDel an optional delegate
 * @public
 */
- (void)			mouseDraggedToPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(p)
	#pragma unused(pc)
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)
}

/** @brief Handle the mouse up event
 * @note
 * Override to do something useful
 * tools usually return YES, tools that operate the user interface such as a zoom tool typically return NO
 * @param p the local point where the mouse went up
 * @param partCode the partcode returned by the mouseDown method
 * @param layer the layer in which the tool is being applied
 * @param event the original event
 * @param aDel an optional delegate
 * @return YES if the tool did something undoable, NO otherwise
 * @public
 */
- (BOOL)			mouseUpAtPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(p)
	#pragma unused(pc)
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)
	
	return NO;
}

/** @brief Handle the initial mouse down
 * @note
 * Override this to get the call from DKObjectDrawingToolLayer after all other drawing has completed
 * @param aRect the rect being redrawn (not used)
 * @param aView the view that is doing the drawing
 * @public
 */
- (void)			drawRect:(NSRect) aRect inView:(NSView*) aView
{
	#pragma unused(aRect)
	#pragma unused(aView)
}

/** @brief The state of the modifier keys changed
 * @note
 * Override this to get notified when the modifier keys change state while your tool is set
 * @param event the event
 * @param layer the current layer that the tool is being applied to
 * @public
 */
- (void)			flagsChanged:(NSEvent*) event inLayer:(DKLayer*) layer
{
	#pragma unused(event)
	#pragma unused(layer)
}

/** @brief Return whether the target layer can be used by this tool
 * @note
 * This is called by the tool controller to determine if the set tool can actually be used in the
 * current layer. Override to reject any layers that can't be used with the tool. The default is to
 * reject all locked or hidden layers, though some tools may still be operable in such a case.
 * @param aLayer a layer object
 * @return YES if the tool can be used with the given layer, NO otherwise
 * @public
 */
- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	return ![aLayer lockedOrHidden];
}

/** @brief Return whether the tool is some sort of object selection tool
 * @note
 * This method is used to assist the tool controller in making sensible decisions about certain
 * automatic operations. Subclasses that implement a selection tool should override this to return YES.
 * @return YES if the tool selects objects, NO otherwise
 * @public
 */
- (BOOL)				isSelectionTool
{
	return NO;
}

/** @brief Set a cursor if the given point is over something interesting
 * @note
 * Called by the tool controller when the mouse moves, this should determine whether a special cursor
 * needs to be set right now and set it. If no special cursor needs to be set, it should set the
 * current one for the tool. Override to implement this in specific tool classes.
 * @param mp the local mouse point
 * @param obj the target object under the mouse, if any
 * @param alayer the active layer
 * @param event the original event
 * @public
 */
- (void)			setCursorForPoint:(NSPoint) mp targetObject:(DKDrawableObject*) obj inLayer:(DKLayer*) aLayer event:(NSEvent*) event
{
	#pragma unused(mp)
	#pragma unused(obj)
	#pragma unused(aLayer)
	#pragma unused(event)
	
	[[self cursor] set];
}

#pragma mark -

/** @brief Sets the keyboard equivalent that can be used to select this tool
 * @note
 * A *registered* tool can be looked up by keyboard equivalent. This is implemented by DKToolController
 * in conjunction with this class.
 * @param str the key character (only the first character in the string is used)
 * @param flags any additional modifier flags - can be 0
 * @public
 */
- (void)			setKeyboardEquivalent:(NSString*) str modifierFlags:(NSUInteger) flags
{
	NSAssert( str != nil, @"attempt to set keyboard equivalent to nil string - string can be empty but not nil");
	
	[str retain];
	[mKeyboardEquivalent release];
	mKeyboardEquivalent = str;
	
	mKeyboardModifiers = flags;
}

/** @brief Return the keyboard equivalent character can be used to select this tool
 * @note
 * A *registered* tool can be looked up by keyboard equivalent. This is implemented by DKToolController
 * in conjunction with this class. Returns nil if no equivalent has been set.
 * @return the key character (only the first character in the string is used)
 * @public
 */
- (NSString*)		keyboardEquivalent
{
	if ([mKeyboardEquivalent length] > 0)
		return [mKeyboardEquivalent substringWithRange:NSMakeRange( 0, 1 )];
	else
		return nil;
}

/** @brief Return the keyboard modifier flags that need to be down to select this tool using the keyboard modifier
 * @note
 * A *registered* tool can be looked up by keyboard equivalent. This is implemented by DKToolController
 * in conjunction with this class.
 * @return the modifier flags - may be 0 if no flags are needed
 * @public
 */
- (NSUInteger)		keyboardModifierFlags
{
	return mKeyboardModifiers;
}

#pragma mark -

/** @brief The tool can return arbitrary persistent data that will be stored in the prefs and returned on
 * the next launch.
 * @return data, or nil
 * @public
 */
- (NSData*)			persistentData
{
	return nil;
}

/** @brief On launch, the data that was saved by the previous session will be reloaded
 * @public
 */
- (void)			shouldLoadPersistentData:(NSData*) data
{
#pragma unused(data)	
}

@end

