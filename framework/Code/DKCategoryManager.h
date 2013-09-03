///**********************************************************************************************************************************
///  DKCategoryManager.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 21/03/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>


// menu creation options:

typedef enum
{
	kDKIncludeRecentlyAddedItems	= ( 1 << 0 ),
	kDKIncludeRecentlyUsedItems		= ( 1 << 1 ),
	kDKIncludeAllItems				= ( 1 << 2 ),
	kDKDontAddDividingLine			= ( 1 << 3 ),
	kDKMenuIsPopUpMenu				= ( 1 << 4 )
}
DKCategoryMenuOptions;

typedef enum
{
	kDKReplaceExisting				= ( 1 << 1 ),		// objects passed in replace those with the same key (doc -> reg)
	kDKReturnExisting				= ( 1 << 2 ),		// objects in reg with the same keys are returned (reg -> doc)
	kDKAddAsNewVersions				= ( 1 << 3 )		// objects with the same keys are copied and registered again (reg || doc)
}
DKCatManagerMergeOptions;


// the class

@interface DKCategoryManager : NSObject <NSCoding, NSCopying>
{
@private
	NSMutableDictionary*	m_masterList;
	NSMutableDictionary*	m_categories;
	NSMutableArray*			m_recentlyAdded;
	NSMutableArray*			m_recentlyUsed;
	NSUInteger				m_maxRecentlyAddedItems;
	NSUInteger				m_maxRecentlyUsedItems;
	NSMutableArray*			mMenusList;
	BOOL					mRecentlyAddedEnabled;
}

+ (DKCategoryManager*)	categoryManager;
+ (DKCategoryManager*)	categoryManagerWithDictionary:(NSDictionary*) dict;
+ (NSArray*)			defaultCategories;
+ (NSString*)			categoryManagerKeyForObject:(id) obj;

+ (id)					dearchivingHelper;
+ (void)				setDearchivingHelper:(id) helper;

// initialization

- (id)					initWithData:(NSData*) data;
- (id)					initWithDictionary:(NSDictionary*) dict;

// adding and retrieving objects

- (void)				addObject:(id) obj forKey:(NSString*) name toCategory:(NSString*) catName createCategory:(BOOL) cg;
- (void)				addObject:(id) obj forKey:(NSString*) name toCategories:(NSArray*) catNames createCategories:(BOOL) cg;
- (void)				removeObjectForKey:(NSString*) key;
- (void)				removeObjectsForKeys:(NSArray*) keys;
- (void)				removeAllObjects;

- (BOOL)				containsKey:(NSString*) name;
- (NSUInteger)			count;

- (id)					objectForKey:(NSString*) key;
- (id)					objectForKey:(NSString*) key addToRecentlyUsedItems:(BOOL) add;

- (NSArray*)			keysForObject:(id) obj;
- (NSDictionary*)		dictionary;

// smartly merging objects:

- (NSSet*)				mergeObjectsFromSet:(NSSet*) aSet inCategories:(NSArray*) categories mergeOptions:(DKCatManagerMergeOptions) options mergeDelegate:(id) aDelegate;
- (id)					mergeObject:(id) obj mergeDelegate:(id) aDelegate;

// retrieving lists of objects by category

- (NSArray*)			objectsInCategory:(NSString*) catName;
- (NSArray*)			objectsInCategories:(NSArray*) catNames;
- (NSArray*)			allKeysInCategory:(NSString*) catName;
- (NSArray*)			allKeysInCategories:(NSArray*) catNames;
- (NSArray*)			allKeys;
- (NSArray*)			allObjects;

- (NSArray*)			allSortedKeysInCategory:(NSString*) catName;
- (NSArray*)			allSortedNamesInCategory:(NSString*) catName;

- (void)				setRecentlyAddedItems:(NSArray*) array;
- (NSArray*)			recentlyAddedItems;
- (NSArray*)			recentlyUsedItems;

// category management - creating, deleting and renaming categories

- (void)				addDefaultCategories;
- (NSArray*)			defaultCategories;

- (void)				addCategory:(NSString*) catName;
- (void)				addCategories:(NSArray*) catNames;
- (void)				removeCategory:(NSString*) catName;
- (void)				renameCategory:(NSString*) catName to:(NSString*) newname;
- (void)				removeAllCategories;

- (void)				addKey:(NSString*) key toCategory:(NSString*) catName createCategory:(BOOL) cg;
- (void)				addKey:(NSString*) key toCategories:(NSArray*) catNames createCategories:(BOOL) cg;
- (void)				removeKey:(NSString*) key fromCategory:(NSString*) catName;
- (void)				removeKey:(NSString*) key fromCategories:(NSArray*) catNames;
- (void)				removeKeyFromAllCategories:(NSString*) key;
- (void)				fixUpCategories;
- (void)				renameKey:(NSString*) key to:(NSString*) newKey;

// getting lists, etc. of the categories

- (NSArray*)			allCategories;
- (NSUInteger)			countOfCategories;
- (NSArray*)			categoriesContainingKey:(NSString*) key;
- (NSArray*)			categoriesContainingKey:(NSString*) key withSorting:(BOOL) sortIt;
- (NSArray*)			reservedCategories;

- (BOOL)				categoryExists:(NSString*) catName;
- (NSUInteger)			countOfObjectsInCategory:(NSString*) catName;
- (BOOL)				key:(NSString*) key existsInCategory:(NSString*) catName;

// managing recent lists

- (void)				setRecentlyAddedListEnabled:(BOOL) enable;
- (BOOL)				addKey:(NSString*) key toRecentList:(NSInteger) whichList;
- (void)				removeKey:(NSString*) key fromRecentList:(NSInteger) whichList;
- (void)				setRecentList:(NSInteger) whichList maxItems:(NSUInteger) max;

// archiving

- (NSData*)				data;
- (NSData*)				dataWithFormat:(NSPropertyListFormat) format;
- (NSString*)			fileType;
- (BOOL)				replaceContentsWithData:(NSData*) data;
- (BOOL)				appendContentsWithData:(NSData*) data;
- (void)				copyItemsFromCategoryManager:(DKCategoryManager*) cm;

// supporting UI:
// menus of just the categories:

- (NSMenu*)				categoriesMenuWithSelector:(SEL) sel target:(id) target;
- (NSMenu*)				categoriesMenuWithSelector:(SEL) sel target:(id) target options:(NSInteger) options;
- (void)				checkItemsInMenu:(NSMenu*) menu forCategoriesContainingKey:(NSString*) key;

// a menu with everything, organised hierarchically by category. Delegate is called for each new item - see protocol below

- (NSMenu*)				createMenuWithItemDelegate:(id) del isPopUpMenu:(BOOL) isPopUp;
- (NSMenu*)				createMenuWithItemDelegate:(id) del options:(DKCategoryMenuOptions) options;
- (NSMenu*)				createMenuWithItemDelegate:(id) del itemTarget:(id) target itemAction:(SEL) action options:(DKCategoryMenuOptions) options;

- (void)				removeMenu:(NSMenu*) menu;
- (void)				updateMenusForKey:(NSString*) key;

@end

// various constants:

enum
{
	kDKDefaultMaxRecentArraySize	= 20,
	kDKListRecentlyAdded			= 0,
	kDKListRecentlyUsed				= 1
};


// standard name for "All items" category:

extern NSString*	kDKDefaultCategoryName;

extern NSString*	kDKRecentlyAddedUserString;
extern NSString*	kDKRecentlyUsedUserString;

extern NSString*	kDKCategoryManagerWillAddObject;
extern NSString*	kDKCategoryManagerDidAddObject;
extern NSString*	kDKCategoryManagerWillRemoveObject;
extern NSString*	kDKCategoryManagerDidRemoveObject;
extern NSString*	kDKCategoryManagerDidRenameCategory;
extern NSString*	kDKCategoryManagerWillAddKeyToCategory;
extern NSString*	kDKCategoryManagerDidAddKeyToCategory;
extern NSString*	kDKCategoryManagerWillRemoveKeyFromCategory;
extern NSString*	kDKCategoryManagerDidRemoveKeyFromCategory;
extern NSString*	kDKCategoryManagerWillCreateNewCategory;
extern NSString*	kDKCategoryManagerDidCreateNewCategory;
extern NSString*	kDKCategoryManagerWillDeleteCategory;
extern NSString*	kDKCategoryManagerDidDeleteCategory;

/*

This is a useful container class that is like a "super dictionary" or maybe a "micro-database". As well as storing an object using a key,
it allows the object to be associated with none, one or more categories. An object can be a member of any number of categories.

As objects are added and used, they are automatically tracked in a "recently added" and "recently used" list, which can be retreived at any time.

As with a dictionary, an object is associated with a key. In addition to storing the object against that key, the key is added to the categories
that the object is a member of. This facilitates category-oriented lookups of objects.


*/

// informal protocol used by the createMenuWithItemDelegate method:

@interface NSObject (CategoryManagerMenuItemDelegate)

- (void)			menuItem:(NSMenuItem*) item wasAddedForObject:(id) object inCategory:(NSString*) category;

@end

// delegate informal protocol allows the delegate to decide which of a pair of objects should be used when merging

@interface NSObject (categoryManagerMergeDelegate)

- (id)				categoryManager:(DKCategoryManager*) cm shouldReplaceObject:(id) regObject withObject:(id) docObject;

@end


// private object used to store menu info - allows efficient management of the menu to match
// the C/Mgrs contents. Menu creation and management is moved to this class, but API in Cat Manager functions as previously.

@interface DKCategoryManagerMenuInfo : NSObject
{
@private
	DKCategoryManager*		mCatManagerRef;					// the category manager that owns this
	NSMenu*					mTheMenu;						// the menu being managed
	id						mTargetRef;						// initial target for new menu items
	id						mCallbackTargetRef;				// delegate for menu items
	SEL						mSelector;						// initial action for new menu items
	DKCategoryMenuOptions	mOptions;						// option flags
	BOOL					mCategoriesOnly;				// YES if the menu just lists the categories and not the category contents
	NSMenuItem*				mRecentlyUsedMenuItemRef;		// the menu item for "recently used"
	NSMenuItem*				mRecentlyAddedMenuItemRef;		// the menu item for "recently added"
}


- (id)					initWithCategoryManager:(DKCategoryManager*) mgr itemTarget:(id) target itemAction:(SEL) selector options:(DKCategoryMenuOptions) options;
- (id)					initWithCategoryManager:(DKCategoryManager*) mgr itemDelegate:(id) delegate options:(DKCategoryMenuOptions) options;
- (id)					initWithCategoryManager:(DKCategoryManager*) mgr itemDelegate:(id) delegate itemTarget:(id) target itemAction:(SEL) selector options:(DKCategoryMenuOptions) options;

- (NSMenu*)				menu;

- (void)				addCategory:(NSString*) newCategory;
- (void)				removeCategory:(NSString*) oldCategory;
- (void)				renameCategoryWithInfo:(NSDictionary*) info;
- (void)				addKey:(NSString*) aKey;
- (void)				addRecentlyAddedOrUsedKey:(NSString*) aKey;
- (void)				syncRecentlyUsedMenuForKey:(NSString*) aKey;
- (void)				removeKey:(NSString*) aKey;
- (void)				checkItemsForKey:(NSString*) key;
- (void)				updateForKey:(NSString*) key;
- (void)				removeAll;


@end

// this tag is set in every menu item that we create/manage automatically. Normally client code of the menus shouldn't use the tags of these items but instead the represented object,
// so this tag identifies items that we can freely discard or modify. Any others are left alone, allowing clients to add other items to the menus that won't get disturbed.

enum
{
	kDKCategoryManagerManagedMenuItemTag		= -42,
	kDKCategoryManagerRecentMenuItemTag			= -43
};


/*
The cat manager supports a UI based on menu(s). To assist, the DKCategoryManagerMenuInfo class is used to "own" a menu - the cat manager keeps a list of these.

When the CM is asked for a menu, this helper object is used to create and manage it. As the CM is used (items and categories added/removed) the menu helpers are
informed of the changes and in turn update the menus to match by adding or deleting menu items. This is necessary because when the CM grows to a significant number
of items, rebuilding the menus is very time-consuming. This way performance is much better.

*/




