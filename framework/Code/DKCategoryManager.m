/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU GPL3; see LICENSE
*/

#import "DKCategoryManager.h"
#import "NSDictionary+DeepCopy.h"
#import "LogEvent.h"
#import "NSMutableArray+DKAdditions.h"
#import "NSString+DKAdditions.h"
#import "DKUnarchivingHelper.h"

#pragma mark Contants(Non - localized)
NSString* kDKDefaultCategoryName = @"All Items";
NSString* kDKRecentlyAddedUserString = @"Recently Added";
NSString* kDKRecentlyUsedUserString = @"Recently Used";

NSString* kDKCategoryManagerWillAddObject = @"kDKCategoryManagerWillAddObject";
NSString* kDKCategoryManagerDidAddObject = @"kDKCategoryManagerDidAddObject";
NSString* kDKCategoryManagerWillRemoveObject = @"kDKCategoryManagerWillRemoveObject";
NSString* kDKCategoryManagerDidRemoveObject = @"kDKCategoryManagerDidRemoveObject";
NSString* kDKCategoryManagerDidRenameCategory = @"kDKCategoryManagerDidRenameCategory";
NSString* kDKCategoryManagerWillAddKeyToCategory = @"kDKCategoryManagerWillAddKeyToCategory";
NSString* kDKCategoryManagerDidAddKeyToCategory = @"kDKCategoryManagerDidAddKeyToCategory";
NSString* kDKCategoryManagerWillRemoveKeyFromCategory = @"kDKCategoryManagerWillRemoveKeyFromCategory";
NSString* kDKCategoryManagerDidRemoveKeyFromCategory = @"kDKCategoryManagerDidRemoveKeyFromCategory";
NSString* kDKCategoryManagerWillCreateNewCategory = @"kDKCategoryManagerWillCreateNewCategory";
NSString* kDKCategoryManagerDidCreateNewCategory = @"kDKCategoryManagerDidCreateNewCategory";
NSString* kDKCategoryManagerWillDeleteCategory = @"kDKCategoryManagerWillDeleteCategory";
NSString* kDKCategoryManagerDidDeleteCategory = @"kDKCategoryManagerDidDeleteCategory";

@interface DKCategoryManager (Private)

- (DKCategoryManagerMenuInfo*)findInfoForMenu:(NSMenu*)aMenu;

@end

#pragma mark -
@implementation DKCategoryManager
#pragma mark As a DKCategoryManager

static id sDearchivingHelper = nil;

/** @brief Returns a new category manager object

 Convenience method. Initial categories only consist of "All Items"
 @return a category manager object
 */
+ (DKCategoryManager*)categoryManager
{
	return [[[DKCategoryManager alloc] init] autorelease];
}

/** @brief Returns a new category manager object based on an existing dictionary

 Convenience method. Initial categories only consist of "All Items"
 @param dict an existign dictionary
 @return a category manager object
 */
+ (DKCategoryManager*)categoryManagerWithDictionary:(NSDictionary*)dict
{
	return [[[DKCategoryManager alloc] initWithDictionary:dict] autorelease];
}

/** @brief Return the default categories defined for this class
 @return an array of categories */
+ (NSArray*)defaultCategories
{
	return [NSArray arrayWithObject:kDKDefaultCategoryName];
}

/** @brief Given an object, return a key that can be used to store it in the category manager.

 Subclasses will need to define this differently - used for merging.
 @param obj an object
 @return a key string */
+ (NSString*)categoryManagerKeyForObject:(id)obj
{
#pragma unused(obj)

	NSLog(@"warning - subclasses of DKCategoryManager must override +categoryManagerKeyForObject: to correctly implement merging");

	return nil;
}

+ (id)dearchivingHelper
{
	if (sDearchivingHelper == nil)
		sDearchivingHelper = [[DKUnarchivingHelper alloc] init];

	return sDearchivingHelper;
}

+ (void)setDearchivingHelper:(id)helper
{
	[helper retain];
	[sDearchivingHelper release];
	sDearchivingHelper = helper;
}

#pragma mark -
#pragma mark - initialization

/** @brief Initialized a category manager object from archive data

 Data is permitted also to be an archived dictionary
 @param data data containing a correctly archived category manager
 @return the category manager object
 */
- (id)initWithData:(NSData*)data
{
	NSAssert(data != nil, @"Expected valid data");

	NSKeyedUnarchiver* unarch = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];

	// in order to translate older files with classes named 'GC' instead of 'DK', need a delegate that can handle the
	// translation. Apps can also swap out this helper, or become listeners of its notifications for progress indication

	id dearchivingHelper = [[self class] dearchivingHelper];
	if ([dearchivingHelper respondsToSelector:@selector(reset)])
		[dearchivingHelper reset];

	[unarch setDelegate:dearchivingHelper];
	id obj = [unarch decodeObjectForKey:@"root"];

	[unarch finishDecoding];
	[unarch autorelease];

	NSAssert(obj != nil, @"Expected valid obj");

	if ([obj isKindOfClass:[DKCategoryManager class]]) // not [self class] as cat mgr is sometimes subclassed
	{
		DKCategoryManager* cm = (DKCategoryManager*)obj;

		self = [self init];
		if (self) {
			[m_masterList setDictionary:cm->m_masterList];
			[m_categories setDictionary:cm->m_categories];
			[m_recentlyAdded setArray:cm->m_recentlyAdded];
			[m_recentlyUsed setArray:cm->m_recentlyUsed];

			m_maxRecentlyUsedItems = cm->m_maxRecentlyUsedItems;
			m_maxRecentlyAddedItems = cm->m_maxRecentlyAddedItems;
		}
	} else if ([obj isKindOfClass:[NSDictionary class]]) {
		self = [self initWithDictionary:obj];
	} else {
		self = [self init];
		NSLog(@"%@ ! data was not a valid archive for -initWithData:", self);
	}
	return self;
}

/** @brief Initialized a category manager object from an existing dictionary

 No categories other than "All Items" are created by default. The recently added list is empty.
 @param dict dictionary containing a set of objects and keys
 @return the category manager object
 */
- (id)initWithDictionary:(NSDictionary*)dict
{
	NSAssert(dict != nil, @"Expected valid dict");
	self = [self init];
	if (self != nil) {
		// dictionary keys need to be all lowercase to allow "case insensitivity" in the master list

		NSEnumerator* iter = [[dict allKeys] objectEnumerator];
		NSString* s;

		while ((s = [iter nextObject])) {
			id obj = [dict objectForKey:s];
			[m_masterList setObject:obj
							 forKey:[s lowercaseString]];
		}

		// add to "All Items":

		NSMutableArray* aicat = [m_categories objectForKey:kDKDefaultCategoryName];

		if (aicat) {
			[aicat addObjectsFromArray:[dict allKeys]];
		}
	}

	return self;
}

#pragma mark -
#pragma mark - adding and retrieving objects

/** @brief Add an object to the container, associating with a key and optionally a category.

 <obj> and <name> cannot be nil. All objects are added to the default category regardless of <catName>
 @param obj the object to add
 @param name the object's key
 @param catName the name of the category to add it to, or nil for defaults only
 @param cg YES to create the category if it doesn't exist. NO not to do so
 */
- (void)addObject:(id)obj forKey:(NSString*)name toCategory:(NSString*)catName createCategory:(BOOL)cg
{
	//	LogEvent_(kStateEvent, @"category manager adding object:%@ name:%@ to category:%@", obj, name, catName );

	NSAssert(obj != nil, @"object cannot be nil");
	NSAssert(name != nil, @"name cannot be nil");
	NSAssert([name length] > 0, @"name cannot be empty");

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerWillAddObject
														object:self];

	// add the object to the master list

	[m_masterList setObject:obj
					 forKey:[name lowercaseString]];
	[self addKey:name
		toRecentList:kDKListRecentlyAdded];

	// add to single category specified if any

	if (catName != nil)
		[self addKey:name
				toCategory:catName
			createCategory:cg];

	[self addKey:name
			toCategory:kDKDefaultCategoryName
		createCategory:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerDidAddObject
														object:self];
}

/** @brief Add an object to the container, associating with a key and optionally a number of categories.

 <obj> and <name> cannot be nil. All objects are added to the default category regardless of <catNames>
 @param obj the object to add
 @param name the object's key
 @param catNames the names of the categories to add it to, or nil for defaults
 @param cg YES to create the categories if they don't exist. NO not to do so
 */
- (void)addObject:(id)obj forKey:(NSString*)name toCategories:(NSArray*)catNames createCategories:(BOOL)cg
{
	//	LogEvent_(kStateEvent, @"category manager adding object:%@ name:%@ to categories:%@", obj, name, catNames );

	NSAssert(obj != nil, @"object cannot be nil");
	NSAssert(name != nil, @"name cannot be nil");
	NSAssert([name length] > 0, @"name cannot be empty");

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerWillAddObject
														object:self];

	// add the object to the master list

	[m_masterList setObject:obj
					 forKey:[name lowercaseString]];
	[self addKey:name
		toRecentList:kDKListRecentlyAdded];

	// add to multiple categories specified

	if (catNames != nil && [catNames count] > 0)
		[self addKey:name
				toCategories:catNames
			createCategories:cg];

	[self addKey:name
			toCategory:kDKDefaultCategoryName
		createCategory:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerDidAddObject
														object:self];
}

/** @brief Remove an object from the container

 After this the key will not be found in any category or either list
 @param key the object's key
 */
- (void)removeObjectForKey:(NSString*)key
{
	// remove this key from any/all categories and lists

	NSAssert(key != nil, @"attempt to remove nil key");

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerWillRemoveObject
														object:self];

	[self removeKeyFromAllCategories:key];
	[self removeKey:key
		fromRecentList:kDKListRecentlyAdded];
	[self removeKey:key
		fromRecentList:kDKListRecentlyUsed];

	// remove from master dictionary

	[m_masterList removeObjectForKey:[key lowercaseString]];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerDidRemoveObject
														object:self];
}

/** @brief Remove multiple objects from the container

 After this no keys will not be found in any category or either list
 @param keys a list of keys
 */
- (void)removeObjectsForKeys:(NSArray*)keys
{
	NSEnumerator* iter = [keys objectEnumerator];
	NSString* key;

	while ((key = [iter nextObject]))
		[self removeObjectForKey:key];
}

/** @brief Removes all objects from the container

 Does not remove the categories, but leaves them all empty.
 */
- (void)removeAllObjects
{
	NSArray* keys = [self allKeys];
	[self removeObjectsForKeys:keys];
}

#pragma mark -

/** @brief Test whether the key is known to the container
 @param key the object's key
 @return YES if known, NO if not
 */
- (BOOL)containsKey:(NSString*)key
{
	return [[m_masterList allKeys] containsObject:[key lowercaseString]];
}

/** @brief Return total number of stored objects in container
 @return the number of objects
 */
- (NSUInteger)count
{
	return [m_masterList count];
}

#pragma mark -

/** @brief Return the object for the given key, but do not remember it in the "recently used" list
 @param key the object's key
 @return the object if available, else nil
 */
- (id)objectForKey:(NSString*)key
{
	return [m_masterList objectForKey:[key lowercaseString]];
}

/** @brief Return the object for the given key, optionally remembering it in the "recently used" list

 Use this method when you wish this access of the object to result in it being added to "recently used"
 @param key the object's key
 @param add if YES, object's key is added to recently used items
 @return the object if available, else nil
 */
- (id)objectForKey:(NSString*)key addToRecentlyUsedItems:(BOOL)add
{
	// returns the object, but optionally adds it to the "recently used" list

	id obj = [self objectForKey:key];

	if (add)
		[self addKey:key
			toRecentList:kDKListRecentlyUsed];

	return obj;
}

#pragma mark -

/** @brief Returns a list of all unique keys that refer to the given object

 The result may contain no keys if the object is unknown
 @param obj the object
 @return an array, listing all the unique keys that refer to the object.
 */
- (NSArray*)keysForObject:(id)obj
{
	//return [[self dictionary] allKeysForObject:obj];  // doesn't work because master dict uses lowercase keys

	NSMutableArray* keys = [[NSMutableArray alloc] init];
	NSEnumerator* iter = [[self allKeys] objectEnumerator];
	NSString* key;

	while ((key = [iter nextObject])) {
		if ([[self objectForKey:key] isEqual:obj])
			[keys addObject:key];
	}

	return [keys autorelease];
}

/** @brief Return a copy of the master dictionary
 @return the main dictionary
 */
- (NSDictionary*)dictionary
{
	return [[m_masterList copy] autorelease];
}

/** @brief Smartly merges objects into the category manager
 @param aSet a set of objects of the same kind as the current contents
 @param categories an optional list of categories to add th eobjects to. Categories will be created if needed.
 @param options replacxement options. Delegate may override these.
 @param adelegate an optional delegate that can be asked to make decisions about which objects get replaced.
 @return a set, possibly empty. The set contains those objects that already existed in the CM that should replace
 equivalent items in the supplied set.
 */
- (NSSet*)mergeObjectsFromSet:(NSSet*)aSet inCategories:(NSArray*)categories mergeOptions:(DKCatManagerMergeOptions)options mergeDelegate:(id)aDelegate
{
	NSAssert(aSet != nil, @"cannot merge - set was nil");

	NSEnumerator* iter = [aSet objectEnumerator];
	id obj, existingObj;
	NSMutableSet* changedStyles = nil;
	NSString* key;

	while ((obj = [iter nextObject])) {
		// if the style is unknown to the registry, simply register it - in this case there's no need to do any complex merging or
		// further analysis.

		key = [[self class] categoryManagerKeyForObject:obj];
		existingObj = [self objectForKey:key];

		if (existingObj == nil)
			[self addObject:obj
						  forKey:key
					toCategories:categories
				createCategories:YES];
		else {
			if ((options & kDKReplaceExisting) != 0) {
				// style is known to us, so a merge is required, overwriting the registered object with the new one. Any clients of the
				// modified style will be updated automatically.

				existingObj = [self mergeObject:obj
								  mergeDelegate:aDelegate];

				if (existingObj != nil) {
					if (changedStyles == nil)
						changedStyles = [NSMutableSet set];

					[changedStyles addObject:existingObj];

					// add to the requested categories if needed

					[self addKey:key
							toCategories:categories
						createCategories:YES];
				}
			} else if ((options & kDKReturnExisting) != 0) {
				// here the options request that the registered styles have priority, so the existing style is added to the return set

				if (changedStyles == nil)
					changedStyles = [NSMutableSet set];

				[changedStyles addObject:existingObj];

				// add to the requested categories if needed

				[self addKey:key
						toCategories:categories
					createCategories:YES];
			} else if ((options & kDKAddAsNewVersions) != 0) {
				// here the options request that the document styles are to be re-registered as new styles. This leaves both document and
				// existing registered styles unaffected but can massively multiply the registry with many duplicates. In general this
				// options should be used sparingly, if at all.

				// TO DO

				// there's nothing to return in this case
			}
		}
	}

	return changedStyles;
}

/** @brief Asks delegate to make decision about the merging of an object

 Subclasses must override this to make use of it. Returning nil means use existing object.
 @param obj the object to consider
 @param aDelegate the delegate to ask
 @return an equivalent object or nil. May be the supplied object or another having an identical ID.
 */
- (id)mergeObject:(id)obj mergeDelegate:(id)aDelegate
{
	NSAssert(obj != nil, @"cannot merge - object was nil");

	id newObj = nil;

	if (aDelegate && [aDelegate respondsToSelector:@selector(categoryManager:
														 shouldReplaceObject:
																  withObject:)]) {
		id existingObject = [self objectForKey:[[self class] categoryManagerKeyForObject:obj]];

		if (existingObject == nil || existingObject == obj)
			return nil; // this is really an error - the object is already registered, or is unregistered

		// ask the delegate:

		newObj = [aDelegate categoryManager:self
						shouldReplaceObject:existingObject
								 withObject:obj];
	}

	return newObj;
}

#pragma mark -
#pragma mark - retrieving lists of objects by category

/** @brief Return all of the objects belonging to a given category

 Returned objects are in no particular order, but do match the key order obtained by
 -allkeysInCategory. Should any key not exist (which should never normally occur), the entry will
 be represented by a NSNull object
 @param catName the category name
 @return an array, the list of objects indicated by the category. May be empty.
 */
- (NSArray*)objectsInCategory:(NSString*)catName
{
	NSMutableArray* keys = [[[NSMutableArray alloc] init] autorelease];
	NSEnumerator* iter = [[self allKeysInCategory:catName] objectEnumerator];
	NSString* s;

	while ((s = [iter nextObject]))
		[keys addObject:[s lowercaseString]];

	return [m_masterList objectsForKeys:keys
						 notFoundMarker:[NSNull null]];
}

/** @brief Return all of the objects belonging to the given categories

 Returned objects are in no particular order, but do match the key order obtained by
 -allKeysInCategories:. Should any key not exist (which should never normally occur), the entry will
 be represented by a NSNull object
 @param catNames list of categories
 @return an array, the list of objects indicated by the categories. May be empty.
 */
- (NSArray*)objectsInCategories:(NSArray*)catNames
{
	NSMutableArray* keys = [[[NSMutableArray alloc] init] autorelease];
	NSEnumerator* iter = [[self allKeysInCategories:catNames] objectEnumerator];
	NSString* s;

	while ((s = [iter nextObject]))
		[keys addObject:[s lowercaseString]];

	return [m_masterList objectsForKeys:keys
						 notFoundMarker:[NSNull null]];
}

/** @brief Return all of the keys in a given category

 Returned objects are in no particular order. This also treats the "recently used" and "recently added"
 items as pseudo-category names, returning these arrays if the catName matches.
 @param catName the category name
 @return an array, the list of keys indicated by the category. May be empty.
 */

/** @brief Return all of the keys

 Returned objects are in no particular order. The keys are obtained by enumerating the categories
 because the master list contains case-modified keys that may not be matched with categories.
 @return an array, all keys (listed only once)
 */
- (NSArray*)allKeysInCategory:(NSString*)catName
{
	if ([catName isEqualToString:kDKRecentlyAddedUserString])
		return [self recentlyAddedItems];
	else if ([catName isEqualToString:kDKRecentlyUsedUserString])
		return [self recentlyUsedItems];
	else
		return [m_categories objectForKey:catName];
}

/** @brief Return all of the keys in all given categories

 Returned objects are in no particular order.
 @param catNames an array of category names
 @return an array, the union of keys in listed categories. May be empty.
 */
- (NSArray*)allKeysInCategories:(NSArray*)catNames
{
	if ([catNames count] == 1)
		return [self allKeysInCategory:[catNames lastObject]];
	else {
		NSMutableArray* temp = [[NSMutableArray alloc] init];
		NSEnumerator* iter = [catNames objectEnumerator];
		NSString* catname;
		NSArray* keys;

		while ((catname = [iter nextObject])) {
			keys = [self allKeysInCategory:catname];

			// add keys not already in <temp> to temp

			[temp addUniqueObjectsFromArray:keys];
		}

		return [temp autorelease];
	}
}

- (NSArray*)allKeys
{
	//return [[self dictionary] allKeys];		// doesn't work because keys are lowercase

	return [self allKeysInCategories:[self allCategories]];
}

/** @brief Return all of the objects
 @return an array, all objects (listed only once, in arbitrary order)
 */
- (NSArray*)allObjects
{
	return [m_masterList allValues];
}

/** @brief Return all of the keys in a given category, sorted into some useful order

 By default the keys are sorted alphabetically. The UI-building methods call this, so a subclass
 can override it and return keys sorted by some other criteria if required.
 @param catName the category name
 @return an array, the list of keys indicated by the category. May be empty.
 */
- (NSArray*)allSortedKeysInCategory:(NSString*)catName
{
	return [[self allKeysInCategory:catName] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

/** @brief Return all of the names in a given category, sorted into some useful order

 For an ordinary DKCategoryManager, names == keys. However, subclasses may store keys in some other
 fashion (hint: they do) and so another method is needed to convert keys to names. Those subclasses
 must override this and do what's appropriate.
 @param catName the category name
 @return an array, the list of names indicated by the category. May be empty.
 */
- (NSArray*)allSortedNamesInCategory:(NSString*)catName
{
	return [self allSortedKeysInCategory:catName];
}

#pragma mark -

/** @brief Replaces the recently added items with new items, up to the current max.
 @param array an array of suitable objects
 */
- (void)setRecentlyAddedItems:(NSArray*)array
{
	[m_recentlyAdded removeAllObjects];

	NSUInteger i;

	for (i = 0; i < MIN([array count], m_maxRecentlyAddedItems); ++i)
		[m_recentlyAdded addObject:[array objectAtIndex:i]];
}

/** @brief Return the list of recently added items

 Returned objects are in order of addition, most recent first.
 @return an array, the list of keys recently added.
 */
- (NSArray*)recentlyAddedItems
{
	return m_recentlyAdded;
}

/** @brief Return the list of recently used items

 Returned objects are in order of use, most recent first.
 @return an array, the list of keys recently used.
 */
- (NSArray*)recentlyUsedItems
{
	return m_recentlyUsed;
}

#pragma mark -
#pragma mark - category management - creating, deleting and renaming categories

/** @brief Add the default categories defined for this class or object

 Is called as part of the initialisation of the CM object
 */
- (void)addDefaultCategories
{
	[self addCategories:[self defaultCategories]];
}

/** @brief Return the default categories defined for this class or object
 @return an array of categories
 */
- (NSArray*)defaultCategories
{
	return [[self class] defaultCategories];
}

/** @brief Create a new category with the given name

 If the name is already a category name, this does nothing
 @param catName the name of the new category */
- (void)addCategory:(NSString*)catName
{
	if ([m_categories objectForKey:catName] == nil) {
		//	LogEvent_(kStateEvent,  @"adding new category '%@'", catName );

		NSMutableArray* cat = [[NSMutableArray alloc] init];
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:catName, @"category_name", nil];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerWillCreateNewCategory
															object:self
														  userInfo:info];
		[m_categories setObject:cat
						 forKey:catName];
		[cat release];

		// inform any menus of the new category

		[mMenusList makeObjectsPerformSelector:@selector(addCategory:)
									withObject:catName];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerDidCreateNewCategory
															object:self
														  userInfo:info];
	}
}

/** @brief Create a new categories with the given names
 @param catNames a list of the names of the new categories */
- (void)addCategories:(NSArray*)catNames
{
	NSEnumerator* iter = [catNames objectEnumerator];
	NSString* catName;

	while ((catName = [iter nextObject]))
		[self addCategory:catName];
}

/** @brief Remove a category with the given name

 The objects listed in the category are not removed, as they may also be listed by other categories.
 If they are not, they can become orphaned however. To avoid this, never delete the "All Items"
 category.
 @param catName the category to remove
 */
- (void)removeCategory:(NSString*)catName
{
	//	LogEvent_(kStateEvent, @"removing category '%@'", catName );

	if ([m_categories objectForKey:catName]) {
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:catName, @"category_name", nil];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerWillDeleteCategory
															object:self
														  userInfo:info];
		[m_categories removeObjectForKey:catName];

		// inform menus that category has gone

		[mMenusList makeObjectsPerformSelector:@selector(removeCategory:)
									withObject:catName];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerDidDeleteCategory
															object:self
														  userInfo:info];
	}
}

/** @brief Change a category's name

 If <newname> already exists, it will be replaced by the entries in <catname>
 @param catName the category's old name
 @param newname the category's new name
 */
- (void)renameCategory:(NSString*)catName to:(NSString*)newname
{
	LogEvent_(kStateEvent, @"renaming the category '%@' to' %@'", catName, newname);

	NSMutableArray* gs = [m_categories objectForKey:catName];

	if (gs) {
		[gs retain];
		[m_categories removeObjectForKey:catName];

		[m_categories setObject:gs
						 forKey:newname];
		[gs release];

		// update menu item title:

		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:catName, @"old_name", newname, @"new_name", nil];
		[mMenusList makeObjectsPerformSelector:@selector(renameCategoryWithInfo:)
									withObject:info];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerDidRenameCategory
															object:self];
	}
}

/** @brief Removes all categories and objects from the CM.

 After this the CM is entirely empty.
 */
- (void)removeAllCategories
{
	[m_masterList removeAllObjects];
	[m_categories removeAllObjects];
	[m_recentlyUsed removeAllObjects];
	[m_recentlyAdded removeAllObjects];

	[mMenusList makeObjectsPerformSelector:@selector(removeAll)];
}

#pragma mark -

/** @brief Adds a new key to a category, optionally creating it if necessary
 @param key the key to add
 @param catName the category to add it to
 @param cg YES to create the category if it doesn't exist, NO otherwise */
- (void)addKey:(NSString*)key toCategory:(NSString*)catName createCategory:(BOOL)cg
{
	// add a key to an existing group, or to a new group if it doesn't yet exist and the flag is set

	NSAssert(key != nil, @"key can't be nil");

	if (catName == nil)
		return;

	LogEvent_(kStateEvent, @"category manager adding key '%@' to category '%@'", key, catName);

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerWillAddKeyToCategory
														object:self];

	NSMutableArray* ga = [m_categories objectForKey:catName];

	if (ga == nil && cg) {
		// doesn't exist - create it

		[self addCategory:catName];
		ga = [m_categories objectForKey:catName];
	}

	// add the key to this group's list if not already known

	if (![ga containsObject:key]) {
		[ga addObject:key];

		// update menus

		[mMenusList makeObjectsPerformSelector:@selector(addKey:)
									withObject:key];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerDidAddKeyToCategory
														object:self];
}

/** @brief Adds a new key to several categories, optionally creating any if necessary
 @param key the key to add
 @param catNames a list of categories to add it to
 @param cg YES to create the category if it doesn't exist, NO otherwise */
- (void)addKey:(NSString*)key toCategories:(NSArray*)catNames createCategories:(BOOL)cg
{
	if (catNames == nil)
		return;

	NSEnumerator* iter = [catNames objectEnumerator];
	NSString* cat;

	while ((cat = [iter nextObject]))
		[self addKey:key
				toCategory:cat
			createCategory:cg];
}

/** @brief Removes a key from a category
 @param key the key to remove
 @param catName the category to remove it from */
- (void)removeKey:(NSString*)key fromCategory:(NSString*)catName
{
	//	LogEvent_(kStateEvent, @"removing key '%@' from category '%@'", key, catName );

	NSMutableArray* ga = [m_categories objectForKey:catName];

	if (ga) {
		// remove from menus - do this first so that the menus are still able to look up category membership
		// of the object

		[mMenusList makeObjectsPerformSelector:@selector(removeKey:)
									withObject:key];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerWillRemoveKeyFromCategory
															object:self];
		[ga removeObject:key];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKCategoryManagerDidRemoveKeyFromCategory
															object:self];
	}
}

/** @brief Removes a key from a number of categories
 @param key the key to remove
 @param catNames the list of categories to remove it from */
- (void)removeKey:(NSString*)key fromCategories:(NSArray*)catNames
{
	if (catNames == nil)
		return;

	NSEnumerator* iter = [catNames objectEnumerator];
	NSString* cat;

	while ((cat = [iter nextObject]))
		[self removeKey:key
			fromCategory:cat];
}

/** @brief Removes a key from all categories
 @param key the key to remove */
- (void)removeKeyFromAllCategories:(NSString*)key
{
	[self removeKey:key
		fromCategories:[self allCategories]];
}

/** @brief Checks that all keys refer to real objects, removing any that do not

 Rarely needed, but can correct for corrupted registries where objects got removed but not all
 keys that refer to it did for some reason (such as an exception). */
- (void)fixUpCategories
{
	NSEnumerator* iter = [[self allKeys] objectEnumerator];
	NSString* key;

	while ((key = [iter nextObject])) {
		if ([self objectForKey:key] == nil)
			[self removeKeyFromAllCategories:key];
	}
}

/** @brief Renames an object's key throughout

 If <key> doesn't exist, or if <newkey> already exists, throws an exception. After this the same
 object that could be located using <key> can be located using <newKey> in the same categories as
 it appeared in originally.
 @param key the existing key
 @param newKey the new key
 */
- (void)renameKey:(NSString*)key to:(NSString*)newKey
{
	NSAssert(key != nil, @"expected non-nil key");
	NSAssert(newKey != nil, @"expected non-nil new key");

	// if the keys are the same, do nothing

	if ([key isEqualToString:newKey])
		return;

	// first check that <key> exists:

	if (![self containsKey:key])
		[NSException raise:NSInvalidArgumentException
					format:@"The key '%@' can't be renamed because it doesn't exist", key];

	// check that the new key isn't in use:

	if ([self containsKey:newKey])
		[NSException raise:NSInvalidArgumentException
					format:@"Cannot rename key to '%@' because that key is already in use", newKey];

	LogEvent_(kStateEvent, @"changing key '%@' to '%@'", key, newKey);

	// what categories are going to be touched?

	NSArray* cats = [self categoriesContainingKey:key];

	// retain the object while we move it around:

	id object = [[self objectForKey:key] retain];
	[self removeObjectForKey:key];
	[self addObject:object
				  forKey:newKey
			toCategories:cats
		createCategories:NO];
	[object release];
}

#pragma mark -
#pragma mark - getting lists, etc.of the categories

/** @brief Get a list of all categories

 The list is alphabetically sorted for the convenience of a user interface
 @return an array containg a list of all category names
 */
- (NSArray*)allCategories
{
	return [[m_categories allKeys] sortedArrayUsingSelector:@selector(localisedCaseInsensitiveNumericCompare:)];
}

/** @brief Get the count of all categories
 @return the number of categories currently defined
 */
- (NSUInteger)countOfCategories
{
	return [m_categories count];
}

/** @brief Get a list of all categories that contain a given key

 The list is alphabetically sorted for the convenience of a user interface
 @param key the key in question
 @return an array containing a list of categories which contain the key
 */
- (NSArray*)categoriesContainingKey:(NSString*)key
{
	return [self categoriesContainingKey:key
							 withSorting:YES];
}

- (NSArray*)categoriesContainingKey:(NSString*)key withSorting:(BOOL)sortIt
{
	NSEnumerator* iter = [[m_categories allKeys] objectEnumerator];
	NSString* catName;
	NSArray* cat;
	NSMutableArray* catList;

	catList = [[NSMutableArray alloc] init];

	while ((catName = [iter nextObject])) {
		cat = [self allKeysInCategory:catName];

		if ([cat containsObject:key])
			[catList addObject:catName];
	}

	if (sortIt)
		[catList sortUsingSelector:@selector(caseInsensitiveCompare:)];

	return [catList autorelease];
}

/** @brief Get a list of reserved categories - those that should not be deleted or renamed

 This list is advisory - a UI is responsible for honouring it, the cat manager itself ignores it.
 The default implementation returns the same as the default categories, thus reserving all
 default cats. Subclasses can change this as they wish.
 @return an array containing a list of the reserved categories 
 */
- (NSArray*)reservedCategories
{
	return [self defaultCategories];
}

#pragma mark -

/** @brief Test whether there is a category of the given name
 @param catName the category name
 @return YES if a category exists with the name, NO otherwise
 */
- (BOOL)categoryExists:(NSString*)catName
{
	return [m_categories objectForKey:catName] != nil;
}

/** @brief Count how many objects in the category of the given name
 @param catName the category name
 @return the number of objects in the category
 */
- (NSUInteger)countOfObjectsInCategory:(NSString*)catName
{
	return [[m_categories objectForKey:catName] count];
}

/** @brief Query whether a given key is present in a particular category
 @param key the key
 @param catName the category name
 @return YES if the category contains <key>, NO if it doesn't
 */
- (BOOL)key:(NSString*)key existsInCategory:(NSString*)catName
{
	return [[m_categories objectForKey:catName] containsObject:key];
}

#pragma mark -
#pragma mark - managing recent lists

/** @brief Set whether the "recent;y added" list accepts new items or not

 This allows the recently added items to be temporarily disabled when bulk adding items to the
 manager. By default the recently added items list is enabled.
 @param enable YES to allow new items to be added, NO otherwise
 */
- (void)setRecentlyAddedListEnabled:(BOOL)enable
{
	mRecentlyAddedEnabled = enable;
}

/** @brief Add a key to one of the 'recent' lists

 Acceptable list IDs are kDKListRecentlyAdded and kDKListRecentlyUsed
 @param key the key to add
 @param whichList an identifier for the list in question
 @return return YES if the key was added, otherwise NO (i.e. if list already contains item) */
- (BOOL)addKey:(NSString*)key toRecentList:(NSInteger)whichList
{
	NSUInteger max;
	NSMutableArray* rl;
	BOOL movedOnly = NO;

	switch (whichList) {
	case kDKListRecentlyAdded:
		rl = m_recentlyAdded;
		max = m_maxRecentlyAddedItems;

		if (!mRecentlyAddedEnabled)
			return NO;

		break;

	case kDKListRecentlyUsed:
		rl = m_recentlyUsed;
		max = m_maxRecentlyUsedItems;
		if ([rl containsObject:key]) {
			[rl removeObject:key]; // forces reinsertion of the key at the head of the list
			movedOnly = YES;
		}
		break;

	default:
		return NO;
	}

	if (![rl containsObject:key]) {
		[rl insertObject:key
				 atIndex:0];
		while ([rl count] > max)
			[rl removeLastObject];

		// manage the menus as required (will remove and add items to keep menu in synch. with array)

		if (!movedOnly)
			[mMenusList makeObjectsPerformSelector:@selector(addRecentlyAddedOrUsedKey:)
										withObject:key];
		else
			[mMenusList makeObjectsPerformSelector:@selector(syncRecentlyUsedMenuForKey:)
										withObject:key];

		return YES;
	}

	return NO;
}

/** @brief Remove a key from one of the 'recent' lists

 Acceptable list IDs are kDKListRecentlyAdded and kDKListRecentlyUsed
 @param key the key to remove
 @param whichList an identifier for the list in question */
- (void)removeKey:(NSString*)key fromRecentList:(NSInteger)whichList
{
	NSMutableArray* rl;

	switch (whichList) {
	case kDKListRecentlyAdded:
		rl = m_recentlyAdded;
		break;

	case kDKListRecentlyUsed:
		rl = m_recentlyUsed;
		break;

	default:
		return;
	}

	[rl removeObject:key];

	// remove items(s) from managed menus also

	[mMenusList makeObjectsPerformSelector:@selector(addRecentlyAddedOrUsedKey:)
								withObject:nil];
}

/** @brief Sets the maximum length of on eof the 'recent' lists

 Acceptable list IDs are kDKListRecentlyAdded and kDKListRecentlyUsed
 @param whichList an identifier for the list in question
 @param max the maximum length to which a list may grow */
- (void)setRecentList:(NSInteger)whichList maxItems:(NSUInteger)max
{
	switch (whichList) {
	case kDKListRecentlyAdded:
		m_maxRecentlyAddedItems = max;
		break;

	case kDKListRecentlyUsed:
		m_maxRecentlyUsedItems = max;
		break;

	default:
		return;
	}
}

#pragma mark -
#pragma mark - archiving

/** @brief Archives the container to a data object (for saving, etc)
 @return a data object, the archive of the container
 */
- (NSData*)data
{
	return [self dataWithFormat:NSPropertyListXMLFormat_v1_0];
}

- (NSData*)dataWithFormat:(NSPropertyListFormat)format
{
	NSMutableData* d = [NSMutableData dataWithCapacity:100];
	NSKeyedArchiver* arch = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];

	[arch setOutputFormat:format];

	[self fixUpCategories]; // avoid archiving a badly formed object
	[arch encodeObject:self
				forKey:@"root"];
	[arch finishEncoding];
	[arch release];

	return d;
}

/** @brief Return the filetype (for saving, etc)

 Subclasses should override to change the filetype used for specific examples of this object
 */
- (NSString*)fileType
{
	return @"dkcatmgr";
}

/** @brief Discard all existing content, then reload from the archive data passed
 @param data data, being an archive earlier obtained using -data
 @return YES if the archive could be read, NO otherwise
 */
- (BOOL)replaceContentsWithData:(NSData*)data
{
	NSAssert(data != nil, @"cannot replace from nil data");

	DKCategoryManager* newCM = [[[self class] alloc] initWithData:data];

	if (newCM) {
		// since we are completely replacing, we can just transfer the master containers straight over without iterating over
		// all the individual items. This should be a lot faster.

		//NSLog(@"%@ replacing CM content from %@", self, newCM );

		[m_masterList setDictionary:newCM->m_masterList];
		[m_categories setDictionary:newCM->m_categories];
		[m_recentlyUsed setArray:newCM->m_recentlyUsed];
		[m_recentlyAdded setArray:newCM->m_recentlyAdded];

		// TODO: deal with menus

		[newCM release];
		[self setRecentlyAddedListEnabled:YES];

		return YES;
	}

	return NO;
}

/** @brief Retain all existing content, and load additional content from the archive data passed

 Because at this level DKCategoryManager has no knowledge of the objects it is storing, it has no
 means to be smart about merging objects that are the same in some higher abstract way. Thus it's
 entirely possible to end up with multiple copies of the "same" object after this operation.
 Subclasses may prefer to do something smarter.
 Note however that duplicate categories are not created.
 @param data data, being an archive earlier obtained using -data
 @return YES if the archive could be read, NO otherwise
 */
- (BOOL)appendContentsWithData:(NSData*)data
{
	NSAssert(data != nil, @"cannot append from nil data");

	DKCategoryManager* newCM = [[[self class] alloc] initWithData:data];

	if (newCM) {
		[self copyItemsFromCategoryManager:newCM];
		[newCM release];

		return YES;
	}

	return NO;
}

/** @brief Retain all existing content, and load additional content from the cat manager passed

 Categories not present in the receiver but exist in <cm> are created, and objects present in <cm>
 are added to the receiver if not already present (as determined solely by address). This method
 disables the "recently added" list while it adds the items.
 @param cm a category manager object
 */
- (void)copyItemsFromCategoryManager:(DKCategoryManager*)cm
{
	NSAssert(cm != nil, @"cannot copy items from nil");

	NSArray* newCategories;
	NSArray* newObjects = [cm allKeys];

	NSEnumerator* iter = [newObjects objectEnumerator];
	NSString* key;
	id obj;

	[self setRecentlyAddedListEnabled:NO];

	while ((key = [iter nextObject])) {
		obj = [cm objectForKey:key];
		newCategories = [cm categoriesContainingKey:key
										withSorting:NO];
		[self addObject:obj
					  forKey:key
				toCategories:newCategories
			createCategories:YES];
	}

	[self setRecentlyAddedListEnabled:YES];
	[self setRecentlyAddedItems:[cm recentlyAddedItems]];
}

#pragma mark -
#pragma mark - supporting UI

- (DKCategoryManagerMenuInfo*)findInfoForMenu:(NSMenu*)aMenu
{
	// private method - returns the management object for the given menu

	NSEnumerator* iter = [mMenusList objectEnumerator];
	DKCategoryManagerMenuInfo* menuInfo;

	while ((menuInfo = [iter nextObject])) {
		if ([menuInfo menu] == aMenu)
			return menuInfo;
	}

	return nil;
}

/** @brief Removes the menu from the list of managed menus

 An object using a menu created by the category manager must remove it from management when it is
 no longer needed as a stale reference can cause a crash.
 @param menu a menu managed by this object
 */
- (void)removeMenu:(NSMenu*)menu
{
	[mMenusList removeObject:[self findInfoForMenu:menu]];
}

/** @brief Synchronises the menus to reflect any change of the object referenced by <key>

 Any change to a stored object that affects the menus' appearance can be handled by calling this.
 this only changes the menu items that represent the object, and not the entire menu, so is an
 efficient way to keep menus up to date with changes.
 @param key an object's key
 */
- (void)updateMenusForKey:(NSString*)key
{
	[mMenusList makeObjectsPerformSelector:@selector(updateForKey:)
								withObject:key];
}

#pragma mark - a menu with everything, organised hierarchically by category

/** @brief Creates a complete menu of the entire contents of the receiver, arranged by category

 The menu returned lists the categories, each of which is a submenu containing the actual objects
 corresponding to the category contents. It also populates a recent items and added items submenu.
 the callback object needs to set up the menu item based on the object itself. The object is added
 automatically as the menu item's represented object. This is one easy way to create a simple UI
 to the cat manager, where you can simply pick an item from the menu.
 Note that the returned menu is fully managed - as objects are added and removed the menu will be
 directly managed to keep in synch. Thus the client code does not need to bother doing this just
 to keep the menus up to date. The menu updating is done very efficiently for performance.
 If the content of a menu item needs to change, call -updateMenusForKey: for the object key in
 question. When the client is dealloc'd, it should call -removeMenu: for any menus it obtained
 using this, so that stale references to the callback object are cleared out.
 @param id an object that is called back with each menu item created (may be nil)
 @param isPopUp set YES if menu is destined for use as a popup (adds extra zeroth item)
 @return a menu object
 */
- (NSMenu*)createMenuWithItemDelegate:(id)del isPopUpMenu:(BOOL)isPopUp
{
	NSInteger options = kDKIncludeRecentlyAddedItems | kDKIncludeRecentlyUsedItems;

	if (isPopUp)
		options |= kDKMenuIsPopUpMenu;

	return [self createMenuWithItemDelegate:del
									options:options];
}

- (NSMenu*)createMenuWithItemDelegate:(id)del options:(DKCategoryMenuOptions)options
{
	return [self createMenuWithItemDelegate:del
								 itemTarget:nil
								 itemAction:NULL
									options:options];
}

- (NSMenu*)createMenuWithItemDelegate:(id)del itemTarget:(id)target itemAction:(SEL)action options:(DKCategoryMenuOptions)options
{
	DKCategoryManagerMenuInfo* menuInfo;

	menuInfo = [[DKCategoryManagerMenuInfo alloc] initWithCategoryManager:self
															 itemDelegate:del
															   itemTarget:target
															   itemAction:action
																  options:options];

	[mMenusList addObject:menuInfo];
	[menuInfo autorelease];

	return [menuInfo menu];
}

#pragma mark - menus of just the categories

/** @brief Creates a menu of categories, recent items and All Items

 Sel and target may be nil
 @param sel the selector which is set as the action for each added item
 @param target the target of category item actions
 @return a menu populated with category and other names
 */
- (NSMenu*)categoriesMenuWithSelector:(SEL)sel target:(id)target
{
	return [self categoriesMenuWithSelector:sel
									 target:target
									options:kDKIncludeRecentlyAddedItems | kDKIncludeRecentlyUsedItems | kDKIncludeAllItems];
}

/** @brief Creates a menu of categories, recent items and All Items

 Sel and target may be nil, options may be 0
 @param sel the selector which is set as the action for each category item
 @param target the target of category item actions
 @param options various flags which set which items are added
 @return a menu populated with category and other names
 */
- (NSMenu*)categoriesMenuWithSelector:(SEL)sel target:(id)target options:(NSInteger)options
{
	// create and populate a menu with the category names plus optionally the recent items lists

	DKCategoryManagerMenuInfo* menuInfo = [[DKCategoryManagerMenuInfo alloc] initWithCategoryManager:self
																						  itemTarget:target
																						  itemAction:sel
																							 options:options];

	[mMenusList addObject:menuInfo];
	[menuInfo release];

	return [menuInfo menu];
}

/** @brief Sets the checkmarks in a menu of category names to reflect the presence of <key> in those categories

 Assumes that item names will be the category names. For localized names, you should handle the
 localization external to this class so that both category names and menu items use the same strings.
 @param menu the menu to examine
 @param key the key to test against
 */
- (void)checkItemsInMenu:(NSMenu*)menu forCategoriesContainingKey:(NSString*)key
{
	DKCategoryManagerMenuInfo* menuInfo = [self findInfoForMenu:menu];

	if (menuInfo)
		[menuInfo checkItemsForKey:key];
}

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	[m_recentlyUsed release];
	[m_recentlyAdded release];
	[m_categories release];
	[m_masterList release];
	[mMenusList release];

	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		m_masterList = [[NSMutableDictionary alloc] init];
		m_categories = [[NSMutableDictionary alloc] init];
		m_recentlyAdded = [[NSMutableArray alloc] init];
		m_recentlyUsed = [[NSMutableArray alloc] init];
		mMenusList = [[NSMutableArray alloc] init];
		mRecentlyAddedEnabled = YES;
		m_maxRecentlyAddedItems = kDKDefaultMaxRecentArraySize;
		m_maxRecentlyUsedItems = kDKDefaultMaxRecentArraySize;

		if (m_masterList == nil
			|| m_categories == nil
			|| m_recentlyAdded == nil
			|| m_recentlyUsed == nil) {
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil) {
		// add the default categories

		[self addDefaultCategories];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	[coder encodeObject:m_masterList
				 forKey:@"master"];
	[coder encodeObject:m_categories
				 forKey:@"categories"];
	[coder encodeObject:m_recentlyAdded
				 forKey:@"recent_add"];
	[coder encodeObject:m_recentlyUsed
				 forKey:@"recent_use"];

	[coder encodeInteger:m_maxRecentlyAddedItems
				  forKey:@"maxadd"];
	[coder encodeInteger:m_maxRecentlyUsedItems
				  forKey:@"maxuse"];
}

- (id)initWithCoder:(NSCoder*)coder
{
	m_masterList = [[coder decodeObjectForKey:@"master"] retain];
	m_categories = [[coder decodeObjectForKey:@"categories"] retain];
	m_recentlyAdded = [[coder decodeObjectForKey:@"recent_add"] retain];
	m_recentlyUsed = [[coder decodeObjectForKey:@"recent_use"] retain];

	m_maxRecentlyAddedItems = [coder decodeIntegerForKey:@"maxadd"];
	m_maxRecentlyUsedItems = [coder decodeIntegerForKey:@"maxuse"];
	mRecentlyAddedEnabled = YES;

	mMenusList = [[NSMutableArray alloc] init];

	if (m_masterList == nil
		|| m_categories == nil
		|| m_recentlyAdded == nil
		|| m_recentlyUsed == nil) {
		[self autorelease];
		self = nil;
	}

	return self;
}

#pragma mark -
#pragma mark As part of NSCopying protocol

- (id)copyWithZone:(NSZone*)zone
{
	// a copy of the category manager has the same objects, a deep copy of the categories, but empty recent lists.
	// it also doesn't copy the menu management data across. Thus the copy has the same data structure as this, but lacks the
	// dynamic information that pertains to current usage and UI. The copy can be used as a "fork" of this CM.

	DKCategoryManager* copy = [[[self class] allocWithZone:zone] init];

	[copy->m_masterList setDictionary:m_masterList];

	NSDictionary* cats = [m_categories deepCopy];
	[copy->m_categories setDictionary:cats];
	[cats release];

	return copy;
}

@end

#pragma mark -
#pragma mark DKCategoryManagerMenuInfo

@interface DKCategoryManagerMenuInfo (Private)

- (void)createMenu;
- (void)createCategoriesMenu;
- (NSMenu*)createSubmenuWithTitle:(NSString*)title forArray:(NSArray*)items;
- (void)removeItemsInMenu:(NSMenu*)aMenu withTag:(NSInteger)tag excludingItem0:(BOOL)title;

@end

@implementation DKCategoryManagerMenuInfo

- (id)initWithCategoryManager:(DKCategoryManager*)mgr itemTarget:(id)target itemAction:(SEL)selector options:(DKCategoryMenuOptions)options
{
	self = [super init];
	if (self != nil) {
		mCatManagerRef = mgr;
		mTargetRef = target;
		mSelector = selector;
		mOptions = options;
		mCategoriesOnly = YES;
		[self createCategoriesMenu];
	}

	return self;
}

- (id)initWithCategoryManager:(DKCategoryManager*)mgr itemDelegate:(id)delegate options:(DKCategoryMenuOptions)options
{
	NSAssert(delegate != nil, @"no delegate for menu item callback");

	self = [super init];
	if (self != nil) {
		mCatManagerRef = mgr;
		mCallbackTargetRef = delegate;
		mOptions = options;
		mCategoriesOnly = NO;
		[self createMenu];
	}

	return self;
}

- (id)initWithCategoryManager:(DKCategoryManager*)mgr itemDelegate:(id)delegate itemTarget:(id)target itemAction:(SEL)selector options:(DKCategoryMenuOptions)options
{
	NSAssert(delegate != nil, @"no delegate for menu item callback");

	self = [super init];
	if (self != nil) {
		mCatManagerRef = mgr;
		mCallbackTargetRef = delegate;
		mTargetRef = target;
		mSelector = selector;
		mOptions = options;
		mCategoriesOnly = NO;
		[self createMenu];
	}

	return self;
}

- (NSMenu*)menu
{
	return mTheMenu;
}

- (void)addCategory:(NSString*)newCategory
{
	LogEvent_(kInfoEvent, @"adding category '%@' to menu %@", newCategory, self);

	// adds a new parent item to the main menu with the given category name and creates an empty submenu. The item is inserted into the menu
	// at the appropriate position to maintain alphabetical order. If the category already exists as a menu item, this does nothing.

	// known?

	NSInteger indx = [mTheMenu indexOfItemWithTitle:[newCategory capitalizedString]];

	if (indx == -1) {
		// prepare the new menu

		NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle:[newCategory capitalizedString]
														 action:mSelector
												  keyEquivalent:@""];

		// disable the item if it has a submenu but no items

		[newItem setEnabled:mCategoriesOnly];
		[newItem setTarget:mTargetRef];
		[newItem setAction:mSelector];
		[newItem setTag:kDKCategoryManagerManagedMenuItemTag];

		// find where to insert it and do so. The categories already contains this item, so we can just sort then find it.

		NSArray* temp = [mCatManagerRef allCategories];
		indx = [temp indexOfObject:newCategory];

		if (indx == NSNotFound)
			indx = 0;

		if (mOptions & kDKIncludeAllItems)
			++indx; // +1 allows for hidden title item unless we skipped "All Items"

		if (mCategoriesOnly) {
			--indx; // we're off by 1 somewhere

			if (mOptions & kDKIncludeRecentlyUsedItems)
				++indx;

			if (mOptions & kDKIncludeRecentlyAddedItems)
				++indx;

			if ((mOptions & kDKDontAddDividingLine) == 0)
				++indx;
		}
		if (indx > [mTheMenu numberOfItems])
			indx = [mTheMenu numberOfItems];

		[mTheMenu insertItem:newItem
					 atIndex:indx];
		[newItem release];
	}
}

- (void)removeCategory:(NSString*)oldCategory
{
	LogEvent_(kInfoEvent, @"removing category '%@' from menu %@", oldCategory, self);

	NSMenuItem* item = [mTheMenu itemWithTitle:[oldCategory capitalizedString]];

	if (item != nil)
		[mTheMenu removeItem:item];
}

- (void)renameCategoryWithInfo:(NSDictionary*)info
{
	NSString* oldCategory = [info objectForKey:@"old_name"];
	NSString* newName = [info objectForKey:@"new_name"];

	NSMenuItem* item = [mTheMenu itemWithTitle:[oldCategory capitalizedString]];

	if (item != nil) {
		[item retain];
		[mTheMenu removeItem:item];
		[item setTitle:[newName capitalizedString]];

		// where should it be reinserted to maintain sorting?

		NSArray* temp = [mCatManagerRef allCategories];
		NSInteger indx = [temp indexOfObject:newName];

		if (mOptions & kDKIncludeAllItems)
			++indx; // +1 allows for hidden title item unless we skipped "All Items"

		if (mCategoriesOnly) {
			--indx; // we're off by 1 somewhere

			if (mOptions & kDKIncludeRecentlyUsedItems)
				++indx;

			if (mOptions & kDKIncludeRecentlyAddedItems)
				++indx;

			if ((mOptions & kDKDontAddDividingLine) == 0)
				++indx;
		}
		if (indx > [mTheMenu numberOfItems])
			indx = [mTheMenu numberOfItems];

		[mTheMenu insertItem:item
					 atIndex:indx];
		[item release];
	}
}

- (void)addKey:(NSString*)aKey
{
	if (mCategoriesOnly)
		return;

	LogEvent_(kInfoEvent, @"adding item key '%@' to menu %@", aKey, self);

	// the key may be being added to several categories, so first get a list of the categories that it belongs to

	NSArray* cats = [mCatManagerRef categoriesContainingKey:aKey];
	NSEnumerator* iter = [cats objectEnumerator];
	NSString* cat;
	id repObject = [mCatManagerRef objectForKey:aKey];

	// iterate over the categories and find the menu responsible for it

	while ((cat = [iter nextObject])) {
		NSMenuItem* catItem = [mTheMenu itemWithTitle:[cat capitalizedString]];

		if (catItem != nil) {
			NSMenu* subMenu = [catItem submenu];

			if (subMenu == nil) {
				// make a submenu to list the actual items

				subMenu = [self createSubmenuWithTitle:[cat capitalizedString]
											  forArray:[NSArray arrayWithObject:aKey]];
				[catItem setSubmenu:subMenu];
				[catItem setEnabled:YES];
			} else {
				// check it's not present already - use the rep object

				NSInteger indx = [subMenu indexOfItemWithRepresentedObject:repObject];

				if (indx == -1) {
					// this menu needs to contain the item, so create an item to add to it. The title is initially set to the key
					// but the client may decide to change it.

					NSMenuItem* childItem = [[NSMenuItem alloc] initWithTitle:[aKey capitalizedString]
																	   action:mSelector
																keyEquivalent:@""];

					// call the callback to make this item into what its client needs

					[childItem setTarget:mTargetRef];
					[childItem setRepresentedObject:repObject];

					if (mCallbackTargetRef && [mCallbackTargetRef respondsToSelector:@selector(menuItem:
																						 wasAddedForObject:
																								inCategory:)])
						[mCallbackTargetRef menuItem:childItem
								   wasAddedForObject:repObject
										  inCategory:cat];

					[childItem setTag:kDKCategoryManagerManagedMenuItemTag];

					// the client should have set its title to something readable, so use that to determine where it should be inserted

					NSString* title = [childItem title];
					NSArray* temp = [mCatManagerRef allSortedNamesInCategory:cat];
					NSInteger insertIndex = [temp indexOfObject:title];

					// not found here would be an error, but not a serious one...

					if (insertIndex == NSNotFound)
						insertIndex = 0;

					//NSLog(@"insertion index = %d in array: %@", insertIndex, temp );

					[subMenu insertItem:childItem
								atIndex:insertIndex];
					[childItem release];
				}
			}
		}
	}
}

- (void)addRecentlyAddedOrUsedKey:(NSString*)aKey
{
	// manages the menu for recently added and recently used items. When the key is added, it is added to the menu and any keys no longer
	// in the arrays are removed from the menu. If <aKey> is nil the menu will drop any items not in the original array.

	LogEvent_(kInfoEvent, @"synching recent menus for key '%@' for menu %@", aKey, self);

	NSInteger k;

	for (k = 0; k < 2; ++k) {
		NSArray* array;
		NSMenu* raSub;
		id repObject;

		if (k == 0) {
			array = [mCatManagerRef recentlyAddedItems];
			raSub = [mRecentlyAddedMenuItemRef submenu];

			[mRecentlyAddedMenuItemRef setEnabled:[array count] > 0];
		} else {
			array = [mCatManagerRef recentlyUsedItems];
			raSub = [mRecentlyUsedMenuItemRef submenu];

			[mRecentlyUsedMenuItemRef setEnabled:[array count] > 0];
		}

		if (!mCategoriesOnly && raSub != nil) {
			// remove any menu items that are not present in the array

			NSArray* items = [[raSub itemArray] copy];
			NSEnumerator* iter = [items objectEnumerator];
			NSMenuItem* item;
			NSArray* allKeys;

			while ((item = [iter nextObject])) {
				allKeys = [mCatManagerRef keysForObject:[item representedObject]];

				// if there are no keys, the object can't be known to the cat mgr, so delete it from the menu now

				if ([allKeys count] < 1)
					[raSub removeItem:item];
				else {
					// still known, but may not be listed in the array

					NSString* kk = [allKeys lastObject];

					if (kk != nil && ![array containsObject:kk])
						[raSub removeItem:item];
				}
			}

			[items release];

			// add a new item for the newly added key if it's unknown in the menu

			if (aKey != nil && [array containsObject:aKey]) {
				repObject = [mCatManagerRef objectForKey:aKey];
				NSInteger indx = [raSub indexOfItemWithRepresentedObject:repObject];

				if (indx == -1) {
					NSMenuItem* childItem = [[NSMenuItem alloc] initWithTitle:[aKey capitalizedString]
																	   action:mSelector
																keyEquivalent:@""];

					[childItem setRepresentedObject:repObject];
					[childItem setTarget:mTargetRef];

					if (mCallbackTargetRef && [mCallbackTargetRef respondsToSelector:@selector(menuItem:
																						 wasAddedForObject:
																								inCategory:)])
						[mCallbackTargetRef menuItem:childItem
								   wasAddedForObject:repObject
										  inCategory:nil];

					// just added, so will always be first item in the list

					[childItem setTag:kDKCategoryManagerManagedMenuItemTag];
					[raSub insertItem:childItem
							  atIndex:0];
					[childItem release];
				}
			}
		}
	}
}

- (void)syncRecentlyUsedMenuForKey:(NSString*)aKey
{
	// the keyed item has moved to the front of the list - do the same for the associated menu item. This is the only
	// menu that requires this because all others can only have one object added or removed at a time, not moved within the same list.

	if (mCategoriesOnly)
		return;

	NSMenu* recentItemsMenu = [mRecentlyUsedMenuItemRef submenu];

	if (recentItemsMenu != nil) {
		id repObject = [mCatManagerRef objectForKey:aKey];
		NSInteger indx = [recentItemsMenu indexOfItemWithRepresentedObject:repObject];

		if (indx != -1) {
			NSMenuItem* item = [[recentItemsMenu itemAtIndex:indx] retain];
			[recentItemsMenu removeItem:item];
			[recentItemsMenu insertItem:item
								atIndex:0];
			[item release];
		}
	}
}

- (void)removeKey:(NSString*)aKey
{
	//NSLog(@"removing item key '%@' from menu %@", aKey, self );

	if (mCategoriesOnly)
		return;

	NSArray* cats = [mCatManagerRef categoriesContainingKey:aKey];
	NSEnumerator* iter = [cats objectEnumerator];
	NSString* cat;
	id repObject = [mCatManagerRef objectForKey:aKey];

	// iterate over the categories and find the menu responsible for it

	while ((cat = [iter nextObject])) {
		NSMenuItem* catItem = [mTheMenu itemWithTitle:[cat capitalizedString]];

		if (catItem != nil) {
			NSMenu* subMenu = [catItem submenu];

			if (subMenu != nil) {
				// this submenu contains the item, so delete the menu item that contains it. Because the item's
				// title may have been changed by the client, we use the represented object to discover the correct item.

				NSInteger indx = [subMenu indexOfItemWithRepresentedObject:repObject];

				if (indx != -1) {
					[subMenu removeItemAtIndex:indx];

					// if this leaves an entirely empty menu, delete it and disable the parent item

					if ([subMenu numberOfItems] == 0) {
						[catItem setSubmenu:nil];
						[catItem setEnabled:NO];
					}
				}
			}
		}
	}
}

- (void)checkItemsForKey:(NSString*)key
{
	// puts a checkmark against any category names in the menu that contain <key>.

	if (mCategoriesOnly)
		return;

	NSArray* categories = [mCatManagerRef categoriesContainingKey:key];

	// check whether there's really anything to do here:

	if ([categories count] > 1) {
		NSEnumerator* iter = [[mTheMenu itemArray] objectEnumerator];
		NSMenuItem* item;
		NSString* ti;

		while ((item = [iter nextObject])) {
			ti = [item title];

			if ([categories containsObject:ti])
				[item setState:NSOnState];
			else
				[item setState:NSOffState];
		}
	}
}

- (void)updateForKey:(NSString*)key
{
	// the object keyed by <key> has changed, so menu items pertaining to it need to be updated. The items involved are
	// not recreated or moved, they are simply passed to the client so that their titles, icons or whatever can be set
	// just as if the item was freshly created.

	if (mCategoriesOnly)
		return;

	NSAssert(key != nil, @"can't update - key was nil");
	LogEvent_(kInfoEvent, @"updating menu %@ for key '%@'", self, key);

	NSMutableArray* categories = [[mCatManagerRef categoriesContainingKey:key] mutableCopy];

	// add the recent items/added menus as if they were categories

	[categories addObject:NSLocalizedString(kDKRecentlyUsedUserString, @"")];
	[categories addObject:NSLocalizedString(kDKRecentlyAddedUserString, @"")];

	// check whether there's really anything to do here:

	id repObject = [mCatManagerRef objectForKey:key];
	NSEnumerator* iter = [categories objectEnumerator];
	NSString* catName;

	while ((catName = [iter nextObject])) {
		NSMenu* subMenu = [[mTheMenu itemWithTitle:[catName capitalizedString]] submenu];

		if (subMenu != nil) {
			NSInteger indx = [subMenu indexOfItemWithRepresentedObject:repObject];

			if (indx != -1) {
				NSMenuItem* item = [subMenu itemAtIndex:indx];

				// keep track of the title so that if it changes we can resort the menu

				NSString* oldTitle = [[item title] retain];

				if (mCallbackTargetRef && [mCallbackTargetRef respondsToSelector:@selector(menuItem:
																					 wasAddedForObject:
																							inCategory:)])
					[mCallbackTargetRef menuItem:item
							   wasAddedForObject:repObject
									  inCategory:catName];

				// if title changed, reposition the item

				if (![oldTitle isEqualToString:[item title]]) {
					// where to insert?

					NSArray* names = [mCatManagerRef allSortedNamesInCategory:catName];
					indx = [names indexOfObject:[item title]];

					if (indx != NSNotFound) {
						[item retain];
						[subMenu removeItem:item];
						[subMenu insertItem:item
									atIndex:indx];
						[item release];
					}
				}
				[oldTitle release];
			}
		}
	}

	[categories release];
}

- (void)removeAll
{
	// removes all managed items and submenus from the menu excluding the recent items

	[self removeItemsInMenu:mTheMenu
					withTag:kDKCategoryManagerManagedMenuItemTag
			 excludingItem0:(mOptions & kDKMenuIsPopUpMenu) != 0];

	// empty the recent items menus also
	if (mRecentlyUsedMenuItemRef != nil) {
		[self removeItemsInMenu:[mRecentlyUsedMenuItemRef submenu]
						withTag:kDKCategoryManagerManagedMenuItemTag
				 excludingItem0:NO];
		[mRecentlyUsedMenuItemRef setEnabled:NO];
	}

	if (mRecentlyAddedMenuItemRef != nil) {
		[self removeItemsInMenu:[mRecentlyAddedMenuItemRef submenu]
						withTag:kDKCategoryManagerManagedMenuItemTag
				 excludingItem0:NO];
		[mRecentlyAddedMenuItemRef setEnabled:NO];
	}
}

- (void)createMenu
{
	mTheMenu = [[NSMenu alloc] initWithTitle:@"Category Manager"];

	NSEnumerator* iter = [[mCatManagerRef allCategories] objectEnumerator];
	NSString* cat;
	NSArray* catObjects;
	NSMenuItem* parentItem;

	// don't use the menu item validation protocol - always enabled

	[mTheMenu setAutoenablesItems:NO];

	if ((mOptions & kDKMenuIsPopUpMenu) != 0) {
		// callback can check object == this to set the title of the popup (generally not needed - whoever called the CM
		// to make the menu in the first place is likely to be able to just set the menu or pop-up button's title afterwards).

		parentItem = [mTheMenu addItemWithTitle:@"Category Manager"
										 action:0
								  keyEquivalent:@""];

		if (mCallbackTargetRef && [mCallbackTargetRef respondsToSelector:@selector(menuItem:
																			 wasAddedForObject:
																					inCategory:)])
			[mCallbackTargetRef menuItem:parentItem
					   wasAddedForObject:self
							  inCategory:nil];
	}

	while ((cat = [iter nextObject])) {
		// if flagged to exclude "all items" then skip it

		if (((mOptions & kDKIncludeAllItems) == 0) && [cat isEqualToString:kDKDefaultCategoryName])
			continue;

		// always add a parent item for the category even if it turns out to be empty - this ensures that the menu UI
		// is consistent with other UI that may be just listing available categories.

		parentItem = [mTheMenu addItemWithTitle:[cat capitalizedString]
										 action:0
								  keyEquivalent:@""];
		[parentItem setTag:kDKCategoryManagerManagedMenuItemTag];

		// get the sorted list of items in the category

		catObjects = [mCatManagerRef allSortedKeysInCategory:cat];

		if ([catObjects count] > 0) {
			// make a submenu to list the actual items

			NSMenu* catMenu = [self createSubmenuWithTitle:[cat capitalizedString]
												  forArray:catObjects];
			[parentItem setSubmenu:catMenu];
			[parentItem setEnabled:YES];
		} else
			[parentItem setEnabled:NO];
	}

	// conditionally add "recently used" and "recently added" items

	if ((mOptions & (kDKIncludeRecentlyAddedItems | kDKIncludeRecentlyUsedItems)) != 0)
		[mTheMenu addItem:[NSMenuItem separatorItem]];

	NSString* title;
	NSMenu* subMenu;

	if ((mOptions & kDKIncludeRecentlyUsedItems) != 0) {
		title = NSLocalizedString(kDKRecentlyUsedUserString, @"");
		parentItem = [mTheMenu addItemWithTitle:title
										 action:0
								  keyEquivalent:@""];
		subMenu = [self createSubmenuWithTitle:title
									  forArray:[mCatManagerRef recentlyUsedItems]];

		[parentItem setTag:kDKCategoryManagerRecentMenuItemTag];
		[parentItem setSubmenu:subMenu];
		mRecentlyUsedMenuItemRef = parentItem;

		[mRecentlyUsedMenuItemRef setEnabled:[[mCatManagerRef recentlyUsedItems] count] > 0];
	}

	if ((mOptions & kDKIncludeRecentlyAddedItems) != 0) {
		title = NSLocalizedString(kDKRecentlyAddedUserString, @"");
		parentItem = [mTheMenu addItemWithTitle:title
										 action:0
								  keyEquivalent:@""];
		subMenu = [self createSubmenuWithTitle:title
									  forArray:[mCatManagerRef recentlyAddedItems]];

		[parentItem setTag:kDKCategoryManagerRecentMenuItemTag];
		[parentItem setSubmenu:subMenu];
		mRecentlyAddedMenuItemRef = parentItem;

		[mRecentlyAddedMenuItemRef setEnabled:[[mCatManagerRef recentlyAddedItems] count] > 0];
	}
}

- (void)createCategoriesMenu
{
	mTheMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Categories", @"default name for categories menu")];
	NSMenuItem* ti = nil;

	// add standard items according to options

	if (mOptions & kDKIncludeAllItems) {
		ti = [mTheMenu addItemWithTitle:kDKDefaultCategoryName
								 action:mSelector
						  keyEquivalent:@""];
		[ti setTarget:mTargetRef];
		[ti setTag:kDKCategoryManagerManagedMenuItemTag];
	}

	if (mOptions & kDKIncludeRecentlyAddedItems) {
		mRecentlyAddedMenuItemRef = [mTheMenu addItemWithTitle:kDKRecentlyAddedUserString
														action:mSelector
												 keyEquivalent:@""];
		[mRecentlyAddedMenuItemRef setTarget:mTargetRef];
		[mRecentlyAddedMenuItemRef setTag:kDKCategoryManagerRecentMenuItemTag];
	}

	if (mOptions & kDKIncludeRecentlyUsedItems) {
		mRecentlyUsedMenuItemRef = [mTheMenu addItemWithTitle:kDKRecentlyUsedUserString
													   action:mSelector
												keyEquivalent:@""];
		[mRecentlyUsedMenuItemRef setTarget:mTargetRef];
		[mRecentlyUsedMenuItemRef setTag:kDKCategoryManagerRecentMenuItemTag];
	}

	if ((mOptions & kDKDontAddDividingLine) == 0)
		[mTheMenu addItem:[NSMenuItem separatorItem]];

	// now just list the categories

	NSEnumerator* iter = [[mCatManagerRef allCategories] objectEnumerator]; // already sorted alphabetically
	NSString* cat;

	while ((cat = [iter nextObject])) {
		if (![cat isEqualToString:kDKDefaultCategoryName]) {
			ti = [mTheMenu addItemWithTitle:cat
									 action:mSelector
							  keyEquivalent:@""];
			[ti setTarget:mTargetRef];
			[ti setTag:kDKCategoryManagerManagedMenuItemTag];
			[ti setEnabled:YES];
		}
	}
}

- (NSMenu*)createSubmenuWithTitle:(NSString*)title forArray:(NSArray*)items
{
	// given an array of keys, this creates a menu listing the items. The delegate is called if present to finalise each item. The intended use for this
	// is to set up the "recently used" and "recently added" menus initially. If the array is empty returns an empty menu.

	NSAssert(items != nil, @"can't create menu for nil array");

	NSMenu* theMenu;
	NSEnumerator* iter;
	NSString* key;

	iter = [items objectEnumerator];

	theMenu = [[NSMenu alloc] initWithTitle:title];

	id repObject;

	while ((key = [iter nextObject])) {
		NSMenuItem* childItem = [theMenu addItemWithTitle:[key capitalizedString]
												   action:mSelector
											keyEquivalent:@""];
		[childItem setTarget:mTargetRef];
		repObject = [mCatManagerRef objectForKey:key];
		[childItem setRepresentedObject:repObject];

		if (mCallbackTargetRef && [mCallbackTargetRef respondsToSelector:@selector(menuItem:
																			 wasAddedForObject:
																					inCategory:)])
			[mCallbackTargetRef menuItem:childItem
					   wasAddedForObject:repObject
							  inCategory:nil];

		[childItem setTag:kDKCategoryManagerManagedMenuItemTag];
	}

	return [theMenu autorelease];
}

- (void)dealloc
{
	[mTheMenu release];
	[super dealloc];
}

#pragma mark -

- (void)removeItemsInMenu:(NSMenu*)aMenu withTag:(NSInteger)tag excludingItem0:(BOOL)title
{
	NSMutableArray* items = [[aMenu itemArray] mutableCopy];
	NSMenuItem* item;

	NSLog(@"menu items = %@", items);

	// if a pop-up menu, don't remove the title item

	if (title)
		[items removeObjectAtIndex:0];

	NSEnumerator* iter = [items reverseObjectEnumerator];

	while ((item = [iter nextObject])) {
		if ([item tag] == tag)
			[aMenu removeItem:item];
	}

	[items release];
}

@end
