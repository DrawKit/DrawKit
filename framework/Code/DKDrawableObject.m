///**********************************************************************************************************************************
///  DKDrawableObject.m
///  DrawKit ¬¨¬©2005-2008 Apptree.net
///
///  Created by graham on 11/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawableObject.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "NSDictionary+DeepCopy.h"
#import "DKGeometryUtilities.h"
#import "LogEvent.h"
#import "NSAffineTransform+DKAdditions.h"
#import "DKDrawKitMacros.h"
#import "NSColor+DKAdditions.h"
#import "NSBezierPath+Combinatorial.h"
#import "DKDrawableObject+Metadata.h"
#import "DKDrawableContainerProtocol.h"
#import "DKObjectDrawingLayer+Alignment.h"
#import "DKAuxiliaryMenus.h"
#import "DKSelectionPDFView.h"
#import "DKPasteboardInfo.h"


#ifdef qIncludeGraphicDebugging
#import "DKDrawingView.h"
#endif

#pragma mark Contants (Non-localized)
NSString*		kDKDrawableDidChangeNotification			= @"kDKDrawableDidChangeNotification";
NSString*		kDKDrawableStyleWillBeDetachedNotification	= @"kDKDrawableStyleWillBeDetachedNotification";
NSString*		kDKDrawableStyleWasAttachedNotification		= @"kDKDrawableStyleWasAttachedNotification";
NSString*		kDKDrawableDoubleClickNotification			= @"kDKDrawableDoubleClickNotification";
NSString*		kDKDrawableSubselectionChangedNotification	= @"kDKDrawableSubselectionChangedNotification";

NSString*		kDKDrawableOldStyleKey		= @"old_style";
NSString*		kDKDrawableNewStyleKey		= @"new_style";
NSString*		kDKDrawableClickedPointKey	= @"click_point";

NSString*		kDKGhostColourPreferencesKey = @"kDKGhostColourPreferencesKey";
NSString*		kDKDragFeedbackEnabledPreferencesKey = @"kDKDragFeedbackEnabledPreferencesKey";

NSString*		kDKDrawableCachedImageKey	= @"DKD_Cached_Img";


#pragma mark Static vars

static NSColor*			s_ghostColour = nil;
static NSDictionary*	s_interconversionTable = nil;

#pragma mark -
@implementation DKDrawableObject
#pragma mark As a DKDrawableObject

///*********************************************************************************************************************
///
/// method:			displaysSizeInfoWhenDragging
/// scope:			class method
/// overrides:		
/// description:	return whether an info floater is displayed when resizing an object
/// 
/// parameters:		none 
/// result:			YES to show the info, NO to not show it
///
/// notes:			size info is width and height
///
///********************************************************************************************************************

+ (BOOL)				displaysSizeInfoWhenDragging
{
	return ![[NSUserDefaults standardUserDefaults] boolForKey:kDKDragFeedbackEnabledPreferencesKey];
}



///*********************************************************************************************************************
///
/// method:			setDisplaysSizeInfoWhenDragging:
/// scope:			class method
/// overrides:		
/// description:	set whether an info floater is displayed when resizing an object
/// 
/// parameters:		<doesDisplay> YES to show the info, NO to not show it
/// result:			none
///
/// notes:			size info is width and height
///
///********************************************************************************************************************

+ (void)				setDisplaysSizeInfoWhenDragging:(BOOL) doesDisplay
{
	[[NSUserDefaults standardUserDefaults] setBool:!doesDisplay forKey:kDKDragFeedbackEnabledPreferencesKey];
}


///*********************************************************************************************************************
///
/// method:			unionOfBoundsOfDrawablesInArray:
/// scope:			class method
/// overrides:		
/// description:	returns the union of the bounds of the objects in the array
/// 
/// parameters:		<array> a list of DKDrawable objects
/// result:			a rect, the union of the bounds of all objects
///
/// notes:			utility method as this is a very common task - throws exception if any object in the list is
///					not a DKDrawableObject or subclass thereof
///
///********************************************************************************************************************

+ (NSRect)				unionOfBoundsOfDrawablesInArray:(NSArray*) array
{
	NSAssert( array != nil, @"array cannot be nil");
	
	NSRect			u = NSZeroRect;
	NSEnumerator*	iter = [array objectEnumerator];
	id				dko;
	
	while(( dko = [iter nextObject]))
	{
		if (![dko isKindOfClass:[DKDrawableObject class]])
			[NSException raise:NSInternalInconsistencyException format:@"objects must all derive from DKDrawableObject"];
			
		u = UnionOfTwoRects( u, [dko bounds]);
	}
	
	return u;
}


///*********************************************************************************************************************
///
/// method:			pasteboardTypesForOperation:
/// scope:			public class method
/// overrides:
/// description:	return pasteboard types that this object class can receive
/// 
/// parameters:		<op> set of flags indicating what this operation the types relate to. Currently objects can only
///					receive drags so this is the only flag that should be passed
/// result:			an array of pasteboard types
///
/// notes:			default method does nothing - subclasses will override if they can receive a drag
///
///********************************************************************************************************************

+ (NSArray*)		pasteboardTypesForOperation:(DKPasteboardOperationType) op
{
	#pragma unused(op)
	return nil;
}


///*********************************************************************************************************************
///
/// method:			initialPartcodeForObjectCreation
/// scope:			public class method
/// overrides:
/// description:	return the partcode that should be used by tools when initially creating a new object
/// 
/// parameters:		none
/// result:			a partcode value
///
/// notes:			default method does nothing - subclasses must override this and supply the right partcode value
///					appropriate to the class. The client of this method is DKObjectCreationTool.
///
///********************************************************************************************************************

+ (NSInteger)				initialPartcodeForObjectCreation
{
	return kDKDrawingNoPart;
}


///*********************************************************************************************************************
///
/// method:			isGroupable
/// scope:			public class method
/// overrides:
/// description:	return whether obejcts of this class can be grouped
/// 
/// parameters:		none
/// result:			YES if objects can be included in groups
///
/// notes:			default is YES. see also [DKShapeGroup objectsAvailableForGroupingFromArray];
///********************************************************************************************************************

+ (BOOL)				isGroupable
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			nativeObjectsFromPasteboard:
/// scope:			public class method
///	overrides:
/// description:	unarchive a list of objects from the pasteboard, if possible
/// 
/// parameters:		<pb> the pasteboard to take objects from
/// result:			a list of objects
///
/// notes:			this factors the dearchiving of objects from the pasteboard. If the pasteboard does not contain
///					any valid types, nil is returned
///
///********************************************************************************************************************

+ (NSArray*)		nativeObjectsFromPasteboard:(NSPasteboard*) pb
{
	NSData*	 pbdata = [pb dataForType:kDKDrawableObjectPasteboardType];
	NSArray* objects = nil;
	
	if ( pbdata != nil )
		objects = [NSKeyedUnarchiver unarchiveObjectWithData:pbdata];

	return objects;
}


///*********************************************************************************************************************
///
/// method:			countOfNativeObjectsOnPasteboard:
/// scope:			public class method
///	overrides:
/// description:	return the number of native objects held by the pasteboard
/// 
/// parameters:		<pb> the pasteboard to read from
/// result:			a count
///
/// notes:			this efficiently queries the info object rather than dearchiving the objects themselves. A value
///					of 0 means no native objects on the pasteboard (naturally)
///
///********************************************************************************************************************

+ (NSUInteger)			countOfNativeObjectsOnPasteboard:(NSPasteboard*) pb
{
	DKPasteboardInfo* info = [DKPasteboardInfo pasteboardInfoWithPasteboard:pb];
	return [info count];
}


///*********************************************************************************************************************
///
/// method:			setGhostColour:
/// scope:			public class method
///	overrides:
/// description:	set the outline colour to use when drawing objects in their ghosted state
/// 
/// parameters:		<ghostColour> the colour to use
/// result:			none
///
/// notes:			the ghost colour is persistent, stored using the kDKGhostColourPreferencesKey key
///
///********************************************************************************************************************

+ (void)				setGhostColour:(NSColor*) ghostColour
{
	[ghostColour retain];
	[s_ghostColour release];
	s_ghostColour = ghostColour;
	
	[[NSUserDefaults standardUserDefaults] setObject:[ghostColour hexString] forKey:kDKGhostColourPreferencesKey];
}


///*********************************************************************************************************************
///
/// method:			ghostColour
/// scope:			public class method
///	overrides:
/// description:	return the outline colour to use when drawing objects in their ghosted state
/// 
/// parameters:		none
/// result:			the colour to use
///
/// notes:			the default is light gray
///
///********************************************************************************************************************

+ (NSColor*)			ghostColour
{
	if( s_ghostColour == nil )
	{
		NSColor* ghost = [NSColor colorWithHexString:[[NSUserDefaults standardUserDefaults] stringForKey:kDKGhostColourPreferencesKey]];
		
		if( ghost == nil )
			ghost = [NSColor lightGrayColor];
		
		[self setGhostColour:ghost];
	}
	
	return s_ghostColour;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			interconversionTable
/// scope:			public class method
///	overrides:
/// description:	return the interconversion table
/// 
/// parameters:		none
/// result:			the table (a dictionary)
///
/// notes:			the interconversion table is used when drawables are converted to another type. The table can be
///					customised to permit conversions to subclasses or other types of object. The default is nil,
///					which simply passes through the requested type unchanged.
///
///********************************************************************************************************************

+ (NSDictionary*)		interconversionTable
{
	return s_interconversionTable;
}


///*********************************************************************************************************************
///
/// method:			setInterconversionTable:
/// scope:			public class method
///	overrides:
/// description:	return the interconversion table
/// 
/// parameters:		<icTable> a dictionary containing mappings from standard base classes to custom classes
/// result:			none
///
/// notes:			the interconversion table is used when drawables are converted to another type. The table can be
///					customised to permit conversions to subclasses of the requested class. The default is nil,
///					which simply passes through the requested type unchanged. The dictionary consists of the base class
///					as a string, and returns the class to use in place of that type.
///
///********************************************************************************************************************

+ (void)				setInterconversionTable:(NSDictionary*) icTable
{
	[icTable retain];
	[s_interconversionTable release];
	s_interconversionTable = icTable;
}


///*********************************************************************************************************************
///
/// method:			classForConversionRequestFor:
/// scope:			public class method
///	overrides:
/// description:	return the class to use in place of the given class when performing a conversion
/// 
/// parameters:		<aClass> the base class which we are converting TO.
/// result:			the actual object class to use for that conversion.
///
/// notes:			the default passes through the input class unchanged. By customising the conversion table, other
///					classes can be substituted when performing a conversion.
///
///********************************************************************************************************************

+ (Class)				classForConversionRequestFor:(Class) aClass
{
	NSAssert( aClass != Nil, @"class was Nil when requesting a conversion class");
	
	Class icClass = [[self interconversionTable] objectForKey:NSStringFromClass(aClass)];
	
	// if not found, return input unchanged
	
	if( icClass == nil )
		return aClass;
	else
	{
		NSAssert2([icClass isSubclassOfClass:aClass], @"conversion failed - %@ must be a subclass of %@", icClass, aClass );
		return icClass;
	}
}


///*********************************************************************************************************************
///
/// method:			substituteClass:forClass:
/// scope:			public class method
///	overrides:
/// description:	sets the class to use in place of the a base class when performing a conversion
/// 
/// parameters:		<newClass> the class which we are converting TO
///					<baseClass> the base class
/// result:			none
///
/// notes:			this is only used when performing conversions, not when creating new objects in other circumstances.
///					<newClass> must be a subclass of <baseClass>
///
///********************************************************************************************************************

+ (void)				substituteClass:(Class) newClass forClass:(Class) baseClass
{
	NSAssert( newClass != Nil, @"class was Nil");
	NSAssert( baseClass != Nil, @"base class was Nil");
	
	if([newClass isSubclassOfClass:baseClass])
	{
		NSMutableDictionary* dict = [[self interconversionTable] mutableCopy];
			
		if( dict == nil )
			dict = [[NSMutableDictionary alloc] init];
		
		[dict setObject:newClass forKey:NSStringFromClass(baseClass)];
		[self setInterconversionTable:dict];
		[dict release];
	}
	else
		[NSException raise:NSInternalInconsistencyException format:@"you must only substitute a subclass for the base class"];
}


///*********************************************************************************************************************
///
/// method:			initWithStyle:
/// scope:			public instance method; designated initializer
/// overrides:
/// description:	initializes the drawable to have the style given
/// 
/// parameters:		<aStyle> the initial style for the object
/// result:			the object
///
/// notes:			you can use -init to initialize using the default style. Note that if creating many objects at
///					once, supplying the style when initializing is more efficient.
///
///********************************************************************************************************************

- (id)					initWithStyle:(DKStyle*) aStyle
{
	self = [super init];
	if( self )
	{
		m_visible = YES;
		m_snapEnable = YES;
		
		[self setStyle:aStyle];
	}
	
	return self;
}


#pragma mark -
#pragma mark - relationships

///*********************************************************************************************************************
///
/// method:			layer
/// scope:			public instance method
/// overrides:
/// description:	returns the layer that this object ultimately belongs to
/// 
/// parameters:		none
/// result:			the containing layer
///
/// notes:			this returns the layer even if container isn't the layer, by recursing up the tree as needed
///
///********************************************************************************************************************

- (DKObjectOwnerLayer*)	layer
{
	return (DKObjectOwnerLayer*)[[self container] layer];
}


///*********************************************************************************************************************
///
/// method:			drawing
/// scope:			public instance method
/// overrides:
/// description:	returns the drawing that owns this object's layer
/// 
/// parameters:		none
/// result:			the drawing
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawing*)		drawing
{
	return [[self container] drawing];
}


///*********************************************************************************************************************
///
/// method:			undoManager
/// scope:			public instance method
/// overrides:
/// description:	returns the undo manager used to handle undoable actions for this object
/// 
/// parameters:		none
/// result:			the undo manager in use
///
/// notes:			
///
///********************************************************************************************************************

- (NSUndoManager*)	undoManager
{
	return [[self drawing] undoManager];
}


///*********************************************************************************************************************
///
/// method:			parent
/// scope:			public instance method
/// overrides:
/// description:	returns the immediate parent of this object
/// 
/// parameters:		none
/// result:			the object's parent
///
/// notes:			a parent is usually a layer, same as owner - but can be a group if the object is grouped
///
///********************************************************************************************************************

- (id<DKDrawableContainer>)	container
{
	return mContainerRef;
}


///*********************************************************************************************************************
///
/// method:			setParent:
/// scope:			private instance method
/// overrides:
/// description:	sets the immediate parent of this object (a DKObjectOwnerLayer layer, typically)
/// 
/// parameters:		<aContainer> the immediate container of this object
/// result:			none
///
/// notes:			the container itself is responsible for setting this - applications should not use this method. An
///					object's container is usually the layer, but can be a group. <aContainer> is not retained. Note that
///					a valid container is required for the object to locate an undo manager, so nothing is undoable
///					until this is set to a valid object that can supply one.
///
///********************************************************************************************************************

- (void)			setContainer:(id<DKDrawableContainer>) aContainer
{
	if ( aContainer != mContainerRef )
	{
		// nil is permitted, but if not nil, must conform to container protocol
		
		if( aContainer )
		{
			NSAssert1([aContainer conformsToProtocol:@protocol(DKDrawableContainer)], @"object passed (%@) does not conform to the DKDrawableContainer protocol", aContainer);
		}
		
		mContainerRef = aContainer;
		
		// make sure any attached style is aware of the undo manager used by the drawing/layers
		
		if( aContainer )
			[[self style] setUndoManager:[self undoManager]];
		else
			[[self style] setUndoManager:nil];
	}
}


///*********************************************************************************************************************
///
/// method:			indexInContainer
/// scope:			public instance method
/// overrides:
/// description:	returns the index position of this object in its container layer
/// 
/// parameters:		none
/// result:			the index position
///
/// notes:			this is intended for debugging and should generally be avoided by user code.
///
///********************************************************************************************************************

- (NSUInteger)			indexInContainer
{
	if([[self container] respondsToSelector:@selector(indexOfObject:)])
		return [[self container] indexOfObject:self];
	else
		return NSNotFound;
}



#pragma mark -
#pragma mark - as part of the DKStorableObject protocol

///*********************************************************************************************************************
///
/// method:			setIndex:
/// scope:			public instance method
/// overrides:		part of the DKStorableObject protocol - exclusively for the use of the storage
/// description:	where object storage stores the Z-index in the object itself, this is used to set it.
/// 
/// parameters:		<zIndex> the desired Z value for the object
/// result:			none
///
/// notes:			note that this doesn't allow the Z-index to be changed, but merely recorded. This method should only
///					be used by storage methods internal to DK and not by external client code. See DKObjectStorageProtocol.h
///
///********************************************************************************************************************

- (void)				setIndex:(NSUInteger) zIndex
{
	mZIndex = zIndex;
}


///*********************************************************************************************************************
///
/// method:			index
/// scope:			public instance method
/// overrides:		part of the DKStorableObject protocol - exclusively for the use of the storage
/// description:	where object storage stores the Z-index in the object itself, this returns it.
/// 
/// parameters:		none
/// result:			the Z value for the object
///
/// notes:			See DKObjectStorageProtocol.h
///
///********************************************************************************************************************

- (NSUInteger)			index
{
	return mZIndex;
}


///*********************************************************************************************************************
///
/// method:			storage
/// scope:			public instance method
/// overrides:		part of the DKStorableObject protocol - exclusively for the use of the storage
/// description:	returns the reference to the object's storage
/// 
/// parameters:		none
/// result:			the object's storage
///
/// notes:			See DKObjectStorageProtocol.h
///
///********************************************************************************************************************

- (id<DKObjectStorage>)		storage
{
	return mStorageRef;
}


///*********************************************************************************************************************
///
/// method:			setStorage:
/// scope:			public instance method
/// overrides:		part of the DKStorableObject protocol - exclusively for the use of the storage
/// description:	returns the reference to the object's storage
/// 
/// parameters:		<storage> the object's storage
/// result:			none
///
/// notes:			See DKObjectStorageProtocol.h. Not for client code.
///
///********************************************************************************************************************

- (void)							setStorage:(id<DKObjectStorage>) storage
{
	mStorageRef = storage;
}


///*********************************************************************************************************************
///
/// method:			setMarked:
/// scope:			public instance method
/// overrides:		part of the DKStorableObject protocol - exclusively for the use of the storage
/// description:	marks the object
/// 
/// parameters:		<markIt> a flag
/// result:			none
///
/// notes:			See DKObjectStorageProtocol.h. Not for client code.
///
///********************************************************************************************************************

- (void)							setMarked:(BOOL) markIt
{
	mMarked = markIt;
}


///*********************************************************************************************************************
///
/// method:			isMarked
/// scope:			public instance method
/// overrides:		part of the DKStorableObject protocol - exclusively for the use of the storage
/// description:	marks the object
/// 
/// parameters:		none
/// result:			a flag
///
/// notes:			See DKObjectStorageProtocol.h. Not for client code.
///
///********************************************************************************************************************

- (BOOL)							isMarked
{
	return mMarked;
}



#pragma mark -
#pragma mark - state
///*********************************************************************************************************************
///
/// method:			setVisible:
/// scope:			public instance method
/// overrides:
/// description:	sets whether the object is drawn (visible) or not
/// 
/// parameters:		<vis> YES to show the object, NO to hide it
/// result:			none
///
/// notes:			The visible property is independent of the locked property, i.e. locked objects may be hidden & shown.
///
///********************************************************************************************************************

- (void)			setVisible:(BOOL) vis
{
	if ( m_visible != vis )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setVisible:m_visible];
		m_visible = vis;
		[self notifyVisualChange];
		[self notifyStatusChange];
		
		[[self storage] objectDidChangeVisibility:self];

		[[self undoManager] setActionName:vis? NSLocalizedString(@"Show", @"undo action for single object show") :
		 NSLocalizedString(@"Hide", @"undo action for single object hide")];
	}
}


///*********************************************************************************************************************
///
/// method:			visible
/// scope:			public instance method
/// overrides:
/// description:	is the object visible?
/// 
/// parameters:		none
/// result:			YES if visible, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			visible
{
	return m_visible;
}


///*********************************************************************************************************************
///
/// method:			setLocked:
/// scope:			public instance method
/// overrides:
/// description:	sets whether the object is locked or not
/// 
/// parameters:		<locked> YES to lock, NO to unlock
/// result:			none
///
/// notes:			locked objects are visible but can't be edited
///
///********************************************************************************************************************

- (void)			setLocked:(BOOL) locked
{
	if ( m_locked != locked )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setLocked:m_locked];
		m_locked = locked;
		[self notifyVisualChange];		// on the assumption that the locked state is shown differently
		[self notifyStatusChange];
		[[self undoManager] setActionName:locked? NSLocalizedString(@"Lock", @"undo action for single object lock") :
													NSLocalizedString(@"Unlock", @"undo action for single object unlock")];
	}
}


///*********************************************************************************************************************
///
/// method:			locked
/// scope:			public instance method
/// overrides:
/// description:	is the object locked?
/// 
/// parameters:		none
/// result:			YES if locked, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			locked
{
	return m_locked;
}


///*********************************************************************************************************************
///
/// method:			setLocationLocked:
/// scope:			public instance method
/// overrides:
/// description:	sets whether the object's location is locked or not
/// 
/// parameters:		<lockLocation> YES to lock location, NO to unlock
/// result:			none
///
/// notes:			location may be locked independently of the general lock
///
///********************************************************************************************************************

- (void)				setLocationLocked:(BOOL) lockLocation
{
	if ( mLocationLocked != lockLocation )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setLocationLocked:mLocationLocked];
		mLocationLocked = lockLocation;
		[self notifyVisualChange];		// on the assumption that the state is shown differently
		[self notifyStatusChange];
	}
}


///*********************************************************************************************************************
///
/// method:			locationLocked:
/// scope:			public instance method
/// overrides:
/// description:	whether the object's location is locked or not
/// 
/// parameters:		none 
/// result:			YES if locked location, NO to unlock
///
/// notes:			location may be locked independently of the general lock
///
///********************************************************************************************************************

- (BOOL)				locationLocked
{
	return mLocationLocked;
}


///*********************************************************************************************************************
///
/// method:			setMouseSnappingEnabled:
/// scope:			public instance method
/// overrides:
/// description:	enable mouse snapping
/// 
/// parameters:		<ems> YES to enable snapping (default), NO to disable it
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			setMouseSnappingEnabled:(BOOL) ems
{
	m_snapEnable = ems;
}


///*********************************************************************************************************************
///
/// method:			mouseSnappingEnabled
/// scope:			public instance method
/// overrides:
/// description:	is mouse snapping enabled?
/// 
/// parameters:		none
/// result:			YES if will snap on mouse actions, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			mouseSnappingEnabled
{
	return m_snapEnable;
}



///*********************************************************************************************************************
///
/// method:			setGhosted:
/// scope:			public instance method
/// overrides:
/// description:	set whether the object is ghosted rather than with its full style
/// 
/// parameters:		<ghosted> YES to ghost the object, NO to unghost it
/// result:			none
///
/// notes:			ghosting is an alternative to hiding - ghosted objects are still visible but are only drawn using
///					a thin outline. See also: +setGhostingColour:
///
///********************************************************************************************************************

- (void)				setGhosted:(BOOL) ghosted
{
	if ( mGhosted != ghosted && ![self locked])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setGhosted:mGhosted];
		mGhosted = ghosted;
		[self notifyVisualChange];
		[self notifyStatusChange];

		[[self undoManager] setActionName:ghosted? NSLocalizedString(@"Ghost", @"undo action for single object ghost") :
		 NSLocalizedString(@"Unghost", @"undo action for single object unghost")];
	}
}


///*********************************************************************************************************************
///
/// method:			isGhosted
/// scope:			public instance method
/// overrides:
/// description:	retuirn whether the object is ghosted rather than with its full style
/// 
/// parameters:		none
/// result:			YES if the object is ghosted, NO otherwise
///
/// notes:			ghosting is an alternative to hiding - ghosted objects are still visible but are only drawn using
///					a thin outline. See also: +setGhostingColour:
///
///********************************************************************************************************************

- (BOOL)				isGhosted
{
	return mGhosted;
}


- (BOOL)			isTrackingMouse
{
	return m_inMouseOp;
}


- (void)			setTrackingMouse:(BOOL) tracking
{
	m_inMouseOp = tracking;
}


- (NSSize)			mouseDragOffset
{
	return m_mouseOffset;
}


- (void)			setMouseDragOffset:(NSSize) offset
{
	m_mouseOffset = offset;
}


- (BOOL)				mouseHasMovedSinceStartOfTracking
{
	return m_mouseEverMoved;
}


- (void)				setMouseHasMovedSinceStartOfTracking:(BOOL) moved
{
	m_mouseEverMoved = moved;
}

#pragma mark -
///*********************************************************************************************************************
///
/// method:			isSelected
/// scope:			public instance method
/// overrides:
/// description:	returns whether the object is selected 
/// 
/// parameters:		none
/// result:			YES if selected, NO otherwise
///
/// notes:			assumes that the owning layer is an object drawing layer (which is a reasonable assumption!)
///
///********************************************************************************************************************

- (BOOL)			isSelected
{
	return [(DKObjectDrawingLayer*)[self layer] isSelectedObject:self];
}


///*********************************************************************************************************************
///
/// method:			objectDidBecomeSelected
/// scope:			public instance method
/// overrides:
/// description:	get notified when the object is selected
/// 
/// parameters:		none
/// result:			none
///
/// notes:			subclasses can override to take action when they become selected (drawing the selection isn't
///					part of this - the layer will do that). Overrides should generally invoke super.
///
///********************************************************************************************************************

- (void)			objectDidBecomeSelected
{
	[self notifyStatusChange];
	[self updateRulerMarkers];
}


///*********************************************************************************************************************
///
/// method:			objectIsNoLongerSelected
/// scope:			public instance method
/// overrides:
/// description:	get notified when an object is deselected
/// 
/// parameters:		none
/// result:			none
///
/// notes:			subclasses can override to take action when they are deselected
///
///********************************************************************************************************************

- (void)			objectIsNoLongerSelected
{
	[self notifyStatusChange];

	// override to make use of this notification
}



///*********************************************************************************************************************
///
/// method:			objectMayBecomeSelected
/// scope:			public instance method
/// overrides:
/// description:	is the object able to be selected?
/// 
/// parameters:		none
/// result:			YES if selectable, NO if not
///
/// notes:			subclasses can override to disallow selection. By default all objects are selectable, but for some
///					specialised use this might be useful.
///
///********************************************************************************************************************

- (BOOL)				objectMayBecomeSelected
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			isPendingObject
/// scope:			public instance method
/// overrides:
/// description:	is the object currently a pending object?
/// 
/// parameters:		none
/// result:			YES if pending, NO if not
///
/// notes:			Esoteric. An object is pending while it is being created and not otherwise. There are few reasons
///					to need to know, but one might be to implement a special selection highlight for this case.
///
///********************************************************************************************************************

- (BOOL)				isPendingObject
{
	return [[self layer] pendingObject] == self;
}


///*********************************************************************************************************************
///
/// method:			isKeyObject
/// scope:			public instance method
/// overrides:
/// description:	is the object currently the layer's key object?
/// 
/// parameters:		none
/// result:			YES if key, NO if not
///
/// notes:			DKObjectDrawingLayer maintains a 'key object' for the purposes of alignment operations. The drawable
///					could use this information to draw itself in a particular way for example. Note that DK doesn't
///					use this information except for object alignment operations.
///
///********************************************************************************************************************

- (BOOL)				isKeyObject
{
	return [(DKObjectDrawingLayer*)[self layer] keyObject] == self;
}


///*********************************************************************************************************************
///
/// method:			subSelection
/// scope:			public instance method
/// overrides:
/// description:	return the subselection of the object
/// 
/// parameters:		none
/// result:			a set containing the selection within the object. May be empty, nil or contain self.
///
/// notes:			DK objects do not have subselections without subclassing, but this method provides a common method
///					for subselections to be passed back to a UI, etc. If there is no subselection, this should return
///					either the empty set, nil or a set containing self.
///					Subclasses will override and return whatever is appropriate. They are also responsible for the complete
///					implementation of the selection including hit-testing and highlighting. In addition, the notification
///					'kDKDrawableSubselectionChangedNotification' should be sent when this changes.
///
///********************************************************************************************************************

- (NSSet*)				subSelection
{
	return [NSSet setWithObject:self];
}


///*********************************************************************************************************************
///
/// method:			objectWasAddedToLayer:
/// scope:			public instance method
/// overrides:
/// description:	the object was added to a layer
/// 
/// parameters:		<aLayer> the layer this was added to
/// result:			none
///
/// notes:			purely for information, should an object need to know. Override to make use of this. Subclasses
///					should call super.
///
///********************************************************************************************************************

- (void)				objectWasAddedToLayer:(DKObjectOwnerLayer*) aLayer
{
	#pragma unused(aLayer)
	
	// begin observing style changes
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( styleWillChange:) name:kDKStyleWillChangeNotification object:[self style]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( styleDidChange:) name:kDKStyleDidChangeNotification object:[self style]];
}


///*********************************************************************************************************************
///
/// method:			objectWasRemovedFromLayer:
/// scope:			public instance method
/// overrides:
/// description:	the object was removed from the layer
/// 
/// parameters:		<aLayer> the layer this was removed from
/// result:			none
///
/// notes:			purely for information, should an object need to know. Override to make use of this. Subclasses
///					should call super to maintain notifications.
///
///********************************************************************************************************************

- (void)				objectWasRemovedFromLayer:(DKObjectOwnerLayer*) aLayer
{
	#pragma unused(aLayer)

	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:[self style]];
}


#pragma mark -
#pragma mark - drawing
///*********************************************************************************************************************
///
/// method:			drawContentWithSelectedState:
/// scope:			public instance method
/// overrides:
/// description:	draw the object and its selection on demand
/// 
/// parameters:		<selected> YES if the object is to draw itself in the selected state, NO otherwise
/// result:			none
///
/// notes:			the caller will have determined that the object needs drawing, so this will only be called when
///					necessary. The default method does nothing - subclasses must override this.
///
///********************************************************************************************************************

- (void)			drawContentWithSelectedState:(BOOL) selected
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	
#ifdef qIncludeGraphicDebugging
	[NSGraphicsContext saveGraphicsState];
	
	if ( m_clipToBBox)
	{
		NSBezierPath* clipPath = [NSBezierPath bezierPathWithRect:[self bounds]];
		[clipPath addClip];
	}
#endif
	// draw the object's actual content
	
	mIsHitTesting = NO;
	[self drawContent];
		
	// draw the selection highlight - other code should have already checked -objectMayBecomeSelected and refused to
	// select the object but if for some reason this wasn't done, this at least supresses the highlight
	
	if ( selected && [self objectMayBecomeSelected])
		[self drawSelectedState];

#ifdef qIncludeGraphicDebugging

	[NSGraphicsContext restoreGraphicsState];

	if ( m_showBBox )
	{
		CGFloat sc = 0.5f / [(DKDrawingView*)[self currentView] scale];
		
		[[NSColor redColor] set];
		
		NSRect bb = [self bounds];
		bb = NSInsetRect( bb, sc, sc );
		NSBezierPath* bbox = [NSBezierPath bezierPathWithRect:bb];

		[bbox moveToPoint:bb.origin];
		[bbox lineToPoint:NSMakePoint( NSMaxX( bb ), NSMaxY( bb ))];
		[bbox moveToPoint:NSMakePoint( NSMaxX( bb ), NSMinY( bb ))];
		[bbox lineToPoint:NSMakePoint( NSMinX( bb ), NSMaxY( bb ))];

		[bbox setLineWidth:0.0];
		[bbox stroke];
	}

#endif
	
	[pool drain];
}


///*********************************************************************************************************************
///
/// method:			drawContent
/// scope:			public instance method
/// overrides:
/// description:	draw the content of the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this just hands off to the style rendering by default, but subclasses may override it to do more.
///
///********************************************************************************************************************

- (void)			drawContent
{
	[self drawContentWithStyle:[self style]];
}


///*********************************************************************************************************************
///
/// method:			drawContentWithStyle:
/// scope:			public instance method
/// overrides:
/// description:	draw the content of the object but using a specific style, which might not be the one attached
/// 
/// parameters:		<aStyle> a valid style object, or nil to use the object's current style
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			drawContentWithStyle:(DKStyle*) aStyle
{
	if([self isGhosted])
		[self drawGhostedContent];
	else if( aStyle && ([aStyle countOfRenderList] > 0 || [aStyle hasTextAttributes]))
	{
		@try
		{
			[aStyle render:self];
		}
		@catch( id exc )
		{
			// exceptions arising within style renderings can cause havoc with the drawing state. To try and gracefully exit,
			// the rogue object is hidden after logging the problem. This is meant as a last resort to keep the document working - 
			// styles may need to handle exceptions more gracefully internally. Any such logs must be investigated.
			
			NSLog(@"object %@ (style = %@) encountered an exception while rendering", self, [self style]);
			//[self setVisible:NO];
			
			@throw;
		}
	}
	else
	{
		// if there's no style, the shape will be invisible. This makes it hard to select for deletion, etc. Thus if
		// drawing to the screen, a visible but feint fill is drawn so that it can be seen and selected. This is not drawn
		// to the printer so the drawing remains correct for printed output.
		
		if([NSGraphicsContext currentContextDrawingToScreen])
		{
			[[NSColor rgbGrey:0.95 withAlpha:0.5] set];
			
			NSBezierPath* rpc = [[self renderingPath] copy];
			[rpc fill];
			[rpc release];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			drawGhostedContent
/// scope:			public instance method
/// overrides:
/// description:	draw the ghosted content of the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			The default simply strokes the rendering path at minimum width using the ghosting colour. Can be
///					overridden for more complex appearances. Note that ghosting should deliberately keep the object
///					unobtrusive and simple.
///
///********************************************************************************************************************

- (void)			drawGhostedContent
{
	[[[self class] ghostColour] set];
	NSBezierPath* rp = [self renderingPath];
	[rp setLineWidth:0];
	[rp stroke];
}


///*********************************************************************************************************************
///
/// method:			drawSelectedState
/// scope:			public instance method
/// overrides:
/// description:	draw the selection highlight for the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the owning layer may call this independently of drawContent~ in some circumstances, so 
///					subclasses need to be ready to factor this code as required.
///
///********************************************************************************************************************

- (void)			drawSelectedState
{
	// placeholder - override to implement this
}



///*********************************************************************************************************************
///
/// method:			drawSelectionPath
/// scope:			public instance method
/// overrides:
/// description:	stroke the given path using the selection highlight colour for the owning layer
/// 
/// parameters:		<path> the selection highlight path
/// result:			none
///
/// notes:			this is a convenient utility method your subclasses can use as needed to make selections consistent
///					among different objects and layers. A side effect is that the line width of the path may be changed.
///
///********************************************************************************************************************

- (void)			drawSelectionPath:(NSBezierPath*) path
{
	if ([self locked])
		[[NSColor lightGrayColor] set];
	else
		[[[self layer] selectionColour] set];

	[path setLineWidth:0.0];
	[path stroke];
}


///*********************************************************************************************************************
///
/// method:			notifyVisualChange
/// scope:			public instance method
/// overrides:
/// description:	request a redraw of this object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			marks the object's bounds as needing updating. Most operations on an object that affect its
///					appearance to the user should call this before and after the operation is performed.
///
///					Subclasses that override this for optimisation purposes should make sure that the layer is
///					updated through the drawable:needsDisplayInRect: method and that the notification is sent, otherwise
///					there may be problems when layer contents are cached.
///
///********************************************************************************************************************

- (void)			notifyVisualChange
{
	if ([self layer])
		[[self layer] drawable:self needsDisplayInRect:[self bounds]];
}


///*********************************************************************************************************************
///
/// method:			notifyStatusChange
/// scope:			public instance method
/// overrides:
/// description:	notify the drawing and its controllers that a non-visual status change occurred
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the drawing passes this back to any controllers it has
///
///********************************************************************************************************************

- (void)			notifyStatusChange
{
	[[self drawing] objectDidNotifyStatusChange:self];
}


///*********************************************************************************************************************
///
/// method:			notifyGeometryChange:
/// scope:			public instance method
/// overrides:
/// description:	notify that the geomnetry of the object has changed
/// 
/// parameters:		<oldBounds> the bounds of the object *before* it got changed by whatever is calling this
/// result:			none
///
/// notes:			subclasses can override this to make use of the change notification. This is intended to signal
///					purely geometric changes which for some objects could be used to invalidate cached information
///					that more general changes might not need to invalidate. This also informs the storage about the
///					bounds change so that if the storage uses bounds information to optimise storage, it can do
///					whatever it needs to to keep the storage correctly organised.
///
///********************************************************************************************************************

- (void)			notifyGeometryChange:(NSRect) oldBounds
{
	if( ! NSEqualRects( oldBounds, [self bounds]))
	{
		[self invalidateRenderingCache];
		[[self storage] object:self didChangeBoundsFrom:oldBounds];
		[self updateRulerMarkers];
	}
}


///*********************************************************************************************************************
///
/// method:			updateRulerMarkers
/// scope:			public instance method
/// overrides:
/// description:	sets the ruler markers for all of the drawing's views to the logical bounds of this
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this is largely automatic, but if there is an operation that shoul dupdate the markers, you can
///					call this to perform it. Also, if a subclass has some special way to set the markers, it may
///					override this.
///
///********************************************************************************************************************

- (void)			updateRulerMarkers
{	
	[[self layer] updateRulerMarkersForRect:[self logicalBounds]];
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRect
/// scope:			public instance method
/// overrides:
/// description:	mark some part of the drawing as needing update
/// 
/// parameters:		<rect> this area requires an update
/// result:			none
///
/// notes:			usually an object should mark only areas within its bounds using this, to be polite.
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRect:(NSRect) rect
{
	[[self layer] drawable:self needsDisplayInRect:rect];
}

///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRects
/// scope:			public instance method
/// overrides:
/// description:	mark multiple parts of the drawing as needing update
/// 
/// parameters:		<setOfRects> a set of NSRect/NSValues to be updated
/// result:			none
///
/// notes:			the layer call with NSZeroRect is to ensure the layer's caches work
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRects:(NSSet*) setOfRects
{
	[[self layer] drawable:self needsDisplayInRect:NSZeroRect];
	[[self layer] setNeedsDisplayInRects:setOfRects];
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRects:withExtraPadding:
/// scope:			public instance method
/// overrides:
/// description:	mark multiple parts of the drawing as needing update
/// 
/// parameters:		<setOfRects> a set of NSRect/NSValues to be updated
///					<padding> some additional margin added to each rect before marking as needing update
/// result:			none
///
/// notes:			the layer call with NSZeroRect is to ensure the layer's caches work
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRects:(NSSet*) setOfRects withExtraPadding:(NSSize) padding
{
	[[self layer] drawable:self needsDisplayInRect:NSZeroRect];
	[[self layer] setNeedsDisplayInRects:setOfRects withExtraPadding:padding];
}



#pragma mark -
#pragma mark - specialised drawing methods

///*********************************************************************************************************************
///
/// method:			drawContentInRect:fromRect:withStyle:
/// scope:			public instance method
/// overrides:
/// description:	renders the object or part of it into the current context, applying scaling and/or a temporary style
/// 
/// parameters:		<destRect> the destination rect in the current context
///					<srcRect> the srcRect in the same coordinate space as the current bounds, or NSZeroRect to mean the
///					entire bounds
///					<aStyle> currently unused - draws in the object's attached style
/// result:			none
///
/// notes:			useful for rendering the object into any context at any size. The object is scaled by the ratio
///					of srcRect to destRect. <destRect> can't be zero-sized.
///
///********************************************************************************************************************

- (void)			drawContentInRect:(NSRect) destRect fromRect:(NSRect) srcRect withStyle:(DKStyle*) aStyle
{
#pragma unused(aStyle)
	
	NSAssert( destRect.size.width > 0.0 && destRect.size.height > 0.0, @"destination rect has zero size");
	
	if ( NSEqualRects( srcRect, NSZeroRect ))
		srcRect = [self bounds];
	else
		srcRect = NSIntersectionRect( srcRect, [self bounds]);
		
	if( NSEqualRects( srcRect, NSZeroRect ))
		return;
		
	SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
	[NSBezierPath clipRect:destRect];
		
	// compute the necessary transform to perform the scaling and translation from srcRect to destRect.

	NSAffineTransform*	tfm = [NSAffineTransform transform];
	[tfm mapFrom:srcRect to:destRect];
	[tfm concat];
	
	[self drawContent];
	RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
}


///*********************************************************************************************************************
///
/// method:			pdf
/// scope:			public instance method
/// overrides:
/// description:	returns the single object rendered as a PDF image
/// 
/// parameters:		none
/// result:			PDF data of the object
///
/// notes:			this allows the object to be extracted as a single PDF in isolation. It works by creating a
///					temporary view that draws just this object.
///
///********************************************************************************************************************
- (NSData*)				pdf
{
	NSRect frame = NSZeroRect;
	frame.size = [[self drawing] drawingSize];
	
	DKDrawablePDFView* pdfView = [[DKDrawablePDFView alloc] initWithFrame:frame object:self];
	
	NSData* pdfData = [pdfView dataWithPDFInsideRect:[self bounds]];
	
	[pdfView release];
	
	return pdfData;
}


#pragma mark -
#pragma mark - style
///*********************************************************************************************************************
///
/// method:			setStyle:
/// scope:			public instance method
/// overrides:
/// description:	attaches a style to the object
/// 
/// parameters:		<aStyle> the style to attach. The object will be drawn using this style from now on
/// result:			none
///
/// notes:			it's important to call the inherited method if you override this, as objects generally need to
///					subscribe to a style's notifications, and a style needs to know when it is attached to objects.
///
///					IMPORTANT: because styles may be set to be shared or not, the rule is that styles MUST be copied
///					before attaching. Shared styles don't really make a copy, so the sharing of such styles occurs
///					automatically without the client object needing to know about it.
///
///********************************************************************************************************************

- (void)			setStyle:(DKStyle*) aStyle
{
	// do not allow in any old object
	
	if( aStyle && ![aStyle isKindOfClass:[DKStyle class]])
		return;
	
	// important rule: always make a 'copy' of the style to honour its sharable flag:
	
	DKStyle* newStyle = [aStyle copy];
	
	if ( newStyle != [self style])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setStyle:) object:[self style]];	
		[self notifyVisualChange];
		
		NSRect oldBounds = [self bounds];
		
		// subscribe to change notifications from the style so we can refresh and undo changes
		
		if ( m_style )
			[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:m_style];
		
		// adding observers is slow, noticeable when creating many objects at a time (for example when reading a file). To help, the observer
		// is not added straight away unless we are already part of a layer. The observation will be established when the object is added to the layer.
		
		if ( newStyle && [self layer])
		{
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( styleWillChange:) name:kDKStyleWillChangeNotification object:newStyle];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( styleDidChange:) name:kDKStyleDidChangeNotification object:newStyle];
		}
		
		// set up the user info. If newStyle is nil, this will terminate the list after the old style
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[self style], kDKDrawableOldStyleKey, newStyle, kDKDrawableNewStyleKey, nil];
		
		if([self layer])
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableStyleWillBeDetachedNotification object:self userInfo:userInfo];
		
		[m_style styleWillBeRemoved:self];
		[m_style release];
		m_style = [newStyle retain];
		
		// set the style's undo manager to ours if it's actually set
		
		if([self undoManager] != nil )
			[m_style setUndoManager:[self undoManager]];
		
		[m_style styleWasAttached:self];
		[self notifyStatusChange];
		[self notifyVisualChange];
		[self notifyGeometryChange:oldBounds];	// in case the style change affects the bounds
		
		// notify if we are part of a layer, otherwise don't bother
		
		if([self layer])
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableStyleWasAttachedNotification object:self userInfo:userInfo];
	}
	
	[newStyle release];
}


///*********************************************************************************************************************
///
/// method:			style
/// scope:			public instance method
/// overrides:
/// description:	return the attached style
/// 
/// parameters:		none
/// result:			the current style
///
/// notes:			
///
///********************************************************************************************************************

- (DKStyle*)	style
{
	return m_style;
}

///*********************************************************************************************************************
///
/// method:			styleWillChange:
/// scope:			private notification method
/// overrides:
/// description:	called when the attached style is about to change
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

static NSRect s_oldBounds;

- (void)			styleWillChange:(NSNotification*) note
{
	if([note object] == [self style])
	{
		s_oldBounds = [self bounds];
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			styleDidChange
/// scope:			private notification method
/// overrides:
/// description:	called just after the attached style has changed
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			styleDidChange:(NSNotification*) note
{
	if([note object] == [self style])
	{
		[self notifyVisualChange];
		[self notifyGeometryChange:s_oldBounds];
	}
}



///*********************************************************************************************************************
///
/// method:			allStyles
/// scope:			public instance method
/// overrides:
/// description:	return all styles used by this object
/// 
/// parameters:		none
/// result:			a set, containing the object's style
///
/// notes:			this is part of an informal protocol used, among other possible uses, for remerging styles after
///					a document load. Objects higher up the chain form the union of all such sets, which is why this
///					is returned as a set, even though it contains just one style. Subclasses might also use more than
///					one style.
///
///********************************************************************************************************************

- (NSSet*)			allStyles
{
	if ([self style] != nil )
		return [NSSet setWithObject:[self style]];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			allRegisteredStyles
/// scope:			public instance method
/// overrides:
/// description:	return all registered styles used by this object
/// 
/// parameters:		none
/// result:			a set, containing the object's style if it is registerd or flagged for remerge
///
/// notes:			this is part of an informal protocol used for remerging styles after
///					a document load. Objects higher up the chain form the union of all such sets, which is why this
///					is returned as a set, even though it contains just one style. Subclasses might also use more than
///					one style. After a fresh load from an archive, this returns the style if the remerge flag is set,
///					but at all other times it returns the style if registered. The remerge flag is cleared by this
///					method, thus you need to make sure to call it just once after a reload if it's the remerge flagged
///					styles you want (in general this usage is automatic and is handled at a much higher level - see
///					DKDrawingDocument).
///
///********************************************************************************************************************

- (NSSet*)			allRegisteredStyles
{
	if ([self style] != nil)
	{
		if([[self style] requiresRemerge] || [[self style] isStyleRegistered])
		{
			[[self style] clearRemergeFlag];
			return [NSSet setWithObject:[self style]];
		}
	}

	return nil;
}


///*********************************************************************************************************************
///
/// method:			replaceMatchingStylesFromSet
/// scope:			public instance method
/// overrides:
/// description:	replace the object's style from any in th egiven set that have the same ID.
/// 
/// parameters:		<aSet> a set of style objects
/// result:			none
///
/// notes:			this is part of an informal protocol used for remerging registered styles after
///					a document load. If <aSet> contains a style having the same ID as this object's current style,
///					the style is updated with the one from the set.
///
///********************************************************************************************************************

- (void)			replaceMatchingStylesFromSet:(NSSet*) aSet
{
	NSAssert( aSet != nil, @"style set was nil");

	if ([self style] != nil )
	{
		NSEnumerator*	iter = [aSet objectEnumerator];
		DKStyle*	st;
		
		while((st = [iter nextObject]))
		{
			if([[st uniqueKey] isEqualToString:[[self style] uniqueKey]])
			{
				LogEvent_(kStateEvent, @"replacing style with %@ '%@'", st, [st name]);
				
				[self setStyle:st];
				break;
			}
		}
	}
}



///*********************************************************************************************************************
///
/// method:			detachStyle
/// scope:			public instance method
/// overrides:
/// description:	If the object's style is currently sharable, copy it and make it non-sharable.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			If the style is already non-sharable, this does nothing. The purpose of this is to detach this
///					from it style such that it has its own private copy. It does not change appearance.
///
///********************************************************************************************************************

- (void)				detachStyle
{
	if([[self style] isStyleSharable])
	{
		DKStyle* detachedStyle = [[self style] mutableCopy];
		
		[detachedStyle setStyleSharable:NO];
		[self setStyle:detachedStyle];
		[detachedStyle release];
	}
}


#pragma mark -
#pragma mark - geometry
///*********************************************************************************************************************
///
/// method:			setSize:
/// scope:			public instance method
/// overrides:
/// description:	sets the object's size to the width and height passed
/// 
/// parameters:		<size> the new size
/// result:			none
///
/// notes:			subclasses should override to set the object's size
///
///********************************************************************************************************************

- (void)			setSize:(NSSize) size
{
	#pragma unused(size)
}


///*********************************************************************************************************************
///
/// method:			size
/// scope:			public instance method
/// overrides:
/// description:	returns the size of the object regardless of angle, etc.
/// 
/// parameters:		none
/// result:			the object's size
///
/// notes:			subclasses should override and return something sensible
///
///********************************************************************************************************************

- (NSSize)			size
{
	NSLog(@"!!! 'size' must be overridden by subclasses of DKDrawableObject (culprit = %@)", self);

	return NSZeroSize;
}


///*********************************************************************************************************************
///
/// method:			resizeWidthBy:heightBy:
/// scope:			public instance method
/// overrides:
/// description:	resizes the object by scaling its width and height by thye given factors.
/// 
/// parameters:		<xFactor> the width scale
///					<yFactor> the height scale
/// result:			none
///
/// notes:			factors of 1.0 have no effect; factors must be postive and > 0.
///
///********************************************************************************************************************

- (void)			resizeWidthBy:(CGFloat) xFactor heightBy:(CGFloat) yFactor
{
	NSAssert( xFactor > 0.0, @"x scale must be greater than 0");
	NSAssert( yFactor > 0.0, @"y scale must be greater than 0");
	
	NSSize newSize = [self size];
	
	newSize.width *= xFactor;
	newSize.height *= yFactor;
	
	[self setSize:newSize];
}


///*********************************************************************************************************************
///
/// method:			apparentBounds
/// scope:			public instance method
/// overrides:
/// description:	returns the visually apparent bounds
/// 
/// parameters:		none
/// result:			the apparent bounds rect
///
/// notes:			this bounds is intended for use when aligning objects to each other or to guides, etc. By default
///					it is the same as the bounds, but subclasses may redefine it to be something else.
///
///********************************************************************************************************************

- (NSRect)			apparentBounds
{
	return [self bounds];
}


///*********************************************************************************************************************
///
/// method:			logicalBounds
/// scope:			public instance method
/// overrides:
/// description:	returns the logical bounds
/// 
/// parameters:		none
/// result:			the logical bounds
///
/// notes:			the logical bounds is the object's bounds ignoring any stylistic effects. Unlike the other bounds,
///					it remains constant for a given paht even if styles change. By default it is the same as the bounds,
///					but subclasses will probably wish to redefine it.
///
///********************************************************************************************************************

- (NSRect)			logicalBounds
{
	return [self bounds];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			intersectsRect:
/// scope:			public instance method
/// overrides:
/// description:	test whether the object intersects a given rectangle
/// 
/// parameters:		<rect> the rect to test against
/// result:			YES if the object intersects the rect, NO otherwise
///
/// notes:			used for selecting using a marquee, and other things. The default hit tests by rendering the object
///					into a special 1-byte bitmap and testing its alpha channel - this is fast and efficient and in most
///					simple cases doesn't need to be overridden.
///
///********************************************************************************************************************

- (BOOL)			intersectsRect:(NSRect) rect
{
	NSRect ir, br = [self bounds];
	
	if ([self visible] && NSIntersectsRect( br, rect ))
	{
		// if <rect> fully encloses the bounds, no further tests are needed and we can return YES immediately
		
		ir = NSIntersectionRect( rect, br );
		
		if( NSEqualRects( ir, br ))
			return YES;
		else
			return [self rectHitsPath:rect];
	}
	else
		return NO;	// invisible objects don't intersect anything
}


///*********************************************************************************************************************
///
/// method:			setLocation:
/// scope:			public instance method
/// overrides:
/// description:	set the location of the object to the given point
/// 
/// parameters:		<p> the point to locate the object at
/// result:			none
///
/// notes:			the object can decide how it aligns itself about its own location in any way that is self-consistent.
///					the default is to align the origin of the bounds at the point, but most subclasses do something
///					more sophisticated
///
///********************************************************************************************************************

- (void)			setLocation:(NSPoint) p
{
	#pragma unused(p)
	
	NSLog(@"**** You must override -setLocation: for the object %@ ****", self);
}


///*********************************************************************************************************************
///
/// method:			offsetLocationByX:byY:
/// scope:			public instance method
/// overrides:
/// description:	offsets the object's position by the values passed
/// 
/// parameters:		<dx> add this much to the x coordinate
///					<dy> add this much to the y coordinate
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			offsetLocationByX:(CGFloat) dx byY:(CGFloat) dy
{
	if ( dx != 0 || dy != 0 )
	{
		NSPoint loc = [self location];
		
		loc.x += dx;
		loc.y += dy;
		
		[self setLocation:loc];
	}
}


///*********************************************************************************************************************
///
/// method:			location
/// scope:			public instance method
/// overrides:
/// description:	return the object's current location
/// 
/// parameters:		none
/// result:			the object's location
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)			location
{
	return [self logicalBounds].origin;
}


///*********************************************************************************************************************
///
/// method:			angle
/// scope:			public instance method
/// overrides:
/// description:	return the object's current angle, in radians
/// 
/// parameters:		none
/// result:			the object's angle
///
/// notes:			override if your subclass implements variable angles
///
///********************************************************************************************************************

- (CGFloat)			angle
{
	return 0.0f;
}


///*********************************************************************************************************************
///
/// method:			setAngle:
/// scope:			public instance method
/// overrides:
/// description:	set the object's current angle in radians
/// 
/// parameters:		<angle> the object's angle (radians)
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setAngle:(CGFloat) angle
{
	#pragma unused(angle)
}


///*********************************************************************************************************************
///
/// method:			angleInDegrees
/// scope:			public instance method
/// overrides:		
/// description:	return the shape's current rotation angle
/// 
/// parameters:		none
/// result:			the shape's angle in degrees
///
/// notes:			this method is primarily to supply the angle for display to the user, rather than for doing angular
///					calculations with. It converts negative values -180 to 0 to +180 to 360 degrees.
///
///********************************************************************************************************************

- (CGFloat)				angleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self angle]);
	
	if( angle < 0 )
		angle += 360.0f;
		
	return fmodf(angle, 360.0f);
}


///*********************************************************************************************************************
///
/// method:			rotateByAngle:
/// scope:			public instance method
/// overrides:		
/// description:	rotate the shape by adding a delta angle to the current angle
/// 
/// parameters:		<da> add this much to the current angle
/// result:			none
///
/// notes:			da is a value in radians
///
///********************************************************************************************************************

- (void)				rotateByAngle:(CGFloat) da
{
	if ( da != 0 )
		[self setAngle:[self angle] + da];
}


///*********************************************************************************************************************
///
/// method:			invalidateRenderingCache
/// scope:			public instance method
/// overrides:		
/// description:	discard all cached rendering information
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the rendering cache is simply emptied. The contents of the cache are generally set by individual
///					renderers to speed up drawing, and are not known to this object. The cache is invalidated by any
///					change that alters the object's appearance - size, position, angle, style, etc.
///
///********************************************************************************************************************

- (void)				invalidateRenderingCache
{
	[mRenderingCache removeAllObjects];
}


///*********************************************************************************************************************
///
/// method:			cachedImage
/// scope:			public instance method
/// overrides:		
/// description:	returns an image of the object representing its current appearance at 100% scale.
/// 
/// parameters:		none
/// result:			an image of the object
///
/// notes:			this image is stored in the rendering cache. If the cache is empty the image is recreated. This
///					image can be used to speed up hit testing.
///
///********************************************************************************************************************

- (NSImage*)			cachedImage
{
	NSImage* img = [mRenderingCache objectForKey:kDKDrawableCachedImageKey];
	
	if( img == nil )
	{
		img = [self swatchImageWithSize:NSZeroSize];
		[mRenderingCache setObject:img forKey:kDKDrawableCachedImageKey];
	}
	
	return img;
}

#pragma mark -
///*********************************************************************************************************************
///
/// method:			setOffset:
/// scope:			public instance method
/// overrides:		
/// description:	set the relative offset of the object's anchor point
/// 
/// parameters:		<offs> a width and height value relative to the object's bounds
/// result:			none
///
/// notes:			subclasses must override if they support this concept
///
///********************************************************************************************************************

- (void)			setOffset:(NSSize) offs
{
	#pragma unused(offs)
	
	// placeholder
}


///*********************************************************************************************************************
///
/// method:			offset
/// scope:			public instance method
/// overrides:		
/// description:	return the relative offset of the object's anchor point
/// 
/// parameters:		none 
/// result:			a width and height value relative to the object's bounds
///
/// notes:			subclasses must override if they support this concept
///
///********************************************************************************************************************

- (NSSize)			offset
{
	return NSZeroSize;
}


///*********************************************************************************************************************
///
/// method:			resetOffset
/// scope:			public instance method
/// overrides:		
/// description:	reset the relative offset of the object's anchor point to its original value
/// 
/// parameters:		none 
/// result:			none
///
/// notes:			subclasses must override if they support this concept
///
///********************************************************************************************************************

- (void)			resetOffset
{
}


///*********************************************************************************************************************
///
/// method:			transform
/// scope:			protected instance method
/// overrides:
/// description:	return a transform that maps the object's stored path to its true location in the drawing
/// 
/// parameters:		none
/// result:			a transform
///
/// notes:			override for real transforms - the default merely returns the identity matrix
///
///********************************************************************************************************************

- (NSAffineTransform*)	transform
{
	return [NSAffineTransform transform];
}


///*********************************************************************************************************************
///
/// method:			applyTransform:
/// scope:			public instance method
/// overrides:
/// description:	apply the transform to the object
/// 
/// parameters:		<transform> a transform
/// result:			none
///
/// notes:			the object's position, size and path are modified by the transform. This is called by the owning
///					layer's applyTransformToObjects method. This ignores locked objects.
///
///********************************************************************************************************************

- (void)				applyTransform:(NSAffineTransform*) transform
{
	NSAssert( transform != nil, @"nil transform in [DKDrawableObject applyTransform:]");
	
	NSPoint p = [transform transformPoint:[self location]];
	[self setLocation:p];
	
	NSSize	size = [transform transformSize:[self size]];
	[self setSize:size];
}


#pragma mark -
#pragma mark - drawing tool information

///*********************************************************************************************************************
///
/// method:			creationTool:willBeginCreationAtPoint:
/// scope:			protected instance method
/// overrides:
/// description:	called by the creation tool when this object has just beeen created by the tool
/// 
/// parameters:		<tool> the tool that created this
///					<p> the initial point that the tool will start dragging the object from
/// result:			none
///
/// notes:			FYI - override to make use of this
///
///********************************************************************************************************************

- (void)			creationTool:(DKDrawingTool*) tool willBeginCreationAtPoint:(NSPoint) p
{
	#pragma unused(tool)
	#pragma unused(p)
	
	// override to make use of this event
}


///*********************************************************************************************************************
///
/// method:			creationTool:willEndCreationAtPoint:
/// scope:			protected instance method
/// overrides:
/// description:	called by the creation tool when this object has finished being created by the tool
/// 
/// parameters:		<tool> the tool that created this
///					<p> the point that the tool finished dragging the object to
/// result:			none
///
/// notes:			FYI - override to make use of this
///
///********************************************************************************************************************

- (void)			creationTool:(DKDrawingTool*) tool willEndCreationAtPoint:(NSPoint) p
{
	#pragma unused(tool)
	#pragma unused(p)
	
	// override to make use of this event
}



///*********************************************************************************************************************
///
/// method:			objectIsValid
/// scope:			public instance method
/// overrides:
/// description:	return whether the object is valid in terms of having a visible, usable state
/// 
/// parameters:		none
/// result:			YES if valid, NO otherwise
///
/// notes:			subclasses must override and implement this appropriately. It is called by the object creation tool
///					at the end of a creation operation to determine if what was created is in any way useful. Objects that
///					cannot be used will not be added to the drawing. The object type needs to decide what constitutes
///					validity - for example shapes with zero size or paths with zero length are likely not valid.
///
///********************************************************************************************************************

- (BOOL)			objectIsValid
{
	return NO;
}


#pragma mark -
#pragma mark - grouping and ungrouping support

///*********************************************************************************************************************
///
/// method:			groupWillAddObject:
/// scope:			public instance method
/// overrides:
/// description:	this object is being added to a group
/// 
/// parameters:		<aGroup> the group adding the object
/// result:			none
///
/// notes:			can be overridden if this event is of interest. Note that for grouping, the object doesn't need
///					to do anything special - the group takes care of it.
///
///********************************************************************************************************************

- (void)				groupWillAddObject:(DKShapeGroup*) aGroup
{
	#pragma unused(aGroup)
}


///*********************************************************************************************************************
///
/// method:			group:willUngroupObjectWithTransform:
/// scope:			public instance method
/// overrides:
/// description:	this object is being ungrouped from a group
/// 
/// parameters:		<aGroup> the group containing the object
///					<aTransform> the transform that the group is applying to the object to scale rotate and translate it.
/// result:			none
///
/// notes:			when ungrouping, an object must help the group to the right thing by resizing, rotating and repositioning
///					itself appropriately. At the time this is called, the object has already has its container set to
///					the layer it will be added to but has not actually been added. Must be overridden.
///
///********************************************************************************************************************

- (void)				group:(DKShapeGroup*) aGroup willUngroupObjectWithTransform:(NSAffineTransform*) aTransform
{
	#pragma unused(aGroup)
	#pragma unused(aTransform)
	
	NSLog(@"*** you should override -group:willUngroupObjectWithTransform: to correctly ungroup '%@' ***", NSStringFromClass([self class]));
}


///*********************************************************************************************************************
///
/// method:			objectWasUngrouped
/// scope:			public instance method
/// overrides:
/// description:	this object was ungrouped from a group
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this is called when the ungrouping operation has finished entirely. The object will belong to its
///					original container and have its location, etc set as required. Override to make use of this notification.
///
///********************************************************************************************************************

- (void)				objectWasUngrouped
{
}


///*********************************************************************************************************************
///
/// method:			willBeAddedAsSubstituteFor:toLayer:
/// scope:			public instance method
/// overrides:
/// description:	some high-level operations substitute a new object in place of an existing one (or several). In
///					those cases this should be called to allow the object to do any special substitution work.
/// 
/// parameters:		<obj> the original object his is being substituted for
///					<aLayer> the layer this will be added to (but is not yet)
/// result:			none
///
/// notes:			subclasses should override this to do additional work during a substitution. Note that user info
///					and style is handled for you, this does not need to deal with those properties.
///
///********************************************************************************************************************

- (void)				willBeAddedAsSubstituteFor:(DKDrawableObject*) obj toLayer:(DKObjectOwnerLayer*) aLayer;
{
#pragma unused(obj, aLayer)	
}


#pragma mark -
#pragma mark - snapping to guides, grid and other objects (utility methods)
///*********************************************************************************************************************
///
/// method:			snappedMousePoint
/// scope:			protected instance method
/// overrides:
/// description:	offset the point to cause snap to grid + guides accoding to the drawing's settings
/// 
/// parameters:		<mp> a point which is the proposed location of the shape
///					<snapControl> a control flag used to temporarily enable/disable snapping
/// result:			a new point which may be offset from the input enough to snap it to the guides and grid
///
/// notes:			DKObjectOwnerLayer + DKDrawing implements the details of this method. The snapControl flag is
///					intended to come from a modifier flag - usually <ctrl>.
///
///********************************************************************************************************************

- (NSPoint)				snappedMousePoint:(NSPoint) mp withControlFlag:(BOOL) snapControl
{
	if ([self mouseSnappingEnabled] && [self layer])
		mp = [(DKObjectOwnerLayer*)[self layer] snappedMousePoint:mp forObject:self withControlFlag:snapControl];

	return mp;
}


///*********************************************************************************************************************
///
/// method:			snappedMousePoint:forSnappingPointsWithControlFlag:
/// scope:			public instance method
/// overrides:
/// description:	offset the point to cause snap to grid + guides according to the drawing's settings
/// 
/// parameters:		<mp> a point which is the proposed location of the shape
///					<snapControl> a flag which enables/disables snapping temporarily
/// result:			a new point which may be offset from the input enough to snap it to the guides and grid
///
/// notes:			given a proposed location, this modifies it by checking if any of the points returned by the
///					object's snappingPoints method will snap. The result can be passed to moveToPoint:
///
///********************************************************************************************************************

- (NSPoint)			snappedMousePoint:(NSPoint) mp forSnappingPointsWithControlFlag:(BOOL) snapControl
{
	if ([self mouseSnappingEnabled] && [self drawing])
	{
		// factor in snap to grid + guides
		
		mp = [[self drawing] snapToGrid:mp withControlFlag:snapControl];
		
		NSSize	offs;
		
		offs.width = mp.x - [self location].x;
		offs.height = mp.y - [self location].y;

		NSSize snapOff = [[self drawing] snapPointsToGuide:[self snappingPointsWithOffset:offs]];
		
		mp.x += snapOff.width;
		mp.y += snapOff.height;
	}

	return mp;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			snappingPoints
/// scope:			public instance method
/// overrides:
/// description:	return an array of NSpoint values representing points that can be snapped to guides
/// 
/// parameters:		none
/// result:			a list of points (NSValues)
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)		snappingPoints
{
	return [self snappingPointsWithOffset:NSZeroSize];
}


///*********************************************************************************************************************
///
/// method:			snappingPointsWithOffset:
/// scope:			public instance method
/// overrides:
/// description:	return an array of NSpoint values representing points that can be snapped to guides
/// 
/// parameters:		<offset> an offset value that is added to each point
/// result:			a list of points (NSValues)
///
/// notes:			snapping points are locations within an object that will snap to a guide. List can be empty.
///
///********************************************************************************************************************

- (NSArray*)		snappingPointsWithOffset:(NSSize) offset
{
	NSPoint p = [self location];
	
	p.x += offset.width;
	p.y += offset.height;
	
	return [NSArray arrayWithObject:[NSValue valueWithPoint:p]];
}


///*********************************************************************************************************************
///
/// method:			mouseOffset
/// scope:			public instance method
/// overrides:
/// description:	returns the offset between the mouse point and the shape's location during a drag
/// 
/// parameters:		none
/// result:			mouse offset during a drag
///
/// notes:			result is undefined except during a dragging operation
///
///********************************************************************************************************************

- (NSSize)			mouseOffset
{
	return m_mouseOffset;
}


#pragma mark -
#pragma mark - getting dimensions in drawing coordinates
///*********************************************************************************************************************
///
/// method:			convertLength:
/// scope:			public instance method
/// overrides:
/// description:	convert a distance in quartz coordinates to the units established by the drawing grid
/// 
/// parameters:		<len> a distance in pixels
/// result:			the distance in drawing units
///
/// notes:			this is a conveniece API to query the drawing's grid layer
///
///********************************************************************************************************************

- (CGFloat)			convertLength:(CGFloat) len
{
	return [[self drawing] convertLength:len];
}


///*********************************************************************************************************************
///
/// method:			convertPointToDrawing:
/// scope:			public instance method
/// overrides:
/// description:	convert a point in quartz coordinates to the units established by the drawing grid
/// 
/// parameters:		<pt> a point value
/// result:			the equivalent point in drawing units
///
/// notes:			this is a conveniece API to query the drawing's grid layer
///
///********************************************************************************************************************

- (NSPoint)			convertPointToDrawing:(NSPoint) pt
{
	return [[self drawing] convertPoint:pt];

}


#pragma mark -
#pragma mark - hit testing
///*********************************************************************************************************************
///
/// method:			hitPart:
/// scope:			public instance method
/// overrides:
/// description:	hit test the object
/// 
/// parameters:		<pt> the mouse location
/// result:			a part code representing which part of the object got hit, if any
///
/// notes:			part codes are private to the object class, except for 0 = nothing hit and -1 = entire object hit.
///					for other parts, the object is free to return any code it likes and attach any meaning it wishes.
///					the part code is passed back by the mouse event methods but apart from 0 and -1 is never interpreted
///					by any other object
///
///********************************************************************************************************************

- (NSInteger)				hitPart:(NSPoint) pt
{
	if ([self visible])
	{
		NSInteger pc = ( NSMouseInRect( pt, [self bounds], [[self drawing] isFlipped])? kDKDrawingEntireObjectPart : kDKDrawingNoPart );
	
		if (( pc == kDKDrawingEntireObjectPart ) && [self isSelected] && ![self locked])
			pc = [self hitSelectedPart:pt forSnapDetection:NO];
			
		return pc;
	}
	else
		return kDKDrawingNoPart;	// can never hit invisible objects
}


///*********************************************************************************************************************
///
/// method:			hitSelectedPart:
/// scope:			protected instance method
/// overrides:
/// description:	hit test the object in the selected state
/// 
/// parameters:		<pt> the mouse location
///					<snap> is YES if called to detect snap, NO otherwise
/// result:			a part code representing which part of the selected object got hit, if any
///
/// notes:			this is a factoring of the general hitPart: method to allow parts that only come into play when
///					selected to be hit tested. It is also used when snapping to objects. Subclasses should override
///					for the partcodes they define such as control knobs that operate when selected.
///
///********************************************************************************************************************

- (NSInteger)				hitSelectedPart:(NSPoint) pt forSnapDetection:(BOOL) snap
{
	#pragma unused(pt)
	#pragma unused(snap)
	
	return kDKDrawingEntireObjectPart;
}


///*********************************************************************************************************************
///
/// method:			pointForPartcode:
/// scope:			public instance method
/// overrides:
/// description:	return the point associated with the part code
/// 
/// parameters:		<pc> a valid partcode for this object
/// result:			the current point associated with the partcode
///
/// notes:			if partcode is no object, returns {-1,-1}, if entire object, return location. Object classes
///					should override this to correctly implement it for partcodes they define
///
///********************************************************************************************************************

- (NSPoint)			pointForPartcode:(NSInteger) pc
{
	if ( pc == kDKDrawingEntireObjectPart )
		return [self location];
	else
		return NSMakePoint( -1, -1 );
}


///*********************************************************************************************************************
///
/// method:			knobTypeForPartCode:
/// scope:			public instance method
/// overrides:
/// description:	provide a mapping between the object's partcode and a knob type draw for that part
/// 
/// parameters:		<pc> a valid partcode for this object
/// result:			a valid knob type
///
/// notes:			knob types are defined by DKKnob, they describe the functional type of the knob, plus the locked
///					state. Concrete subclasses should override this unless the default suffices.
///
///********************************************************************************************************************

- (DKKnobType)		knobTypeForPartCode:(NSInteger) pc
{
	#pragma unused(pc)
	
	DKKnobType result = kDKControlPointKnobType;
	
	if ([self locked])
		result |= kDKKnobIsDisabledFlag;
		
	return result;
}


///*********************************************************************************************************************
///
/// method:			rectHitsPath:
/// scope:			private instance method
/// overrides:		
/// description:	test if a rect encloses any of the shape's actual pixels
/// 
/// parameters:		<r> the rect to test
/// result:			YES if at least one pixel enclosed by the rect, NO otherwise
///
/// notes:			note this can be an expensive way to test this - eliminate all obvious trivial cases first.
///
///********************************************************************************************************************

- (BOOL)				rectHitsPath:(NSRect) r
{
	NSRect	ir = NSIntersectionRect( r, [self bounds]);
	BOOL	hit = NO;
	
	if ( ir.size.width > 0.0 && ir.size.height > 0.0 )
	{
		// if ir is equal to our bounds, we know that <r> fully encloses this, so there's no need
		// to perform the expensive bitmap test - just return YES. This assumes that the shape draws *something*
		// somewhere within its bounds, which is not unreasonable.
		
		if( NSEqualRects( ir, [self bounds]))
			return YES;
		else
		{
			// this method scales the whole hit rect directly down into a 1x1 bitmap context - if it ends up opaque, it's hit. If transparent, it's not.
			// this method suggested by Ken Ferry (Apple), as it avoids the need for writable access to NSBimapImageRep and so should
			// perform best on most graphics architectures. This also doesn't require any style substitution.
			
			// since the context is always the same, it's also created as a static var, so only one is ever needed. This removes the overhead of
			// creating it for every test - instead we can simply clear the byte each time.
			
			static CGContextRef			bm = NULL;
			static NSGraphicsContext*	bitmapContext = nil;
			static uint8_t				byte[8];				// includes some unused padding
			static NSRect				srcRect = {{0,0},{1,1}};
			
			if( bm == NULL )
			{
				bm = CGBitmapContextCreate( byte, 1, 1, 8, 1, NULL, kCGImageAlphaOnly );
				CGContextSetInterpolationQuality( bm, kCGInterpolationNone );
				CGContextSetShouldAntialias( bm, NO );
				CGContextSetShouldSmoothFonts( bm, NO );
				bitmapContext = [[NSGraphicsContext graphicsContextWithGraphicsPort:bm flipped:YES] retain];
				[bitmapContext setShouldAntialias:NO];
			}
			
			SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:bitmapContext];
			byte[0] = 0;
			
			// flag that hit-testing is taking place - drawing methods may use quick-and-dirty rendering for better performance.
			
			mIsHitTesting = YES;
			
			// try using a cached copy of the object's image:
			/*
			NSImage* cachedImage = [self cachedImage];
			
			if( cachedImage )
			{
				NSRect br = [self bounds];
				
				ir = NSOffsetRect( ir, -br.origin.x, -br.origin.y );
				[cachedImage drawInRect:srcRect fromRect:ir operation:NSCompositeSourceOver fraction:1.0];
			}
			else
			 */
			{
				// draw the object but without any shadows - this both speeds up the hit testing which doesn't care about shadows
				// and avoids a nasty crashing bug in Quartz.
				
				BOOL drawShadows = [DKStyle setWillDrawShadows:NO];
				[self drawContentInRect:srcRect fromRect:ir withStyle:nil];
				[DKStyle setWillDrawShadows:drawShadows];
			}
			mIsHitTesting = NO;
			
			RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
			
			hit = ( byte[0] != 0 );
		}
	}
	
	return hit;
}


///*********************************************************************************************************************
///
/// method:			pointHitsPath:
/// scope:			private instance method
/// overrides:		
/// description:	test a point against the offscreen bitmap representation of the shape
/// 
/// parameters:		<p> the point to test
/// result:			YES if the point hit the shape's pixels, NO otherwise
///
/// notes:			special case of the rectHitsPath call, which is now the fastest way to perform this test
///
///********************************************************************************************************************

- (BOOL)				pointHitsPath:(NSPoint) p
{
	if( NSPointInRect( p, [self bounds]))
	{
		NSRect	pr = NSRectCentredOnPoint( p, NSMakeSize( 1e-3, 1e-3 ));
		return [self rectHitsPath:pr];
	}
	else
		return NO;
}


///*********************************************************************************************************************
///
/// method:			isBeingHitTested
/// scope:			private instance method
/// overrides:		
/// description:	is a hit-test in progress
/// 
/// parameters:		none
/// result:			YES if hit-testing is taking place, otherwise NO
///
/// notes:			drawing methods can check this to see if they can take shortcuts to save time when hit-testing.
///					This will only return YES during calls to -drawContent etc when invoked by the rectHitsPath method.
///
///********************************************************************************************************************

- (BOOL)				isBeingHitTested
{
	return mIsHitTesting;
}


///*********************************************************************************************************************
///
/// method:			setBeingHitTested
/// scope:			private instance method
/// overrides:		
/// description:	set whether a hit-test in progress
/// 
/// parameters:		<hitTesting> YES if hit-testing, NO otherwise
/// result:			none
///
/// notes:			Applicaitons should not generally use this. It allows certain container classes (e.g. groups) to
///					flag the *they* are being hit tested to provide easier hitting of thin objects in groups.
///
///********************************************************************************************************************

- (void)				setBeingHitTested:(BOOL) hitTesting
{
	mIsHitTesting = hitTesting;
}


#pragma mark -
#pragma mark - basic event handling

///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:
/// description:	the mouse went down in this object
/// 
/// parameters:		<mp> the mouse point (already converted to the relevant view - gives drawing relative coordinates)
///					<partcode> the partcode that was returned by hitPart if non-zero.
///					<evt> the original event
/// result:			none
///
/// notes:			default method records the mouse offset, but otherwise you will override to make use of this
///
///********************************************************************************************************************

- (void)			mouseDownAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	#pragma unused( evt, partcode )
	
	m_mouseOffset.width = mp.x - [self location].x;
	m_mouseOffset.height = mp.y - [self location].y;
	[self setMouseHasMovedSinceStartOfTracking:NO];
	[self setTrackingMouse:YES];
}


///*********************************************************************************************************************
///
/// method:			mouseDraggedAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:
/// description:	the mouse is dragging within this object
/// 
/// parameters:		<mp> the mouse point (already converted to the relevant view - gives drawing relative coordinates)
///					<partcode> the partcode that was returned by hitPart if non-zero.
///					<evt> the original event
/// result:			none
///
/// notes:			default method moves the entire object, and snaps to grid and guides if enabled. Control key disables
///					snapping temporarily.
///
///********************************************************************************************************************

- (void)			mouseDraggedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	#pragma unused(partcode)
	
	if(![self locationLocked])
	{
		mp.x -= [self mouseDragOffset].width;
		mp.y -= [self mouseDragOffset].height;
		
		BOOL controlKey = (([evt modifierFlags] & NSControlKeyMask) != 0 );
		mp = [self snappedMousePoint:mp forSnappingPointsWithControlFlag:controlKey];
		
		[self setLocation:mp];
		[self setMouseHasMovedSinceStartOfTracking:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			mouseUpAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:
/// description:	the mouse went up in this object
/// 
/// parameters:		<mp> the mouse point (already converted to the relevant view - gives drawing relative coordinates)
///					<partcode> the partcode that was returned by hitPart if non-zero.
///					<evt> the original event
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			mouseUpAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	#pragma unused(mp)
	#pragma unused(partcode)
	#pragma unused(evt)
	
	if ([self mouseHasMovedSinceStartOfTracking])
	{
		[[self undoManager] setActionName:NSLocalizedString( @"Move", @"undo string for move object")];
		[self setMouseHasMovedSinceStartOfTracking:NO];
	}
	
	[self setTrackingMouse:NO];
}


///*********************************************************************************************************************
///
/// method:			currentView
/// scope:			public instance method
/// overrides:
/// description:	get the view currently drawing or passing events to this
/// 
/// parameters:		none
/// result:			the view that is either drawing or handling the mouse/responder events
///
/// notes:			the view is only meaningful when called from within a drawing or event handling method.
///
///********************************************************************************************************************

- (NSView*)			currentView
{
	return [[self layer] currentView];
}


///*********************************************************************************************************************
///
/// method:			cursorForPartcode:
/// scope:			public instance method
/// overrides:
/// description:	return the cursor displayed when a given partcode is hit or entered
/// 
/// parameters:		<partcode> the partcode
///					<button> YES if the mouse left button is pressed, NO otherwise
/// result:			a cursor object
///
/// notes:			the cursor may be displayed when the mouse hovers over or is clicked in the area indicated by the
///					partcode. The default is simply to return the standard arrow - override for others.
///
///********************************************************************************************************************

- (NSCursor*)		cursorForPartcode:(NSInteger) partcode mouseButtonDown:(BOOL) button
{
	#pragma unused(partcode)
	#pragma unused(button)
	
	return [NSCursor arrowCursor];
}


///*********************************************************************************************************************
///
/// method:			mouseDoubleClickedAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:
/// description:	inform the object that it was double-clicked
/// 
/// parameters:		<mp> the point where it was clicked
///					<partcode> the partcode
///					<event> the original mouse event
/// result:			none
///
/// notes:			This is invoked by the select tool and any others that decide to implement it. The object can
///					respond however it likes - by default it simply broadcasts a notification. Override for
///					different behaviours.
///
///********************************************************************************************************************

- (void)			mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	#pragma unused( partcode, evt)
	
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:[NSValue valueWithPoint:mp] forKey:kDKDrawableClickedPointKey];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableDoubleClickNotification object:self userInfo:userInfo];
	
	// notify the layer directly
	
	[[self layer] drawable:self wasDoubleClickedAtPoint:mp];
}


#pragma mark -
#pragma mark - contextual menu


///*********************************************************************************************************************
///
/// method:			menu
/// scope:			public instance method
/// overrides:
/// description:	reurn the menu to use as the object's contextual menu
/// 
/// parameters:		none
/// result:			the menu
///
/// notes:			The menu is obtained via DKAuxiliaryMenus helper object which in turn loads the menu from a nib,
///					overridable by the app. This is the preferred method of supplying the menu. It doesn't need to
///					be overridden by subclasses generally speaking, since all menu customisation per class is done in
///					the nib.
///
///********************************************************************************************************************

- (NSMenu*)				menu
{
	return [[[DKAuxiliaryMenus auxiliaryMenus] copyMenuForClass:[self class]] autorelease];
}


///*********************************************************************************************************************
///
/// method:			populateContextualMenu:
/// scope:			public instance method
/// overrides:
/// description:	allows the object to populate the menu with commands that are relevant to its current state and type
/// 
/// parameters:		<theMenu> a menu - add items and commands to it as required
/// result:			YES if any items were added, NO otherwise.
///
/// notes:			the default method adds commands to copy and paste the style
///
///********************************************************************************************************************

- (BOOL)			populateContextualMenu:(NSMenu*) theMenu
{
	// if the object supports any contextual menu commands, it should add them to the menu and return YES. If subclassing,
	// you would usually call the inherited method first so that the menu is the union of all the ancestor's added methods.
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Copy Style", @"menu item for copy style") action:@selector( copyDrawingStyle: ) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Paste Style", @"menu item for paste style") action:@selector( pasteDrawingStyle: ) keyEquivalent:@""] setTarget:self];
	
	if([self locked])
		[[theMenu addItemWithTitle:NSLocalizedString(@"Unlock", @"menu item for unlock") action:@selector( unlock: ) keyEquivalent:@""] setTarget:self];
	else
		[[theMenu addItemWithTitle:NSLocalizedString(@"Lock", @"menu item for lock") action:@selector( lock: ) keyEquivalent:@""] setTarget:self];

	return YES;
}


///*********************************************************************************************************************
///
/// method:			populateContextualMenu:atPoint:
/// scope:			public instance method
/// overrides:
/// description:	allows the object to populate the menu with commands that are relevant to its current state and type
/// 
/// parameters:		<theMenu> a menu - add items and commands to it as required
///						<localPoint> the point in local (view) coordinates where the menu click went down
/// result:			YES if any items were added, NO otherwise.
///
/// notes:			the default method adds commands to copy and paste the style. This method allows the point to
///					be used by subclasses to refine the menu for special areas within the object.
///
///********************************************************************************************************************

- (BOOL)			populateContextualMenu:(NSMenu*) theMenu atPoint:(NSPoint) localPoint
{
	#pragma unused(localPoint)
	
	return [self populateContextualMenu:theMenu];
}


#pragma mark -
#pragma mark - swatch
///*********************************************************************************************************************
///
/// method:			swatchImageWithSize:
/// scope:			public instance method
/// overrides:
/// description:	returns an image of this object rendered using its current style and path
/// 
/// parameters:		<size> desired size of the image - shape is scaled to fit in this size
/// result:			the image
///
/// notes:			if size is NSZeroRect, uses the current bounds size
///
///********************************************************************************************************************

- (NSImage*)		swatchImageWithSize:(NSSize) size
{
	if( NSEqualSizes( size, NSZeroSize ))
		size = [self bounds].size;
	
	if(!NSEqualSizes( size, NSZeroSize ))
	{
		NSImage* image = [[NSImage alloc] initWithSize:size];
		[image setFlipped:YES];
		[image lockFocus];
		
		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
		NSRect destRect = NSMakeRect( 0, 0, size.width, size.height );
		
		[self drawContentInRect:destRect fromRect:NSZeroRect withStyle:nil];
		[image unlockFocus];
		[image setFlipped:NO];
		
		return [image autorelease];
	}
	else
		return nil;
}


#pragma mark -
#pragma mark - user info
///*********************************************************************************************************************
///
/// method:			setUserInfo:
/// scope:			public instance method
/// overrides:
/// description:	attach a dictionary of metadata to the object
/// 
/// parameters:		<info> a dictionary containing anything you wish
/// result:			none
///
/// notes:			The dictionary replaces the current user info. To merge with any existing user info, use addUserInfo:
///
///********************************************************************************************************************

- (void)			setUserInfo:(NSDictionary*) info
{
	if( mUserInfo == nil )
		mUserInfo = [[NSMutableDictionary alloc] init];
	
	[mUserInfo setDictionary:info];
	[self notifyStatusChange];
}


///*********************************************************************************************************************
///
/// method:			addUserInfo:
/// scope:			public instance method
/// overrides:
/// description:	add a dictionary of metadata to the object
/// 
/// parameters:		<info> a dictionary containing anything you wish
/// result:			none
///
/// notes:			<info> is merged with the existin gcontent of the user info
///
///********************************************************************************************************************

- (void)			addUserInfo:(NSDictionary*) info
{
	if( mUserInfo == nil )
		mUserInfo = [[NSMutableDictionary alloc] init];
	
	NSDictionary* deepCopy = [info deepCopy];
	
	[mUserInfo addEntriesFromDictionary:deepCopy];
	[deepCopy release];
	[self notifyStatusChange];
}



///*********************************************************************************************************************
///
/// method:			userInfo
/// scope:			public instance method
/// overrides:
/// description:	return the attached user info
/// 
/// parameters:		none
/// result:			the user info
///
/// notes:			The user info is returned as a mutable dictionary (which it is), and can thus have its contents
///					mutated directly for certain uses. Doing this cannot cause any notification of the status of
///					the object however.
///
///********************************************************************************************************************

- (NSMutableDictionary*)userInfo
{
	return mUserInfo;
}

///*********************************************************************************************************************
///
/// method:			userInfoObjectForKey:
/// scope:			public instance method
/// overrides:
/// description:	return an item of user info
/// 
/// parameters:		<key> the key to use to refer to the item
/// result:			the user info item
///
/// notes:			
///
///********************************************************************************************************************

- (id)					userInfoObjectForKey:(NSString*) key
{
	return [[self userInfo] objectForKey:key];
}


///*********************************************************************************************************************
///
/// method:			setUserInfoObject:forKey:
/// scope:			public instance method
/// overrides:
/// description:	set an item of user info
/// 
/// parameters:		<obj> the object to store
///					<key> the key to use to refer to the item
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setUserInfoObject:(id) obj forKey:(NSString*) key
{
	NSAssert( obj != nil, @"cannot add nil to the user info");
	NSAssert( key != nil, @"user info key can't be nil");
	
	if( mUserInfo == nil )
		mUserInfo = [[NSMutableDictionary alloc] init];
	
	[mUserInfo setObject:obj forKey:key];
	[self notifyStatusChange];
}


#pragma mark -
#pragma mark - pasteboard

///*********************************************************************************************************************
///
/// method:			writeSupplementaryDataToPasteboard:
/// scope:			public instance method
/// overrides:
/// description:	write additional data to the pasteboard specific to the object
/// 
/// parameters:		<pb> the pasteboard to write to
/// result:			none
///
/// notes:			the owning layer generally handles the case of writing the selected objects to the pasteboard but
///					sometimes an object might wish to supplement that data. For example a text-bearing object might
///					add the text to the pasteboard. This is only invoked when the object is the only object selected.
///					The default method does nothing - override to make use of this. Also, your override must declare
///					the types it's writing using addTypes:owner:
///
///********************************************************************************************************************

- (void)				writeSupplementaryDataToPasteboard:(NSPasteboard*) pb
{
#pragma unused(pb)
	// override to make use of
}


///*********************************************************************************************************************
///
/// method:			readSupplementaryDataFromPasteboard:
/// scope:			public instance method
/// overrides:
/// description:	read additional data from the pasteboard specific to the object
/// 
/// parameters:		<pb> the pasteboard to read from
/// result:			none
///
/// notes:			This is invoked by the owning layer after an object has been pasted. Override to make use of. Note
///					that this is not necessarily symmetrical with -writeSupplementaryDataToPasteboard: depending on
///					what data types the other method actually wrote. For example standard text would not normally
///					need to be handled as a special case.
///
///********************************************************************************************************************

- (void)				readSupplementaryDataFromPasteboard:(NSPasteboard*) pb
{
#pragma unused(pb)
	// override to make use of
}

#pragma mark -
#pragma mark - user level commands that can be responded to by this object (and its subclasses)
///*********************************************************************************************************************
///
/// method:			copyDrawingStyle:
/// scope:			public action method
/// overrides:
/// description:	copies the object's style to the general pasteboard
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)		copyDrawingStyle:(id) sender
{
	#pragma unused(sender)
	
	// allows the attached style to be copied to the clipboard.
	
	if ([self style] != nil )
	{
		[[NSPasteboard generalPasteboard] declareTypes:[NSArray array] owner:self];
		[[self style] copyToPasteboard:[NSPasteboard generalPasteboard]];
	}
}


///*********************************************************************************************************************
///
/// method:			pasteDrawingStyle:
/// scope:			public action method
/// overrides:
/// description:	pastes a style from the general pasteboard onto the object
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			attempts to maintain shared styles by using the style's name initially.
///
///********************************************************************************************************************

- (IBAction)		pasteDrawingStyle:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked])
	{
		DKStyle* style = [DKStyle styleFromPasteboard:[NSPasteboard generalPasteboard]];
		
		if ( style != nil )
		{
			[self setStyle:style];
			[[self undoManager] setActionName:NSLocalizedString(@"Paste Style", "undo string for object paste style")];
		}
	}
}

- (IBAction)			lock:(id) sender
{
#pragma unused(sender)
	if(![self locked])
	{
		[self setLocked:YES];
	}
}


- (IBAction)			unlock:(id) sender
{
#pragma unused(sender)
	if([self locked])
	{
		[self setLocked:NO];
	}
}


- (IBAction)			lockLocation:(id) sender
{
#pragma unused(sender)
	if(![self locationLocked])
	{
		[self setLocationLocked:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Lock Location", @"undo action for single object lock location")];
	}
}


- (IBAction)			unlockLocation:(id) sender
{
#pragma unused(sender)
	if([self locationLocked])
	{
		[self setLocationLocked:NO];
		[[self undoManager] setActionName:NSLocalizedString(@"Unlock Location", @"undo action for single object unlock location")];
	}
}



#ifdef qIncludeGraphicDebugging
#pragma mark -
#pragma mark - debugging

- (IBAction)		toggleShowBBox:(id) sender
{
	#pragma unused(sender)
	
	m_showBBox = !m_showBBox;
	[self notifyVisualChange];
}


- (IBAction)		toggleClipToBBox:(id) sender
{
	#pragma unused(sender)
	
	m_clipToBBox = !m_clipToBBox;
	[self notifyVisualChange];
}


- (IBAction)		toggleShowPartcodes:(id) sender
{
	#pragma unused(sender)
	
	m_showPartcodes = !m_showPartcodes;
	[self notifyVisualChange];
}


- (IBAction)		toggleShowTargets:(id) sender
{
	#pragma unused(sender)
	
	m_showTargets = !m_showTargets;
	[self notifyVisualChange];
}


- (IBAction)		logDescription:(id) sender
{
#pragma unused(sender)
	NSLog(@"%@", self );
}

#endif


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if ( m_style != nil )
	{
		[m_style styleWillBeRemoved:self];
		[m_style release];
	}
	[mUserInfo release];
	[mRenderingCache release];
	[super dealloc];
}


- (id)				init
{
	return [self initWithStyle:[DKStyle defaultStyle]];
}


- (NSString*)		description
{
	return [NSString stringWithFormat:@"%@ size: %@, loc: %@, angle: %.4f, offset: %@, locked: %@, style: %@, container: %x, storage: %@, user info:%@",
				[super description],
				NSStringFromSize([self size]),
				NSStringFromPoint([self location]),
				[self angle],
				NSStringFromSize([self offset]),
				[self locked]? @"YES" : @"NO",
				[self style],
				[self container],
				[self storage],
				[self userInfo]];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	
	[coder encodeConditionalObject:[self container] forKey:@"container"];
	[coder encodeObject:[self style] forKey:@"style"];
	[coder encodeObject:[self userInfo] forKey:@"userinfo"];
	
	[coder encodeBool:[self visible] forKey:@"visible"];
	[coder encodeBool:[self locked] forKey:@"locked"];
	[coder encodeInteger:mZIndex forKey:@"DKDrawableObject_zIndex"];
	[coder encodeBool:[self isGhosted] forKey:@"DKDrawable_ghosted"];
	[coder encodeBool:[self locationLocked] forKey:@"DKDrawable_locationLocked"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
//	LogEvent_(kFileEvent, @"decoding drawable object %@", self);

	self = [self initWithStyle:nil];
	if (self != nil )
	{
		[self setContainer:[coder decodeObjectForKey:@"container"]];
		
		// if container is nil, as it could be for very old test files, set it to the same value as the owner.
		// for groups this is incorrect and the file won't open correctly.
		
		if ([self container] == nil )
		{
			// more recent older files wrote this key as "parent" - try that 
			
			[self setContainer:[coder decodeObjectForKey:@"parent"]];
		}
		[self setStyle:[coder decodeObjectForKey:@"style"]];
		[self setUserInfo:[coder decodeObjectForKey:@"userinfo"]];
		[self updateMetadataKeys];
		
		[self setVisible:[coder decodeBoolForKey:@"visible"]];
		mZIndex = [coder decodeIntegerForKey:@"DKDrawableObject_zIndex"];
		m_snapEnable = YES;
		
		[self setGhosted:[coder decodeBoolForKey:@"DKDrawable_ghosted"]];
		
		// lock and location lock is not set here, as it prevents subclasses from setting other properties when dearchiving
		// see -awakeAfterUsingCoder:
	}
	return self;
}


- (id)		awakeAfterUsingCoder:(NSCoder*) coder
{
	[self setLocationLocked:[coder decodeBoolForKey:@"DKDrawable_locationLocked"]];
	[self setLocked:[coder decodeBoolForKey:@"locked"]];
	
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)				copyWithZone:(NSZone*) zone
{
	DKDrawableObject* copy = [[[self class] allocWithZone:zone] init];
	
	[copy setContainer:nil];			// we don't know who will own the copy
	
	DKStyle* styleCopy = [[self style] copy];
	[copy setStyle:styleCopy];			// style will be shared if set to be shared, otherwise copied
	[styleCopy release];
	
	// ghost setting is copied but lock states are not
	
	[copy setGhosted:[self isGhosted]];
	
	// gets a deep copy of the user info
	
	if([self userInfo] != nil )
	{									
		NSDictionary*	ucopy = [[self userInfo] deepCopy];
		[copy setUserInfo:ucopy];
		[ucopy release];
	}
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)			validateMenuItem:(NSMenuItem*) item
{
	SEL	action = [item action];
	
	if (![self locked])
	{
		if ( action == @selector(pasteDrawingStyle:))
		{
			BOOL canPaste = [DKStyle canInitWithPasteboard:[NSPasteboard generalPasteboard]];
			NSString* itemTitle = NSLocalizedString(@"Paste Style",nil);
			
			if( canPaste )
			{
				DKStyle* theStyle = [DKStyle styleFromPasteboard:[NSPasteboard generalPasteboard]];
				NSString* name = [theStyle name];
				
				if( name && [name length] > 0 )
					itemTitle = [NSString stringWithFormat:NSLocalizedString(@"Paste Style '%@'", nil ), name];
				
				// don't bother pasting the same style we already have
				
				if([theStyle isEqualToStyle:[self style]])
					canPaste = NO;
			}
			[item setTitle:itemTitle];
			return canPaste;
		}
	}
		
	// even locked objects can have their style copied
	
	if ( action == @selector(copyDrawingStyle:))
	{
		DKStyle* theStyle = [self style];
		NSString* itemTitle = NSLocalizedString(@"Copy Style", nil);
		
		if( theStyle )
		{
			NSString* name = [theStyle name];
			if( name && [name length] > 0 )
				itemTitle = [NSString stringWithFormat:NSLocalizedString(@"Copy Style '%@'", nil), name];
		}
		[item setTitle:itemTitle];
		return (theStyle != nil );
	}
	
	if( action == @selector(lock:))
		return ![self locked];
	
	if( action == @selector(unlock:))
		return [self locked];
	
	if( action == @selector(lockLocation:))
		return ![self locationLocked] && ![self locked];
	
	if( action == @selector(unlockLocation:))
		return [self locationLocked] && ![self locked];
	
#ifdef qIncludeGraphicDebugging
	if ( action == @selector( toggleShowBBox:) ||
		 action == @selector( toggleClipToBBox:) ||
		 action == @selector( toggleShowTargets:) ||
		 action == @selector( toggleShowPartcodes:))
	{
		// set a checkmark next to those that are turned on
		
		if( action == @selector(toggleShowBBox:))
			[item setState:m_showBBox? NSOnState : NSOffState];
		else if ( action == @selector(toggleClipToBBox:))
			[item setState:m_clipToBBox? NSOnState : NSOffState];
		else if ( action == @selector(toggleShowTargets:))
			[item setState:m_showTargets? NSOnState : NSOffState];
		else if ( action == @selector(toggleShowPartcodes:))
			[item setState:m_showPartcodes? NSOnState : NSOffState];
		
		return YES;
	}
	
	if( action == @selector(logDescription:))
		return YES;
	
#endif
	
	return NO;
}


#pragma mark -
#pragma mark - as an implementer of the DKRenderable protocol

///*********************************************************************************************************************
///
/// method:			bounds
/// scope:			public instance method
/// overrides:
/// description:	return the full extent of the object within the drawing, including any decoration, etc.
/// 
/// parameters:		none
/// result:			the full bounds of the object
///
/// notes:			the object must draw only within its declared bounds. If it draws outside of this, it will leave
///					trails and debris when moved, rotated or scaled. All style-based decoration must be contained within
///					bounds. The style has the method -extraSpaceNeeded to help you determine the correct bounds.
///
///					subclasses must override this and return a valid, sensible bounds rect
///
///********************************************************************************************************************

- (NSRect)			bounds
{
	NSLog(@"!!! 'bounds' must be overridden by subclasses of DKDrawableObject (culprit = %@)", self);
	
	return NSZeroRect;
}


///*********************************************************************************************************************
///
/// method:			extraSpaceNeeded
/// scope:			public instance method
/// overrides:
/// description:	returns the extra space needed to display the object graphically. This will usually be the difference
///					between the logical and reported bounds.
/// 
/// parameters:		none
/// result:			the extra space required
///
/// notes:			
///********************************************************************************************************************

- (NSSize)			extraSpaceNeeded
{
	if ([self style])
		return [[self style] extraSpaceNeeded];
	else
		return NSMakeSize( 0, 0 );
}





///*********************************************************************************************************************
///
/// method:			containerTransform
/// scope:			protected instance method
/// overrides:
/// description:	return the container's transform
/// 
/// parameters:		none
/// result:			a transform
///
/// notes:			the container transform must be taken into account for rendering this object, as it accounts for
///					groups and other possible containers.
///
///********************************************************************************************************************

- (NSAffineTransform*)	containerTransform
{
	NSAffineTransform*	ct = [[self container] renderingTransform];
	
	if( ct == nil )
		return [NSAffineTransform transform];
	else
		return ct;
}





///*********************************************************************************************************************
///
/// method:			renderingPath
/// scope:			public instance method
/// overrides:
/// description:	return the path that represents the final user-visible path of the drawn object
/// 
/// parameters:		none
/// result:			the object's path
///
/// notes:			the default method does nothing. Subclasses should override this and supply the appropriate path,
///					which is the one requested by a renderer when the object is actually drawn. See also the
///					DKRasterizerProtocol, which makes use of this.
///
///********************************************************************************************************************

- (NSBezierPath*)	renderingPath
{
	return nil;
}


///*********************************************************************************************************************
///
/// method:			useLowQualityDrawing
/// scope:			public instance method
/// overrides:
/// description:	return hint to rasterizers that low quality drawing should be used
/// 
/// parameters:		none
/// result:			YES to use low quality drawing, no otherwise
///
/// notes:			part of the informal rendering protocol used by rasterizers
///
///********************************************************************************************************************

- (BOOL)			useLowQualityDrawing
{
	return [[self drawing] lowRenderingQuality];
}


///*********************************************************************************************************************
///
/// method:			geometryChecksum
/// scope:			public instance method
/// overrides:
/// description:	return a number that changes when any aspect of the geometry changes. This can be used to detect
///					that a change has taken place since an earlier time.
/// 
/// parameters:		none
/// result:			a number
///
/// notes:			do not rely on what the number is, only whether it has changed. Also, do not persist it in any way.
///
///********************************************************************************************************************

- (NSUInteger)		geometryChecksum
{
	NSUInteger cd = 282735623;	// arbitrary
	NSPoint	loc;
	NSSize	size;
	CGFloat	angle;
	NSSize	offset;
	
	loc = [self location];
	size = [self size];
	angle = [self angleInDegrees] * 10;
	offset = [self offset];
	
	cd ^= roundtol( loc.x ) ^ roundtol( loc.y ) ^ roundtol( size.width ) ^ roundtol( size.height ) ^ roundtol( angle ) ^ roundtol( offset.width ) ^ roundtol( offset.height );
	
	return cd;
}


- (NSMutableDictionary*)	renderingCache
{
	return mRenderingCache;
}



@end



