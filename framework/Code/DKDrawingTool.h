///**********************************************************************************************************************************
///  DKDrawingTool.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 23/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawingToolProtocol.h"


@class DKToolController;

@interface DKDrawingTool : NSObject <DKDrawingTool>
{
@private
	NSString*			mKeyboardEquivalent;
	NSUInteger			mKeyboardModifiers;
}

+ (BOOL)				toolPerformsUndoableAction;
+ (void)				loadDefaults;
+ (void)				saveDefaults;
+ (id)					firstResponderAbleToSetTool;

- (NSString*)			registeredName;
- (void)				drawRect:(NSRect) aRect inView:(NSView*) aView;
- (void)				flagsChanged:(NSEvent*) event inLayer:(DKLayer*) layer;
- (BOOL)				isValidTargetLayer:(DKLayer*) aLayer;
- (BOOL)				isSelectionTool;

- (void)				set;
- (void)				toolControllerDidSetTool:(DKToolController*) aController;
- (void)				toolControllerWillUnsetTool:(DKToolController*) aController;
- (void)				toolControllerDidUnsetTool:(DKToolController*) aController;
- (void)				setCursorForPoint:(NSPoint) mp targetObject:(DKDrawableObject*) obj inLayer:(DKLayer*) aLayer event:(NSEvent*) event;

// if a keyboard equivalent is set, the tool controller will set the tool if the keyboard equivalent is received in keyDown:
// the tool must be registered for this to function.

- (void)				setKeyboardEquivalent:(NSString*) str modifierFlags:(NSUInteger) flags;
- (NSString*)			keyboardEquivalent;
- (NSUInteger)			keyboardModifierFlags;

// drawing tools can optionally return arbitrary persistent data that DK will store in the prefs for it

- (NSData*)				persistentData;
- (void)				shouldLoadPersistentData:(NSData*) data;

@end


@interface DKDrawingTool	(OptionalMethods)

- (void)			mouseMoved:(NSEvent*) event inView:(NSView*) view;

@end


#pragma mark -

@interface DKDrawingTool (Deprecated)

// most of these are now implemented by DKToolRegistry - these methods call it for compatibility

+ (NSDictionary*)		sharedToolRegistry;
+ (DKDrawingTool*)		drawingToolWithName:(NSString*) name;
+ (void)				registerDrawingTool:(DKDrawingTool*) tool withName:(NSString*) name;
+ (DKDrawingTool*)		drawingToolWithKeyboardEquivalent:(NSEvent*) keyEvent;

+ (void)				registerStandardTools;
+ (NSArray*)			toolNames;


@end


/*

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
