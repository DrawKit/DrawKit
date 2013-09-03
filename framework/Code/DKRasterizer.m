///**********************************************************************************************************************************
///  DKRasterizer.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 23/11/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKRasterizer.h"
#import "DKStyle.h"
#import "LogEvent.h"
#import "NSBezierPath+Geometry.h"

NSString*	kDKRasterizerPasteboardType		= @"kDKRendererPasteboardType";
NSString*	kDKRasterizerPropertyWillChange	= @"kDKRasterizerPropertyWillChange";
NSString*	kDKRasterizerPropertyDidChange	= @"kDKRasterizerPropertyDidChange";
NSString*	kDKRasterizerChangedPropertyKey = @"kDKRasterizerChangedPropertyKey";

@implementation DKRasterizer
#pragma mark As a DKRasterizer

+ (DKRasterizer*)		rasterizerFromPasteboard:(NSPasteboard*) pb
{
	// creates a renderer from the pasteboard if possible. Returns the renderer, or nil.
	
	NSAssert( pb != nil, @"expected a non-nil pasteboard");
	
	DKRasterizer* rend = nil;
	NSString* typeString = [pb availableTypeFromArray:[NSArray arrayWithObject:kDKRasterizerPasteboardType]];
	
	if ( typeString != nil )
	{
		NSData* data = [pb dataForType:typeString];
		
		if ( data != nil )
			rend = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	}
	
	return rend;
}


///*********************************************************************************************************************
///
/// method:			container
/// scope:			public method
/// overrides:		
/// description:	returns the immediate container of this object, if owned by a group
/// 
/// parameters:		none
/// result:			the object's container group, if any
///
/// notes:			
///
///********************************************************************************************************************

- (DKRastGroup*)	container
{
	return mContainerRef;
}


///*********************************************************************************************************************
///
/// method:			setContainer:
/// scope:			private method
/// overrides:		
/// description:	sets the immediate container of this object
/// 
/// parameters:		<container> the objects's container - must be a group, or nil
/// result:			none
///
/// notes:			this is a weak reference as the object is owned by its container. Generally this is called as
///					required when the object is added to a group, so should not be used by app code
///
///********************************************************************************************************************

- (void)			setContainer:(DKRastGroup*) container
{
	if ( container != nil && ![container isKindOfClass:[DKRastGroup class]])
		[NSException raise:NSInternalInconsistencyException format:@"attempt to set the container to an illegal object type"];
	
	mContainerRef = container;
}

#pragma mark -
///*********************************************************************************************************************
///
/// method:			setName:
/// scope:			public method
/// overrides:
/// description:	set the name of the renderer
/// 
/// parameters:		<name> the name to give the renderer
/// result:			none
///
/// notes:			named renderers can be referred to in scripts or bound to in the UI. The name is copied for safety.
///
///********************************************************************************************************************

- (void)		setName:(NSString*) name
{
	NSString* nameCopy = [name copy];
	
	[m_name release];
	m_name = nameCopy;
}


///*********************************************************************************************************************
///
/// method:			name
/// scope:			public method
/// overrides:
/// description:	get the name of the renderer
/// 
/// parameters:		none
/// result:			the renderer's name
///
/// notes:			named renderers can be referred to in scripts or bound to in the UI
///
///********************************************************************************************************************

- (NSString*)	name
{
	return m_name;
}


///*********************************************************************************************************************
///
/// method:			label
/// scope:			public method
/// overrides:
/// description:	get the name or classname of the renderer
/// 
/// parameters:		none
/// result:			the renderer's name or classname
///
/// notes:			named renderers can be referred to in scripts or bound to in the UI
///
///********************************************************************************************************************

- (NSString*)	label
{
	if ([self name])
		return [self name];
	else
		return NSStringFromClass ([self class]);
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			isValid
/// scope:			public method
/// overrides:
/// description:	queries whether the renderer is valid, that is, it will draw something.
/// 
/// parameters:		none
/// result:			YES if the renderer will draw something, NO otherwise
///
/// notes:			used to optimize drawing - invalid renderers are skipped
///
///********************************************************************************************************************

- (BOOL)		isValid
{
	return NO;
}


///*********************************************************************************************************************
///
/// method:			styleScript
/// scope:			public method
/// overrides:
/// description:	return the equivalent style script for this renderer
/// 
/// parameters:		none
/// result:			a string, representing the script that would create an equivalent renderer if parsed
///
/// notes:			subclasses shold override this - the default method returns the object's description for debugging.
///
///********************************************************************************************************************

- (NSString*)	styleScript
{
	return [NSString stringWithFormat:@"(%@)", self];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setEnabled:
/// scope:			public method
/// overrides:
/// description:	set whether the renderer is enabled or not
/// 
/// parameters:		<enable> YES to enable, NO to disable
/// result:			none
///
/// notes:			disabled renderers won't draw anything, so this can be used to temporarily turn off part of a
///					larget set of renderers (in a style, say) from the UI, but without actually deleting the renderer
///
///********************************************************************************************************************

- (void)		setEnabled:(BOOL) enable
{
	m_enabled = enable;
}


///*********************************************************************************************************************
///
/// method:			enabled
/// scope:			public method
/// overrides:
/// description:	query whether the renderer is enabled or not
/// 
/// parameters:		none
/// result:			YES if enabled, NO if not
///
/// notes:			disabled renderers won't draw anything, so this can be used to temporarily turn off part of a
///					larget set of renderers (in a style, say) from the UI, but without actually deleting the renderer
///
///********************************************************************************************************************

- (BOOL)		enabled
{
	return m_enabled;
}


///*********************************************************************************************************************
///
/// method:			setClipping:
/// scope:			public method
/// overrides:
/// description:	set whether the rasterizer's effect is clipped to the path or not, and if so, which side
/// 
/// parameters:		<clipping> a DKClippingOption value
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		setClipping:(DKClippingOption) clipping
{
	mClipping = clipping;
}


- (void)		setClippingWithoutNotifying:(DKClippingOption) clipping
{
	mClipping = clipping;
}


///*********************************************************************************************************************
///
/// method:			clipping:
/// scope:			public method
/// overrides:
/// description:	whether the rasterizer's effect is clipped to the path or not, and if so, which side
/// 
/// parameters:		none
/// result:			a DKClippingOption value
///
/// notes:			
///
///********************************************************************************************************************

- (DKClippingOption) clipping
{
	return mClipping;
}



#pragma mark -
///*********************************************************************************************************************
///
/// method:			renderingPathForObject:
/// scope:			protected method
/// overrides:
/// description:	returns the path to render given the object doing the rendering
/// 
/// parameters:		<object> the object to render
/// result:			the rendering path
///
/// notes:			this method is called internally by render: to obtain the path to be rendered. It is factored to
///					allow a delegate to modify the path just before rendering, and to allow special subclasses to
///					override it to modify the path for special effects. The normal behaviour is simply to ask the
///					object for its rendering path.
///
///********************************************************************************************************************

- (NSBezierPath*)	renderingPathForObject:(id<DKRenderable>) object
{
	return [object renderingPath];
}


- (BOOL)			copyToPasteboard:(NSPasteboard*) pb
{
	NSAssert( pb != nil, @"expected pasteboard to be non-nil");
	
	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:self];

	if ( data != nil )
	{
		[pb declareTypes:[NSArray arrayWithObject:kDKRasterizerPasteboardType] owner:self];
		return [pb setData:data forType:kDKRasterizerPasteboardType];
	}
	
	return NO;
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [NSArray arrayWithObjects:@"name", @"enabled", @"clipping", nil];
}


- (NSString*)		actionNameForKeyPath:(NSString*) keypath changeKind:(NSKeyValueChange) kind
{
	if([keypath isEqualToString:@"enabled"])
	{
		if ([self enabled])
			return NSLocalizedString(@"Enable Style Component", @"undo string for enable component");
		else
			return NSLocalizedString(@"Disable Style Component", @"undo string for enable component");
	}
	else	
		return [super actionNameForKeyPath:keypath changeKind:kind];
}

#pragma mark -
#pragma mark As an NSObject
- (void)		dealloc
{
	[m_name release];
	[super dealloc];
}


- (id)				init
{
	self = [super init];
	if(self != nil)
	{
		m_enabled = YES;
		mClipping = kDKClippingNone;
	}
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizer Protocol
///*********************************************************************************************************************
///
/// method:			extraSpaceNeeded
/// scope:			public method
/// overrides:
/// description:	returns the amount of extra space the renderer needs to draw its output over and above the bounds
///					of the object or path requesting the render
/// 
/// parameters:		none
/// result:			a size, the additional width and height needed
///
/// notes:			default method returns zero extra space needed. Subclasses need to accurately return the amount
///					needed. If they don't you risk drawing outside the object's bounds which will lead to improper
///					updates and erasure of pixels.
///
///********************************************************************************************************************

- (NSSize)		extraSpaceNeeded
{
	return NSZeroSize;
}


///*********************************************************************************************************************
///
/// method:			render:
/// scope:			public method
/// overrides:
/// description:	renders an object
/// 
/// parameters:		<object> the object to render
/// result:			none
///
/// notes:			default method extracts the path and calls -renderPath:
///
///********************************************************************************************************************

- (void)		render:(id<DKRenderable>) object
{
	if( ! [object conformsToProtocol:@protocol(DKRenderable)])
		return;
	
	if ([self enabled])
	{
		NSBezierPath* path = [self renderingPathForObject:object];
		SAVE_GRAPHICS_CONTEXT	//[NSGraphicsContext saveGraphicsState];
		
		switch([self clipping])
		{
			default:
			case kDKClippingNone:
				break;
			
			case kDKClipInsidePath:
				[path addClip];
				break;
				
			case kDKClipOutsidePath:
				[path addInverseClip];
				break;
		}
		
		[self renderPath:path];
		RESTORE_GRAPHICS_CONTEXT		//[NSGraphicsContext restoreGraphicsState];
	}
}


///*********************************************************************************************************************
///
/// method:			renderPath:
/// scope:			public method
/// overrides:
/// description:	renders an object's path
/// 
/// parameters:		<path> the path to render
/// result:			none
///
/// notes:			default method does nothing. Subclasses will override this (or -render:) and implement the actual
///					rendering
///
///********************************************************************************************************************

- (void)		renderPath:(NSBezierPath*) path
{
	#pragma unused(path)
	
	// placeholder
}


///*********************************************************************************************************************
///
/// method:			isFill
/// scope:			public method
/// overrides:
/// description:	queries whther the rasterizer implements a fill or not
/// 
/// parameters:		none
/// result:			YES if the rasterizer is considered a fill type
///
/// notes:			default is NO - subclasses must override to return this appropriately. A style uses this result
///					to determine whether it implements any fills, which in turn affect swatches, object hit-testing
///					and so on.
///
///********************************************************************************************************************

- (BOOL)		isFill
{
	return NO;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeObject:[self name] forKey:@"name"];
	[coder encodeBool:[self enabled] forKey:@"enabled"];
	[coder encodeInteger:[self clipping] forKey:@"DKRasterizer_clipping"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super init];
	if(self != nil)
	{
		[self setName:[coder decodeObjectForKey:@"name"]];
		[self setEnabled:[coder decodeBoolForKey:@"enabled"]];
		[self setClipping:[coder decodeIntegerForKey:@"DKRasterizer_clipping"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)			copyWithZone:(NSZone*) zone
{
	DKRasterizer* copy = [[[self class] allocWithZone:zone] init];
	
	[copy setName:[self name]];
	[copy setEnabled:[self enabled]];
	[copy setClipping:[self clipping]];
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSKeyValueObserving Protocol
///*********************************************************************************************************************
///
/// method:			willChangeValueForKey:
/// scope:			public method
/// overrides:		NSObject
/// description:	intercepts impending change via KVC to force an update of any client objects
/// 
/// parameters:		<key> the key for the value about to be changed
/// result:			none
///
/// notes:			assumes top level of hierarchy is in fact a style. In practice it nearly always will be, but if
///					not should not cause any problems. This also sends a notificaiton which can be used in more
///					general-purpose situations such as when a rasterizer is used without a style.
///
///********************************************************************************************************************

- (void)		willChangeValueForKey:(NSString*) key
{
	LogEvent_( kKVOEvent, @"%@ about to change '%@'", self, key );
	
	NSDictionary* info = [NSDictionary dictionaryWithObject:key forKey:kDKRasterizerChangedPropertyKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKRasterizerPropertyWillChange object:self userInfo:info];

	id top = [[self container] root];
	
	if( top && [top respondsToSelector:@selector(notifyClientsBeforeChange)])
		[top notifyClientsBeforeChange]; 

	[super willChangeValueForKey:key];
}


///*********************************************************************************************************************
///
/// method:			didChangeValueForKey:
/// scope:			public method
/// overrides:		NSObject
/// description:	notifies that a property change took place
/// 
/// parameters:		<key> the key for the value that was changed
/// result:			none
///
/// notes:			Sends a notificaiton which can be used in more
///					general-purpose situations such as when a rasterizer is used without a style.
///
///********************************************************************************************************************

- (void)		didChangeValueForKey:(NSString*) key
{
	[super didChangeValueForKey:key];

	NSDictionary* info = [NSDictionary dictionaryWithObject:key forKey:kDKRasterizerChangedPropertyKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKRasterizerPropertyDidChange object:self userInfo:info];
}


@end


#pragma mark -
@implementation NSObject (DKRendererDelegate)
#pragma mark Renderer Delegate
- (NSBezierPath*)	renderer:(DKRasterizer*) aRenderer willRenderPath:(NSBezierPath*) aPath
{
	#pragma unused(aRenderer)
	
	// default is to return the path entirely unmodified
	
	return aPath;
}

@end
