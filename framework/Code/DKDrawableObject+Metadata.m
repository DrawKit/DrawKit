///**********************************************************************************************************************************
///  DKDrawableObject+Metadata.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 19/03/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawableObject+Metadata.h"
#import "DKUndoManager.h"
#import "LogEvent.h"

NSString*	kDKMetaDataUserInfoKey				= @"kDKMetaDataUserInfoKey";
NSString*	kDKMetaDataUserInfo107OrLaterKey	= @"kDKMetaDataUserInfo107OrLaterKey";
NSString*	kDKMetadataWillChangeNotification	= @"kDKMetadataWillChangeNotification";
NSString*	kDKMetadataDidChangeNotification	= @"kDKMetadataDidChangeNotification";
NSString*	kDKUndoableChangesUserDefaultsKey	= @"DKMetadataChangesAreNotUndoable";

#define		USE_107_OR_LATER_SCHEMA		1



@implementation DKDrawableObject (Metadata)
#pragma mark As a DKDrawableObject


+ (void)		setMetadataChangesAreUndoable:(BOOL) undo
{
	[[NSUserDefaults standardUserDefaults] setBool:!undo forKey:kDKUndoableChangesUserDefaultsKey];
}


+ (BOOL)		metadataChangesAreUndoable
{
	return ![[NSUserDefaults standardUserDefaults] boolForKey:kDKUndoableChangesUserDefaultsKey];
}


- (NSMutableDictionary*)	metadata
{
#if USE_107_OR_LATER_SCHEMA
	return (NSMutableDictionary*)[self userInfoObjectForKey:kDKMetaDataUserInfo107OrLaterKey];
#else
	return (NSMutableDictionary*)[self userInfoObjectForKey:kDKMetaDataUserInfoKey];
#endif
}



- (NSArray*)	metadataKeys
{
	return [[self metadata] allKeys];
}



- (void)		setupMetadata
{
	if ([self metadata] == nil && ![self locked])
	{
#if USE_107_OR_LATER_SCHEMA
		[self setUserInfoObject:[NSMutableDictionary dictionary] forKey:kDKMetaDataUserInfo107OrLaterKey];
#else		
		[self setUserInfoObject:[NSMutableDictionary dictionary] forKey:kDKMetaDataUserInfoKey];
#endif
	}
}


- (DKMetadataSchema) schema
{
	// detects the current schema and returns a constant indicating which is in use. When an object is unarchived it is automatically
	// migrated to the latest schema using the -updateMetadataKeys method.
	
	id obj = [self userInfoObjectForKey:kDKMetaDataUserInfoKey];
	
	if( obj )
		return kDKMetadataMark2Schema;
	else
	{
		obj = [self userInfoObjectForKey:kDKMetaDataUserInfo107OrLaterKey];
		if( obj )
			return kDKMetadata107Schema;
	}
	
	return kDKMetadataOriginalSchema;
}


- (void)		setMetadataItem:(DKMetadataItem*) item forKey:(NSString*) key
{
	NSAssert( item != nil, @"cannot set a nil metadata item");
	NSAssert( key != nil, @"cannot use a nil metadata key");

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
		
		[self notifyVisualChange];
		[self metadataDidChangeKey:key];
	}
}


- (DKMetadataItem*)	metadataItemForKey:(NSString*) key
{
	return [self metadataItemForKey:key limitToLocalSearch:NO];
}


- (DKMetadataItem*)	metadataItemForKey:(NSString*) key limitToLocalSearch:(BOOL) local
{
	DKMetadataItem* item = [[self metadata] objectForKey:[key lowercaseString]];
	
	if( item == nil && !local && ([self container] != (id)self))
		item = [[self container] metadataItemForKey:key];
	
	return item;
}


- (NSArray*)	metadataItemsForKeysInArray:(NSArray*) keyArray
{
	// returns an array of metadata items for the keys listed in <keyArray>. The returned order matches that of the keyArray, and is a local search only.

	return [self metadataItemsForKeysInArray:keyArray limitToLocalSearch:YES];
}


- (NSArray*)	metadataItemsForKeysInArray:(NSArray*) keyArray limitToLocalSearch:(BOOL) local
{
	// returns an array of metadata items for the keys listed in <keyArray>. The returned order matches that of the keyArray.
	
	NSMutableArray*	result = [NSMutableArray arrayWithCapacity:[keyArray count]];
	NSEnumerator*	iter = [keyArray objectEnumerator];
	NSString*		key;
	DKMetadataItem*	item;
	
	while(( key = [iter nextObject]))
	{
		item = [self metadataItemForKey:key limitToLocalSearch:local];
		
		if( item )
			[result addObject:item];
	}
	return result;
}


- (void)		setMetadataItemValue:(id) value forKey:(NSString*) key
{
	// if an item exists for <key> its value is set to <value>. This records the old value for Undo if enabled. It does nothing if the
	// item doesn't exist already.
	
	if( ![self locked])
	{
		DKMetadataItem* item = [self metadataItemForKey:key];
		
		if( item )
		{
			if([[self class] metadataChangesAreUndoable])
				[[[self undoManager] prepareWithInvocationTarget:self] setMetadataItemValue:[item value] forKey:key];
			
			[self metadataWillChangeKey:key];
			[item setValue:value];
			[self notifyVisualChange];
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
			[self notifyVisualChange];
			[self metadataDidChangeKey:key];
		}
	}
}



#pragma mark -

- (void)		setMetadataObject:(id) obj forKey:(NSString*) key
{
	NSAssert( obj != nil, @"cannot set a nil metadata object");
	NSAssert( key != nil, @"cannot use a nil metadata key");
	
	if( ![self locked])
	{
#if USE_107_OR_LATER_SCHEMA
		NSLog(@"-setMetadataObject:forkey: is deprecated - migrate code to use -setMetadataItem:forKey: instead");
#endif		
		
		[self setupMetadata];

		// if the key already exists, enforce the data type of the value. This allows this method to
		// be connected to a table view for editing without changing any edited value into a string.
		
		id oldValue = [[self metadata] objectForKey:[key lowercaseString]];
		
		// optionally make the change undoable
		
		if([[self class] metadataChangesAreUndoable])
		{
			if( oldValue )
				[[[self undoManager] prepareWithInvocationTarget:self] setMetadataObject:oldValue forKey:key];
			else
				[[[self undoManager] prepareWithInvocationTarget:self] removeMetadataForKey:key];
		}

		if( oldValue )
		{
			if([oldValue class] != [obj class])
			{
				// the classes differ, so check if a data type conversion is required. Specifically, if <obj> is a string and
				// <oldValue> is a number, we need to find out what sort of number and extract it from the string
				
				if([obj isKindOfClass:[NSString class]] && [oldValue isKindOfClass:[NSNumber class]])
				{
					const char* dataType = [oldValue objCType];
					NSNumber*	newValue;
					
					if( strcmp( dataType, @encode(CGFloat)) == 0 )
						newValue = [NSNumber numberWithDouble:[obj doubleValue]];
					else if( strcmp( dataType, @encode(double)) == 0 )
						newValue = [NSNumber numberWithDouble:[obj doubleValue]];
					else if( strcmp( dataType, @encode(NSInteger)) == 0 )
						newValue = [NSNumber numberWithInteger:[obj integerValue]];
					else if( strcmp( dataType, @encode(BOOL)) == 0 )
						newValue = [NSNumber numberWithBool:[obj integerValue]];
					else
						newValue = obj;
					
					obj = newValue;
				}
			}
		}
		
		[self metadataWillChangeKey:key];
		[[self metadata] setObject:obj forKey:[key lowercaseString]];
		[self notifyVisualChange];
		[self metadataDidChangeKey:key];
	}
}


- (id)			metadataObjectForKey:(NSString*) key
{
	// retrieve the metadata object for the given key. As an extra bonus, if the
	// key is a string, and it starts with a dollar sign, the rest of the string is used
	// as a keypath, and will return the property at that keypath. This allows stuff that
	// reads metadata to introspect objects in the framework - for example $style.name returns the style name, etc.
	
	// to allow metadata retrieval to work smarter with nested objects, if the keyed object isn't found here and
	// the container also implements this, the container is searched and so on until a non-confoming container is hit,
	// at which point the search gives up and returns nil.
	
	@try
	{
		if([key length] > 1 && [[key substringWithRange:NSMakeRange( 0, 1 )] isEqualToString:@"$"])
		{
			NSString* keyPath = [key substringFromIndex:1];
			return [self valueForKeyPath:keyPath];
		}
	}
	@catch(...)
	{
		// exceptions usually mean valueForUndefinedKey: was invoked, which we can ignore.
		
		return @"";
	}
	
	
#if USE_107_OR_LATER_SCHEMA
	
	// if using items, just return the item's data. This also searches the hierarchy but does not recognise keypaths
	
	return [[self metadataItemForKey:key] value];
	
#else
	
	id object = [[self metadata] objectForKey:[key lowercaseString]];
	
	// search upwards through the containment hierarchy for the data. If it is anywhere between here and the root drawing, it will be found.
	// normally the container can't legally be self, but this prevents a infinite recursion bug if it is wrongly set.
	
	if( object == nil && [self container] != self )
		object = [(id)[self container] metadataObjectForKey:key];
	
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
	[self setUserInfoObject:md forKey:kDKMetaDataUserInfo107OrLaterKey];
#else
	[self setUserInfoObject:md forKey:kDKMetaDataUserInfoKey];
#endif
	[md release];
	[self metadataDidChangeKey:nil];
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


- (NSInteger)	intValueForKey:(NSString*) key
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
	// save as 2 keyed floats to allow keyed archiving of the metadata
	
#if USE_107_OR_LATER_SCHEMA
	[self setMetadataItem:[DKMetadataItem metadataItemWithSize:size] forKey:key];
#else
	if([[self class] metadataChangesAreUndoable] && [[self undoManager] respondsToSelector:@selector(enableUndoTaskCoalescing:)])
		[(DKUndoManager*)[self undoManager] enableUndoTaskCoalescing:NO];
	
	[self setMetadataObject:[NSNumber numberWithDouble:size.width] forKey:[NSString stringWithFormat:@"%@.size_width", key]];
	[self setMetadataObject:[NSNumber numberWithDouble:size.height] forKey:[NSString stringWithFormat:@"%@.size_height", key]];

	if([[self class] metadataChangesAreUndoable] && [[self undoManager] respondsToSelector:@selector(enableUndoTaskCoalescing:)])
		[(DKUndoManager*)[self undoManager] enableUndoTaskCoalescing:YES];
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


#pragma mark -

- (void)		updateMetadataKeys
{
	// this (misnamed) method is reposible for migrating the metadata to the latest schema. It is called afer dearchiving the object's
	// metadata.
	
	// which schema is the object using? It will be one of three possible
	
	DKMetadataSchema		schema = [self schema];
	NSMutableDictionary*	metaDict = nil;
	
	if( schema == kDKMetadata107Schema )
		return;		// latest - nothing to do
	
	if( schema == kDKMetadataOriginalSchema )
	{
		// the original schema stored objects directly using case-sensitive keys. Migrate these to either the Mk2 or the 107 schema.
		
		metaDict = [NSMutableDictionary dictionaryWithDictionary:[self userInfo]];
		[[self userInfo] removeAllObjects];
		
#if USE_107_OR_LATER_SCHEMA
		// directly convert original schema to 107 without going to Mk2 first
		
		metaDict = [[DKMetadataItem dictionaryOfMetadataItemsWithDictionary:metaDict] mutableCopy];
		[self setUserInfoObject:metaDict forKey:kDKMetaDataUserInfo107OrLaterKey];
		[metaDict release];
#else
		[self setUserInfoObject:metaDict forKey:kDKMetaDataUserInfoKey];
		// having moved the data to the subdictionary, ensure all the keys are lowercase. This is not required
		// for metadata subdictionaries, since they post-date the change to all lowercase keys.
		
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
		return;
	}
	
#if USE_107_OR_LATER_SCHEMA
	if( schema == kDKMetadataMark2Schema )
	{
		// migrate Mk2 schema to 107 schema
		
		metaDict = [self userInfoObjectForKey:kDKMetaDataUserInfoKey];
		metaDict = [[DKMetadataItem dictionaryOfMetadataItemsWithDictionary:metaDict] mutableCopy];
		[[self userInfo] removeObjectForKey:kDKMetaDataUserInfoKey];
		[self setUserInfoObject:metaDict forKey:kDKMetaDataUserInfo107OrLaterKey];
		[metaDict release];
	}
#endif
}


- (NSUInteger)	metadataChecksum
{
	// returns a number that is derived from the content of the metadata. If it changes, it means the metadata changed in some way. Don't interpret or store
	// this number, only compare it to an earlier value.
	
	NSUInteger cs = 1873176417;	// arbitrary
	
	NSMutableArray* array = [[[self metadata] allKeys] mutableCopy];
	[array sortUsingSelector:@selector(compare:)];
	
	NSEnumerator* iter = [array objectEnumerator];
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
	
	if([self container])
		cs ^= [(id)[self container] metadataChecksum];

	return cs;
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


@end


#pragma mark -
#pragma mark Contants (Non-localized)

NSString*	kDKPrivateShapeOriginalText			= @"Original Text";


@implementation DKDrawableObject (DrawkitPrivateMetadata)

- (void)				setOriginalText:(NSAttributedString*) text
{
#if USE_107_OR_LATER_SCHEMA
	[self setMetadataItem:[DKMetadataItem metadataItemWithAttributedString:text] forKey:kDKPrivateShapeOriginalText];
#else
	[self setMetadataObject:text forKey:kDKPrivateShapeOriginalText];
#endif
}


- (NSAttributedString*)	originalText
{
#if USE_107_OR_LATER_SCHEMA
	return [[self metadataItemForKey:kDKPrivateShapeOriginalText] attributedStringValue];
#else
	return [self metadataObjectForKey:kDKPrivateShapeOriginalText];
#endif
}


@end

