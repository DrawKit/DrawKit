/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawingToolProtocol.h"

@class DKToolController;

/** @brief DKDrawingTool is the semi-abstract base class for all types of drawing tool.

DKDrawingTool is the semi-abstract base class for all types of drawing tool. The point of a tool is to act as a translator for basic mouse events and
convert those events into meaningful operations on the target layer or object(s). One tool can be set at a time (see DKToolController) and
establishes a "mode" of operation for handling mouse events.

The tool also supplies a cursor for the view when that tool is selected.

A tool typically targets a layer or the objects within it. The calling sequence to a tool is coordinated by the DKToolController, targeting
the current active layer. Tools can change the data content of the layer or not - for example a zoom zool would only change the scale of
a view, not change any data.

Tools should be considered to be controllers, and sit between the view and the drawing data model.

Note: do not confuse "tools" as DK defines them with a palette of buttons or other UI - an application might implement an interface to
select a tool in such a way, but the buttons are not tools. A button could store a tool as its representedObject however. These UI con-
siderations are outside the scope of DK itself.
*/
@interface DKDrawingTool : NSObject <DKDrawingTool> {
@private
    NSString* mKeyboardEquivalent;
    NSUInteger mKeyboardModifiers;
}

/** @brief Does the tool ever implement undoable actions?

 Classes must override this and say YES if the tool does indeed perform an undoable action
 (i.e. it does something to an object)
 @return NO
 */
+ (BOOL)toolPerformsUndoableAction;

/** @brief Load tool defaults from the user defaults

 If used, this sets up the state of the tools and the styles they are set to to whatever was saved
 by the saveDefaults method in an earlier session. Someone (such as the app delegate) needs to call this
 on app launch after the tools have all been set up and registered.
 */
+ (void)loadDefaults;

/** @brief Save tool defaults to the user defaults

 Saves the persistent data, if any, of each registered tool. The main use for this is to
 restore the styles associated with each tool when the app is next launched.
 */
+ (void)saveDefaults;
+ (id)firstResponderAbleToSetTool;

/** @brief Return the registry name for this tool

 If the tool isn't registered, returns nil
 @return a string, the name this tool is registerd under, if any:
 */
- (NSString*)registeredName;
- (void)drawRect:(NSRect)aRect inView:(NSView*)aView;
- (void)flagsChanged:(NSEvent*)event inLayer:(DKLayer*)layer;
- (BOOL)isValidTargetLayer:(DKLayer*)aLayer;

/** @brief Return whether the tool is some sort of object selection tool

 This method is used to assist the tool controller in making sensible decisions about certain
 automatic operations. Subclasses that implement a selection tool should override this to return YES.
 @return YES if the tool selects objects, NO otherwise
 */
- (BOOL)isSelectionTool;

/** @brief Sets the tool as the current tool for the key view in the main window, if possible

 This follows the -set approach that cocoa uses for many objects. It looks for the key view in the
 main window. If it's a DKDrawingView that has a tool controller, it sets itself as the controller's
 current tool. This might be more convenient than other ways of setting a tool.
 */
- (void)set;

/** @brief Called when this tool is set by a tool controller

 Subclasses can make use of this message to prepare themselves when they are set if necessary
 @param aController the controller that set this tool
 */
- (void)toolControllerDidSetTool:(DKToolController*)aController;

/** @brief Called when this tool is about to be unset by a tool controller

 Subclasses can make use of this message to prepare themselves when they are unset if necessary, for
 example by finishing the work they were doing and cleaning up.
 @param aController the controller that set this tool
 */
- (void)toolControllerWillUnsetTool:(DKToolController*)aController;

/** @brief Called when this tool is unset by a tool controller

 Subclasses can make use of this message to prepare themselves when they are unset if necessary
 @param aController the controller that set this tool
 */
- (void)toolControllerDidUnsetTool:(DKToolController*)aController;
- (void)setCursorForPoint:(NSPoint)mp targetObject:(DKDrawableObject*)obj inLayer:(DKLayer*)aLayer event:(NSEvent*)event;

// if a keyboard equivalent is set, the tool controller will set the tool if the keyboard equivalent is received in keyDown:
// the tool must be registered for this to function.

- (void)setKeyboardEquivalent:(NSString*)str modifierFlags:(NSUInteger)flags;
- (NSString*)keyboardEquivalent;
- (NSUInteger)keyboardModifierFlags;

// drawing tools can optionally return arbitrary persistent data that DK will store in the prefs for it

- (NSData*)persistentData;
- (void)shouldLoadPersistentData:(NSData*)data;

@end

@interface DKDrawingTool (OptionalMethods)

- (void)mouseMoved:(NSEvent*)event inView:(NSView*)view;

@end

#pragma mark -

@interface DKDrawingTool (Deprecated)

// most of these are now implemented by DKToolRegistry - these methods call it for compatibility

/** @brief Return the shared instance of the tool registry

 Creates a new empty registry if it doesn't yet exist
 @return a dictionary - contains drawing tool objects keyed by name
 */
+ (NSDictionary*)sharedToolRegistry;

/** @brief Retrieve a tool from the registry with the given name

 Registered tools may be conveniently set by name - see DKToolController
 @param name the registry name of the tool required.
 @return the tool if it exists, or nil
 */
+ (DKDrawingTool*)drawingToolWithName:(NSString*)name;

/** @brief Register a tool in th eregistry with the given name

 Registered tools may be conveniently set by name - see DKToolController
 @param tool a tool object to register
 @param name a name to register it against.
 */
+ (void)registerDrawingTool:(DKDrawingTool*)tool withName:(NSString*)name;

/** @brief Retrieve a tool from the registry matching the key equivalent indicated by the key event passed

 See DKToolController
 @param keyEvent a keyDown event.
 @return the tool if it can be matched, or nil
 */
+ (DKDrawingTool*)drawingToolWithKeyboardEquivalent:(NSEvent*)keyEvent;

/** @brief Set a "standard" set of tools in the registry

 "Standard" tools are creation tools for various basic shapes, the selection tool, zoom tool and
 launch time, may be safely called more than once - subsequent calls are no-ops.
 If the conversion table has been set up prior to this, the tools will automatically pick up
 the class from the table, so that apps don't need to swap out all the tools for subclasses, but
 can simply set up the table.
 */
+ (void)registerStandardTools;

/** @brief Return a list of registered tools' names, sorted alphabetically

 May be useful for supporting a UI
 @return an array, a list of NSStrings
 */
+ (NSArray*)toolNames;

@end
