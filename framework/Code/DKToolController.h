///**********************************************************************************************************************************
///  DKToolController.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 8/04/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************



#import "DKViewController.h"


@class DKDrawingTool, DKUndoManager;

// this type is used to set the scope of tools within a DK application:

typedef enum
{
	kDKToolScopeLocalToView		= 0,		// tools can be individually set per view
	kDKToolScopeLocalToDocument	= 1,		// tools are set individually for the document, the same tool in all views of that document (default)
	kDKToolScopeGlobal			= 2			// tools are set globally for the whole application
}
DKDrawingToolScope;


// controller class:


@interface DKToolController : DKViewController
{
@private
	DKDrawingTool*		mTool;				// the current tool if stored locally
	BOOL				mAutoRevert;		// YES to "spring" tool back to selection after each one completes
	NSInteger			mPartcode;			// partcode to pass back during mouse ops
	BOOL				mOpenedUndoGroup;	// YES if an undo group was requested by the tool at some point
	BOOL				mAbortiveMouseDown;	// YES flagged after exception during mouse down - rejects drag and up events
}

+ (void)				setDrawingToolOperatingScope:(DKDrawingToolScope) scope;
+ (DKDrawingToolScope)	drawingToolOperatingScope;

+ (void)				setToolsAutoActivateValidLayer:(BOOL) autoActivate;
+ (BOOL)				toolsAutoActivateValidLayer;

- (void)				setDrawingTool:(DKDrawingTool*) aTool;
- (void)				setDrawingToolWithName:(NSString*) name;
- (DKDrawingTool*)		drawingTool;
- (BOOL)				canSetDrawingTool:(DKDrawingTool*) aTool;

- (void)				setAutomaticallyRevertsToSelectionTool:(BOOL) reverts;
- (BOOL)				automaticallyRevertsToSelectionTool;

- (IBAction)			selectDrawingToolByName:(id) sender;
- (IBAction)			selectDrawingToolByRepresentedObject:(id) sender;
- (IBAction)			toggleAutoRevertAction:(id) sender;

- (id)					undoManager;
- (void)				openUndoGroup;
- (void)				closeUndoGroup;

@end



// notifications:

extern NSString*		kDKWillChangeToolNotification;
extern NSString*		kDKDidChangeToolNotification;
extern NSString*		kDKDidChangeToolAutoRevertStateNotification;

// defaults keys:

extern NSString*		kDKDrawingToolAutoActivatesLayerDefaultsKey;

// constants:

extern NSString*		kDKStandardSelectionToolName;



/*

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


