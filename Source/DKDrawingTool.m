/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKArcPath.h"
#import "DKCropTool.h"
#import "DKDrawablePath.h"
#import "DKLayer.h"
#import "DKObjectCreationTool.h"
#import "DKPathInsertDeleteTool.h"
#import "DKRegularPolygonPath.h"
#import "DKReshapableShape.h"
#import "DKSelectAndEditTool.h"
#import "DKShapeFactory.h"
#import "DKStyle.h"
#import "DKTextPath.h"
#import "DKTextShape.h"
#import "DKToolController.h"
#import "DKToolRegistry.h"
#import "DKZoomTool.h"
#import "LogEvent.h"

#pragma mark constants

NSString* const kDKDrawingToolUserDefaultsKey = @"DK_DrawingTool_Defaults";

#pragma mark -
@implementation DKDrawingTool (Deprecated)

+ (NSDictionary*)sharedToolRegistry
{
	NSLog(@"+[DKDrawingTool sharedToolRegistry] is deprecated and is a no-op");

	return nil;
}

+ (DKDrawingTool*)drawingToolWithName:(NSString*)name
{
	return [[DKToolRegistry sharedToolRegistry] drawingToolWithName:name];
}

+ (DKDrawingTool*)drawingToolWithKeyboardEquivalent:(NSEvent*)keyEvent
{
	return [[DKToolRegistry sharedToolRegistry] drawingToolWithKeyboardEquivalent:keyEvent];
}

+ (void)registerDrawingTool:(DKDrawingTool*)tool withName:(NSString*)name
{
	[[DKToolRegistry sharedToolRegistry] registerDrawingTool:tool
													withName:name];
}

+ (void)registerStandardTools
{
	// no longer needs to do anything - the shared tool registry registers standard tools by default the first time it is
	// referenced.
}

+ (NSArray*)toolNames
{
	return [[DKToolRegistry sharedToolRegistry] toolNames];
}

@end

@implementation DKDrawingTool
#pragma mark As a DKDrawingTool

/** @brief Load tool defaults from the user defaults

 If used, this sets up the state of the tools and the styles they are set to to whatever was saved
 by the saveDefaults method in an earlier session. Someone (such as the app delegate) needs to call this
 on app launch after the tools have all been set up and registered.
 */
+ (void)loadDefaults
{
	LogEvent_(kInfoEvent, @"restoring tools persistent data");

	NSDictionary* toolInfo = [[NSUserDefaults standardUserDefaults] objectForKey:kDKDrawingToolUserDefaultsKey];

	if (toolInfo) {
		for (NSString* key in toolInfo) {
			NSData* data = [toolInfo objectForKey:key];

			if (data) {
				DKDrawingTool* tool = [[DKToolRegistry sharedToolRegistry] drawingToolWithName:key];
				[tool shouldLoadPersistentData:data];
			}
		}
	}
}

/** @brief Save tool defaults to the user defaults

 Saves the persistent data, if any, of each registered tool. The main use for this is to
 restore the styles associated with each tool when the app is next launched.
 */
+ (void)saveDefaults
{
	NSMutableDictionary* toolInfo = [NSMutableDictionary dictionary];

	for (NSString* key in [[DKToolRegistry sharedToolRegistry] toolNames]) {
		DKDrawingTool* tool = [[DKToolRegistry sharedToolRegistry] drawingToolWithName:key];
		NSData* pd = [tool persistentData];

		if (pd)
			[toolInfo setObject:pd
						 forKey:key];
	}

	if ([toolInfo count] > 0)
		[[NSUserDefaults standardUserDefaults] setObject:toolInfo
												  forKey:kDKDrawingToolUserDefaultsKey];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kDKDrawingToolUserDefaultsKey];
}

+ (id)firstResponderAbleToSetTool
{
	NSResponder* firstResponder = [[NSApp mainWindow] firstResponder];

	// follow responder chain until we find one that can respond, or we hit the end of the chain

	while (firstResponder && ![firstResponder respondsToSelector:@selector(setDrawingTool:)])
		firstResponder = [firstResponder nextResponder];

	if (firstResponder)
		return firstResponder;
	else {
		// before giving up, check if the active document implements -setDrawingTool: - subclasses of DKDrawingDocument do

		NSDocument* curDoc = [[NSDocumentController sharedDocumentController] currentDocument];

		if ([curDoc respondsToSelector:@selector(setDrawingTool:)])
			return curDoc;
	}

	return nil;
}

/** @brief Does the tool ever implement undoable actions?

 Classes must override this and say YES if the tool does indeed perform an undoable action
 (i.e. it does something to an object)
 @return NO
 */
+ (BOOL)toolPerformsUndoableAction
{
	return NO;
}

#pragma mark -

/** @brief Return the registry name for this tool

 If the tool isn't registered, returns nil
 @return a string, the name this tool is registerd under, if any:
 */
- (NSString*)registeredName
{
	NSArray* keys = [[DKToolRegistry sharedToolRegistry] allKeysForTool:self];

	if ([keys count] > 0)
		return [keys lastObject];

	return nil;
}

/** @brief Sets the tool as the current tool for the key view in the main window, if possible

 This follows the -set approach that cocoa uses for many objects. It looks for the key view in the
 main window. If it's a DKDrawingView that has a tool controller, it sets itself as the controller's
 current tool. This might be more convenient than other ways of setting a tool.
 */
- (void)set
{
	LogEvent_(kReactiveEvent, @"drawing tool %@ received the 'set' message - will attempt to set this tool", [self description]);

	id fr = [[self class] firstResponderAbleToSetTool];

	if (fr)
		[fr setDrawingTool:self];
	else
		[NSException raise:NSDestinationInvalidException
					format:@"The tool could not be set because first responder doesn't respond to -setDrawingTool:"];
}

/** @brief Called when this tool is set by a tool controller

 Subclasses can make use of this message to prepare themselves when they are set if necessary
 @param aController the controller that set this tool
 */
- (void)toolControllerDidSetTool:(DKToolController*)aController
{
#pragma unused(aController)

	// override to make use of this notification

	LogEvent_(kReactiveEvent, @"tool set: %@ by controller: %@", self, aController);
}

/** @brief Called when this tool is about to be unset by a tool controller

 Subclasses can make use of this message to prepare themselves when they are unset if necessary, for
 example by finishing the work they were doing and cleaning up.
 @param aController the controller that set this tool
 */
- (void)toolControllerWillUnsetTool:(DKToolController*)aController
{
#pragma unused(aController)

	// override to make use of this notification
}

/** @brief Called when this tool is unset by a tool controller

 Subclasses can make use of this message to prepare themselves when they are unset if necessary
 @param aController the controller that set this tool
 */
- (void)toolControllerDidUnsetTool:(DKToolController*)aController
{
#pragma unused(aController)

	// override to make use of this notification

	LogEvent_(kReactiveEvent, @"tool unset: %@ by controller: %@", self, aController);
}

#pragma mark -
#pragma mark - As part of DKDrawingTool Protocol

/** @brief Returns the undo action name for the tool

 Override to return something useful
 @return a string
 */
- (NSString*)actionName
{
	return nil;
}

/** @brief Return the tool's cursor

 Override to return a cursor appropriate to the tool
 @return the arrow cursor
 */
- (NSCursor*)cursor
{
	return [NSCursor arrowCursor];
}

/** @brief Handle the initial mouse down

 Override to do something useful
 @param p the local point where the mouse went down
 @param obj the target object, if there is one
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 @return the partcode of the target that was hit, or 0 (no object)
 */
- (NSInteger)mouseDownAtPoint:(NSPoint)p targetObject:(DKDrawableObject*)obj layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(p)
#pragma unused(obj)
#pragma unused(layer)
#pragma unused(event)
#pragma unused(aDel)

	return kDKDrawingNoPart;
}

/** @brief Handle the mouse dragged event

 Override to do something useful
 @param p the local point where the mouse has been dragged to
 @param pc the partcode returned by the mouseDown method
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 */
- (void)mouseDraggedToPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(p)
#pragma unused(pc)
#pragma unused(layer)
#pragma unused(event)
#pragma unused(aDel)
}

/** @brief Handle the mouse up event

 Override to do something useful
 tools usually return YES, tools that operate the user interface such as a zoom tool typically return NO
 @param p the local point where the mouse went up
 @param pc the partcode returned by the mouseDown method
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 @return YES if the tool did something undoable, NO otherwise
 */
- (BOOL)mouseUpAtPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(p)
#pragma unused(pc)
#pragma unused(layer)
#pragma unused(event)
#pragma unused(aDel)

	return NO;
}

- (void)drawRect:(NSRect)aRect inView:(NSView*)aView
{
#pragma unused(aRect)
#pragma unused(aView)
}

- (void)flagsChanged:(NSEvent*)event inLayer:(DKLayer*)layer
{
#pragma unused(event)
#pragma unused(layer)
}

- (BOOL)isValidTargetLayer:(DKLayer*)aLayer
{
	return ![aLayer lockedOrHidden];
}

/** @brief Return whether the tool is some sort of object selection tool

 This method is used to assist the tool controller in making sensible decisions about certain
 automatic operations. Subclasses that implement a selection tool should override this to return YES.
 @return YES if the tool selects objects, NO otherwise
 */
- (BOOL)isSelectionTool
{
	return NO;
}

- (void)setCursorForPoint:(NSPoint)mp targetObject:(DKDrawableObject*)obj inLayer:(DKLayer*)aLayer event:(NSEvent*)event
{
#pragma unused(mp)
#pragma unused(obj)
#pragma unused(aLayer)
#pragma unused(event)

	[[self cursor] set];
}

#pragma mark -

/** @brief Sets the keyboard equivalent that can be used to select this tool

 A *registered* tool can be looked up by keyboard equivalent. This is implemented by DKToolController
 in conjunction with this class.
 @param str the key character (only the first character in the string is used)
 @param flags any additional modifier flags - can be 0
 */
- (void)setKeyboardEquivalent:(NSString*)str modifierFlags:(NSEventModifierFlags)flags
{
	NSAssert(str != nil, @"attempt to set keyboard equivalent to nil string - string can be empty but not nil");

	if (str.length > 0) {
		mKeyboardEquivalent = [str substringWithRange:NSMakeRange(0, 1)];
	} else {
		mKeyboardEquivalent = @"";
	}

	mKeyboardModifiers = flags;
}

- (NSString*)keyboardEquivalent
{
	if ([mKeyboardEquivalent length] > 0)
		return [mKeyboardEquivalent substringWithRange:NSMakeRange(0, 1)];
	else
		return nil;
}

@synthesize keyboardModifierFlags = mKeyboardModifiers;

#pragma mark -

- (NSData*)persistentData
{
	return nil;
}

- (void)shouldLoadPersistentData:(NSData*)data
{
#pragma unused(data)
}

@end
