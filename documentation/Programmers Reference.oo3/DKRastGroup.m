///**********************************************************************************************************************************
///  DKRastGroup.m
///  DrawKit
///
///  Created by graham on 17/03/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKRastGroup.h"

#import "DKStyleReader.h"
#import "NSDictionary+DeepCopy.h"

// For the silly lookup herein
#import "DKFill.h"
#import "DKStroke.h"
#import "DKGradient.h"
#import "LogEvent.h"


@implementation DKRastGroup
#pragma mark As a DKRenderGroup
///*********************************************************************************************************************
///
/// method:			renderGroupWithStyleScript:
/// scope:			public class method
/// overrides:		
/// description:	builds a style group from a script
/// 
/// parameters:		<string> a string with a valid style script
/// result:			a renderer group built from the script
///
/// notes:			generally you should use [DKStyle styleWithScript:]. Depending on the script this may
///					actually construct a style.
///
///********************************************************************************************************************

+ (DKRastGroup*)	rasterizerGroupWithStyleScript:(NSString*) string
{
	// given a formatted spec string this returns a render group containing all of the renderers specified by the string.
	// The format of the spec string is given in the header
	
	static DKStyleReader* parser = nil;
	
	if ( parser == nil )
		parser = [[DKStyleReader alloc] init];

	LogEvent_(kReactiveEvent, @"spec: %@", string );

	DKRastGroup*	newGroup = [parser evaluateScript:string];
	
	LogEvent_(kReactiveEvent, @"built new group: %@", newGroup );
	
	return newGroup;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setRenderList:
/// scope:			public method
/// overrides:		
/// description:	set the contained objects to those in array
/// 
/// parameters:		<list> a list of renderer objects
/// result:			none
///
/// notes:			this method no longer attempts to try and manage observing of the objects. The observer must
///					properly stop observing before this is called, or start observing after it is called when
///					initialising from an archive. 
///
///********************************************************************************************************************

- (void)		setRenderList:(NSArray*) list
{
	if( list != [self renderList])
	{
		NSMutableArray* rl = [list mutableCopy];
		[m_renderList release];
		m_renderList = rl;
		
		// set the container ref for each item in the list - when unarchiving newer files this is already done but
		// for older files may not be. It's a weak ref so doing it anyway here is harmless. The added objects are not
		// yet notified to the root for observation as we don't want them getting observed twice. When the style
		// completes unarchiving it will start observing the whole tree itself. When individual rasterizers are added and
		// removed their observation is managed individually (inclusing the adding/removal of groups, which deals with
		// all the subordinate objects).
		
		[[self renderList] makeObjectsPerformSelector:@selector(setContainer:) withObject:self];
	}
}


///*********************************************************************************************************************
///
/// method:			renderList
/// scope:			public method
/// overrides:		
/// description:	get the list of contained renderers
/// 
/// parameters:		none
/// result:			an array containing the list of renderers
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)	renderList
{
	return m_renderList;
}


#pragma mark -


///*********************************************************************************************************************
///
/// method:			root
/// scope:			public method
/// overrides:		
/// description:	returns the top-level group in any hierarchy, which in DrawKit is a style object
/// 
/// parameters:		none
/// result:			the top level group
///
/// notes:			will return nil if the group isn't part of a complete tree
///
///********************************************************************************************************************

- (DKRastGroup*)	root
{
	return [[self container] root];
}




///*********************************************************************************************************************
///
/// method:			observableWasAdded:
/// scope:			public method
/// overrides:		
/// description:	notifies that an observable object was added to the group
/// 
/// parameters:		<observable> the object to start observing
/// result:			none
///
/// notes:			overridden by the root object (style)
///
///********************************************************************************************************************

- (void)			observableWasAdded:(GCObservableObject*) observable
{
	#pragma unused(observable)
	
	// placeholder
}


///*********************************************************************************************************************
///
/// method:			observableWillBeRemoved:
/// scope:			public method
/// overrides:		
/// description:	notifies that an observable object is about to be removed from the group
/// 
/// parameters:		<observable> the object to stop observing
/// result:			none
///
/// notes:			overridden by the root object (style)
///
///********************************************************************************************************************

- (void)			observableWillBeRemoved:(GCObservableObject*) observable
{
	#pragma unused(observable)
	
	// placeholder
}



#pragma mark -
///*********************************************************************************************************************
///
/// method:			addRenderer:
/// scope:			public method
/// overrides:		
/// description:	adds a renderer to the group
/// 
/// parameters:		<renderer> a renderer object
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		addRenderer:(DKRasterizer*) renderer
{
	if(! [m_renderList containsObject:renderer])
	{
		[renderer setContainer:self];
		[self insertObject:renderer inRenderListAtIndex:[self countOfRenderList]];
		
		// let the root object know so it can start observing the added renderer
		
		[[self root] observableWasAdded:renderer];
	}
}


///*********************************************************************************************************************
///
/// method:			removeRenderer:
/// scope:			public method
/// overrides:		
/// description:	removes a renderer from the group
/// 
/// parameters:		<renderer> the renderer object to remove
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		removeRenderer:(DKRasterizer*) renderer
{
	if( [m_renderList containsObject:renderer])
	{
		// let the root object know so it can stop observing the renderer that is about to vanish
		
		[[self root] observableWillBeRemoved:renderer];
		[renderer setContainer:nil];
		[self removeObjectFromRenderListAtIndex:[self indexOfRenderer:renderer]];
	}
}


///*********************************************************************************************************************
///
/// method:			moveRendererAtIndex:toIndex:
/// scope:			public method
/// overrides:		
/// description:	relocates a renderer within the group (which affects drawing order)
/// 
/// parameters:		<src> the index position of the renderer to move
///					<dest> the index where to move it
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		moveRendererAtIndex:(unsigned) src toIndex:(unsigned) dest
{
	if ( src == dest )
		return;
		
	if ( src >= [m_renderList count])
		src = [m_renderList count] - 1;
	
	DKRasterizer* moving = [[m_renderList objectAtIndex:src] retain];

	[self removeObjectFromRenderListAtIndex:src];
	
	if ( src < dest )
		--dest;
	
	[self insertObject:moving inRenderListAtIndex:dest];
	[moving release];
}


///*********************************************************************************************************************
///
/// method:			insertRenderer:atIndex:
/// scope:			public method
/// overrides:		
/// description:	inserts a renderer into the group at the given index
/// 
/// parameters:		<renderer> the renderer to insert
///					<index> the index where to insert it
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		insertRenderer:(DKRasterizer*) renderer atIndex:(unsigned) indx
{
	if(! [m_renderList containsObject:renderer])
	{
		[renderer setContainer:self];
		[self insertObject:renderer inRenderListAtIndex:indx];

		// let the root object know so it can start observing
		
		[[self root] observableWasAdded:renderer];
	}
}


///*********************************************************************************************************************
///
/// method:			removeRendererAtIndex:
/// scope:			public method
/// overrides:		
/// description:	removes the renderer at the given index
/// 
/// parameters:		<index> the index to remove
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		removeRendererAtIndex:(unsigned) indx
{
	DKRasterizer* renderer = [self rendererAtIndex:indx];
	
	if( [m_renderList containsObject:renderer])
	{
		// let the root object know so it can stop observing:
		
		[[self root] observableWillBeRemoved:renderer];
		[renderer setContainer:nil];
		[self removeObjectFromRenderListAtIndex:indx];
	}
}


///*********************************************************************************************************************
///
/// method:			indexOfRenderer:
/// scope:			public method
/// overrides:		
/// description:	returns the index of the given renderer
/// 
/// parameters:		<renderer> the renderer in question
/// result:			the index position of the renderer, or NSNotFound
///
/// notes:			
///
///********************************************************************************************************************

- (unsigned)	indexOfRenderer:(DKRasterizer*) renderer
{
	return [[self renderList] indexOfObject:renderer];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			rendererAtIndex:
/// scope:			public method
/// overrides:		
/// description:	returns the rendere at the given index position
/// 
/// parameters:		<index> the index position of the renderer
/// result:			the renderer at that position
///
/// notes:			
///
///********************************************************************************************************************

- (DKRasterizer*)	rendererAtIndex:(unsigned) indx
{
	return (DKRasterizer*)[self objectInRenderListAtIndex:indx];//[[self renderList] objectAtIndex:indx];
}


///*********************************************************************************************************************
///
/// method:			rendererWithName:
/// scope:			public method
/// overrides:		
/// description:	returns the renderer matching the given name
/// 
/// parameters:		<name> the name of the renderer
/// result:			the renderer with that name, if any
///
/// notes:			
///
///********************************************************************************************************************

- (DKRasterizer*)	rendererWithName:(NSString*) name
{
	NSEnumerator*	iter = [[self renderList] objectEnumerator];
	DKRasterizer*		rend;
	
	while(( rend = [iter nextObject]))
	{
		if ([[rend name] isEqualToString:name])
			return rend;
	}
	
	return nil;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			reverseRenderingOrder
/// scope:			public method
/// overrides:		
/// description:	reverses the rendering order of the renderers in the group
/// 
/// parameters:		none
/// result:			none
///
/// notes:			reversal is propagated to any nested groups. Take care, since the reverse always changes the order
///					so you should set reversal at the highest level in a hierarchy that it applies to.
///
///********************************************************************************************************************

- (void)		reverseRenderingOrder
{
	m_reverse = !m_reverse;
	
	// need to reverse the order of any subgroups
	
	NSEnumerator*	iter = [[self renderList] objectEnumerator];
	DKRasterizer*		rend;
	
	while(( rend = [iter nextObject]))
	{
		if ([rend isKindOfClass:[DKRastGroup class]])
			[(DKRastGroup*)rend reverseRenderingOrder];
	}
}


///*********************************************************************************************************************
///
/// method:			isRenderingOrderReversed
/// scope:			public method
/// overrides:		
/// description:	queries whether the rendering order is reversed
/// 
/// parameters:		none
/// result:			YES if reversed, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)		isRenderingOrderReversed
{
	return m_reverse;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			countRenderers
/// scope:			public method
/// overrides:		
/// description:	returns the number of directly contained renderers
/// 
/// parameters:		none
/// result:			the count of renderers
///
/// notes:			doesn't count renderers owned by nested groups within this one
///
///********************************************************************************************************************

- (unsigned)	countOfRenderList
{
	return [[self renderList] count];
}


///*********************************************************************************************************************
///
/// method:			containsRendererOfClass:
/// scope:			public method
/// overrides:		
/// description:	queries whether a renderer of a given class exists somewhere in the render tree
/// 
/// parameters:		<cl> the class to look for
/// result:			YES if there is at least one enabled renderer with the given class, NO otherwise
///
/// notes:			usually called from the top level to get a broad idea of what the group will draw. A style
///					has some higher level methods that call this.
///
///********************************************************************************************************************

- (BOOL)		containsRendererOfClass:(Class) cl
{
	if ([self countOfRenderList] > 0 )
	{
		NSEnumerator*	iter = [[self renderList] objectEnumerator];
		id				rend;
		
		while(( rend = [iter nextObject]))
		{
			if ([rend isKindOfClass:cl] && [rend enabled])
				return YES;
				
			if ([rend isKindOfClass:[DKRastGroup class]])
			{
				if ([rend containsRendererOfClass:cl])
					return YES;
			}
		}
	}

	return NO;
}


///*********************************************************************************************************************
///
/// method:			renderersOfClass:
/// scope:			public method
/// overrides:		
/// description:	returns a flattened list of renderers of a given class
/// 
/// parameters:		<cl> the class to look for
/// result:			an array containing the renderers matching <cl>, or nil.
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)	renderersOfClass:(Class) cl
{
	if ([self containsRendererOfClass:cl])
	{
		NSMutableArray* rl = [[NSMutableArray alloc] init];
		NSEnumerator*	iter = [[self renderList] objectEnumerator];
		id				rend;
		
		while(( rend = [iter nextObject]))
		{
			if ([rend isKindOfClass:cl])
				[rl addObject:rend];
				
			if ([rend isKindOfClass:[self class]])
			{
				NSArray* temp = [rend renderersOfClass:cl];
				[rl addObjectsFromArray:temp];
			}
		}
		
		return [rl autorelease];
	}
	
	return nil;
}


///*********************************************************************************************************************
///
/// method:			removeAllRenderers
/// scope:			public method
/// overrides:		
/// description:	removes all renderers from this group except other groups
/// 
/// parameters:		none
/// result:			none
///
/// notes:			specialist use - not generally for application use
///
///********************************************************************************************************************

- (void)			removeAllRenderers
{
	NSEnumerator*	iter = [[self renderList] reverseObjectEnumerator];
	DKRasterizer*	rast;
	
	while(( rast = [iter nextObject]))
	{
		if(![rast isKindOfClass:[self class]])
			[self removeRenderer:rast];
	}
}


///*********************************************************************************************************************
///
/// method:			removeRenderersOfClass:inSubgroups:
/// scope:			public method
/// overrides:		
/// description:	removes all renderers of the given class, optionally traversing levels below this
/// 
/// parameters:		<cl> the renderer class to remove
/// result:			<subs> if YES, traverses into subgroups and repeats the exercise there. NO to only examine this level.
///
/// notes:			renderers must be an exact match for <class> - subclasses are not considered a match. This is
///					intended for specialist use and should not generally be used by application code
///
///********************************************************************************************************************

- (void)			removeRenderersOfClass:(Class) cl inSubgroups:(BOOL) subs
{
	// removes any renderers of the given *exact* class from the group. If <subs> is YES, recurses down to any subgroups below.
	
	NSEnumerator*	iter = [[self renderList] reverseObjectEnumerator];
	DKRasterizer*	rast;
	
	while(( rast = [iter nextObject]))
	{
		if([rast isMemberOfClass:cl])
			[self removeRenderer:rast];
		else if ( subs && [rast isKindOfClass:[self class]])
			[(DKRastGroup*)rast removeRenderersOfClass:cl inSubgroups:subs];
	}
}


#pragma mark-
#pragma mark KVO-compliant accessor methods for "renderList"


- (id)				objectInRenderListAtIndex:(unsigned) indx
{
	return [[self renderList] objectAtIndex:indx];
}


- (void)			insertObject:(id) obj inRenderListAtIndex:(unsigned) indx
{
	[m_renderList insertObject:obj atIndex:indx];
}


- (void)			removeObjectFromRenderListAtIndex:(unsigned) indx
{
	[m_renderList removeObjectAtIndex:indx];
}


#pragma mark -
#pragma mark As a DKRasterizer
///*********************************************************************************************************************
///
/// method:			isValid
/// scope:			public method
/// overrides:		DKRasterizer
/// description:	determines whther the group will draw anything by finding if any contained renderer will draw anything
/// 
/// parameters:		none
/// result:			YES if at least one contained renderer will draw something
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)		isValid
{
	// returns YES if the group will result in something being actually drawn, NO if not. A group
	// needs to contain at least one stroke, fill, hatch, gradient, etc that will actually set pixels
	// otherwise it will do nothing. In general invalid renderers should be avoided because they may
	// result in invisible graphic objects that can't be seen or selected.

	if ([self countOfRenderList] < 1)
		return NO;
		
	NSEnumerator*	iter = [[self renderList] objectEnumerator];
	DKRasterizer*		rend;
	
	while(( rend = [iter nextObject]))
	{
		if ([rend enabled] && [rend isValid])
			return YES;
	}
	
	// went through list and nothing was valid, so group isn't valid.
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			styleScript
/// scope:			public method
/// overrides:		DKRasterizer
/// description:	returns a style csript representing the group
/// 
/// parameters:		none
/// result:			a string containg a complete script for the group and all contained objects
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)		styleScript
{
	// returns the spec string of this group. The spec string consists of the concatenation of the spec strings for all renderers, formatted
	// with the correct syntax to indicate the full hierarchy and oredr ofthe renderers. The spec string can be used to construct a
	// render group having the same properties.
	
	NSEnumerator*		iter = [[self renderList] objectEnumerator];
	DKRasterizer*			rend;
	NSMutableString*	str;
	
	str = [[NSMutableString alloc] init];
	
	[str setString:@"{"];
	
	while(( rend = [iter nextObject]))
		[str appendString:[rend styleScript]];
	
	[str appendString:@"}"];
	
	return [str autorelease];
}


#pragma mark -
#pragma mark As a GCObservableObject

///*********************************************************************************************************************
///
/// method:			observableKeyPaths
/// scope:			public class method
/// overrides:		GCObservableObject
/// description:	returns the keypaths of the properties that can be observed
/// 
/// parameters:		none
/// result:			an array listing the observable key paths
///
/// notes:			
///
///********************************************************************************************************************

+ (NSArray*)	observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"renderList", nil]];
}


///*********************************************************************************************************************
///
/// method:			observableKeyPaths
/// scope:			public instance method
/// overrides:		GCObservableObject
/// description:	registers the action names for the observable properties published by the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		registerActionNames
{
	[super registerActionNames];
	
	// note that all operations on the group's contents invoke the same keypath via KVO, so the action name is
	// not very fine-grained. TO DO - find a better way. (n.b. for DKStyle, undo is handled differently
	// and overrides the KVO mechanism, avoiding this issue - only sub-groups are affected)
	
	[self setActionName:@"#kind# Component Group" forKeyPath:@"renderList"];
}


///*********************************************************************************************************************
///
/// method:			setUpKVOForObserver:
/// scope:			public instance method
/// overrides:		GCObservableObject
/// description:	sets up KVO for the given observer object
/// 
/// parameters:		<object> the observer
/// result:			none
///
/// notes:			propagates the request down to all the components in the group, including other groups so the
///					entire tree is traversed
///
///********************************************************************************************************************

- (BOOL)		setUpKVOForObserver:(id) object
{
	[[self renderList] makeObjectsPerformSelector:@selector( setUpKVOForObserver: ) withObject:object];
	return [super setUpKVOForObserver:object];
}


///*********************************************************************************************************************
///
/// method:			tearDownKVOForObserver:
/// scope:			public instance method
/// overrides:		GCObservableObject
/// description:	tears down KVO for the given observer object
/// 
/// parameters:		<object> the observer
/// result:			none
///
/// notes:			propagates the request down to all the components in the group, including other groups so the
///					entire tree is traversed
///
///********************************************************************************************************************

- (BOOL)		tearDownKVOForObserver:(id) object
{
	[[self renderList] makeObjectsPerformSelector:@selector( tearDownKVOForObserver: ) withObject:object];
	return [super tearDownKVOForObserver:object];
}


#pragma mark -
#pragma mark As an NSObject

- (void)		dealloc
{
	[m_renderList release];
	[super dealloc];
}


- (id)			init
{
	self = [super init];
	if (self != nil)
	{
		m_renderList = [[NSMutableArray alloc] init];
		NSAssert(!m_reverse, @"Expected init to NO");
		
		if (m_renderList == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizer Protocol
///*********************************************************************************************************************
///
/// method:			extraSpaceNeeded
/// scope:			public method
/// overrides:		DKRasterizer
/// description:	determines the extra space needed to render by finding the most space needed by any contained renderer
/// 
/// parameters:		none
/// result:			the extra width and height needed over and above the object's (path) bounds
///
/// notes:			
///
///********************************************************************************************************************

- (NSSize)		extraSpaceNeeded
{
	NSSize			rs, accSize = NSZeroSize;

	if ([self enabled])
	{
		NSEnumerator*	iter = [[self renderList] objectEnumerator];
		DKRasterizer*		rend;
		
		while(( rend = [iter nextObject]))
		{
			rs = [rend extraSpaceNeeded];
			
			if ( rs.width > accSize.width )
				accSize.width = rs.width;
				
			if ( rs.height > accSize.height )
				accSize.height = rs.height;
		}
	}
	
	return accSize;
}


///*********************************************************************************************************************
///
/// method:			render:
/// scope:			public method
/// overrides:		DKRasterizer
/// description:	renders the object by iterating over the contained renderers
/// 
/// parameters:		<object> the object to render
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		render:(id) object
{
	if(! [self enabled])
		return;
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	NSEnumerator*	iter;
	DKRasterizer*		rend;
	
	if ([self isRenderingOrderReversed])
		iter = [[self renderList] reverseObjectEnumerator];
	else
		iter = [[self renderList] objectEnumerator];
	
	while(( rend = [iter nextObject]))
	{
		if([rend enabled])
			[rend render:object];
	}
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}


///*********************************************************************************************************************
///
/// method:			renderPath:
/// scope:			public method
/// overrides:		DKRasterizer
/// description:	renders the object's path by iterating over the contained renderers
/// 
/// parameters:		<path> the path to render
/// result:			none
///
/// notes:			normally groups and styles should use render: but this provides correct behaviour if a top level
///					object elects to use the path (in general, don't do this)
///
///********************************************************************************************************************

- (void)		renderPath:(NSBezierPath*) path
{
	if(! [self enabled])
		return;
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	NSEnumerator*	iter;
	DKRasterizer*		rend;
	
	if ([self isRenderingOrderReversed])
		iter = [[self renderList] reverseObjectEnumerator];
	else
		iter = [[self renderList] objectEnumerator];
	
	while(( rend = [iter nextObject]))
	{
		if([rend enabled])
			[rend renderPath:path];
	}
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}


#pragma mark -
#pragma mark As part of GraphicsAttributes Protocol
///*********************************************************************************************************************
///
/// method:			setValue:forNumericParameter:
/// scope:			public method
/// overrides:		NSObject (GraphicsAttributes)
/// description:	installs renderers when built from a script
/// 
/// parameters:		<val> a renderer object
///					<pnum> th eordinal position of the value in the original expression. Not used here.
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		setValue:(id) val forNumericParameter:(int) pnum
{
	LogEvent_(kReactiveEvent, @"anonymous parameter #%d, value = %@", pnum, val );
	
	// if <val> conforms to the DKRasterizer protocol, we add it
	
	if ([val conformsToProtocol:@protocol(DKRasterizer)])
		[self addRenderer:val];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeConditionalObject:[self container] forKey:@"DKRastGroup_container"];
	[coder encodeObject:[self renderList] forKey:@"renderlist"];
	[coder encodeBool:m_reverse forKey:@"reverse"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setContainer:[coder decodeObjectForKey:@"DKRastGroup_container"]];
		[self setRenderList:[coder decodeObjectForKey:@"renderlist"]];
		m_reverse = [coder decodeBoolForKey:@"reverse"];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)			copyWithZone:(NSZone*) zone
{
	DKRastGroup* copy = [super copyWithZone:zone];
	
	NSArray* rl = [[self renderList] deepCopy];
	[copy setRenderList:rl];
	[rl release];
	
	copy->m_reverse = m_reverse;
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSKeyValueCoding Protocol
///*********************************************************************************************************************
///
/// method:			renderClassForKey:
/// scope:			public method
/// overrides:		
/// description:	returns a renderer class associated with the given key
/// 
/// parameters:		<key> a key for the renderer class
/// result:			a renderer class matching the key, if any
///
/// notes:			this is used to support simple UI's that bind to certain renderers based on generic keypaths
///
///********************************************************************************************************************

- (Class)		renderClassForKey:(NSString* )key
{
	// TO DO: make this a much smarter and more general lookup
	
	if ([@"fill" isEqualToString:key])
		return [DKFill class];
		
	else if ([@"stroke" isEqualToString:key])
		return [DKStroke class];
		
	else if ([@"gradient" isEqualToString:key])
		return [DKGradient class];
	else
		return Nil;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			valueForUndefinedKey:
/// scope:			public method
/// overrides:		NSObject
/// description:	returns a renderer class associated with the given key
/// 
/// parameters:		<key> a key for the renderer class
/// result:			a renderer matching the key, if any
///
/// notes:			this is used to support simple UI's that bind to certain renderers based on generic keypaths. Here,
///					the renderer is preferentially referred to by name, but if that fails, falls back on generic
///					lookup based on a simplified classname.
///
///********************************************************************************************************************

- (id)			valueForUndefinedKey:(NSString*) key
{
	NSEnumerator*	iter = [[self renderList] objectEnumerator];
	DKRasterizer*		rend;
	Class			classForKey = [self renderClassForKey:key];
	
	while(( rend = [iter nextObject]))
	{
		if ([[rend name] isEqualToString:key] ||
			(classForKey && [rend isKindOfClass:classForKey]))
			return rend;
	}
	return nil;
}


@end
