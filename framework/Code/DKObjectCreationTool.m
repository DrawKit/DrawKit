///**********************************************************************************************************************************
///  DKObjectCreationTool.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 09/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKObjectCreationTool.h"
#import "DKObjectDrawingLayer.h"
#import "DKDrawablePath.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKStyleRegistry.h"
#import "DKToolController.h"
#import "LogEvent.h"

#pragma mark Contants (Non-localized)
NSString*	kDKDrawingToolWillMakeNewObjectNotification = @"kDKDrawingToolWillMakeNewObjectNotification";
NSString*	kDKDrawingToolCreatedObjectsStyleDidChange	= @"kDKDrawingToolCreatedObjectsStyleDidChange";

#pragma mark Static Vars
static DKStyle*	sCreatedObjectsStyle = nil;


@interface DKObjectCreationTool (Private)

- (BOOL)	finishCreation:(DKToolController*) controller;

@end

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
	if(![aStyle isEqualToStyle:sCreatedObjectsStyle])
	{
		//NSLog(@"setting style for created objects = '%@'", [aStyle name]);
		
		[aStyle retain];
		[sCreatedObjectsStyle release];
		sCreatedObjectsStyle = aStyle;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingToolCreatedObjectsStyleDidChange object:self];
	}
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
		[self setStylePickupEnabled:YES];

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
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingToolWillMakeNewObjectNotification object:self];
	
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


- (void)				setStyle:(DKStyle*) aStyle
{
	// sets the style for the prototype (an dhence subsequently created objects). This setting is overridden by
	// a style set for the class as a whole.
	
	if([[self prototype] respondsToSelector:_cmd])
		[(DKDrawableObject*)[self prototype] setStyle:aStyle];
}


- (DKStyle*)			style
{
	// returns the style that will be used by this tool. That is the prototype's style or the general style applied by the class.
	
	if([[self class] styleForCreatedObjects] != nil )
		return [[self class] styleForCreatedObjects];
	else
		return [(DKDrawableObject*)[self prototype] style];
}


- (void)				setStylePickupEnabled:(BOOL) pickup
{
	mEnableStylePickup = pickup;
}


- (BOOL)				stylePickupEnabled
{
	return mEnableStylePickup;
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
	return [[self prototype] swatchImageWithSize:kDKDefaultToolSwatchSize];
}


///*********************************************************************************************************************
///
/// method:			finishCreation
/// scope:			private instance method
///	overrides:
/// description:	complete the object creation cleanly
/// 
/// parameters:		none
/// result:			YES if undo task generated, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				finishCreation:(DKToolController*) controller
{
	BOOL result = NO;
	
	if( m_protoObject )
	{
		DKObjectOwnerLayer* layer = (DKObjectOwnerLayer*)[controller activeLayer];
		
		// let the object know we are finishing, whether it is valid or not
		@try
		{
			[m_protoObject mouseUpAtPoint:mLastPoint inPart:mPartcode event:[NSApp currentEvent]];
			[m_protoObject creationTool:self willEndCreationAtPoint:mLastPoint];
		}
		@catch( NSException* e )
		{
			[m_protoObject release];
			m_protoObject = nil;
		}
		
		// if the object created is not valid, the pending add to the layer needs to be
		// aborted. Otherwise the object is committed to the layer
		
		if (![m_protoObject objectIsValid])
		{
			[layer removePendingObject];
			LogEvent_( kReactiveEvent, @"object invalid - not committed to layer");
			result = NO;
			
			// should be unnecessary as undo disabled while tool creating, but in case code turned it on...
			
			[[layer undoManager] removeAllActionsWithTarget:m_protoObject];
			
			[m_protoObject release];
			m_protoObject = nil;

			// turn undo back on
			
			if(![[layer undoManager] isUndoRegistrationEnabled])
				[[layer undoManager] enableUndoRegistration];
		}
		else
		{
			// a valid object was made, so commit it to the layer and select it
			// turn undo back on and commit the object
			
			if(![[layer undoManager] isUndoRegistrationEnabled])
				[[layer undoManager] enableUndoRegistration];
			
			[controller toolWillPerformUndoableAction:self];
			
			[(DKObjectDrawingLayer*)layer recordSelectionForUndo];
			[(DKObjectDrawingLayer*)layer commitPendingObjectWithUndoActionName:[self actionName]];
			[(DKObjectDrawingLayer*)layer replaceSelectionWithObject:m_protoObject];
			[(DKObjectDrawingLayer*)layer commitSelectionUndoWithActionName:[self actionName]];
			
			LogEvent_( kReactiveEvent, @"object OK - committed to layer");
			
			[m_protoObject release];
			m_protoObject = nil;
			
			result = YES;
		}
	}
	
	return result;
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
#pragma mark - As a DKDrawingTool

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
/// notes:			if the tool has a set style, it is archived and returned so that it can be restored to the same
///					style next session.
///
///********************************************************************************************************************

- (NSData*)			persistentData
{
	if([self style])
		return [NSKeyedArchiver archivedDataWithRootObject:[self style]];
	else
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
	NSAssert( data != nil, @"data was nil");
	
	@try
	{
		DKStyle* aStyle = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
		if( aStyle )
		{
			// this style may be registered, which means we must merge it with the registry correctly
			
			if([aStyle requiresRemerge])
			{
				NSSet* set = [NSSet setWithObject:aStyle];
				set = [DKStyleRegistry mergeStyles:set inCategories:nil options:kDKReturnExistingStyles mergeDelegate:nil];
				
				aStyle = [set anyObject];
				[aStyle clearRemergeFlag];
			}
			
			//NSLog(@"restoring style '%@' to '%@'", [aStyle name], [self registeredName]);
			
			[self setStyle:aStyle];
		}
	}
	@catch( NSException* excp )
	{
		NSLog(@"Tool '%@' was unable to load the style - will use default. Exception: %@", [self registeredName], excp );
		
		// ignore exception
		
	}
}


///*********************************************************************************************************************
///
/// method:			toolControllerWillUnsetTool:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	clean up when tool is switched out
/// 
/// parameters:		<aController> the tool controller
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				toolControllerWillUnsetTool:(DKToolController*) aController
{
	//NSLog(@"unsetting %@, proto = %@", self, m_protoObject);
	
	[self finishCreation:aController];
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
	NSString* objectName = [self registeredName];
	NSString* s = [NSString stringWithFormat:@"New %@", objectName];
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

- (NSInteger)					mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(aDel)
	
	NSAssert( layer != nil, @"layer in creation tool mouse down was nil");
	
	mPartcode = kDKDrawingNoPart;
	mDidPickup = NO;
	m_protoObject = nil;
	
	// sanity check the layer type - in practice it shouldn't ever be anything else as this is also checked by the tool controller.
		
	if ([layer isKindOfClass:[DKObjectOwnerLayer class]])
	{
		// this tool may do a style pickup if enabled. This allows a command-click to choose the style of the clicked object
		
		BOOL pickUpStyle = (obj != nil) && [self stylePickupEnabled] && (([event modifierFlags] & NSCommandKeyMask) != 0);
		
		if( pickUpStyle )
		{
			DKStyle* style = [obj style];
			[self setStyle:style];
			mDidPickup = YES;
			return mPartcode;
		}
		
		// because this tool creates new objects, ignore the <obj> parameter and just make a new one
		
		if( m_protoObject == nil )
			m_protoObject = [[self objectFromPrototype] retain];
		
		NSAssert( m_protoObject != nil, @"creation tool couldn't create object from prototype");
		
		// turn off recording of undo until we commit the object
		
		[[layer undoManager] disableUndoRegistration];
		
		@try
		{
			// the object is initially added as a pending object - this allows it to be created without making undo tasks for
			// the layer being added to. If the creation subsequently fails, the pending object can be discarded and the layer state
			// remains as it was before.
				
			[(DKObjectOwnerLayer*)layer addObjectPendingCreation:m_protoObject];

			// align mouse click to the grid/guides - note, no point checking for ctrl key at this point as mouseDown + ctrl = right click -> menu
			// thus we just accept the current setting for grid snapping applied to the drawing as a whole
			
			p = [m_protoObject snappedMousePoint:p forSnappingPointsWithControlFlag:NO];
			
			// set the object's initial size and position (zero size, at the mouse point)
			// the call below to the object's mouseDown method will set up the drag anchoring and offset as needed
			
			LogEvent_( kReactiveEvent, @"creating object %@ at: %@", [m_protoObject description], NSStringFromPoint(p));
			
			[m_protoObject setLocation:p];
			[m_protoObject setSize:NSZeroSize];
			
			// let the object know we are about to start:
			
			[m_protoObject creationTool:self willBeginCreationAtPoint:p];

			// object creation starts by dragging some part - the object class can tell us what part to use here, we shouldn't
			// rely on hit-testing it directly because the result can be ambiguous for such a small object size:
			
			mPartcode = [[m_protoObject class] initialPartcodeForObjectCreation];
			[m_protoObject mouseDownAtPoint:p inPart:mPartcode event:event];
		}
		@catch( NSException* excp )
		{
			[m_protoObject release];
			m_protoObject = nil;
			
			[[layer undoManager] enableUndoRegistration];
			
			@throw;
		}
	}
	
	// return the partcode for the new object, so that we get it passed back in subsequent calls

	return mPartcode;
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

- (void)				mouseDraggedToPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(layer)
	#pragma unused(aDel)
	
	if ( m_protoObject != nil && !mDidPickup)
	{
		[m_protoObject mouseDraggedAtPoint:p inPart:pc event:event];
	
		mLastPoint = p;
	}
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

- (BOOL)				mouseUpAtPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
#pragma unused(pc)
	NSAssert( layer != nil, @"layer was nil in creation tool mouse up");
	
	if( mDidPickup )
	{
		mDidPickup = NO;
		return NO;
	}
	
	BOOL controlKey = ([event modifierFlags] & NSControlKeyMask) != 0;
	p = [[layer drawing] snapToGrid:p withControlFlag:controlKey];
	mLastPoint = p;

	return [self finishCreation:aDel];
}


- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	return [aLayer isKindOfClass:[DKObjectDrawingLayer class]] && ![aLayer locked] && [aLayer visible];
}


@end
