/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKViewController.h"

@class DKDrawingTool, DKUndoManager;

// this type is used to set the scope of tools within a DK application:

typedef enum {
	kDKToolScopeLocalToView = 0, // tools can be individually set per view
	kDKToolScopeLocalToDocument = 1, // tools are set individually for the document, the same tool in all views of that document (default)
	kDKToolScopeGlobal = 2 // tools are set globally for the whole application
} DKDrawingToolScope;

// controller class:

/** @brief This object is a view controller that can apply one of a range of tools to the objects in the currently active drawing layer.

This object is a view controller that can apply one of a range of tools to the objects in the currently active drawing layer.

==== WHAT IS A TOOL? ====

Users "see" tools often as a button in a palette of tools, and can choose which tool is operative by clicking the button. While your
application may certainly implement a user interface for selecting among tools in this way, DK's concept of a tool is more abstract.

In DK, a tool is an object that takes basic mouse events that originate in a view and translates those events into meaningful operations
on the data model or other parts of DK. Thus a tool is essentially a translator of mouse events into specific behaviours. Different tools have
different behaviours, but all adopt the same basic DKDrawingTool protocol. Tools are part of the controller layer of the M-V-C
paradigm.

Not all tools necessarily change the data content of the drawing. For example a user might pick a zoom tool from the same palette that
has other drawing tools such as rects or ovals. A zoom tool doesn't change the data content, it only changes the state of the view. The
tool protocol permits the controller to determine whether the data content was changed so it can help manage undo and so forth.

Tools may optionally draw something in the view - if so, they are given the opportunity to do so after all other drawing, so tools draw
"on top" of any other content. Typically a tool might draw a selection rect or similar.

Tools are responsible for applying their own behaviour to the target object(s), this controller merely calls the tool appropriately.

==== CHOOSING TOOLS ====

This controller permits one tool at a time to be set. This can be applied globally for the whole application, on a per-document (drawing)
basis, or individually for the view. Which you use will depend on your needs and the sort of user interface that your application wants
to implement for tools. DK provides no UI and makes no assumptions about it - your UI is required to somehow pick a tool and set it.

Tools can be stored in a registry (see DKDrawingTool) using a name. A UI may take advantage of this by using the name to look up the
tool and set it. As a convenience, the -selectDrawingToolByName: action method will use the -title property of <sender> as the name and
set the tool if one exists in the registry with this name - thus a palette of buttons for example can just set each button title to the
tool's name and target first responder with this action.
*/
@interface DKToolController : DKViewController {
@private
	DKDrawingTool* mTool; // the current tool if stored locally
	BOOL mAutoRevert; // YES to "spring" tool back to selection after each one completes
	NSInteger mPartcode; // partcode to pass back during mouse ops
	BOOL mOpenedUndoGroup; // YES if an undo group was requested by the tool at some point
	BOOL mAbortiveMouseDown; // YES flagged after exception during mouse down - rejects drag and up events
}

/** @brief Set the operating scope for tools for this application

 DK allows tools to be set per-view, per-document, or per-application. This is called the operating
 scope. Generally your app should decide what is appropriate, set it at start up and stick to it.
 It is not expected that this will be called during the subsequent use of the app - though it is
 harmless to do so it's very likely to confuse the user.
 @param scope the operating scope for tools
 */
+ (void)setDrawingToolOperatingScope:(DKDrawingToolScope)scope;

/** @brief Return the operating scope for tools for this application

 DK allows tools to be set per-view, per-document, or per-application. This is called the operating
 scope. Generally your app should decide what is appropriate, set it at start up and stick to it.
 The default is per-document scope.
 @return the operating scope for tools
 */
+ (DKDrawingToolScope)drawingToolOperatingScope;

/** @brief Set whether setting a tool will auto-activate a layer appropriate to the tool

 Default is NO. If YES, when a tool is set but the active layer is not valid for the tool, the
 layers are searched top down until one is found that the tool validates, which is then made
 active. Layers which are locked, hidden or refuse active status are skipped. Persistent.
 @param autoActivate YES to autoactivate, NO otherwise
 */
+ (void)setToolsAutoActivateValidLayer:(BOOL)autoActivate;

/** @brief Return whether setting a tool will auto-activate a layer appropriate to the tool

 Default is NO. If YES, when a tool is set but the active layer is not valid for the tool, the
 layers are searched top down until one is found that the tool validates, which is then made
 active. Layers which are locked, hidden or refuse active status are skipped. Persistent.
 @return YES if tools auto-activate appropriate layer, NO if not
 */
+ (BOOL)toolsAutoActivateValidLayer;

/** @brief Sets the current drawing tool

 The tool is set locally, for the drawing or globally according to the current scope.
 @param aTool the tool to set
 */
- (void)setDrawingTool:(DKDrawingTool*)aTool;

/** @brief Select the tool using its registered name

 Tools must be registered in the DKDrawingTool registry with the given name before you can use this
 method to set them, otherwise an exception is thrown.
 @param name the registered name of the required tool
 */
- (void)setDrawingToolWithName:(NSString*)name;

/** @brief Return the current drawing tool

 The tool is set locally, for the drawing or globally according to the current scope.
 @return the current tool
 */
- (DKDrawingTool*)drawingTool;

/** @brief Check if the tool can be set for the current active layer

 Can be used to test whether a tool is able to be selected in the current context. There is no
 requirement to use this - you can set the drawing tool anyway and if an attempt to use it in
 an invalid layer is made, the tool controller will handle it anyway. A UI might want to use this
 to prevent the selection of a tool before it gets to that point however.
 @param aTool the propsed drawing tool
 @return YES if the tool can be applied to the current active layer, NO if not
 */
- (BOOL)canSetDrawingTool:(DKDrawingTool*)aTool;

/** @brief Set whether the tool should automatically "spring back" to the selection tool after each application

 The default is YES
 @param reverts YES to spring back, NO to leave the present tool active after each use
 */
- (void)setAutomaticallyRevertsToSelectionTool:(BOOL)reverts;

/** @brief Whether the tool should automatically "spring back" to the selection tool after each application

 The default is YES
 @return YES to spring back, NO to leave the present tool active after each use
 */
- (BOOL)automaticallyRevertsToSelectionTool;

/** @brief Select the tool using its registered name based on the title of a UI control, etc.

 This is a convenience for hooking up a UI for picking a tool. You can set the title of a button to
 be the tool's name and target first responder using this action, and it will select the tool if it
 has been registered using the name. This makes UI such as a palette of tools trivial to implement,
 but doesn't preclude you from using any other UI as you see fit.
 @param sender the sender of the action - it should implement -title (e.g. a button, menu item)
 */
- (IBAction)selectDrawingToolByName:(id)sender;

/** @brief Select the tool using the represented object of a UI control, etc.

 This is a convenience for hooking up a UI for picking a tool. You can set the rep. object of a button to
 be the tool and target first responder using this action, and it will set the tool to the button's
 represented object.
 @param sender the sender of the action - it should implement -representedObject (e.g. a button, menu item)
 */
- (IBAction)selectDrawingToolByRepresentedObject:(id)sender;

/** @brief Toggle the state of the automatic tool "spring" behaviour.

 Flips the state of the auto-revert flag. A UI can make use of this to control the flag in order to
 make a tool "sticky". Often this is done by double-clicking the tool button.
 @param sender the sender of the action
 */
- (IBAction)toggleAutoRevertAction:(id)sender;

- (id)undoManager;

/** @brief Opens a new undo manager group if one has not already been opened
 */
- (void)openUndoGroup;

/** @brief Closes the current undo manager group if one has been opened

 When the controller is set up to always open a group, this also deals with the bogus task bug in
 NSUndoManager, where opening and closig a group creates an empty undo task. If that case is detected,
 the erroneous task is removed from the stack by invoking undo while temporarily disabling the UM.
 */
- (void)closeUndoGroup;

@end

// notifications:

extern NSString* kDKWillChangeToolNotification;
extern NSString* kDKDidChangeToolNotification;
extern NSString* kDKDidChangeToolAutoRevertStateNotification;

// defaults keys:

extern NSString* kDKDrawingToolAutoActivatesLayerDefaultsKey;

// constants:

extern NSString* kDKStandardSelectionToolName;
