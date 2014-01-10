/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

// menu creation options:

typedef enum {
    kDKIncludeRecentlyAddedItems = (1 << 0),
    kDKIncludeRecentlyUsedItems = (1 << 1),
    kDKIncludeAllItems = (1 << 2),
    kDKDontAddDividingLine = (1 << 3),
    kDKMenuIsPopUpMenu = (1 << 4)
} DKCategoryMenuOptions;

typedef enum {
    kDKReplaceExisting = (1 << 1), // objects passed in replace those with the same key (doc -> reg)
    kDKReturnExisting = (1 << 2), // objects in reg with the same keys are returned (reg -> doc)
    kDKAddAsNewVersions = (1 << 3) // objects with the same keys are copied and registered again (reg || doc)
} DKCatManagerMergeOptions;

// the class

/** @brief The cat manager supports a UI based on menu(s).

 The cat manager supports a UI based on menu(s). To assist, the DKCategoryManagerMenuInfo class is used to "own" a menu - the cat manager keeps a list of these.

 When the CM is asked for a menu, this helper object is used to create and manage it. As the CM is used (items and categories added/removed) the menu helpers are
 informed of the changes and in turn update the menus to match by adding or deleting menu items. This is necessary because when the CM grows to a significant number
 of items, rebuilding the menus is very time-consuming. This way performance is much better.
*/
@interface DKCategoryManager : NSObject <NSCoding, NSCopying> {
@private
    NSMutableDictionary* m_masterList;
    NSMutableDictionary* m_categories;
    NSMutableArray* m_recentlyAdded;
    NSMutableArray* m_recentlyUsed;
    NSUInteger m_maxRecentlyAddedItems;
    NSUInteger m_maxRecentlyUsedItems;
    NSMutableArray* mMenusList;
    BOOL mRecentlyAddedEnabled;
}

/** @brief Returns a new category manager object

 Convenience method. Initial categories only consist of "All Items"
 @return a category manager object
 */
+ (DKCategoryManager*)categoryManager;

/** @brief Returns a new category manager object based on an existing dictionary

 Convenience method. Initial categories only consist of "All Items"
 @param dict an existign dictionary
 @return a category manager object
 */
+ (DKCategoryManager*)categoryManagerWithDictionary:(NSDictionary*)dict;

/** @brief Return the default categories defined for this class
 @return an array of categories */
+ (NSArray*)defaultCategories;

/** @brief Given an object, return a key that can be used to store it in the category manager.

 Subclasses will need to define this differently - used for merging.
 @param obj an object
 @return a key string */
+ (NSString*)categoryManagerKeyForObject:(id)obj;

+ (id)dearchivingHelper;
+ (void)setDearchivingHelper:(id)helper;

// initialization

/** @brief Initialized a category manager object from archive data

 Data is permitted also to be an archived dictionary
 @param data data containing a correctly archived category manager
 @return the category manager object
 */
- (id)initWithData:(NSData*)data;

/** @brief Initialized a category manager object from an existing dictionary

 No categories other than "All Items" are created by default. The recently added list is empty.
 @param dict dictionary containing a set of objects and keys
 @return the category manager object
 */
- (id)initWithDictionary:(NSDictionary*)dict;

// adding and retrieving objects

/** @brief Add an object to the container, associating with a key and optionally a category.

 <obj> and <name> cannot be nil. All objects are added to the default category regardless of <catName>
 @param obj the object to add
 @param name the object's key
 @param catName the name of the category to add it to, or nil for defaults only
 @param cg YES to create the category if it doesn't exist. NO not to do so
 */
- (void)addObject:(id)obj forKey:(NSString*)name toCategory:(NSString*)catName createCategory:(BOOL)cg;

/** @brief Add an object to the container, associating with a key and optionally a number of categories.

 <obj> and <name> cannot be nil. All objects are added to the default category regardless of <catNames>
 @param obj the object to add
 @param name the object's key
 @param catNames the names of the categories to add it to, or nil for defaults
 @param cg YES to create the categories if they don't exist. NO not to do so
 */
- (void)addObject:(id)obj forKey:(NSString*)name toCategories:(NSArray*)catNames createCategories:(BOOL)cg;

/** @brief Remove an object from the container

 After this the key will not be found in any category or either list
 @param key the object's key
 */
- (void)removeObjectForKey:(NSString*)key;

/** @brief Remove multiple objects from the container

 After this no keys will not be found in any category or either list
 @param keys a list of keys
 */
- (void)removeObjectsForKeys:(NSArray*)keys;

/** @brief Removes all objects from the container

 Does not remove the categories, but leaves them all empty.
 */
- (void)removeAllObjects;

- (BOOL)containsKey:(NSString*)name;

/** @brief Return total number of stored objects in container
 @return the number of objects
 */
- (NSUInteger)count;

/** @brief Return the object for the given key, but do not remember it in the "recently used" list
 @param key the object's key
 @return the object if available, else nil
 */
- (id)objectForKey:(NSString*)key;

/** @brief Return the object for the given key, optionally remembering it in the "recently used" list

 Use this method when you wish this access of the object to result in it being added to "recently used"
 @param key the object's key
 @param add if YES, object's key is added to recently used items
 @return the object if available, else nil
 */
- (id)objectForKey:(NSString*)key addToRecentlyUsedItems:(BOOL)add;

/** @brief Returns a list of all unique keys that refer to the given object

 The result may contain no keys if the object is unknown
 @param obj the object
 @return an array, listing all the unique keys that refer to the object.
 */
- (NSArray*)keysForObject:(id)obj;

/** @brief Return a copy of the master dictionary
 @return the main dictionary
 */
- (NSDictionary*)dictionary;

// smartly merging objects:

/** @brief Smartly merges objects into the category manager
 @param aSet a set of objects of the same kind as the current contents
 @param categories an optional list of categories to add th eobjects to. Categories will be created if needed.
 @param options replacxement options. Delegate may override these.
 @param adelegate an optional delegate that can be asked to make decisions about which objects get replaced.
 @return a set, possibly empty. The set contains those objects that already existed in the CM that should replace
 equivalent items in the supplied set.
 */
- (NSSet*)mergeObjectsFromSet:(NSSet*)aSet inCategories:(NSArray*)categories mergeOptions:(DKCatManagerMergeOptions)options mergeDelegate:(id)aDelegate;

/** @brief Asks delegate to make decision about the merging of an object

 Subclasses must override this to make use of it. Returning nil means use existing object.
 @param obj the object to consider
 @param aDelegate the delegate to ask
 @return an equivalent object or nil. May be the supplied object or another having an identical ID.
 */
- (id)mergeObject:(id)obj mergeDelegate:(id)aDelegate;

// retrieving lists of objects by category

/** @brief Return all of the objects belonging to a given category

 Returned objects are in no particular order, but do match the key order obtained by
 -allkeysInCategory. Should any key not exist (which should never normally occur), the entry will
 be represented by a NSNull object
 @param catName the category name
 @return an array, the list of objects indicated by the category. May be empty.
 */
- (NSArray*)objectsInCategory:(NSString*)catName;

/** @brief Return all of the objects belonging to the given categories

 Returned objects are in no particular order, but do match the key order obtained by
 -allKeysInCategories:. Should any key not exist (which should never normally occur), the entry will
 be represented by a NSNull object
 @param catNames list of categories
 @return an array, the list of objects indicated by the categories. May be empty.
 */
- (NSArray*)objectsInCategories:(NSArray*)catNames;

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
- (NSArray*)allKeysInCategory:(NSString*)catName;

/** @brief Return all of the keys in all given categories

 Returned objects are in no particular order.
 @param catNames an array of category names
 @return an array, the union of keys in listed categories. May be empty.
 */
- (NSArray*)allKeysInCategories:(NSArray*)catNames;
- (NSArray*)allKeys;

/** @brief Return all of the objects
 @return an array, all objects (listed only once, in arbitrary order)
 */
- (NSArray*)allObjects;

/** @brief Return all of the keys in a given category, sorted into some useful order

 By default the keys are sorted alphabetically. The UI-building methods call this, so a subclass
 can override it and return keys sorted by some other criteria if required.
 @param catName the category name
 @return an array, the list of keys indicated by the category. May be empty.
 */
- (NSArray*)allSortedKeysInCategory:(NSString*)catName;

/** @brief Return all of the names in a given category, sorted into some useful order

 For an ordinary DKCategoryManager, names == keys. However, subclasses may store keys in some other
 fashion (hint: they do) and so another method is needed to convert keys to names. Those subclasses
 must override this and do what's appropriate.
 @param catName the category name
 @return an array, the list of names indicated by the category. May be empty.
 */
- (NSArray*)allSortedNamesInCategory:(NSString*)catName;

/** @brief Replaces the recently added items with new items, up to the current max.
 @param array an array of suitable objects
 */
- (void)setRecentlyAddedItems:(NSArray*)array;

/** @brief Return the list of recently added items

 Returned objects are in order of addition, most recent first.
 @return an array, the list of keys recently added.
 */
- (NSArray*)recentlyAddedItems;

/** @brief Return the list of recently used items

 Returned objects are in order of use, most recent first.
 @return an array, the list of keys recently used.
 */
- (NSArray*)recentlyUsedItems;

// category management - creating, deleting and renaming categories

/** @brief Add the default categories defined for this class or object

 Is called as part of the initialisation of the CM object
 */
- (void)addDefaultCategories;

/** @brief Return the default categories defined for this class or object
 @return an array of categories
 */
- (NSArray*)defaultCategories;

/** @brief Create a new category with the given name

 If the name is already a category name, this does nothing
 @param catName the name of the new category */
- (void)addCategory:(NSString*)catName;

/** @brief Create a new categories with the given names
 @param catNames a list of the names of the new categories */
- (void)addCategories:(NSArray*)catNames;

/** @brief Remove a category with the given name

 The objects listed in the category are not removed, as they may also be listed by other categories.
 If they are not, they can become orphaned however. To avoid this, never delete the "All Items"
 category.
 @param catName the category to remove
 */
- (void)removeCategory:(NSString*)catName;

/** @brief Change a category's name

 If <newname> already exists, it will be replaced by the entries in <catname>
 @param catName the category's old name
 @param newname the category's new name
 */
- (void)renameCategory:(NSString*)catName to:(NSString*)newname;

/** @brief Removes all categories and objects from the CM.

 After this the CM is entirely empty.
 */
- (void)removeAllCategories;

/** @brief Adds a new key to a category, optionally creating it if necessary
 @param key the key to add
 @param catName the category to add it to
 @param cg YES to create the category if it doesn't exist, NO otherwise */
- (void)addKey:(NSString*)key toCategory:(NSString*)catName createCategory:(BOOL)cg;

/** @brief Adds a new key to several categories, optionally creating any if necessary
 @param key the key to add
 @param catNames a list of categories to add it to
 @param cg YES to create the category if it doesn't exist, NO otherwise */
- (void)addKey:(NSString*)key toCategories:(NSArray*)catNames createCategories:(BOOL)cg;

/** @brief Removes a key from a category
 @param key the key to remove
 @param catName the category to remove it from */
- (void)removeKey:(NSString*)key fromCategory:(NSString*)catName;

/** @brief Removes a key from a number of categories
 @param key the key to remove
 @param catNames the list of categories to remove it from */
- (void)removeKey:(NSString*)key fromCategories:(NSArray*)catNames;

/** @brief Removes a key from all categories
 @param key the key to remove */
- (void)removeKeyFromAllCategories:(NSString*)key;

/** @brief Checks that all keys refer to real objects, removing any that do not

 Rarely needed, but can correct for corrupted registries where objects got removed but not all
 keys that refer to it did for some reason (such as an exception). */
- (void)fixUpCategories;

/** @brief Renames an object's key throughout

 If <key> doesn't exist, or if <newkey> already exists, throws an exception. After this the same
 object that could be located using <key> can be located using <newKey> in the same categories as
 it appeared in originally.
 @param key the existing key
 @param newKey the new key
 */
- (void)renameKey:(NSString*)key to:(NSString*)newKey;

// getting lists, etc. of the categories

/** @brief Get a list of all categories

 The list is alphabetically sorted for the convenience of a user interface
 @return an array containg a list of all category names
 */
- (NSArray*)allCategories;

/** @brief Get the count of all categories
 @return the number of categories currently defined
 */
- (NSUInteger)countOfCategories;

/** @brief Get a list of all categories that contain a given key

 The list is alphabetically sorted for the convenience of a user interface
 @param key the key in question
 @return an array containing a list of categories which contain the key
 */
- (NSArray*)categoriesContainingKey:(NSString*)key;
- (NSArray*)categoriesContainingKey:(NSString*)key withSorting:(BOOL)sortIt;

/** @brief Get a list of reserved categories - those that should not be deleted or renamed

 This list is advisory - a UI is responsible for honouring it, the cat manager itself ignores it.
 The default implementation returns the same as the default categories, thus reserving all
 default cats. Subclasses can change this as they wish.
 @return an array containing a list of the reserved categories 
 */
- (NSArray*)reservedCategories;

/** @brief Test whether there is a category of the given name
 @param catName the category name
 @return YES if a category exists with the name, NO otherwise
 */
- (BOOL)categoryExists:(NSString*)catName;

/** @brief Count how many objects in the category of the given name
 @param catName the category name
 @return the number of objects in the category
 */
- (NSUInteger)countOfObjectsInCategory:(NSString*)catName;

/** @brief Query whether a given key is present in a particular category
 @param key the key
 @param catName the category name
 @return YES if the category contains <key>, NO if it doesn't
 */
- (BOOL)key:(NSString*)key existsInCategory:(NSString*)catName;

// managing recent lists

/** @brief Set whether the "recent;y added" list accepts new items or not

 This allows the recently added items to be temporarily disabled when bulk adding items to the
 manager. By default the recently added items list is enabled.
 @param enable YES to allow new items to be added, NO otherwise
 */
- (void)setRecentlyAddedListEnabled:(BOOL)enable;

/** @brief Add a key to one of the 'recent' lists

 Acceptable list IDs are kDKListRecentlyAdded and kDKListRecentlyUsed
 @param key the key to add
 @param whichList an identifier for the list in question
 @return return YES if the key was added, otherwise NO (i.e. if list already contains item) */
- (BOOL)addKey:(NSString*)key toRecentList:(NSInteger)whichList;

/** @brief Remove a key from one of the 'recent' lists

 Acceptable list IDs are kDKListRecentlyAdded and kDKListRecentlyUsed
 @param key the key to remove
 @param whichList an identifier for the list in question */
- (void)removeKey:(NSString*)key fromRecentList:(NSInteger)whichList;

/** @brief Sets the maximum length of on eof the 'recent' lists

 Acceptable list IDs are kDKListRecentlyAdded and kDKListRecentlyUsed
 @param whichList an identifier for the list in question
 @param max the maximum length to which a list may grow */
- (void)setRecentList:(NSInteger)whichList maxItems:(NSUInteger)max;

// archiving

/** @brief Archives the container to a data object (for saving, etc)
 @return a data object, the archive of the container
 */
- (NSData*)data;
- (NSData*)dataWithFormat:(NSPropertyListFormat)format;

/** @brief Return the filetype (for saving, etc)

 Subclasses should override to change the filetype used for specific examples of this object
 */
- (NSString*)fileType;

/** @brief Discard all existing content, then reload from the archive data passed
 @param data data, being an archive earlier obtained using -data
 @return YES if the archive could be read, NO otherwise
 */
- (BOOL)replaceContentsWithData:(NSData*)data;

/** @brief Retain all existing content, and load additional content from the archive data passed

 Because at this level DKCategoryManager has no knowledge of the objects it is storing, it has no
 means to be smart about merging objects that are the same in some higher abstract way. Thus it's
 entirely possible to end up with multiple copies of the "same" object after this operation.
 Subclasses may prefer to do something smarter.
 Note however that duplicate categories are not created.
 @param data data, being an archive earlier obtained using -data
 @return YES if the archive could be read, NO otherwise
 */
- (BOOL)appendContentsWithData:(NSData*)data;

/** @brief Retain all existing content, and load additional content from the cat manager passed

 Categories not present in the receiver but exist in <cm> are created, and objects present in <cm>
 are added to the receiver if not already present (as determined solely by address). This method
 disables the "recently added" list while it adds the items.
 @param cm a category manager object
 */
- (void)copyItemsFromCategoryManager:(DKCategoryManager*)cm;

// supporting UI:
// menus of just the categories:

/** @brief Creates a menu of categories, recent items and All Items

 Sel and target may be nil
 @param sel the selector which is set as the action for each added item
 @param target the target of category item actions
 @return a menu populated with category and other names
 */
- (NSMenu*)categoriesMenuWithSelector:(SEL)sel target:(id)target;

/** @brief Creates a menu of categories, recent items and All Items

 Sel and target may be nil, options may be 0
 @param sel the selector which is set as the action for each category item
 @param target the target of category item actions
 @param options various flags which set which items are added
 @return a menu populated with category and other names
 */
- (NSMenu*)categoriesMenuWithSelector:(SEL)sel target:(id)target options:(NSInteger)options;

/** @brief Sets the checkmarks in a menu of category names to reflect the presence of <key> in those categories

 Assumes that item names will be the category names. For localized names, you should handle the
 localization external to this class so that both category names and menu items use the same strings.
 @param menu the menu to examine
 @param key the key to test against
 */
- (void)checkItemsInMenu:(NSMenu*)menu forCategoriesContainingKey:(NSString*)key;

// a menu with everything, organised hierarchically by category. Delegate is called for each new item - see protocol below

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
- (NSMenu*)createMenuWithItemDelegate:(id)del isPopUpMenu:(BOOL)isPopUp;
- (NSMenu*)createMenuWithItemDelegate:(id)del options:(DKCategoryMenuOptions)options;
- (NSMenu*)createMenuWithItemDelegate:(id)del itemTarget:(id)target itemAction:(SEL)action options:(DKCategoryMenuOptions)options;

/** @brief Removes the menu from the list of managed menus

 An object using a menu created by the category manager must remove it from management when it is
 no longer needed as a stale reference can cause a crash.
 @param menu a menu managed by this object
 */
- (void)removeMenu:(NSMenu*)menu;

/** @brief Synchronises the menus to reflect any change of the object referenced by <key>

 Any change to a stored object that affects the menus' appearance can be handled by calling this.
 this only changes the menu items that represent the object, and not the entire menu, so is an
 efficient way to keep menus up to date with changes.
 @param key an object's key
 */
- (void)updateMenusForKey:(NSString*)key;

@end

// various constants:

enum {
    kDKDefaultMaxRecentArraySize = 20,
    kDKListRecentlyAdded = 0,
    kDKListRecentlyUsed = 1
};

// standard name for "All items" category:

extern NSString* kDKDefaultCategoryName;

extern NSString* kDKRecentlyAddedUserString;
extern NSString* kDKRecentlyUsedUserString;

extern NSString* kDKCategoryManagerWillAddObject;
extern NSString* kDKCategoryManagerDidAddObject;
extern NSString* kDKCategoryManagerWillRemoveObject;
extern NSString* kDKCategoryManagerDidRemoveObject;
extern NSString* kDKCategoryManagerDidRenameCategory;
extern NSString* kDKCategoryManagerWillAddKeyToCategory;
extern NSString* kDKCategoryManagerDidAddKeyToCategory;
extern NSString* kDKCategoryManagerWillRemoveKeyFromCategory;
extern NSString* kDKCategoryManagerDidRemoveKeyFromCategory;
extern NSString* kDKCategoryManagerWillCreateNewCategory;
extern NSString* kDKCategoryManagerDidCreateNewCategory;
extern NSString* kDKCategoryManagerWillDeleteCategory;
extern NSString* kDKCategoryManagerDidDeleteCategory;

/*

This is a useful container class that is like a "super dictionary" or maybe a "micro-database". As well as storing an object using a key,
it allows the object to be associated with none, one or more categories. An object can be a member of any number of categories.

As objects are added and used, they are automatically tracked in a "recently added" and "recently used" list, which can be retreived at any time.

As with a dictionary, an object is associated with a key. In addition to storing the object against that key, the key is added to the categories
that the object is a member of. This facilitates category-oriented lookups of objects.

*/

// informal protocol used by the createMenuWithItemDelegate method:

@interface NSObject (CategoryManagerMenuItemDelegate)

- (void)menuItem:(NSMenuItem*)item wasAddedForObject:(id)object inCategory:(NSString*)category;

@end

// delegate informal protocol allows the delegate to decide which of a pair of objects should be used when merging

@interface NSObject (categoryManagerMergeDelegate)

- (id)categoryManager:(DKCategoryManager*)cm shouldReplaceObject:(id)regObject withObject:(id)docObject;

@end

/** @brief private object used to store menu info - allows efficient management of the menu to match the C/Mgrs contents.

 Menu creation and management is moved to this class, but API in Cat Manager functions as previously.
 */
@interface DKCategoryManagerMenuInfo : NSObject {
@private
    DKCategoryManager* mCatManagerRef; // the category manager that owns this
    NSMenu* mTheMenu; // the menu being managed
    id mTargetRef; // initial target for new menu items
    id mCallbackTargetRef; // delegate for menu items
    SEL mSelector; // initial action for new menu items
    DKCategoryMenuOptions mOptions; // option flags
    BOOL mCategoriesOnly; // YES if the menu just lists the categories and not the category contents
    NSMenuItem* mRecentlyUsedMenuItemRef; // the menu item for "recently used"
    NSMenuItem* mRecentlyAddedMenuItemRef; // the menu item for "recently added"
}

- (id)initWithCategoryManager:(DKCategoryManager*)mgr itemTarget:(id)target itemAction:(SEL)selector options:(DKCategoryMenuOptions)options;
- (id)initWithCategoryManager:(DKCategoryManager*)mgr itemDelegate:(id)delegate options:(DKCategoryMenuOptions)options;
- (id)initWithCategoryManager:(DKCategoryManager*)mgr itemDelegate:(id)delegate itemTarget:(id)target itemAction:(SEL)selector options:(DKCategoryMenuOptions)options;

- (NSMenu*)menu;

- (void)addCategory:(NSString*)newCategory;
- (void)removeCategory:(NSString*)oldCategory;
- (void)renameCategoryWithInfo:(NSDictionary*)info;
- (void)addKey:(NSString*)aKey;
- (void)addRecentlyAddedOrUsedKey:(NSString*)aKey;
- (void)syncRecentlyUsedMenuForKey:(NSString*)aKey;
- (void)removeKey:(NSString*)aKey;
- (void)checkItemsForKey:(NSString*)key;
- (void)updateForKey:(NSString*)key;
- (void)removeAll;

@end

// this tag is set in every menu item that we create/manage automatically. Normally client code of the menus shouldn't use the tags of these items but instead the represented object,
// so this tag identifies items that we can freely discard or modify. Any others are left alone, allowing clients to add other items to the menus that won't get disturbed.

enum {
    kDKCategoryManagerManagedMenuItemTag = -42,
    kDKCategoryManagerRecentMenuItemTag = -43
};
