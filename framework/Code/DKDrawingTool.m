///**********************************************************************************************************************************
///  DKDrawingTool.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 23/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
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

///*********************************************************************************************************************
///
/// method:			sharedToolRegistry
/// scope:			public class method
///	overrides:		
/// description:	return the shared instance of the tool registry
/// 
/// parameters:		none
/// result:			a dictionary - contains drawing tool objects keyed by name
///
/// notes:			creates a new empty registry if it doesn't yet exist
///
///********************************************************************************************************************

+ (NSDictionary*)		sharedToolRegistry
{
	NSLog(@"+[DKDrawingTool sharedToolRegistry] is deprecated and is a no-op");
	
	return nil;
}

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
	return [[DKToolRegistry sharedToolRegistry] drawingToolWithName:name];
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
	return [[DKToolRegistry sharedToolRegistry] drawingToolWithKeyboardEquivalent:keyEvent];
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
	[[DKToolRegistry sharedToolRegistry] registerDrawingTool:tool withName:name];
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
///					If the conversion table has been set up prior to this, the tools will automatically pick up
///					the class from the table, so that apps don't need to swap out all the tools for subclasses, but
///					can simply set up the table.
///
///********************************************************************************************************************

+ (void)				registerStandardTools
{
	// no longer needs to do anything - the shared tool registry registers standard tools by default the first time it is
	// referenced.
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
	return [[DKToolRegistry sharedToolRegistry] toolNames];
}


///*********************************************************************************************************************
///
/// method:			loadDefaults
/// scope:			public class method
///	overrides:		
/// description:	load tool defaults from the user defaults
/// 
/// parameters:		none
/// result:			none
///
/// notes:			if used, this sets up the state of the tools and the styles they are set to to whatever was saved
///					by the saveDefaults method in an earlier session. Someone (such as the app delegate) needs to call this
///					on app launch after the tools have all been set up and registered.
///
///********************************************************************************************************************

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


///*********************************************************************************************************************
///
/// method:			saveDefaults
/// scope:			public class method
///	overrides:		
/// description:	save tool defaults to the user defaults
/// 
/// parameters:		none
/// result:			none
///
/// notes:			saves the persistent data, if any, of each registered tool. The main use for this is to
///					restore the styles associated with each tool when the app is next launched.
///
///********************************************************************************************************************

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


///*********************************************************************************************************************
///
/// method:			firstResponderAbleToSetTool
/// scope:			public class method
///	overrides:		
/// description:	return the first responder in the current responder chain able to respond to -setDrawingTool:
/// 
/// parameters:		none
/// result:			a responder, or nil
///
/// notes:			This searches upwards from the current first responder. If that fails, it also checks the
///					current document. Used by -set and other code that needs to know whether -set will succeed.
///
///********************************************************************************************************************

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
	NSArray* keys = [[DKToolRegistry sharedToolRegistry] allKeysForTool:self];
		
	if ([keys count] > 0 )
		return [keys lastObject];

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
///
///********************************************************************************************************************

- (void)				set
{
	LogEvent_( kReactiveEvent, @"drawing tool %@ received the 'set' message - will attempt to set this tool", [self description]);
	
	id fr = [[self class] firstResponderAbleToSetTool];
	
	if( fr )
		[fr setDrawingTool:self];
	else
		[NSException raise:NSDestinationInvalidException format:@"The tool could not be set because first responder doesn't respond to -setDrawingTool:"];
}


///*********************************************************************************************************************
///
/// method:			toolControllerDidSetTool:
/// scope:			public instance method
///	overrides:		
/// description:	called when this tool is set by a tool controller
/// 
/// parameters:		<aController> the controller that set this tool
/// result:			none
///
/// notes:			subclasses can make use of this message to prepare themselves when they are set if necessary
///
///********************************************************************************************************************

- (void)				toolControllerDidSetTool:(DKToolController*) aController
{
	#pragma unused(aController)
	
	// override to make use of this notification
	
	LogEvent_( kReactiveEvent, @"tool set: %@ by controller: %@", self, aController );
}


///*********************************************************************************************************************
///
/// method:			toolControllerWillUnsetTool:
/// scope:			public instance method
///	overrides:		
/// description:	called when this tool is about to be unset by a tool controller
/// 
/// parameters:		<aController> the controller that set this tool
/// result:			none
///
/// notes:			subclasses can make use of this message to prepare themselves when they are unset if necessary, for
///					example by finishing the work they were doing and cleaning up.
///
///********************************************************************************************************************

- (void)				toolControllerWillUnsetTool:(DKToolController*) aController
{
#pragma unused(aController)
	
	// override to make use of this notification
}


///*********************************************************************************************************************
///
/// method:			toolControllerDidUnsetTool:
/// scope:			public instance method
///	overrides:		
/// description:	called when this tool is unset by a tool controller
/// 
/// parameters:		<aController> the controller that set this tool
/// result:			none
///
/// notes:			subclasses can make use of this message to prepare themselves when they are unset if necessary
///
///********************************************************************************************************************

- (void)				toolControllerDidUnsetTool:(DKToolController*) aController
{
#pragma unused(aController)
	
	// override to make use of this notification
	
	LogEvent_( kReactiveEvent, @"tool unset: %@ by controller: %@", self, aController );
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

- (NSInteger)				mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(p)
	#pragma unused(obj)
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)

	return kDKDrawingNoPart;
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

- (void)			mouseDraggedToPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
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

- (BOOL)			mouseUpAtPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
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
/// method:			isSelectionTool
/// scope:			public instance method
///	overrides:		
/// description:	return whether the tool is some sort of object selection tool
/// 
/// parameters:		none
/// result:			YES if the tool selects objects, NO otherwise
///
/// notes:			this method is used to assist the tool controller in making sensible decisions about certain
///					automatic operations. Subclasses that implement a selection tool should override this to return YES.
///
///********************************************************************************************************************

- (BOOL)				isSelectionTool
{
	return NO;
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

- (void)			setKeyboardEquivalent:(NSString*) str modifierFlags:(NSUInteger) flags
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

- (NSUInteger)		keyboardModifierFlags
{
	return mKeyboardModifiers;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			persistentData
/// scope:			public instance method
///	overrides:		
/// description:	the tool can return arbitrary persistent data that will be stored in the prefs and returned on
///					the next launch.
/// 
/// parameters:		none
/// result:			data, or nil
///
/// notes:			
///
///********************************************************************************************************************

- (NSData*)			persistentData
{
	return nil;
}


///*********************************************************************************************************************
///
/// method:			shouldLoadPersistentData:
/// scope:			public instance method
///	overrides:		
/// description:	on launch, the data that was saved by the previous session will be reloaded
/// 
/// parameters:		the data to reload
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			shouldLoadPersistentData:(NSData*) data
{
#pragma unused(data)	
}



@end
