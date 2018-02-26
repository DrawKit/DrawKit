/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class DKCategoryManagerMenuInfo;
@protocol DKCategoryManagerMergeDelegate;
@protocol DKCategoryManagerMenuItemDelegate;

typedef NSString* DKCategoryName NS_EXTENSIBLE_STRING_ENUM;

// menu creation options:
typedef NS_OPTIONS(NSUInteger, DKCategoryMenuOptions) {
	kDKIncludeRecentlyAddedItems = (1 << 0),
	kDKIncludeRecentlyUsedItems = (1 << 1),
	kDKIncludeAllItems = (1 << 2),
	kDKDontAddDividingLine = (1 << 3),
	kDKMenuIsPopUpMenu = (1 << 4)
};

typedef NS_OPTIONS(NSUInteger, DKCatManagerMergeOptions) {
	kDKReplaceExisting = (1 << 1), //!< objects passed in replace those with the same key (doc -> reg)
	kDKReturnExisting = (1 << 2), //!< objects in reg with the same keys are returned (reg -> doc)
	kDKAddAsNewVersions = (1 << 3) //!< objects with the same keys are copied and registered again (reg || doc)
};

// the class

/** @brief The cat manager supports a UI based on menu(s).

 The cat manager supports a UI based on menu(s). To assist, the \c DKCategoryManagerMenuInfo class is used to "own" a menu - the cat manager keeps a list of these.

 When the CM is asked for a menu, this helper object is used to create and manage it. As the CM is used (items and categories added/removed) the menu helpers are
 informed of the changes and in turn update the menus to match by adding or deleting menu items. This is necessary because when the CM grows to a significant number
 of items, rebuilding the menus is very time-consuming. This way performance is much better.
*/
@interface DKCategoryManager <__covariant ObjectType> : NSObject <NSCoding, NSCopying>
{
@private
	NSMutableDictionary<NSString*, ObjectType>* m_masterList;
	NSMutableDictionary<DKCategoryName, NSMutableArray<ObjectType>*>* m_categories;
	NSMutableArray<ObjectType>* m_recentlyAdded;
	NSMutableArray<ObjectType>* m_recentlyUsed;
	NSUInteger m_maxRecentlyAddedItems;
	NSUInteger m_maxRecentlyUsedItems;
	NSMutableArray<DKCategoryManagerMenuInfo*>* mMenusList;
	BOOL mRecentlyAddedEnabled;
}

/** @brief Returns a new category manager object

 Convenience method. Initial categories only consist of "All Items"
 @return A category manager object.
 */
@property (class, readonly, strong) DKCategoryManager* categoryManager;

/** @brief Returns a new category manager object based on an existing dictionary

 Convenience method. Initial categories only consist of "All Items"
 @param dict An existign dictionary.
 @return A category manager object.
 */
+ (DKCategoryManager<ObjectType>*)categoryManagerWithDictionary:(NSDictionary<NSString*, ObjectType>*)dict;

/** @brief Return the default categories defined for this class.
 @return an array of categories */
@property (class, readonly, copy) NSArray<DKCategoryName>* defaultCategories;

/** @brief Given an object, return a key that can be used to store it in the category manager.

 Subclasses will need to define this differently - used for merging.
 @param obj An object.
 @return A key string. */
+ (nullable NSString*)categoryManagerKeyForObject:(ObjectType)obj;

@property (class, retain, null_resettable) id dearchivingHelper;

/** @name initialization
 @{ */

/** @brief Initialized a category manager object from archive data.

 Data is permitted also to be an archived dictionary.
 @param data Data containing a correctly archived category manager.
 @return The category manager object.
 */
- (instancetype)initWithData:(NSData*)data;

/** @brief Initialized a category manager object from an existing dictionary.

 No categories other than "All Items" are created by default. The recently added list is empty.
 @param dict Dictionary containing a set of objects and keys.
 @return The category manager object.
 */
- (instancetype)initWithDictionary:(NSDictionary<NSString*, ObjectType>*)dict;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder*)aDecoder NS_DESIGNATED_INITIALIZER;

/** @}
 @name adding and retrieving objects
 @{ */

/** @brief Add an object to the container, associating with a key and optionally a category.

 \c obj and \c name cannot be <code>nil</code>. All objects are added to the default category regardless of \c catName
 @param obj The object to add.
 @param name The object's key.
 @param catName The name of the category to add it to, or \c nil for defaults only.
 @param cg \c YES to create the category if it doesn't exist. \c NO not to do so.
 */
- (void)addObject:(ObjectType)obj forKey:(NSString*)name toCategory:(nullable DKCategoryName)catName createCategory:(BOOL)cg;

/** @brief Add an object to the container, associating with a key and optionally a number of categories.

 \c obj and \c name cannot be <code>nil</code>. All objects are added to the default category regardless of \c catNames
 @param obj The object to add.
 @param name The object's key.
 @param catNames The names of the categories to add it to, or \c nil for defaults.
 @param cg \c YES to create the categories if they don't exist. \c NO not to do so.
 */
- (void)addObject:(ObjectType)obj forKey:(NSString*)name toCategories:(nullable NSArray<DKCategoryName>*)catNames createCategories:(BOOL)cg;

/** @brief Remove an object from the container.

 After this, the key will not be found in any category or either list.
 @param key The object's key.
 */
- (void)removeObjectForKey:(NSString*)key;

/** @brief Remove multiple objects from the container.

 After this, the keys will not be found in any category or either list.
 @param keys A list of keys.
 */
- (void)removeObjectsForKeys:(NSArray<NSString*>*)keys;

/** @brief Removes all objects from the container.

 Does not remove the categories, but leaves them all empty.
 */
- (void)removeAllObjects;

/** @brief Test whether the key is known to the container.
 @param name The object's key.
 @return \c YES if known, \c NO if not.
 */
- (BOOL)containsKey:(NSString*)name;

/** @brief Return total number of stored objects in container.
 */
@property (readonly) NSUInteger count;

/** @brief Return the object for the given key, but do not remember it in the "recently used" list.
 @param key The object's key.
 @return The object if available, else <code>nil</code>.
 */
- (nullable ObjectType)objectForKey:(NSString*)key;

/** @brief Return the object for the given key, optionally remembering it in the "recently used" list.

 Use this method when you wish this access of the object to result in it being added to "recently used".
 @param key The object's key.
 @param add If <code>YES</code>, object's key is added to recently used items.
 @return The object if available, else <code>nil</code>.
 */
- (nullable ObjectType)objectForKey:(NSString*)key addToRecentlyUsedItems:(BOOL)add;

/** @brief Returns a list of all unique keys that refer to the given object.

 The result may contain no keys if the object is unknown.
 @param obj The object.
 @return An array, listing all the unique keys that refer to the object.
 */
- (NSArray<NSString*>*)keysForObject:(ObjectType)obj;

/** @brief Return a copy of the master dictionary.
 */
@property (readonly, copy) NSDictionary<NSString*, ObjectType>* dictionary;

/** @}
 @name Smartly Merging Objects
 @{ */

/** @brief Smartly merges objects into the category manager.
 @param aSet A set of objects of the same kind as the current contents.
 @param categories An optional list of categories to add th eobjects to. Categories will be created if needed.
 @param options Replacement options. Delegate may override these.
 @param aDelegate An optional delegate that can be asked to make decisions about which objects get replaced.
 @return A set, possibly empty. The set contains those objects that already existed in the CM that should replace
 equivalent items in the supplied set.
 */
- (nullable NSSet<ObjectType>*)mergeObjectsFromSet:(NSSet<ObjectType>*)aSet inCategories:(NSArray<DKCategoryName>*)categories mergeOptions:(DKCatManagerMergeOptions)options mergeDelegate:(nullable id<DKCategoryManagerMergeDelegate>)aDelegate;

/** @brief Asks delegate to make decision about the merging of an object.

 Subclasses must override this to make use of it. Returning \c nil means use existing object.
 @param obj The object to consider.
 @param aDelegate The delegate to ask.
 @return an equivalent object or nil. May be the supplied object or another having an identical ID.
 */
- (nullable ObjectType)mergeObject:(ObjectType)obj mergeDelegate:(nullable id<DKCategoryManagerMergeDelegate>)aDelegate;

/** @}
 @brief Retrieving lists of objects by category.
 @{ */

/** @brief Return all of the objects belonging to a given category.

 Returned objects are in no particular order, but do match the key order obtained by
 <code>-allkeysInCategory:</code>. Should any key not exist (which should never normally occur), the entry will
 be represented by an \c NSNull object.
 @param catName The category name.
 @return An array, the list of objects indicated by the category. May be empty.
 */
- (NSArray<ObjectType>*)objectsInCategory:(DKCategoryName)catName NS_REFINED_FOR_SWIFT;

/** @brief Return all of the objects belonging to the given categories.

 Returned objects are in no particular order, but do match the key order obtained by
 <code>-allKeysInCategories:</code>. Should any key not exist (which should never normally occur), the entry will
 be represented by an \c NSNull object.
 @param catNames List of categories.
 @return An array, the list of objects indicated by the categories. May be empty.
 */
- (NSArray<ObjectType>*)objectsInCategories:(NSArray<DKCategoryName>*)catNames NS_REFINED_FOR_SWIFT;

/** @brief Return all of the keys in a given category.

 Returned objects are in no particular order. This also treats the "recently used" and "recently added"
 items as pseudo-category names, returning these arrays if the catName matches.
 @param catName The category name.
 @return An array, the list of keys indicated by the category. May be empty.
 */
- (NSArray<NSString*>*)allKeysInCategory:(DKCategoryName)catName;

/** @brief Return all of the keys in all given categories.

 Returned objects are in no particular order.
 @param catNames An array of category names.
 @return An array, the union of keys in listed categories. May be empty.
 */
- (NSArray<NSString*>*)allKeysInCategories:(NSArray<DKCategoryName>*)catNames;

/** @brief Return all of the keys.
 
 Returned objects are in no particular order. The keys are obtained by enumerating the categories
 because the master list contains case-modified keys that may not be matched with categories.
 @return An array, all keys (listed only once).
 */
@property (readonly, copy) NSArray<NSString*>* allKeys;

/** @brief Return all of the objects.
 @return An array, all objects (listed only once, in arbitrary order).
 */
@property (readonly, copy) NSArray<ObjectType>* allObjects;

/** @brief Return all of the keys in a given category, sorted into some useful order.

 By default the keys are sorted alphabetically. The UI-building methods call this, so a subclass
 can override it and return keys sorted by some other criteria if required.
 @param catName The category name.
 @return An array, the list of keys indicated by the category. May be empty.
 */
- (NSArray<NSString*>*)allSortedKeysInCategory:(DKCategoryName)catName;

/** @brief Return all of the names in a given category, sorted into some useful order.

 For an ordinary <code>DKCategoryManager</code>, names are the same as keys. However, subclasses may
 store keys in some other
 fashion (hint: they do) and so another method is needed to convert keys to names. Those subclasses
 must override this and do what's appropriate.
 @param catName The category name.
 @return An array, the list of names indicated by the category. May be empty.
 */
- (NSArray<NSString*>*)allSortedNamesInCategory:(DKCategoryName)catName;

/** @brief The list of recently added items.
 
 Returned objects are in order of addition, most recent first.

 When setting, replaces the recently added items with new items, up to the current max.
*/
@property (nonatomic, strong) NSArray<ObjectType>* recentlyAddedItems;

/** @brief Return the list of recently used items.

 Returned objects are in order of use, most recent first.
 @return An array, the list of keys recently used.
 */
@property (readonly, nonatomic, strong) NSArray<ObjectType>* recentlyUsedItems;

/** @}
 @name Category Management
 @brief Creating, deleting and renaming categories.
 @{ */

/** @brief Add the default categories defined for this class or object

 Is called as part of the initialisation of the CM object
 */
- (void)addDefaultCategories;

/** @brief Return the default categories defined for this class or object.
 */
@property (readonly, copy) NSArray<DKCategoryName>* defaultCategories;

/** @brief Create a new category with the given name.

 If the name is already a category name, this does nothing.
 @param catName The name of the new category. */
- (void)addCategory:(DKCategoryName)catName;

/** @brief Create a new categories with the given names.
 @param catNames A list of the names of the new categories. */
- (void)addCategories:(NSArray<DKCategoryName>*)catNames;

/** @brief Remove a category with the given name.

 The objects listed in the category are not removed, as they may also be listed by other categories.
 If they are not, they can become orphaned however. To avoid this, never delete the "All Items"
 category.
 @param catName The category to remove.
 */
- (void)removeCategory:(DKCategoryName)catName;

/** @brief Change a category's name.

 If \c newname already exists, it will be replaced by the entries in <code>catname</code>
 @param catName The category's old name.
 @param newname The category's new name.
 */
- (void)renameCategory:(DKCategoryName)catName to:(DKCategoryName)newname;

/** @brief Removes all categories and objects from the CM.

 After this the CM is entirely empty.
 */
- (void)removeAllCategories;

/** @brief Adds a new key to a category, optionally creating it if necessary.
 @param key The key to add.
 @param catName The category to add it to.
 @param cg \c YES to create the category if it doesn't exist, \c NO otherwise. */
- (void)addKey:(NSString*)key toCategory:(DKCategoryName)catName createCategory:(BOOL)cg;

/** @brief Adds a new key to several categories, optionally creating any if necessary.
 @param key The key to add.
 @param catNames A list of categories to add it to.
 @param cg \c YES to create the category if it doesn't exist, \c NO otherwise. */
- (void)addKey:(NSString*)key toCategories:(NSArray<DKCategoryName>*)catNames createCategories:(BOOL)cg;

/** @brief Removes a key from a category
 @param key the key to remove
 @param catName the category to remove it from */
- (void)removeKey:(NSString*)key fromCategory:(DKCategoryName)catName;

/** @brief Removes a key from a number of categories.
 @param key The key to remove.
 @param catNames The list of categories to remove it from. */
- (void)removeKey:(NSString*)key fromCategories:(NSArray<DKCategoryName>*)catNames;

/** @brief Removes a key from all categories.
 @param key The key to remove. */
- (void)removeKeyFromAllCategories:(NSString*)key;

/** @brief Checks that all keys refer to real objects, removing any that do not.

 Rarely needed, but can correct for corrupted registries where objects got removed but not all
 keys that refer to it did for some reason (such as an exception). */
- (void)fixUpCategories;

/** @brief Renames an object's key throughout.

 If \c key doesn't exist, or if \c newkey already exists, throws an exception. After this the same
 object that could be located using \c key can be located using \c newKey in the same categories as
 it appeared in originally.
 @param key The existing key.
 @param newKey The new key.
 */
- (void)renameKey:(NSString*)key to:(NSString*)newKey;

/** @}
 @name Category Lists
 @brief Getting lists, etc. of the categories.
 @{ */

/** @brief Get a list of all categories.

 The list is alphabetically sorted for the convenience of a user interface.
 */
@property (readonly, copy) NSArray<DKCategoryName>* allCategories;

/** @brief Get the count of all categories.
 */
@property (readonly) NSUInteger countOfCategories;

/** @brief Get a list of all categories that contain a given key.

 The list is alphabetically sorted for the convenience of a user interface.
 @param key The key in question.
 @return An array containing a list of categories which contain the key.
 */
- (NSArray<DKCategoryName>*)categoriesContainingKey:(NSString*)key;

/** @brief Get a list of all categories that contain a given key.
 
 The list may be alphabetically sorted for the convenience of a user interface.
 @param key The key in question.
 @param sortIt \c YES to sort the list.
 @return An array containing a list of categories which contain the key.
 */
- (NSArray<DKCategoryName>*)categoriesContainingKey:(NSString*)key withSorting:(BOOL)sortIt;

/** @brief Get a list of reserved categories - those that should not be deleted or renamed.

 This list is advisory - a UI is responsible for honouring it, the cat manager itself ignores it.
 The default implementation returns the same as the default categories, thus reserving all
 default cats. Subclasses can change this as they wish.
 */
@property (readonly, copy) NSArray<DKCategoryName>* reservedCategories;

/** @brief Test whether there is a category of the given name.
 @param catName The category name.
 @return \c YES if a category exists with the name, \c NO otherwise.
 */
- (BOOL)categoryExists:(DKCategoryName)catName;

/** @brief Count how many objects in the category of the given name.
 @param catName The category name.
 @return The number of objects in the category.
 */
- (NSUInteger)countOfObjectsInCategory:(DKCategoryName)catName;

/** @brief Query whether a given key is present in a particular category.
 @param key The key.
 @param catName The category name.
 @return \c YES if the category contains <code>key</code>, \c NO if it doesn't.
 */
- (BOOL)key:(NSString*)key existsInCategory:(DKCategoryName)catName;

/** @}
 @name Managing Recent Lists
 @{ */

/** @brief Set whether the "recently added" list accepts new items or not.

 This allows the recently added items to be temporarily disabled when bulk adding items to the
 manager. By default the recently added items list is enabled.
 @param enable \c YES to allow new items to be added, \c NO otherwise
 */
- (void)setRecentlyAddedListEnabled:(BOOL)enable;

/** @brief Add a key to one of the 'recent' lists.

 Acceptable list IDs are \c kDKListRecentlyAdded and \c kDKListRecentlyUsed
 @param key The key to add.
 @param whichList An identifier for the list in question.
 @return return \c YES if the key was added, otherwise \c NO (i.e. if list already contains item). */
- (BOOL)addKey:(NSString*)key toRecentList:(NSInteger)whichList;

/** @brief Remove a key from one of the 'recent' lists.

 Acceptable list IDs are \c kDKListRecentlyAdded and \c kDKListRecentlyUsed
 @param key The key to remove.
 @param whichList An identifier for the list in question. */
- (void)removeKey:(NSString*)key fromRecentList:(NSInteger)whichList;

/** @brief Sets the maximum length of one of the 'recent' lists.

 Acceptable list IDs are \c kDKListRecentlyAdded and \c kDKListRecentlyUsed
 @param whichList An identifier for the list in question.
 @param max The maximum length to which a list may grow. */
- (void)setRecentList:(NSInteger)whichList maxItems:(NSUInteger)max;

/** @}
 @name Archiving
 @{ */

/** @brief Archives the container to a data object (for saving, etc).
 @return a data object, the archive of the container
 */
@property (readonly, copy) NSData* data;

/** @brief Archives the container to a data object (for saving, etc).
 @param format The property list format to use for the data.
 @return A data object, the archive of the container.
 */
- (NSData*)dataWithFormat:(NSPropertyListFormat)format;

/** @brief Return the filetype (for saving, etc)

 Subclasses should override to change the filetype used for specific examples of this object
 */
@property (readonly, copy) NSString* fileType;

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

/** @}
 @name Supporting UI
 @{
 @name Category Menus
 @brief Menus of just the categories.
 @{ */

/** @brief Creates a menu of categories, recent items and All Items

 Sel and target may be nil
 @param sel the selector which is set as the action for each added item
 @param target the target of category item actions
 @return a menu populated with category and other names
 */
- (NSMenu*)categoriesMenuWithSelector:(nullable SEL)sel target:(nullable id)target;

/** @brief Creates a menu of categories, recent items and All Items

 Sel and target may be nil, options may be 0
 @param sel the selector which is set as the action for each category item
 @param target the target of category item actions
 @param options various flags which set which items are added
 @return a menu populated with category and other names
 */
- (NSMenu*)categoriesMenuWithSelector:(nullable SEL)sel target:(nullable id)target options:(DKCategoryMenuOptions)options;

/** @brief Sets the checkmarks in a menu of category names to reflect the presence of \c key in those categories

 Assumes that item names will be the category names. For localized names, you should handle the
 localization external to this class so that both category names and menu items use the same strings.
 @param menu the menu to examine
 @param key the key to test against
 */
- (void)checkItemsInMenu:(NSMenu*)menu forCategoriesContainingKey:(NSString*)key;

/** @}
 @name Everything Menu
 @brief a menu with everything, organised hierarchically by category. Delegate is called for each new item - see protocol below
 @{ */

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
 @param del an object that is called back with each menu item created (may be nil)
 @param isPopUp set YES if menu is destined for use as a popup (adds extra zeroth item)
 @return a menu object
 */
- (NSMenu*)createMenuWithItemDelegate:(id<DKCategoryManagerMenuItemDelegate>)del isPopUpMenu:(BOOL)isPopUp;
- (NSMenu*)createMenuWithItemDelegate:(id<DKCategoryManagerMenuItemDelegate>)del options:(DKCategoryMenuOptions)options;
- (NSMenu*)createMenuWithItemDelegate:(id<DKCategoryManagerMenuItemDelegate>)del itemTarget:(nullable id)target itemAction:(nullable SEL)action options:(DKCategoryMenuOptions)options;

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

/** }@
 @} */
@end

// various constants:

enum {
	kDKDefaultMaxRecentArraySize = 20,
	kDKListRecentlyAdded = 0,
	kDKListRecentlyUsed = 1
};

// standard name for "All items" category:

extern DKCategoryName const kDKDefaultCategoryName;

extern DKCategoryName const kDKRecentlyAddedUserString;
extern DKCategoryName const kDKRecentlyUsedUserString;

extern NSNotificationName const kDKCategoryManagerWillAddObject;
extern NSNotificationName const kDKCategoryManagerDidAddObject;
extern NSNotificationName const kDKCategoryManagerWillRemoveObject;
extern NSNotificationName const kDKCategoryManagerDidRemoveObject;
extern NSNotificationName const kDKCategoryManagerDidRenameCategory;
extern NSNotificationName const kDKCategoryManagerWillAddKeyToCategory;
extern NSNotificationName const kDKCategoryManagerDidAddKeyToCategory;
extern NSNotificationName const kDKCategoryManagerWillRemoveKeyFromCategory;
extern NSNotificationName const kDKCategoryManagerDidRemoveKeyFromCategory;
extern NSNotificationName const kDKCategoryManagerWillCreateNewCategory;
extern NSNotificationName const kDKCategoryManagerDidCreateNewCategory;
extern NSNotificationName const kDKCategoryManagerWillDeleteCategory;
extern NSNotificationName const kDKCategoryManagerDidDeleteCategory;

/*

This is a useful container class that is like a "super dictionary" or maybe a "micro-database". As well as storing an object using a key,
it allows the object to be associated with none, one or more categories. An object can be a member of any number of categories.

As objects are added and used, they are automatically tracked in a "recently added" and "recently used" list, which can be retreived at any time.

As with a dictionary, an object is associated with a key. In addition to storing the object against that key, the key is added to the categories
that the object is a member of. This facilitates category-oriented lookups of objects.

*/

/** Protocol used by the createMenuWithItemDelegate method. */
@protocol DKCategoryManagerMenuItemDelegate <NSObject>

- (void)menuItem:(NSMenuItem*)item wasAddedForObject:(id)object inCategory:(nullable DKCategoryName)category;

@end

/** Delegate protocol allows the delegate to decide which of a pair of objects should be used when merging. */
@protocol DKCategoryManagerMergeDelegate <NSObject>

- (id)categoryManager:(DKCategoryManager*)cm shouldReplaceObject:(id)regObject withObject:(id)docObject;

@end

NS_ASSUME_NONNULL_END
