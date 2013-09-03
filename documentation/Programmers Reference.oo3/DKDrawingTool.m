///**********************************************************************************************************************************
///  DKDrawingTool.m
///  DrawKit
///
///  Created by graham on 23/09/2006.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************


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


#pragma mark constants
NSString*		kGCDrawingToolWasRegisteredNotification = @"kGCDrawingToolWasRegisteredNotification";
NSString*		kDKStandardSelectionToolName = @"Select";


#pragma mark Static Vars
static NSMutableDictionary*		sToolRegistry = nil;


#pragma mark -
@implementation DKDrawingTool
#pragma mark As a DKDrawingTool



///*********************************************************************************************************************
///
/// method:			drawingToolWithName:
/// scope:			public class method
///	overrides:		
/// description:	retrieve a tool from the registry with the given name
/// 
/// parameters:		<name> the registry name of the tool required.
/// result:			the tool if it exists, or nil
///
/// notes:			Registered tools may be conveniently set by name - see DKToolController
///
///********************************************************************************************************************

+ (DKDrawingTool*)		drawingToolWithName:(NSString*) name
{
	if ( sToolRegistry != nil )
		return [sToolRegistry objectForKey:name];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			drawingToolWithKeyboardEquivalent:
/// scope:			public class method
///	overrides:		
/// description:	retrieve a tool from the registry matching the key equivalent indicated by the key event passed
/// 
/// parameters:		<keyEvent> a keyDown event.
/// result:			the tool if it can be matched, or nil
///
/// notes:			see DKToolController
///
///********************************************************************************************************************

+ (DKDrawingTool*)		drawingToolWithKeyboardEquivalent:(NSEvent*) keyEvent
{
	NSEnumerator*	iter = [[sToolRegistry allKeys] objectEnumerator];
	NSString*		name;
	NSString*		keyEquivalent;
	DKDrawingTool*	tool;
	unsigned		flags;
	
	while(( name = [iter nextObject]))
	{
		tool = [sToolRegistry objectForKey:name];
		
		keyEquivalent = [tool keyboardEquivalent];
		flags = [tool keyboardModifierFlags];
		
		if([keyEquivalent isEqualToString:[keyEvent charactersIgnoringModifiers]])
		{
			if(( flags & [keyEvent modifierFlags]) == flags )
				return tool;
		}
	}
	return nil;
}


///*********************************************************************************************************************
///
/// method:			registerDrawingTool:withName:
/// scope:			public class method
///	overrides:		
/// description:	register a tool in th eregistry with the given name
/// 
/// parameters:		<tool> a tool object to register
///					<name> a name to register it against.
/// result:			none
///
/// notes:			Registered tools may be conveniently set by name - see DKToolController
///
///********************************************************************************************************************

+ (void)				registerDrawingTool:(DKDrawingTool*) tool withName:(NSString*) name
{
	NSAssert( tool != nil, @"cannot register a nil tool");
	NSAssert( name != nil, @"cannot register a tool with a nil name");
	NSAssert([name length] > 0, @"cannot register a tool with an empty name");
	
	if ( sToolRegistry == nil )
		sToolRegistry = [[NSMutableDictionary alloc] init];
		
	NSAssert( sToolRegistry != nil, @"registry is nil - cannot register tool");
		
	[sToolRegistry setObject:tool forKey:name];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCDrawingToolWasRegisteredNotification object:tool];
}


///*********************************************************************************************************************
///
/// method:			registerStandardTools
/// scope:			public class method
///	overrides:		
/// description:	set a "standard" set of tools in the registry
/// 
/// parameters:		none
/// result:			none
///
/// notes:			"Standard" tools are creation tools for various basic shapes, the selection tool, zoom tool and
///					path insert/delete tools. You ar free to ignore, replace or use them as is. Typically called at app
///					launch time, may be safely called more than once - subsequent calls are no-ops.
///
///********************************************************************************************************************

+ (void)				registerStandardTools
{
	// convenience method sets up a set of "standard" tools
	
	static BOOL sIsInited = NO;
	
	if ( ! sIsInited )
	{
		// ------ rect ------
		
		DKDrawableShape*	shape = [[DKDrawableShape alloc] init];
		[shape setPath:[DKShapeFactory rect]];
		/*
		[shape setPath:[NSBezierPath bezierPathWithBoltOfLength:0.5
									threadDiameter:0.1
									threadPitch:0.02
									headDiameter:0.2
									headHeight:0.1
									shankLength:0
									options:0]];
		*/
		DKDrawingTool*		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
		[shape release];
		[self registerDrawingTool:dt  withName:@"Rectangle"];
		[dt setKeyboardEquivalent:@"r" modifierFlags:0];
		[dt release];
		
		// ----- roundrect -----
		
		DKReshapableShape* rss = [[DKReshapableShape alloc] init];
		[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]  selector:@selector( roundRectInRect:objParam: ) ];
		[rss setOptionalParameter:[NSNumber numberWithFloat:16.0]];
		/*
		DKHotspot* hs = [[DKHotspot alloc] initHotspotWithOwner:rss partcode:0 delegate:nil];
		[hs setRelativeLocation:NSMakePoint( 0.40, -0.40 )];
		[rss addHotspot:hs];
		[hs release];
		*/
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
		[rss release];
		[self registerDrawingTool:dt  withName:@"Round Rectangle"];
		[dt release];
		
		// ----- roundendrect -----
		
		rss = [[DKReshapableShape alloc] init];
		[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]  selector:@selector( roundEndedRect:objParam: ) ];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
		[rss release];
		[self registerDrawingTool:dt  withName:@"Round End Rectangle"];
		[dt release];
		
		// ------ text ------
		
		DKTextShape*		tshape = [[DKTextShape alloc] init];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:tshape];
		[tshape release];
		[self registerDrawingTool:dt  withName:@"Text"];
		[dt setKeyboardEquivalent:@"t" modifierFlags:0];
		[dt release];
		
		// -------- oval -------
		
		shape = [[DKDrawableShape alloc] init];
		[shape setPath:[DKShapeFactory oval]];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
		[shape release];
		[self registerDrawingTool:dt  withName:@"Oval"];
		[dt setKeyboardEquivalent:@"o" modifierFlags:0];
		[dt release];
		
		// -------- ring -------
		
		shape = [[DKDrawableShape alloc] init];
		[shape setPath:[DKShapeFactory ring:0.67]];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
		[shape release];
		[self registerDrawingTool:dt  withName:@"Ring"];
		[dt release];
 
		// -------- bezier path -------
		
		DKDrawablePath* path = [[DKDrawablePath alloc] init];
		[path setPathEditingMode:kGCPathCreateModeBezierCreate];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
		[path release];
		[self registerDrawingTool:dt  withName:@"Path"];
		[dt setKeyboardEquivalent:@"p" modifierFlags:0];
		[dt release];
		
		//-------- line ---------

		path = [[DKDrawablePath alloc] init];
		[path setPathEditingMode:kGCPathCreateModeLineCreate];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
		[path release];
		[self registerDrawingTool:dt  withName:@"Line"];
		[dt setKeyboardEquivalent:@"l" modifierFlags:0];
		[dt release];

		//-------- polygon ---------

		path = [[DKDrawablePath alloc] init];
		[path setPathEditingMode:kGCPathCreateModePolygonCreate];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
		[path release];
		[self registerDrawingTool:dt  withName:@"Polygon"];
		[dt release];
		
		//-------- freehand -------
		
		path = [[DKDrawablePath alloc] init];
		[path setPathEditingMode:kGCPathCreateModeFreehandCreate];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
		[path release];
		[self registerDrawingTool:dt  withName:@"Freehand"];
		[dt setKeyboardEquivalent:@"f" modifierFlags:0];
		[dt release];
		
		//-------- arc ---------

		path = [[DKDrawablePath alloc] init];
		[path setPathEditingMode:kGCPathCreateModeArcSegment];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
		[path release];
		[self registerDrawingTool:dt  withName:@"Arc"];
		[dt setKeyboardEquivalent:@"a" modifierFlags:0];
		[dt release];
		
		//-------- wedge ---------

		path = [[DKDrawablePath alloc] init];
		[path setPathEditingMode:kGCPathCreateModeWedgeSegment];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
		[path release];
		[self registerDrawingTool:dt  withName:@"Wedge"];
		[dt setKeyboardEquivalent:@"w" modifierFlags:0];
		[dt release];

		// ----- speech balloon ----
		
		rss = [[DKReshapableShape alloc] init];
		[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]  selector:@selector( speechBalloonInRect:objParam: ) ];
		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
		[rss release];
		[self registerDrawingTool:dt  withName:@"Speech Balloon"];
		[dt release];
		
		// ----- path add/delete tools ----
		
		dt = [DKPathInsertDeleteTool pathDeletionTool];
		[self registerDrawingTool:dt  withName:@"Delete Path Point"];
		
		dt = [DKPathInsertDeleteTool pathInsertionTool];
		[self registerDrawingTool:dt  withName:@"Insert Path Point"];
		
		// ----- zoom tool -----
		
		dt = [[DKZoomTool alloc] init];
		[self registerDrawingTool:dt withName:@"Zoom"];
		[dt setKeyboardEquivalent:@"m" modifierFlags:0];
		[dt release];
		
		// ----- select and edit tool -----
		
		dt = [[DKSelectAndEditTool alloc] init];
		[self registerDrawingTool:dt withName:kDKStandardSelectionToolName];
		[dt setKeyboardEquivalent:@" " modifierFlags:0];
		[dt release];
		
		sIsInited = YES;
	}
}


///*********************************************************************************************************************
///
/// method:			toolNames
/// scope:			public class method
///	overrides:		
/// description:	return a list of registered tools' names, sorted alphabetically
/// 
/// parameters:		none
/// result:			an array, a list of NSStrings
///
/// notes:			May be useful for supporting a UI
///
///********************************************************************************************************************

+ (NSArray*)			toolNames
{
	NSMutableArray*		tn = [[sToolRegistry allKeys] mutableCopy];
	
	[tn sortUsingSelector:@selector(compare:)];
	
	return [tn autorelease];
}


///*********************************************************************************************************************
///
/// method:			toolPerformsUndoableAction
/// scope:			public class method
///	overrides:		
/// description:	does the tool ever implement undoable actions?
/// 
/// parameters:		none
/// result:			NO
///
/// notes:			classes must override this and say YES if the tool does indeed perform an undoable action
///					(i.e. it does something to an object)
///
///********************************************************************************************************************

+ (BOOL)				toolPerformsUndoableAction
{
	return NO;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			registeredName
/// scope:			public instance method
///	overrides:		
/// description:	return the registry name for this tool
/// 
/// parameters:		none
/// result:			a string, the name this tool is registerd under, if any:
///
/// notes:			if the tool isn't registered, returns nil
///
///********************************************************************************************************************

- (NSString*)			registeredName
{
	if ( sToolRegistry != nil )
	{
		NSArray* keys = [sToolRegistry allKeysForObject:self];
		
		if ([keys count] > 0 )
			return [keys lastObject];
	}
	return nil;
}



///*********************************************************************************************************************
///
/// method:			set
/// scope:			public instance method
///	overrides:		
/// description:	sets the tool as the current tool for the key view in the main window, if possible
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this follows the -set approach that cocoa uses for many objects. It looks for the key view in the
///					main window. If it's a DKDrawingView that has a tool controller, it sets itself as the controller's
///					current tool. This might be more convenient than other ways of setting a tool.
///
///********************************************************************************************************************

- (void)				set
{
	LogEvent_( kReactiveEvent, @"drawing tool %@ received the 'set' message - will attempt to set this tool", [self description]);
	
	NSResponder* firstResponder = [[NSApp mainWindow] firstResponder];
	
	if( firstResponder != nil && [firstResponder respondsToSelector:@selector(setDrawingTool:)])
	{
		[(id)firstResponder setDrawingTool:self];
		
		// since this is a somewhat blind method, sanity check that the tool was actually set - if not
		// raise an exception which will log the failure of the method
		
		if([(id)firstResponder drawingTool] != self)
			[NSException raise:NSDestinationInvalidException format:@"The tool could not be set because the target object was unable to use it"];
	}
	else
		[NSException raise:NSDestinationInvalidException format:@"The tool could not be set because first responder doesn't respond to -setDrawingTool:"];
}


#pragma mark -
#pragma mark - As part of DKDrawingTool Protocol

///*********************************************************************************************************************
///
/// method:			actionName
/// scope:			public instance method
///	overrides:		
/// description:	returns the undo action name for the tool
/// 
/// parameters:		none
/// result:			a string
///
/// notes:			override to return something useful
///
///********************************************************************************************************************

- (NSString*)		actionName
{
	return nil;
}


///*********************************************************************************************************************
///
/// method:			cursor
/// scope:			public instance method
///	overrides:		
/// description:	return the tool's cursor
/// 
/// parameters:		none
/// result:			the arrow cursor
///
/// notes:			override to return a cursor appropriate to the tool
///
///********************************************************************************************************************

- (NSCursor*)		cursor
{
	return [NSCursor arrowCursor];
}


///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:targetObject:layer:event:delegate:
/// scope:			public instance method
///	overrides:		
/// description:	handle the initial mouse down
/// 
/// parameters:		<p> the local point where the mouse went down
///					<obj> the target object, if there is one
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			the partcode of the target that was hit, or 0 (no object)
///
/// notes:			override to do something useful
///
///********************************************************************************************************************

- (int)				mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(p)
	#pragma unused(obj)
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)

	return kGCDrawingNoPart;
}


///*********************************************************************************************************************
///
/// method:			mouseDraggedToPoint:partCode:layer:event:delegate:
/// scope:			public instance method
///	overrides:		
/// description:	handle the mouse dragged event
/// 
/// parameters:		<p> the local point where the mouse has been dragged to
///					<partCode> the partcode returned by the mouseDown method
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			none
///
/// notes:			override to do something useful
///
///********************************************************************************************************************

- (void)			mouseDraggedToPoint:(NSPoint) p partCode:(int) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(p)
	#pragma unused(pc)
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)
}


///*********************************************************************************************************************
///
/// method:			mouseUpAtPoint:partCode:layer:event:delegate:
/// scope:			public instance method
///	overrides:		
/// description:	handle the mouse up event
/// 
/// parameters:		<p> the local point where the mouse went up
///					<partCode> the partcode returned by the mouseDown method
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			YES if the tool did something undoable, NO otherwise
///
/// notes:			override to do something useful
///					return YES if the tool changed the data content of <layer>, NO if it did not. Object editing/creation
///					tools usually return YES, tools that operate the user interface such as a zoom tool typically return NO
///
///********************************************************************************************************************

- (BOOL)			mouseUpAtPoint:(NSPoint) p partCode:(int) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(p)
	#pragma unused(pc)
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			drawRect:InView:
/// scope:			public instance method
///	overrides:		
/// description:	handle the initial mouse down
/// 
/// parameters:		<aRect> the rect being redrawn (not used)
///					<aView> the view that is doing the drawing
/// result:			none
///
/// notes:			override this to get the call from DKObjectDrawingToolLayer after all other drawing has completed
///
///********************************************************************************************************************

- (void)			drawRect:(NSRect) aRect inView:(NSView*) aView
{
	#pragma unused(aRect)
	#pragma unused(aView)
}


///*********************************************************************************************************************
///
/// method:			flagsChanged:inLayer:
/// scope:			public instance method
///	overrides:		
/// description:	the state of the modifier keys changed
/// 
/// parameters:		<event> the event
///					<layer> the current layer that the tool is being applied to
/// result:			none
///
/// notes:			override this to get notified when the modifier keys change state while your tool is set

///
///********************************************************************************************************************

- (void)			flagsChanged:(NSEvent*) event inLayer:(DKLayer*) layer
{
	#pragma unused(event)
	#pragma unused(layer)
}



///*********************************************************************************************************************
///
/// method:			isValidTargetLayer:
/// scope:			public instance method
///	overrides:		
/// description:	return whether the target layer can be used by this tool
/// 
/// parameters:		<aLayer> a layer object
/// result:			YES if the tool can be used with the given layer, NO otherwise
///
/// notes:			this is called by the tool controller to determine if the set tool can actually be used in the
///					current layer. Override to reject any layers that can't be used with the tool. The default is to
///					reject all locked or hidden layers, though some tools may still be operable in such a case.
///
///********************************************************************************************************************

- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	return ![aLayer lockedOrHidden];
}

///*********************************************************************************************************************
///
/// method:			setCursorForPoint:targetObject:inLayer:buttonDown:
/// scope:			public instance method
///	overrides:		
/// description:	set a cursor if the given point is over something interesting
/// 
/// parameters:		<mp> the local mouse point
///					<obj> the target object under the mouse, if any
///					<alayer> the active layer
///					<event> the original event
/// result:			none
///
/// notes:			called by the tool controller when the mouse moves, this should determine whether a special cursor
///					needs to be set right now and set it. If no special cursor needs to be set, it should set the
///					current one for the tool. Override to implement this in specific tool classes.
///
///********************************************************************************************************************

- (void)			setCursorForPoint:(NSPoint) mp targetObject:(DKDrawableObject*) obj inLayer:(DKLayer*) aLayer event:(NSEvent*) event
{
	#pragma unused(mp)
	#pragma unused(obj)
	#pragma unused(aLayer)
	#pragma unused(event)
	
	[[self cursor] set];
}

#pragma mark -

///*********************************************************************************************************************
///
/// method:			setKeyboardEquivalent:modifierFlags:
/// scope:			public instance method
///	overrides:		
/// description:	sets the keyboard equivalent that can be used to select this tool
/// 
/// parameters:		<str> the key character (only the first character in the string is used)
///					<flags> any additional modifier flags - can be 0
/// result:			none
///
/// notes:			a *registered* tool can be looked up by keyboard equivalent. This is implemented by DKToolController
///					in conjunction with this class.
///
///********************************************************************************************************************

- (void)			setKeyboardEquivalent:(NSString*) str modifierFlags:(unsigned) flags
{
	NSAssert( str != nil, @"attempt to set keyboard equivalent to nil string - string can be empty but not nil");
	
	[str retain];
	[mKeyboardEquivalent release];
	mKeyboardEquivalent = str;
	
	mKeyboardModifiers = flags;
}


///*********************************************************************************************************************
///
/// method:			keyboardEquivalent
/// scope:			public instance method
///	overrides:		
/// description:	return the keyboard equivalent character can be used to select this tool
/// 
/// parameters:		none
/// result:			the key character (only the first character in the string is used)
///
/// notes:			a *registered* tool can be looked up by keyboard equivalent. This is implemented by DKToolController
///					in conjunction with this class. Returns nil if no equivalent has been set.
///
///********************************************************************************************************************

- (NSString*)		keyboardEquivalent
{
	if ([mKeyboardEquivalent length] > 0)
		return [mKeyboardEquivalent substringWithRange:NSMakeRange( 0, 1 )];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			keyboardModifierFlags
/// scope:			public instance method
///	overrides:		
/// description:	return the keyboard modifier flags that need to be down to select this tool using the keyboard modifier
/// 
/// parameters:		none
/// result:			the modifier flags - may be 0 if no flags are needed
///
/// notes:			a *registered* tool can be looked up by keyboard equivalent. This is implemented by DKToolController
///					in conjunction with this class.
///
///********************************************************************************************************************

- (unsigned)		keyboardModifierFlags
{
	return mKeyboardModifiers;
}



@end
