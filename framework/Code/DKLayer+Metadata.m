///**********************************************************************************************************************************
///  DKDrawing+Metadata.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 19/03/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKLayer+Metadata.h"
#import "LogEvent.h"


#define		USE_107_OR_LATER_SCHEMA		1

NSString*	kDKLayerMetadataUserInfoKey						= @"kDKLayerMetadataUserInfoKey";
NSString*	kDKLayerMetadataUndoableChangesUserDefaultsKey	= @"kDKLayerMetadataUndoableChangesUserDefaultsKey";


@implementation DKLayer (Metadata)
#pragma mark As a DKLayer


+ (void)		setMetadataChangesAreUndoable:(BOOL) undo
{
	[[NSUserDefaults standardUserDefaults] setBool:!undo forKey:kDKLayerMetadataUndoableChangesUserDefaultsKey];
}


+ (BOOL)		metadataChangesAreUndoable
{
	return ![[NSUserDefaults standardUserDefaults] boolForKey:kDKLayerMetadataUndoableChangesUserDefaultsKey];
}


- (void)		setupMetadata
{
#if USE_107_OR_LATER_SCHEMA
	if([self metadata] == nil)
		[self setUserInfoObject:[NSMutableDictionary dictionary] forKey:kDKLayerMetadataUserInfoKey];
#else	
	if ([self userInfo] == nil && ![self locked])
		[self setUserInfo:[NSMutableDictionary dictionaryWithCapacity:8]];
#endif
}


- (NSMutableDictionary*)	metadata
{
#if USE_107_OR_LATER_SCHEMA
	return (NSMutableDictionary*)[self userInfoObjectForKey:kDKLayerMetadataUserInfoKey];
#else
	return [self userInfo];
#endif
}


- (DKLayerMetadataSchema)	schema
{
	id obj = [self userInfoObjectForKey:kDKLayerMetadataUserInfoKey];
	if( obj )
		return kDKLayerMetadata107Schema;
	
	return kDKLayerMetadataOriginalSchema;
}


- (NSArray*)				metadataKeys
{
	return [[self metadata] allKeys];
}


- (void)		setMetadataItem:(DKMetadataItem*) item forKey:(NSString*) key
{
	if( ![self locked])
	{
		[self setupMetadata];

		DKMetadataItem* oldValue = [self metadataItemForKey:key];
		
		if([[self class] metadataChangesAreUndoable])
		{
			if( oldValue )
				[[[self undoManager] prepareWithInvocationTarget:self] setMetadataItem:oldValue forKey:key];
			else
				[[[self undoManager] prepareWithInvocationTarget:self] removeMetadataForKey:key];
		}
		
		[self metadataWillChangeKey:key];
		item = [item copy];
		[[self metadata] setObject:item forKey:[key lowercaseString]];
		[item release];
		
		[self metadataDidChangeKey:key];
	}
}


- (DKMetadataItem*)	metadataItemForKey:(NSString*) key
{
	DKMetadataItem* item = [[self metadata] objectForKey:[key lowercaseString]];
	
	if( item == nil )
		item = [[self layerGroup] metadataItemForKey:key];
	
	return item;
}


- (void)		setMetadataItemValue:(id) value forKey:(NSString*) key
{
	// if an item exists for <key> its value is set to <value>. This records the old value for Undo if enabled. It does nothing if the
	// item doesn't exist already.
	
	if(![self locked])
	{
		DKMetadataItem* item = [self metadataItemForKey:key];
		
		if( item )
		{
			if([[self class] metadataChangesAreUndoable])
				[[[self undoManager] prepareWithInvocationTarget:self] setMetadataItemValue:[item value] forKey:key];

			[self metadataWillChangeKey:key];
			[item setValue:value];
			[self metadataDidChangeKey:key];
		}
	}
}


- (void)		setMetadataItemType:(DKMetadataType) type forKey:(NSString*) key
{
	// undoably sets the type of an item. Note tha changing types can be lossy - this does not care whether that is the case. You can
	// query an item to see if a type change would be lossy before calling this if necessary.
	
	if( ![self locked])
	{
		DKMetadataItem* item = [self metadataItemForKey:key];
		
		if( item )
		{
			if([[self class] metadataChangesAreUndoable])
			{
				// so that undo can revert a lossy change, the entire item is copied
				
				DKMetadataItem* oldItem = [item copy];
				[[[self undoManager] prepareWithInvocationTarget:self] setMetadataItem:oldItem forKey:key];
				[oldItem release];
			}
			
			[self metadataWillChangeKey:key];
			[item setType:type];
			[self metadataDidChangeKey:key];
		}
	}
}



- (void)		addMetadata:(NSDictionary*) dict
{
	if( dict )
	{
		if([[self class] metadataChangesAreUndoable])
		{
			NSDictionary*	mdCopy = [[self metadata] copy];
			[[[self undoManager] prepareWithInvocationTarget:self] setMetadata:mdCopy];
			[mdCopy release];
		}
		
#if USE_107_OR_LATER_SCHEMA
		// wrap objects in the input dictionary with DKMetadataItems. Note that even if the input dict is already in this
		// form, the operation will work OK (though the copy that will occur is not really needed).
		
		dict = [DKMetadataItem dictionaryOfMetadataItemsWithDictionary:dict];
#endif
		
		[self setupMetadata];
		[self metadataWillChangeKey:nil];
		[[self metadata] addEntriesFromDictionary:dict];
		[self metadataDidChangeKey:nil];
	}
}


- (void)		setMetadata:(NSDictionary*) dict
{
	NSAssert( dict != nil, @"Cannot set metadata to a nil dictionary");
	
	if([[self class] metadataChangesAreUndoable])
		[[[self undoManager] prepareWithInvocationTarget:self] setMetadata:[self metadata]];
	
	[self metadataWillChangeKey:nil];
	NSMutableDictionary* md = [dict mutableCopy];
#if USE_107_OR_LATER_SCHEMA
	[self setUserInfoObject:md forKey:kDKLayerMetadataUserInfoKey];
#else
	[self setUserInfo:md];
#endif
	[md release];
	[self metadataDidChangeKey:nil];
}


#pragma mark -
- (void)		setMetadataObject:(id) obj forKey:(id) key
{
	NSAssert( obj != nil, @"cannot set a nil metadata object");
	NSAssert( key != nil, @"cannot use a nil metadata key");
	
#if USE_107_OR_LATER_SCHEMA
	NSLog(@"[DKLayer setMetadataObject:forKey:] is deprecated - please migrate code to -setMetadataItem:forKey: instead");
#endif	
	
	if( ![self locked])
	{
		[self setupMetadata];
		[self metadataWillChangeKey:key];
		[[self metadata] setObject:obj forKey:[key lowercaseString]];
		[self metadataDidChangeKey:key];
	}
}


- (id)			metadataObjectForKey:(NSString*) key
{
	// retrieve the metadata object for the given key. As an extra bonus, if the
	// key is a string, and it starts with a dollar sign, the rest of the string is used
	// as a keypath, and will return the property at that keypath. This allows stuff that
	// reads metadata to introspect objects in the framework - for example $style.name returns the style name, etc.
	
	if([key length] > 1 && [[key substringWithRange:NSMakeRange( 0, 1 )] isEqualToString:@"$"])
	{
		NSString* keyPath = [key substringFromIndex:1];
		return [self valueForKeyPath:keyPath];
	}

#if USE_107_OR_LATER_SCHEMA
	
	return [[self metadataItemForKey:key] value];
	
#else
	
	id object = [[self metadata] objectForKey:[key lowercaseString]];

	// search upwards through the containment hierarchy for the data. If it is anywhere between here and the root drawing, it will be found.
	
	if( object == nil )
		object = [[self layerGroup] metadataObjectForKey:key];
		
	return object;
#endif
}


- (BOOL)		hasMetadataForKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	return ([self metadataItemForKey:key] != nil);
#else
	return ([self metadataObjectForKey:key] != nil);
#endif
}


- (void)		removeMetadataForKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	if([[self class] metadataChangesAreUndoable])
	{
		DKMetadataItem* item = [self metadataItemForKey:key];
		
		if( item )
			[[[self undoManager] prepareWithInvocationTarget:self] setMetadataItem:item forKey:key];
	}
#else
	if([[self class] metadataChangesAreUndoable])
	{
		id obj = [self metadataObjectForKey:key];
		
		if( obj )
			[[[self undoManager] prepareWithInvocationTarget:self] setMetadataObject:obj forKey:key];
	}
#endif	
	[self metadataWillChangeKey:key];
	[[self metadata] removeObjectForKey:[key lowercaseString]];
	[self metadataDidChangeKey:key];
}


#pragma mark -
- (void)		setFloatValue:(float) val forKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	[self setMetadataItem:[DKMetadataItem metadataItemWithReal:val] forKey:key];
#else
	[self setMetadataObject:[NSNumber numberWithDouble:val] forKey:key];
#endif
}


- (CGFloat)		floatValueForKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	return [[self metadataItemForKey:key] floatValue];
#else
	return [[self metadataObjectForKey:key] doubleValue];
#endif
}


- (void)		setIntValue:(int) val forKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	[self setMetadataItem:[DKMetadataItem metadataItemWithInteger:val] forKey:key];
#else
	[self setMetadataObject:[NSNumber numberWithInteger:val] forKey:key];
#endif
}


- (NSInteger)			intValueForKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	return [[self metadataItemForKey:key] intValue];
#else
	return [[self metadataObjectForKey:key] integerValue];
#endif
}


- (void)		setString:(NSString*) string forKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	[self setMetadataItem:[DKMetadataItem metadataItemWithString:string] forKey:key];
#else
	[self setMetadataObject:string forKey:key];
#endif
}


- (NSString*)	stringForKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	return [[self metadataItemForKey:key] stringValue];
#else
	return (NSString*)[self metadataObjectForKey:key];
#endif
}


- (void)		setColour:(NSColor*) colour forKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	[self setMetadataItem:[DKMetadataItem metadataItemWithColour:colour] forKey:key];
#else
	[self setMetadataObject:colour forKey:key];
#endif
}


- (NSColor*)	colourForKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	return [[self metadataItemForKey:key] colourValue];
#else
	return (NSColor*)[self metadataObjectForKey:key];
#endif
}


- (void)		setSize:(NSSize) size forKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	[self setMetadataItem:[DKMetadataItem metadataItemWithSize:size] forKey:key];
#else
	// save as 2 keyed floats to allow keyed archiving of the metadata
	
	[self setMetadataObject:[NSNumber numberWithDouble:size.width] forKey:[NSString stringWithFormat:@"%@.size_width", key]];
	[self setMetadataObject:[NSNumber numberWithDouble:size.height] forKey:[NSString stringWithFormat:@"%@.size_height", key]];
#endif
}


- (NSSize)		sizeForKey:(NSString*) key
{
#if USE_107_OR_LATER_SCHEMA
	return [[self metadataItemForKey:key] sizeValue];
#else
	NSSize size;
	
	size.width = [[self metadataObjectForKey:[NSString stringWithFormat:@"%@.size_width", key]] doubleValue];
	size.height = [[self metadataObjectForKey:[NSString stringWithFormat:@"%@.size_height", key]] doubleValue];
	
	return size;
#endif
}


- (void)		metadataWillChangeKey:(NSString*) key
{
	NSDictionary* userInfo = nil;
	if( key )
		userInfo = [NSDictionary dictionaryWithObject:[key lowercaseString] forKey:@"key"];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKMetadataWillChangeNotification object:self userInfo:userInfo];
}


- (void)		metadataDidChangeKey:(NSString*) key;
{
	NSDictionary* userInfo = nil;
	if( key )
		userInfo = [NSDictionary dictionaryWithObject:[key lowercaseString] forKey:@"key"];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKMetadataDidChangeNotification object:self userInfo:userInfo];
}



#pragma mark -

- (void)		updateMetadataKeys
{
	// this method migrates the metadata to the current schema. In the original schema, raw values were stored directly in the user info
	// with case sensitive keys. Later, case insensitive keys were used (by making them always lowercase when set). In the 107 schema,
	// the metadata was stored in DKMetadataItem objects within a subdictionary within the user info, also with case insensitive keys.
	
	// Also in the 107 schema, drawing info set by DKDrawing is stored in a separate subdictionary (but not using DKMetadataItem wrappers).
	// To deal with that, DKDrawing implements an override of this method which migrates its user info items to the drawing info subdictionary.
	
	DKLayerMetadataSchema	schema = [self schema];
	
	if( schema == kDKLayerMetadata107Schema )
		return;	// up to date - nothing to do
	
	// assume original schema
	
	NSMutableDictionary*	metaDict = [NSMutableDictionary dictionaryWithDictionary:[self userInfo]];
	
	[[self userInfo] removeAllObjects];

#if USE_107_OR_LATER_SCHEMA
	// update directly to the 107 schema
	
	metaDict = [[DKMetadataItem dictionaryOfMetadataItemsWithDictionary:metaDict] mutableCopy];
	[self setUserInfoObject:metaDict forKey:kDKLayerMetadataUserInfoKey];
	[metaDict release];
#else
	
	// just ensure all keys are lowercase
	
	NSEnumerator*			iter = [[metaDict allKeys] objectEnumerator];
	NSString*				key;
	id						value;
	
	while(( key = [iter nextObject]))
	{
		value = [[metaDict objectForKey:key] retain];
		[metaDict removeObjectForKey:key];
		[metaDict setObject:value forKey:[key lowercaseString]];
		[value release];
	}
#endif
}



- (NSUInteger)	metadataChecksum
{
	NSUInteger cs = 319162352;	// arbitrary
	
	NSMutableArray* array = [[[self metadata] allKeys] mutableCopy];
	[array sortUsingSelector:@selector(compare:)];
	
	NSEnumerator*	iter = [array objectEnumerator];
	NSString*		key;
	id				value;
	
	while(( key = [iter nextObject]))
	{
#if USE_107_OR_LATER_SCHEMA
		value = [[self metadataItemForKey:key] value];
#else
		value = [self metadataObjectForKey:key];
#endif
		cs ^= [key hash] ^ [value hash];
	}
	
	[array release];
	
	if([self layerGroup])
		cs ^= [[self layerGroup] metadataChecksum];
	
	return cs;
}


- (BOOL)		supportsMetadata
{
	// subclasses that want to prevent access to metadata for a layer can override this to return NO. Controllers that provide
	// UI to metadata need to check this - it is not honoured at this level.
	
	return YES;
}


@end
