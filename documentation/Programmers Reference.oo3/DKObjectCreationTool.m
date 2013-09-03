///**********************************************************************************************************************************
///  DKObjectCreationTool.m
///  DrawKit
///
///  Created by graham on 09/06/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKObjectCreationTool.h"
#import "DKObjectDrawingLayer.h"
#import "DKDrawablePath.h"
#import "DKDrawing.h"
#import "LogEvent.h"

#pragma mark Contants (Non-localized)
NSString*	kGCDrawingToolWillMakeNewObjectNotification = @"kGCDrawingToolWillMakeNewObjectNotification";


#pragma mark Static Vars
static DKStyle*	sCreatedObjectsStyle = nil;


#pragma mark -
@implementation DKObjectCreationTool
#pragma mark As a DKObjectCreationTool

///*********************************************************************************************************************
///
/// method:			registerDrawingToolForObject:withName:
/// scope:			public class method
///	overrides:
/// description:	create a tool for an existing object
/// 
/// parameters:		<shape> a drawable object that can be created by the tool - typically a DKDrawableShape
///					<name> the name of the tool to register this with
/// result:			none
///
/// notes:			this method conveniently allows you to create tools for any object you already have. For example
///					if you create a complex shape from others, or make a group of objects, you can turn that object
///					into an interactive tool to make more of the same.
///
///********************************************************************************************************************

+ (void)				registerDrawingToolForObject:(id <NSCopying>) shape withName:(NSString*) name
{
	// creates a drawing tool for the given object and registers it with the name. This quickly allows you to make a tool
	// for any object you already have, give it a name and use it to make more similar objects in the drawing.
	
	NSAssert( shape != nil, @"trying to make a tool for nil shape");
	
	id						cpy = [shape copyWithZone:nil];
	DKObjectCreationTool*	dt = [[[DKObjectCreationTool alloc] initWithPrototypeObject:cpy] autorelease];
	[cpy release];
	
	[DKDrawingTool registerDrawingTool:dt  withName:name];
}


///*********************************************************************************************************************
///
/// method:			setStyleForCreatedObjects:
/// scope:			public class method
///	overrides:
/// description:	set a style to be used for subsequently created objects
/// 
/// parameters:		<aStyle> a style object that will be applied to each new object as it is created
/// result:			none
///
/// notes:			if you set nil, the style set in the prototype object for the individual tool will be used instead.
///
///********************************************************************************************************************

+ (void)				setStyleForCreatedObjects:(DKStyle*) aStyle
{
	[aStyle retain];
	[sCreatedObjectsStyle release];
	sCreatedObjectsStyle = aStyle;
}


///*********************************************************************************************************************
///
/// method:			styleForCreatedObjects
/// scope:			public class method
///	overrides:
/// description:	return a style to be used for subsequently created objects
/// 
/// parameters:		none
/// result:			a style object that will be applied to each new object as it is created, or nil
///
/// notes:			if you set nil, the style set in the prototype object for the individual tool will be used instead.
///
///********************************************************************************************************************

+ (DKStyle*)			styleForCreatedObjects
{
	return sCreatedObjectsStyle;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			initWithPrototypeObject:
/// scope:			public instance method, designated initializer
///	overrides:
/// description:	initialize the tool
/// 
/// parameters:		<aPrototype> an object that will be used as the tool's prototype - each new object created will
///					be a copy of this one.
/// result:			the tool object
///
/// notes:			
///
///********************************************************************************************************************

- (id)					initWithPrototypeObject:(id <NSObject>) aPrototype
{
	self = [super init];
	if (self != nil)
	{
		[self setPrototype:aPrototype];

		if (m_prototypeObject == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			setPrototype:
/// scope:			public instance method
///	overrides:
/// description:	set the object to be copied when the tool created a new one
/// 
/// parameters:		<aPrototype> an object that will be used as the tool's prototype - each new object created will
///					be a copy of this one.
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setPrototype:(id <NSObject>) aPrototype
{
	NSAssert( aPrototype != nil, @"prototype object cannot be nil");
	
	[aPrototype retain];
	[m_prototypeObject release];
	m_prototypeObject = aPrototype;
}


///*********************************************************************************************************************
///
/// method:			prototype
/// scope:			public instance method
///	overrides:
/// description:	return the object to be copied when the tool creates a new one
/// 
/// parameters:		none
/// result:			an object - each new object created will be a copy of this one.
///
/// notes:			
///
///********************************************************************************************************************

- (id)					prototype
{
	return m_prototypeObject;
}


///*********************************************************************************************************************
///
/// method:			objectFromPrototype
/// scope:			public instance method
///	overrides:
/// description:	return a new object copied from the prototype, but with the current class style if there is one
/// 
/// parameters:		none
/// result:			a new object based on the prototype.
///
/// notes:			the returned object is autoreleased
///
///********************************************************************************************************************

- (id)					objectFromPrototype
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCDrawingToolWillMakeNewObjectNotification object:self];
	
	id obj = [[[self prototype] copy] autorelease];
	
	NSAssert( obj != nil, @"couldn't create new object from prototype");
	
	// if there is a class setting for a style, set it. Otherwise use the prototype's style.
	
	if([obj isKindOfClass:[DKDrawableObject class]])
	{
		if([[self class] styleForCreatedObjects] != nil )
		{
			[(DKDrawableObject*)obj setStyle:[[self class] styleForCreatedObjects]];
		}
	}
	return obj;
}


#pragma mark -


///*********************************************************************************************************************
///
/// method:			image
/// scope:			public instance method
///	overrides:
/// description:	return an image showing what the tool creates
/// 
/// parameters:		none
/// result:			an image
///
/// notes:			the image may be used as an icon for this tool in a UI, for example
///
///********************************************************************************************************************

- (NSImage*)			image
{
	return [[self prototype] swatchImageWithSize:kGCDefaultToolSwatchSize];
}


#pragma mark -
#pragma mark As an NSObject

///*********************************************************************************************************************
///
/// method:			dealloc
/// scope:			public instance method
///	overrides:
/// description:	deallocate the tool
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				dealloc
{
	[m_prototypeObject release];
	[super dealloc];
}


#pragma mark -
#pragma mark - As part of DKDrawingTool Protocol

///*********************************************************************************************************************
///
/// method:			toolPerformsUndoableAction
/// scope:			public class method
///	overrides:		DKDrawingTool
/// description:	does the tool ever implement undoable actions?
/// 
/// parameters:		none
/// result:			always returns YES
///
/// notes:			returning YES means that the tool can POTENTIALLY do undoable things, not that it always will.
///
///********************************************************************************************************************

+ (BOOL)				toolPerformsUndoableAction
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			actionName
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	return a string representing what the tool did
/// 
/// parameters:		none
/// result:			a string
///
/// notes:			The registered name of the tool is assumed to be descriptive of the objects it creates, for example
///					"Rectangle", thus this returns "New Rectangle"
///
///********************************************************************************************************************

- (NSString*)			actionName
{
	NSString* s = [NSString stringWithFormat:@"New %@", [self registeredName]];
	return NSLocalizedString( s, @"undo string for new object (type)" );
}


///*********************************************************************************************************************
///
/// method:			cursor
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	return the tool's cursor
/// 
/// parameters:		none
/// result:			the cross-hair cursor
///
/// notes:			
///
///********************************************************************************************************************

- (NSCursor*)			cursor
{
	return [NSCursor crosshairCursor];
}


///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:targetObject:layer:event:delegate:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	handle the initial mouse down
/// 
/// parameters:		<p> the local point where the mouse went down
///					<obj> the target object, if there is one
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			the partcode of object nominated by its class for creating instances of itself interactively
///
/// notes:			starts the creation of an object by copying the prototype and adding it to the layer as a pending
///					object (pending objects are only committed if they are valid after being created). As a side-effect
///					this turns off undo registration temporarily as the initial sizing of the object has no benefit
///					being undone. Note that for some object types, like paths, the object will keep control in their
///					own loop for the entire creation process, finally posting a mouseUp in the original view so that
///					the finalising procedure is carried out.
///
///********************************************************************************************************************

- (int)					mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(obj)
	#pragma unused(event)
	#pragma unused(aDel)
	
	NSAssert( layer != nil, @"layer in creation tool mouse down was nil");
	
	int part = kGCDrawingNoPart;

	// sanity check the layer type - in practice it shouldn't ever be anything else as this is also checked by the tool controller.
		
	if ([layer isKindOfClass:[DKObjectOwnerLayer class]])
	{
		// because this tool creates new objects, ignore the <obj> parameter and just make a new one
		
		m_protoObject = [[self objectFromPrototype] retain];
		
		NSAssert( m_protoObject != nil, @"creation tool couldn't create object from prototype");
		
		// align mouse click to the grid - note, no point checking for ctrl key at this point as mouseDown + ctrl = right click -> menu
		// thus we just accept the current setting for grid snapping applied to the drawing as a whole
		
		p = [[layer drawing] snapToGrid:p withControlFlag:NO];
		
		// turn off recording of undo until we commit the object
		
		[[layer undoManager] disableUndoRegistration];
		
		// set the object's initial size and position (zero size, at the mouse point)
		// the call below to the object's mouseDown method will set up the drag anchoring and offset as needed
		
		LogEvent_( kReactiveEvent, @"creating object %@ at: %@", [m_protoObject description], NSStringFromPoint(p));
		
		[m_protoObject moveToPoint:p];
		[m_protoObject setSize:NSZeroSize];
		
		// the object is initially added as a pending object - this allows it to be created without making undo tasks for
		// the layer being added to. If the creation subsequently fails, the pending object can be discarded and the layer state
		// remains as it was before.
			
		[(DKObjectOwnerLayer*)layer addObjectPendingCreation:m_protoObject];
		
		// let the object know we are about to start:
		
		[m_protoObject creationTool:self willBeginCreationAtPoint:p];
		
		// object creation starts by dragging some part - the object class can tell us what part to use here, we shouldn't
		// rely on hit-testing it directly because the result can be ambiguous for such a small object size:
		
		part = [[m_protoObject class] initialPartcodeForObjectCreation];
		[m_protoObject mouseDownAtPoint:p inPart:part event:event];
	}
	
	// return the partcode for the new object, so that we get it passed back in subsequent calls
	
	return part;
}


///*********************************************************************************************************************
///
/// method:			mouseDraggedToPoint:partCode:layer:event:delegate:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	handle the mouse dragged event
/// 
/// parameters:		<p> the local point where the mouse has been dragged to
///					<partCode> the partcode returned by the mouseDown method
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			none
///
/// notes:			keep dragging out the object
///
///********************************************************************************************************************

- (void)				mouseDraggedToPoint:(NSPoint) p partCode:(int) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(obj)
	#pragma unused(layer)
	#pragma unused(aDel)
	
	if ( m_protoObject != nil )
		[m_protoObject mouseDraggedAtPoint:p inPart:pc event:event];
}


///*********************************************************************************************************************
///
/// method:			mouseUpAtPoint:partCode:layer:event:delegate:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	handle the mouse up event
/// 
/// parameters:		<p> the local point where the mouse went up
///					<partCode> the partcode returned by the mouseDown method
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			YES if the tool did something undoable, NO otherwise
///
/// notes:			this finalises he object creation by calling the -objectIsValid method. Valid means that the path
///					is not empty or zero-sized for example. If the object is valid it is committed to the layer after
///					re-enabling undo. Invalid objects are simply discarded. The delegate is called to signal an undoable
///					task is about to be made.
///
///********************************************************************************************************************

- (BOOL)				mouseUpAtPoint:(NSPoint) p partCode:(int) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	NSAssert( layer != nil, @"layer was nil in creation tool mouse up");
	
	BOOL result = YES;
	BOOL controlKey = ([event modifierFlags] & NSControlKeyMask) != 0;
	p = [[layer drawing] snapToGrid:p withControlFlag:controlKey];

	[m_protoObject mouseUpAtPoint:p inPart:pc event:event];
	
	LogEvent_(kReactiveEvent, @"object creation tool completed (mouse up)");
	
	// let the object know we are finishing, whether it is valid or not
	
	[m_protoObject creationTool:self willEndCreationAtPoint:p];
	
	// if the object created is not valid, the pending add to the layer needs to be
	// aborted. Otherwise the object is committed to the layer
	
	if (![m_protoObject objectIsValid])
	{
		[(DKObjectOwnerLayer*)layer removePendingObject];
		LogEvent_( kReactiveEvent, @"object invalid - not committed to layer");
		result = NO;

		// turn undo back on
		
		[[layer undoManager] enableUndoRegistration];
	}
	else
	{
		// a valid object was made, so commit it to the layer and select it
		// turn undo back on and commit the object
		
		[[layer undoManager] enableUndoRegistration];
		[aDel toolWillPerformUndoableAction:self];
		
		[(DKObjectDrawingLayer*)layer commitPendingObjectWithUndoActionName:[self actionName]];
		[(DKObjectDrawingLayer*)layer replaceSelectionWithObject:m_protoObject];
		
		LogEvent_( kReactiveEvent, @"object OK - committed to layer");
	}
	
	[m_protoObject release];
	m_protoObject = nil;
	
	return result;
}


- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	return [aLayer isKindOfClass:[DKObjectDrawingLayer class]];
}


@end
