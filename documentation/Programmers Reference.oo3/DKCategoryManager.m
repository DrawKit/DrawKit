///**********************************************************************************************************************************
///  DKCategoryManager.m
///  DrawKit
///
///  Created by graham on 21/03/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKCategoryManager.h"

#import "LogEvent.h"
#import "NSMutableArray+DKAdditions.h"

#pragma mark Contants (Non-localized)
NSString*	kGCDefaultCategoryName = @"All Items";
NSString*	kGCRecentlyAddedUserString = @"Recently Added";
NSString*	kGCRecentlyUsedUserString = @"Recently Used";

NSString*	kGCCategoryManagerWillAddObject = @"kGCCategoryManagerWillAddObject";
NSString*	kGCCategoryManagerDidAddObject = @"kGCCategoryManagerDidAddObject";
NSString*	kGCCategoryManagerWillRemoveObject = @"kGCCategoryManagerWillRemoveObject";
NSString*	kGCCategoryManagerDidRemoveObject = @"kGCCategoryManagerDidRemoveObject";
NSString*	kGCCategoryManagerDidRenameCategory = @"kGCCategoryManagerDidRenameCategory";
NSString*	kGCCategoryManagerWillAddKeyToCategory = @"kGCCategoryManagerWillAddKeyToCategory";
NSString*	kGCCategoryManagerDidAddKeyToCategory = @"kGCCategoryManagerDidAddKeyToCategory";
NSString*	kGCCategoryManagerWillRemoveKeyFromCategory = @"kGCCategoryManagerWillRemoveKeyFromCategory";
NSString*	kGCCategoryManagerDidRemoveKeyFromCategory = @"kGCCategoryManagerDidRemoveKeyFromCategory";


#pragma mark -
@implementation DKCategoryManager
#pragma mark As a DKCategoryManager

///*********************************************************************************************************************
///
/// method:			categoryManager
/// scope:			public classmethod
/// overrides:
/// description:	returns a new category manager object
/// 
/// parameters:		none
/// result:			a category manager object
///
/// notes:			convenience method. Initial categories only consist of "All Items"
///
///********************************************************************************************************************


+ (DKCategoryManager*)	categoryManager
{
	return [[[DKCategoryManager alloc] init] autorelease];
}


///*********************************************************************************************************************
///
/// method:			categoryManagerWithDictionary
/// scope:			public class method
/// overrides:
/// description:	returns a new category manager object based on an existing dictionary
/// 
/// parameters:		<dict> an existign dictionary
/// result:			a category manager object
///
/// notes:			convenience method. Initial categories only consist of "All Items"
///
///********************************************************************************************************************


+ (DKCategoryManager*)	categoryManagerWithDictionary:(NSDictionary*) dict
{
	return [[[DKCategoryManager alloc] initWithDictionary:dict] autorelease];
}


#pragma mark -
#pragma mark - initialization
///*********************************************************************************************************************
///
/// method:			initWithData:
/// scope:			public method
/// overrides:
/// description:	initialized a category manager object from archive data
/// 
/// parameters:		<data> data containing a correctly archived category manager
/// result:			the category manager object
///
/// notes:			data is permitted also to be an archived dictionary
///
///********************************************************************************************************************

- (id)					initWithData:(NSData*) data
{
	NSAssert(data != nil, @"Expected valid data");
	id obj = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	NSAssert(obj != nil, @"Expected valid obj");
	if([obj isKindOfClass:[self class]])
	{
		[self autorelease];
		self = [obj retain];
		[self fixUpCategories];
		
	}
	else if ([obj isKindOfClass:[NSDictionary class]])
	{
		self = [self initWithDictionary:obj];
	}
	else
	{
		self = [self init];
	}
	return self;
}


///*********************************************************************************************************************
///
/// method:			initWithDictionary:
/// scope:			public method
/// overrides:
/// description:	initialized a category manager object from an existing dictionary
/// 
/// parameters:		<dict> dictionary containing a set of objects and keys
/// result:			the category manager object
///
/// notes:			no categories other than "All Items" are created by default. The recently added list is empty.
///
///********************************************************************************************************************

- (id)					initWithDictionary:(NSDictionary*) dict
{
	NSAssert(dict != nil, @"Expected valid dict");
	self = [self init];
	if (self != nil)
	{
		// dictionary keys need to be all lowercase to allow "case insensitivity" in the master list
		
		NSEnumerator*		iter = [[dict allKeys] objectEnumerator];
		NSString*			s;
		
		while(( s = [iter nextObject]))
		{
			id	obj = [dict objectForKey:s];
			[m_masterList setObject:obj forKey:[s lowercaseString]];
		}
		
		// add to "All Items":
		
		NSMutableArray* aicat = [m_categories objectForKey:kGCDefaultCategoryName];
		
		if ( aicat )
		{
			[aicat addObjectsFromArray:[dict allKeys]];
		}
	}
	
	return self;
}


#pragma mark -
#pragma mark - adding and retrieving objects
///*********************************************************************************************************************
///
/// method:			addObject:forKey:toCategory:createCategory:
/// scope:			public method
/// overrides:
/// description:	add an object to the container, associating with a key and optionally a category.
/// 
/// parameters:		<obj> the object to add
///					<name> the object's key
///					<catName> the name of the category to add it to, or nil for defaults only
///					<cg> YES to create the category if it doesn't exist. NO not to do so
/// result:			none
///
/// notes:			<obj> and <name> cannot be nil. All objects are added to the default category regardless of <catName>
///
///********************************************************************************************************************

- (void)				addObject:(id) obj forKey:(NSString*) name toCategory:(NSString*) catName createCategory:(BOOL) cg
{
//	LogEvent_(kStateEvent, @"category manager adding object:%@ name:%@ to category:%@", obj, name, catName );

	NSAssert( obj != nil, @"object cannot be nil" );
	NSAssert( name != nil, @"name cannot be nil" );
	NSAssert([name length] > 0, @"name cannot be empty");
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerWillAddObject object:self];

	// add the object to the master list
	
	[m_masterList setObject:obj forKey:[name lowercaseString]];
	[self addKey:name toRecentList:kGCListRecentlyAdded];
	
	// add to single category specified if any
	
	if ( catName != nil )
		[self addKey:name toCategory:catName createCategory:cg];
	
	[self addKey:name toCategory:kGCDefaultCategoryName createCategory:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerDidAddObject object:self];
}


///*********************************************************************************************************************
///
/// method:			addObject:forKey:toCategory:createCategory:
/// scope:			public method
/// overrides:
/// description:	add an object to the container, associating with a key and optionally a number of categories.
/// 
/// parameters:		<obj> the object to add
///					<name> the object's key
///					<catNames> the names of the categories to add it to, or nil for defaults
///					<cg> YES to create the categories if they don't exist. NO not to do so
/// result:			none
///
/// notes:			<obj> and <name> cannot be nil. All objects are added to the default category regardless of <catNames>
///
///********************************************************************************************************************

- (void)				addObject:(id) obj forKey:(NSString*) name toCategories:(NSArray*) catNames createCategories:(BOOL) cg
{
//	LogEvent_(kStateEvent, @"category manager adding object:%@ name:%@ to categories:%@", obj, name, catNames );

	NSAssert( obj != nil, @"object cannot be nil" );
	NSAssert( name != nil, @"name cannot be nil" );
	NSAssert([name length] > 0, @"name cannot be empty");
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerWillAddObject object:self];
	
	// add the object to the master list
	
	[m_masterList setObject:obj forKey:[name lowercaseString]];
	[self addKey:name toRecentList:kGCListRecentlyAdded];
	
	// add to multiple categories specified
	
	if ( catNames != nil && [catNames count] > 0 )
		[self addKey:name toCategories:catNames createCategories:cg];
	
	[self addKey:name toCategory:kGCDefaultCategoryName createCategory:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerDidAddObject object:self];
}


///*********************************************************************************************************************
///
/// method:			removeObjectForKey:
/// scope:			public method
/// overrides:
/// description:	remove an object from the container
/// 
/// parameters:		<key> the object's key
/// result:			none
///
/// notes:			after this the key will not be found in any category or either list
///
///********************************************************************************************************************

- (void)				removeObjectForKey:(NSString*) key
{
	// remove this key from any/all categories and lists
	
	NSAssert( key != nil, @"attempt to remove nil key");
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerWillRemoveObject object:self];

	[self removeKeyFromAllCategories:key];
	[self removeKey:key fromRecentList:kGCListRecentlyAdded];
	[self removeKey:key fromRecentList:kGCListRecentlyUsed];

	// remove from master dictionary
	
	[m_masterList removeObjectForKey:[key lowercaseString]];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerDidRemoveObject object:self];
}


///*********************************************************************************************************************
///
/// method:			removeObjectsForKeys:
/// scope:			public method
/// overrides:
/// description:	remove multiple objects from the container
/// 
/// parameters:		<keys> a list of keys
/// result:			none
///
/// notes:			after this no keys will not be found in any category or either list
///
///********************************************************************************************************************

- (void)				removeObjectsForKeys:(NSArray*) keys
{
	NSEnumerator*	iter = [keys objectEnumerator];
	NSString*		key;
	
	while(( key = [iter nextObject]))
		[self removeObjectForKey:key];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			containsKey:
/// scope:			public method
/// overrides:
/// description:	test whether the key is known to the container
/// 
/// parameters:		<key> the object's key
/// result:			YES if known, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				containsKey:(NSString*) key
{
	return [[m_masterList allKeys] containsObject:[key lowercaseString]];
}


///*********************************************************************************************************************
///
/// method:			count
/// scope:			public method
/// overrides:
/// description:	return total number of stored objects in container
/// 
/// parameters:		none
/// result:			the number of objects
///
/// notes:			
///
///********************************************************************************************************************

- (unsigned)			count
{
	return [m_masterList count];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			objectForKey:
/// scope:			public method
/// overrides:
/// description:	return the object for the given key, but do not remember it in the "recently used" list
/// 
/// parameters:		<key> the object's key
/// result:			the object if available, else nil
///
/// notes:			
///
///********************************************************************************************************************

- (id)					objectForKey:(NSString*) key
{
	return [m_masterList objectForKey:[key lowercaseString]];
}


///*********************************************************************************************************************
///
/// method:			objectForKey:addToRecentlyUsedItems:
/// scope:			public method
/// overrides:
/// description:	return the object for the given key, optionally remembering it in the "recently used" list
/// 
/// parameters:		<key> the object's key
///					<add> if YES, object's key is added to recently used items
/// result:			the object if available, else nil
///
/// notes:			use this method when you wish this access of the object to result in it being added to "recently used"
///
///********************************************************************************************************************

- (id)					objectForKey:(NSString*) key addToRecentlyUsedItems:(BOOL) add
{
	// returns the object, but optionally adds it to the "recently used" list
	
	id obj = [self objectForKey:key];
	
	if ( add )
		[self addKey:key toRecentList:kGCListRecentlyUsed];
	
	return obj;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			keysForObject:
/// scope:			public method
/// overrides:
/// description:	returns a list of all unique keys that refer to the given object
/// 
/// parameters:		<obj> the object
/// result:			an array, listing all the unique keys that refer to the object.
///
/// notes:			The result may contain no keys if the object is unknown
///
///********************************************************************************************************************

- (NSArray*)			keysForObject:(id) obj
{
	//return [[self dictionary] allKeysForObject:obj];  // doesn't work because master dict uses lowercase keys
	
	NSMutableArray*		keys = [[NSMutableArray alloc] init];
	NSEnumerator*		iter = [[self allKeys] objectEnumerator];
	NSString*			key;
	
	while(( key = [iter nextObject]))
	{
		if ([[self objectForKey:key] isEqual:obj])
			[keys addObject:key];
	}
	
	return [keys autorelease];
}


///*********************************************************************************************************************
///
/// method:			dictionary
/// scope:			public method
/// overrides:
/// description:	return a copy of the master dictionary
/// 
/// parameters:		none
/// result:			the main dictionary
///
/// notes:			
///
///********************************************************************************************************************

- (NSDictionary*)		dictionary
{
	return [[m_masterList copy] autorelease];
}


#pragma mark -
#pragma mark - retrieving lists of objects by category
///*********************************************************************************************************************
///
/// method:			objectsInCategory:
/// scope:			public method
/// overrides:
/// description:	return all of the objects belonging to a given category
/// 
/// parameters:		<catName> the category name
/// result:			an array, the list of objects indicated by the category. May be empty.
///
/// notes:			returned objects are in no particular order, but do match the key order obtained by
///					-allkeysInCategory. Should any key not exist (which should never normally occur), the entry will
///					be represented by a NSNull object
///
///********************************************************************************************************************

- (NSArray*)			objectsInCategory:(NSString*) catName
{
	NSMutableArray*		keys = [[[NSMutableArray alloc] init] autorelease];
	NSEnumerator*		iter = [[self allKeysInCategory:catName] objectEnumerator];
	NSString*			s;
	
	while(( s = [iter nextObject]))
		[keys addObject:[s lowercaseString]];
	
	return [m_masterList objectsForKeys:keys notFoundMarker:[NSNull null]];
}


///*********************************************************************************************************************
///
/// method:			objectsInCategories:
/// scope:			public method
/// overrides:
/// description:	return all of the objects belonging to the given categories
/// 
/// parameters:		<catNames> list of categories
/// result:			an array, the list of objects indicated by the categories. May be empty.
///
/// notes:			returned objects are in no particular order, but do match the key order obtained by
///					-allKeysInCategories:. Should any key not exist (which should never normally occur), the entry will
///					be represented by a NSNull object
///
///********************************************************************************************************************

- (NSArray*)			objectsInCategories:(NSArray*) catNames
{
	NSMutableArray*		keys = [[[NSMutableArray alloc] init] autorelease];
	NSEnumerator*		iter = [[self allKeysInCategories:catNames] objectEnumerator];
	NSString*			s;
	
	while(( s = [iter nextObject]))
		[keys addObject:[s lowercaseString]];
	
	return [m_masterList objectsForKeys:keys notFoundMarker:[NSNull null]];
}


///*********************************************************************************************************************
///
/// method:			allKeysInCategory:
/// scope:			public method
/// overrides:
/// description:	return all of the keys in a given category
/// 
/// parameters:		<catName> the category name
/// result:			an array, the list of keys indicated by the category. May be empty.
///
/// notes:			returned objects are in no particular order.
///
///********************************************************************************************************************

- (NSArray*)			allKeysInCategory:(NSString*) catName
{
	return [m_categories objectForKey:catName];
}


///*********************************************************************************************************************
///
/// method:			allKeysInCategories:
/// scope:			public method
/// overrides:
/// description:	return all of the keys in all given categories
/// 
/// parameters:		<catNames> an array of category names
/// result:			an array, the union of keys in listed categories. May be empty.
///
/// notes:			returned objects are in no particular order.
///
///********************************************************************************************************************

- (NSArray*)			allKeysInCategories:(NSArray*) catNames
{
	if ([catNames count] == 1 )
		return [self allKeysInCategory:[catNames lastObject]];
	else
	{
		NSMutableArray*	temp = [[NSMutableArray alloc] init];
		NSEnumerator*	iter = [catNames objectEnumerator];
		NSString*		catname;
		NSArray*		keys;
		
		while(( catname = [iter nextObject]))
		{
			keys = [self allKeysInCategory:catname];
		
			// add keys not already in <temp> to temp
			
			[temp addUniqueObjectsFromArray:keys];
		}
		
		return [temp autorelease];
	}
}


///*********************************************************************************************************************
///
/// method:			allKeys
/// scope:			public method
/// overrides:
/// description:	return all of the keys
/// 
/// parameters:		none
/// result:			an array, all keys (listed only once)
///
/// notes:			returned objects are in no particular order. The keys are obtained by enumerating the categories
///					because the master list contains case-modified keys that may not be matched with categories.
///
///********************************************************************************************************************

- (NSArray*)			allKeys
{
	//return [[self dictionary] allKeys];		// doesn't work because keys are lowercase
	
	return [self allKeysInCategories:[self allCategories]];	
}


///*********************************************************************************************************************
///
/// method:			allObjects
/// scope:			public method
/// overrides:
/// description:	return all of the objects
/// 
/// parameters:		none
/// result:			an array, all objects (listed only once, in arbitrary order)
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)			allObjects
{
	return [m_masterList allValues];

}


///*********************************************************************************************************************
///
/// method:			allSortedKeysInCategory:
/// scope:			public method
/// overrides:
/// description:	return all of the keys in a given category, sorted into some useful order
/// 
/// parameters:		<catName> the category name
/// result:			an array, the list of keys indicated by the category. May be empty.
///
/// notes:			by default the keys are sorted alphabetically. The UI-building methods call this, so a subclass
///					camn override it and return keys sorted by som eother criteria if required.
///
///********************************************************************************************************************

- (NSArray*)			allSortedKeysInCategory:(NSString*) catName
{
	return [[self allKeysInCategory:catName] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];	
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			recentlyAddedItems
/// scope:			public method
/// overrides:
/// description:	return the list of recently added items
/// 
/// parameters:		none
/// result:			an array, the list of keys recently added.
///
/// notes:			returned objects are in order of addition, most recent first.
///
///********************************************************************************************************************

- (NSArray*)			recentlyAddedItems
{
	return m_recentlyAdded;
}


///*********************************************************************************************************************
///
/// method:			recentlyUsedItems
/// scope:			public method
/// overrides:
/// description:	return the list of recently used items
/// 
/// parameters:		none
/// result:			an array, the list of keys recently used.
///
/// notes:			returned objects are in order of use, most recent first.
///
///********************************************************************************************************************

- (NSArray*)			recentlyUsedItems
{
	return m_recentlyUsed;
}


#pragma mark -
#pragma mark - category management - creating, deleting and renaming categories
///*********************************************************************************************************************
///
/// method:			addCategory:
/// scope:			protected method
/// overrides:
/// description:	create a new category with the given name
/// 
/// parameters:		<catName> the name of the new category
/// result:			none
///
/// notes:			if the name is already a category name, this does nothing
///
///********************************************************************************************************************

- (void)				addCategory:(NSString*) catName
{
	if ([m_categories objectForKey:catName] == nil )
	{
	//	LogEvent_(kStateEvent,  @"adding new category '%@'", catName );

		NSMutableArray* cat = [[NSMutableArray alloc] init];
		
		[m_categories setObject:cat forKey:catName];
		[cat release];
	}
}


///*********************************************************************************************************************
///
/// method:			addCategories:
/// scope:			protected method
/// overrides:
/// description:	create a new categories with the given names
/// 
/// parameters:		<catNames> a list of the names of the new categories
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				addCategories:(NSArray*) catNames
{
	NSEnumerator*   iter = [catNames objectEnumerator];
	NSString*		catName;
	
	while(( catName = [iter nextObject]))
		[self addCategory:catName];
}


///*********************************************************************************************************************
///
/// method:			removeCategory:
/// scope:			public method
/// overrides:
/// description:	remove a category with the given name
/// 
/// parameters:		<catName> the category to remove
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeCategory:(NSString*) catName
{
//	LogEvent_(kStateEvent, @"removing category '%@'", catName );
	[m_categories removeObjectForKey:catName];
}


///*********************************************************************************************************************
///
/// method:			renameCategory:to:
/// scope:			public method
/// overrides:
/// description:	change a category's name
/// 
/// parameters:		<catName> the category's old name
///					<newname> the category's new name
/// result:			none
///
/// notes:			if <newname> already exists, it will be replaced by the entries in <catname>
///
///********************************************************************************************************************

- (void)				renameCategory:(NSString*) catName to:(NSString*) newname
{
//	LogEvent_(kStateEvent, @"renaming the category '%@' to' %@'", catName, newname );
	
	NSMutableArray* gs = [m_categories objectForKey:catName];
	
	if ( gs )
	{
		[gs retain];
		[m_categories removeObjectForKey:catName];
	
		[m_categories setObject:gs forKey:newname];
		[gs release];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerDidRenameCategory object:self];
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			addKey:toCategory:createCategory:
/// scope:			protected method
/// overrides:
/// description:	adds a new key to a category, optionally creating it if necessary
/// 
/// parameters:		<key> the key to add
///					<catName> the category to add it to
///					<cg> YES to create the category if it doesn't exist, NO otherwise
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				addKey:(NSString*) key toCategory:(NSString*) catName createCategory:(BOOL) cg
{
	// add a key to an existing group, or to a new group if it doesn't yet exist and the flag is set
	
//	LogEvent_(kStateEvent,  @"category manager adding key '%@' to category '%@'", key, catName );
	NSAssert( key != nil, @"key can't be nil");
	
	if ( catName == nil )
		return;
		
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerWillAddKeyToCategory object:self];
		
	NSMutableArray* ga = [m_categories objectForKey:catName];
	
	if ( ga == nil && cg )
	{
		// doesn't exist - create it
		
		[self addCategory:catName];
		ga = [m_categories objectForKey:catName];
	}
	
	// add the key to this group's list if not already known, and sort the list
	
	if (! [ga containsObject:key])
	{
		[ga addObject:key];
		[ga sortUsingSelector:@selector(caseInsensitiveCompare:)];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerDidAddKeyToCategory object:self];
}


///*********************************************************************************************************************
///
/// method:			addKey:toCategories:createCategories:
/// scope:			protected method
/// overrides:
/// description:	adds a new key to several categories, optionally creating any if necessary
/// 
/// parameters:		<key> the key to add
///					<catNames> a list of categories to add it to
///					<cg> YES to create the category if it doesn't exist, NO otherwise
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				addKey:(NSString*) key toCategories:(NSArray*) catNames createCategories:(BOOL) cg
{
	if ( catNames == nil )
		return;
	
	NSEnumerator*	iter = [catNames objectEnumerator];
	NSString*		cat;
	
	while(( cat = [iter nextObject]))
		[self addKey:key toCategory:cat createCategory:cg];
}


///*********************************************************************************************************************
///
/// method:			removeKey:fromCategory:
/// scope:			protected method
/// overrides:
/// description:	removes a key from a category
/// 
/// parameters:		<key> the key to remove
///					<catName> the category to remove it from
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeKey:(NSString*) key fromCategory:(NSString*) catName
{
//	LogEvent_(kStateEvent, @"removing key '%@' from category '%@'", key, catName );
	
	NSMutableArray*		ga = [m_categories objectForKey:catName];
	
	if ( ga )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerWillRemoveKeyFromCategory object:self];
		[ga removeObject:key];
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCCategoryManagerDidRemoveKeyFromCategory object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			removeKey:fromCategories:
/// scope:			protected method
/// overrides:
/// description:	removes a key from a number of categories
/// 
/// parameters:		<key> the key to remove
///					<catNames> the list of categories to remove it from
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeKey:(NSString*) key fromCategories:(NSArray*) catNames
{
	if ( catNames == nil )
		return;
	
	NSEnumerator*	iter = [catNames objectEnumerator];
	NSString*		cat;
	
	while(( cat = [iter nextObject]))
		[self removeKey:key fromCategory:cat];
}


///*********************************************************************************************************************
///
/// method:			removeKeyFromAllCategories:
/// scope:			protected method
/// overrides:
/// description:	removes a key from all categories
/// 
/// parameters:		<key> the key to remove
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeKeyFromAllCategories:(NSString*) key
{
	[self removeKey:key fromCategories:[self allCategories]];
}


///*********************************************************************************************************************
///
/// method:			fixUpCategories
/// scope:			protected method
/// overrides:
/// description:	checks that all keys refer to real objects, removing any that do not
/// 
/// parameters:		none
/// result:			none
///
/// notes:			rarely needed, but can correct for corrupted registries where objects got removed but not all
///					keys that refer to it did for some reason (such as an exception).
///
///********************************************************************************************************************

- (void)				fixUpCategories
{
	NSEnumerator*	iter = [[self allKeys] objectEnumerator];
	NSString*		key;
	
	while(( key = [iter nextObject]))
	{
		if ([self objectForKey:key] == nil)
			[self removeKeyFromAllCategories:key];
	}
}


///*********************************************************************************************************************
///
/// method:			renameKey:to:
/// scope:			public method
/// overrides:
/// description:	renames an object's key throughout
/// 
/// parameters:		<key> the existing key
///					<newKey> the new key
/// result:			none
///
/// notes:			if <key> doesn't exist, or if <newkey> already exists, throws an exception. After this the same
///					object that could be located using <key> can be located using <newKey> in the same categories as
///					it appeared in originally.
///
///********************************************************************************************************************

- (void)				renameKey:(NSString*) key to:(NSString*) newKey
{
	NSAssert( key != nil, @"expected non-nil key");
	NSAssert( newKey != nil, @"expected non-nil new key");
	
	// if the keys are the same, do nothing
	
	if ([key isEqualToString:newKey])
		return;
	
	// first check that <key> exists:
	
	if ( ![self containsKey:key])
		[NSException raise:NSInvalidArgumentException format:@"The key '%@' can't be renamed because it doesn't exist", key ];
		
	// check that the new key isn't in use:
	
	if ([self containsKey:newKey])
		[NSException raise:NSInvalidArgumentException format:@"Cannot rename key to '%@' because that key is already in use", newKey ];
	
	LogEvent_(kStateEvent, @"changing key '%@' to '%@'", key, newKey);
			
	// what categories are going to be touched?
	
	NSArray* cats = [self categoriesContainingKey:key];
	
	// retain the object while we move it around:
	
	id object = [[self objectForKey:key] retain];
	[self removeObjectForKey:key];
	[self addObject:object forKey:newKey toCategories:cats createCategories:NO];
	[object release];
}


#pragma mark -
#pragma mark - getting lists, etc. of the categories
///*********************************************************************************************************************
///
/// method:			allCategories
/// scope:			public method
/// overrides:
/// description:	get a list of all categories
/// 
/// parameters:		none
/// result:			an array containg a list of all category names
///
/// notes:			the list is alphabetically sorted for the convenience of a user interface
///
///********************************************************************************************************************

- (NSArray*)			allCategories
{
	return [[m_categories allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}


///*********************************************************************************************************************
///
/// method:			categoriesContainingKey:
/// scope:			public method
/// overrides:
/// description:	get a list of all categories that contain a given key
/// 
/// parameters:		<key> the key in question
/// result:			an array containing a list of categories which contain the key
///
/// notes:			the list is alphabetically sorted for the convenience of a user interface
///
///********************************************************************************************************************

- (NSArray*)			categoriesContainingKey:(NSString*) key
{
	NSEnumerator*	iter = [[m_categories allKeys] objectEnumerator];
	NSString*		catName;
	NSArray*		cat;
	NSMutableArray*	catList;
	
	catList = [[NSMutableArray alloc] init];
	
	while(( catName = [iter nextObject]))
	{
		cat = [self allKeysInCategory:catName];
		
		if ([cat containsObject:key])
			[catList addObject:catName];
	}
	
	[catList sortUsingSelector:@selector(caseInsensitiveCompare:)];
	return [catList autorelease];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			categoryExists:
/// scope:			public method
/// overrides:
/// description:	test whether there is a category of the given name
/// 
/// parameters:		<catName> the category name
/// result:			YES if a category exists with the name, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				categoryExists:(NSString*) catName
{
	return [m_categories objectForKey:catName] != nil;
}


///*********************************************************************************************************************
///
/// method:			countOfObjectsInCategory:
/// scope:			public method
/// overrides:
/// description:	count how many objects in the category of the given name
/// 
/// parameters:		<catName> the category name
/// result:			the number of objects in the category
///
/// notes:			
///
///********************************************************************************************************************

- (unsigned)			countOfObjectsInCategory:(NSString*) catName
{
	return [[m_categories objectForKey:catName] count];
}


///*********************************************************************************************************************
///
/// method:			key:existsInCategory:
/// scope:			public method
/// overrides:
/// description:	query whether a given key is present in a particular category
/// 
/// parameters:		<key> the key
///					<catName> the category name
/// result:			YES if the category contains <key>, NO if it doesn't
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				key:(NSString*) key existsInCategory:(NSString*) catName
{
	return [[m_categories objectForKey:catName] containsObject:key];
}


#pragma mark -
#pragma mark - managing recent lists
///*********************************************************************************************************************
///
/// method:			addKey:toRecentList:
/// scope:			protected method
/// overrides:
/// description:	add a key to one of the 'recent' lists
/// 
/// parameters:		<key> the key to add
///					<whichList> an identifier for the list in question
/// result:			return YES if the key was added, otherwise NO (i.e. if list already contains item)
///
/// notes:			acceptable list IDs are kGCListRecentlyAdded and kGCListRecentlyUsed
///
///********************************************************************************************************************

- (BOOL)				addKey:(NSString*) key toRecentList:(int) whichList
{
	unsigned		max;
	NSMutableArray* rl;
	
	switch( whichList )
	{
		case kGCListRecentlyAdded:
			rl = m_recentlyAdded;
			max = m_maxRecentlyAddedItems;
			break;
			
		case kGCListRecentlyUsed:
			rl = m_recentlyUsed;
			max = m_maxRecentlyUsedItems;
			break;
			
		default:
			return NO;
	}
	
	if ( ![rl containsObject:key] )
	{
		[rl insertObject:key atIndex:0];
		if ( [rl count] > max )
			[rl removeLastObject];
			
		return YES;
	}
	else
		return NO;
}


///*********************************************************************************************************************
///
/// method:			removeKey:fromRecentList:
/// scope:			protected method
/// overrides:
/// description:	remove a key from one of the 'recent' lists
/// 
/// parameters:		<key> the key to remove
///					<whichList> an identifier for the list in question
/// result:			none
///
/// notes:			acceptable list IDs are kGCListRecentlyAdded and kGCListRecentlyUsed
///
///********************************************************************************************************************

- (void)				removeKey:(NSString*) key fromRecentList:(int) whichList
{
	NSMutableArray* rl;

	switch( whichList )
	{
		case kGCListRecentlyAdded:
			rl = m_recentlyAdded;
			break;
			
		case kGCListRecentlyUsed:
			rl = m_recentlyUsed;
			break;
			
		default:
			return;
	}
	
	[rl removeObject:key];
}


///*********************************************************************************************************************
///
/// method:			setRecentList:maxItems:
/// scope:			protected method
/// overrides:
/// description:	sets the maximum length of on eof the 'recent' lists
/// 
/// parameters:		<whichList> an identifier for the list in question
///					<max> the maximum length to which a list may grow
/// result:			none
///
/// notes:			acceptable list IDs are kGCListRecentlyAdded and kGCListRecentlyUsed
///
///********************************************************************************************************************

- (void)				setRecentList:(int) whichList maxItems:(int) max
{
	switch( whichList )
	{
		case kGCListRecentlyAdded:
			m_maxRecentlyAddedItems = max;
			break;
			
		case kGCListRecentlyUsed:
			m_maxRecentlyUsedItems = max;
			break;
			
		default:
			return;
	}
}


#pragma mark -
#pragma mark - archiving
///*********************************************************************************************************************
///
/// method:			data
/// scope:			public method
/// overrides:
/// description:	archives the container to a data object (for saving, etc)
/// 
/// parameters:		none
/// result:			a data object, the archive of the container
///
/// notes:			
///
///********************************************************************************************************************

- (NSData*)				data
{
	NSMutableData*		d = [NSMutableData dataWithCapacity:100];
	NSKeyedArchiver*	arch = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];

	[arch setOutputFormat:NSPropertyListXMLFormat_v1_0];
	
	[self fixUpCategories];		// avoid archiving a badly formed object
	[arch encodeObject:self forKey:@"root"];
	[arch finishEncoding];
	[arch release];
	
	return d;
}


#pragma mark -
#pragma mark - supporting UI
#pragma mark -- menus of just the categories
///*********************************************************************************************************************
///
/// method:			categoriesMenuWithSelector:target:
/// scope:			public method
/// overrides:
/// description:	creates a menu of categories, recent items and All Items
/// 
/// parameters:		<sel> the selector which is set as the action for each added item
///					<target> the target of category item actions
/// result:			a menu populated with category and other names
///
/// notes:			sel and target may be nil
///
///********************************************************************************************************************

- (NSMenu*)				categoriesMenuWithSelector:(SEL) sel target:(id) target
{
	return [self categoriesMenuWithSelector:sel target:target options:kGCIncludeRecentlyAddedItems | kGCIncludeRecentlyUsedItems | kGCIncludeAllItems];
}


///*********************************************************************************************************************
///
/// method:			categoriesMenuWithOptions:selector:target:
/// scope:			public method
/// overrides:
/// description:	creates a menu of categories, recent items and All Items
/// 
/// parameters:		<sel> the selector which is set as the action for each category item
///					<target> the target of category item actions
///					<options> various flags which set which items are added
/// result:			a menu populated with category and other names
///
/// notes:			sel and target may be nil, options may be 0
///
///********************************************************************************************************************

- (NSMenu*)				categoriesMenuWithSelector:(SEL) sel target:(id) target options:(int) options
{
	// create and populate a menu with the category names plus optionally the recent items lists
	
	NSMenu*			menu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Categories", @"default name for categories menu")];
	NSMenuItem*		ti = nil;
	
	// add standard items according to options
	
	if ( options & kGCIncludeAllItems )
	{
		ti = [menu addItemWithTitle:kGCDefaultCategoryName action:sel keyEquivalent:@""];
		[ti setTarget:target];
	}
	
	if ( options & kGCIncludeRecentlyAddedItems )
	{
		[menu addItemWithTitle:kGCRecentlyAddedUserString action:sel keyEquivalent:@""];
		[ti setTarget:target];
	}

	if ( options & kGCIncludeRecentlyUsedItems )
	{
		[menu addItemWithTitle:kGCRecentlyUsedUserString action:sel keyEquivalent:@""];
		[ti setTarget:target];
	}
	
	if (( options & kGCDontAddDividingLine ) == 0 )
		[menu addItem:[NSMenuItem separatorItem]];
		
	// now just list the categories
	
	NSEnumerator*	iter = [[self allCategories] objectEnumerator];	// already sorted alphabetically
	NSString*		cat;
	
	while(( cat = [iter nextObject]))
	{
		if (! [cat isEqualToString:kGCDefaultCategoryName])
		{
			ti = [menu addItemWithTitle:cat action:sel keyEquivalent:@""];
			[ti setTarget:target];
		}
	}
		
	return [menu autorelease];
}


///*********************************************************************************************************************
///
/// method:			checkItemsInMenu:forCategoriesContainingKey:
/// scope:			public method
/// overrides:
/// description:	sets the checkmarks in a menu of category names to reflect the presence of <key> in those categories
/// 
/// parameters:		<menu> the menu to examine
///					<key> the key to test against
/// result:			none
///
/// notes:			assumes that item names will be the category names. For localized names, you should handle the
///					localization external to this class so that both category names and menu items use the same strings.
///
///********************************************************************************************************************


- (void)				checkItemsInMenu:(NSMenu*) menu forCategoriesContainingKey:(NSString*) key
{
	// puts a checkmark against any category names in the menu that contain <key>. Exception is "All Items" which is never checked.
	
	NSArray*		categories = [self categoriesContainingKey:key];
	
	// check whether there's really anything to do here:
	
	if ([categories count] > 1)
	{
		NSEnumerator*	iter = [[menu itemArray] objectEnumerator];
		NSMenuItem*		item;
		NSString*		ti;
		
		while(( item = [iter nextObject]))
		{
			ti = [item title];
			
			if(![ti isEqualToString:kGCDefaultCategoryName] && [categories containsObject:ti])
				[item setState:NSOnState];
			else
				[item setState:NSOffState];
		}
	}
}


#pragma mark -
#pragma mark -- a menu with everything, organised hierarchically by category
///*********************************************************************************************************************
///
/// method:			createItemMenuWithItemCallback:
/// scope:			public method
/// overrides:
/// description:	creates a complete menu of the entire contents of the receiver, arranged by category
/// 
/// parameters:		<id> an object that is called back with each menu item created (may be nil)
///					<isPopUp> set YES if menu is destined for use as a popup (adds extra zeroth item)
/// result:			a menu object
///
/// notes:			the menu returned lists the categories, each of which is a submenu containing the actual objects
///					corresponding to the category contents. It also populates a recent items and added items submenu.
///					the callback object needs to set up the menu item based on the object itself. The object is added
///					automatically as the menu item's represented object. This is one easy way to create a simple UI
///					to the cat manager, where you can simply pick an item from the menu.
///
///********************************************************************************************************************

- (NSMenu*)				createItemMenuWithItemCallback:(id) callback isPopUpMenu:(BOOL) isPopUp
{
	// the title is fixed but in many cases will never be seen (pop up). Caller can change it if needed.
	
	NSMenu*			menu = [[NSMenu alloc] initWithTitle:@"Category Manager"];
	NSEnumerator*	iter = [[self allCategories] objectEnumerator];
	NSString*		cat;
	NSArray*		catObjects;
	NSMenuItem*		parentItem;
	NSMenuItem*		childItem;
	NSMenu*			parentMenu;
	NSEnumerator*	itemIter;
	NSString*		key;
	
	if ( isPopUp )
	{
		// callback can check object == this to set the title of the popup
		
		parentItem = [menu addItemWithTitle:@"Category Manager" action:0 keyEquivalent:@""];
		[callback menuItem:parentItem wasAddedForObject:self inCategory:nil];
	}
	
	while(( cat = [iter nextObject]))
	{
		catObjects = [self allSortedKeysInCategory:cat];
		
		if ([catObjects count] > 0)
		{
			parentItem = [menu addItemWithTitle:[cat capitalizedString] action:0 keyEquivalent:@""];
		
			// make a submenu to list the actual items
			
			parentMenu = [[NSMenu alloc] initWithTitle:cat];
			[parentItem setSubmenu:parentMenu];
			[parentMenu release];
			
			// iterate over the items in the category
			
			itemIter = [catObjects objectEnumerator];
			
			while(( key = [itemIter nextObject]))
			{
				// create a menu item for the item. Key is used as the menu item's title. If this is a bad assumption,
				// the callback can set it to something more appropriate.
				
				childItem = [parentMenu addItemWithTitle:[key capitalizedString] action:0 keyEquivalent:@""];
				
				// call the callback to make this item into what it needs
				[childItem setRepresentedObject:[self objectForKey:key]];
				[callback menuItem:childItem wasAddedForObject:[self objectForKey:key] inCategory:cat];
			}
		}
	}
	
	// add a dividing line then the recently used and recently added lists
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	iter = [[self recentlyUsedItems] objectEnumerator];
	
	parentItem = [menu addItemWithTitle:NSLocalizedString(kGCRecentlyUsedUserString, @"") action:0 keyEquivalent:@""];
	parentMenu = [[NSMenu alloc] initWithTitle:[parentItem title]];
	[parentItem setSubmenu:parentMenu];
	[parentMenu release];
	
	while(( key = [iter nextObject]))
	{
		childItem = [parentMenu addItemWithTitle:[key capitalizedString] action:0 keyEquivalent:@""];
		[childItem setRepresentedObject:[self objectForKey:key]];
		[callback menuItem:childItem wasAddedForObject:[self objectForKey:key] inCategory:nil];
	}
	
	iter = [[self recentlyAddedItems] objectEnumerator];
	
	parentItem = [menu addItemWithTitle:NSLocalizedString(kGCRecentlyAddedUserString, @"") action:0 keyEquivalent:@""];
	parentMenu = [[NSMenu alloc] initWithTitle:[parentItem title]];
	[parentItem setSubmenu:parentMenu];
	[parentMenu release];
	
	while(( key = [iter nextObject]))
	{
		childItem = [parentMenu addItemWithTitle:[key capitalizedString] action:0 keyEquivalent:@""];
		[childItem setRepresentedObject:[self objectForKey:key]];
		[callback menuItem:childItem wasAddedForObject:[self objectForKey:key] inCategory:nil];
	}
	
	return [menu autorelease];
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	[m_recentlyUsed release];
	[m_recentlyAdded release];
	[m_categories release];
	[m_masterList release];
	
	[super dealloc];
}


- (id)					init
{
	self = [super init];
	if (self != nil)
	{
		m_masterList = [[NSMutableDictionary alloc] init];
		m_categories = [[NSMutableDictionary alloc] init];
		m_recentlyAdded  = [[NSMutableArray alloc] init];
		m_recentlyUsed   = [[NSMutableArray alloc] init];
		
		m_maxRecentlyAddedItems = kGCDefaultMaxRecentArraySize;
		m_maxRecentlyUsedItems = kGCDefaultMaxRecentArraySize;
		
		if (m_masterList == nil 
				|| m_categories == nil 
				|| m_recentlyAdded == nil 
				|| m_recentlyUsed == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		// in order to provide some default functionality in the event of no categories ever being created, add a "catch all"
		// category
		
		[self addCategory:kGCDefaultCategoryName];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeObject:m_masterList forKey:@"master"];
	[coder encodeObject:m_categories forKey:@"categories"];
	[coder encodeObject:m_recentlyAdded forKey:@"recent_add"];
	[coder encodeObject:m_recentlyUsed forKey:@"recent_use"];
	
	[coder encodeInt:m_maxRecentlyAddedItems forKey:@"maxadd"];
	[coder encodeInt:m_maxRecentlyUsedItems forKey:@"maxuse"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[m_masterList release];
	[m_categories release];
	[m_recentlyAdded release];
	[m_recentlyUsed release];
	
	self = [super init];
	if (self != nil)
	{
		m_masterList = [[coder decodeObjectForKey:@"master"] retain];
		m_categories = [[coder decodeObjectForKey:@"categories"] retain];
		m_recentlyAdded = [[coder decodeObjectForKey:@"recent_add"] retain];
		m_recentlyUsed = [[coder decodeObjectForKey:@"recent_use"] retain];
		
		m_maxRecentlyAddedItems = [coder decodeIntForKey:@"maxadd"];
		m_maxRecentlyUsedItems = [coder decodeIntForKey:@"maxuse"];
		
		if (m_masterList == nil 
				|| m_categories == nil 
				|| m_recentlyAdded == nil 
				|| m_recentlyUsed == nil)
		{
			[self autorelease];
			self = nil;
		}
	}

	return self;
}


@end

