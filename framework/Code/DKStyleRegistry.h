/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKCategoryManager.h"

@class DKStyle;

// options flags - control behaviour when styles from a document are merged with the registry

typedef enum {
	kDKIgnoreUnsharedStyles = (1 << 0), // compatibility with old registry - styles with sharing off are ignored
	kDKReplaceExistingStyles = (1 << 1), // styles passed in replace those with the same key (doc -> reg)
	kDKReturnExistingStyles = (1 << 2), // styles in reg with the same keys are returned (reg -> doc)
	kDKAddStylesAsNewVersions = (1 << 3) // styles with the same keys are copied and registered again (reg || doc)
} DKStyleMergeOptions;

// values you can test for in result of compareStylesInSet:

enum {
	kDKStyleNotRegistered = 0,
	kDKStyleIsOlder = 1,
	kDKStyleUnchanged = 2,
	kDKStyleIsNewer = 3
};

// class:

/**
The style registry is a singleton category manager instance that consolidates styles from a variety of sources into a single app-wide "database"
of styles, organised into categories.

Styles can come from these sources:

1. The application defaults, if the app is launched with no library preferences available (i.e. first run).

2. The styles library, which is the complete registry saved to disk (user prefs) at quit time.

3. A document, when it is opened.

4. A separate file containing just styles.

5. A new style being created and registered by the user as the app is used.

-------------------------------------------------------------------------------------------------------------------------------------------------
The point of the registry is twofold:

A. It permits the construction of a UI for accessing pre-built styles and applying them to objects in a drawing. By organising styles into categories,
potentially large number of styles may be managed effectively.

B. It tracks styles across any number of documents as they are created. For example if a document uses a particular registered style, when that
document is reopened at a later date, the style can be recognised and linked to the same style in the registry. If the style has changed in the
meantime so that there is a difference between the saved style and the currently registered version, the user can be offered the option to
update the style in the document to match the registry, update the registry to match the document, or to re-register the style as a new version.

Note the registry is not mandatory - an app using DK can use styles without registering them if it wishes. The advantage of the registry is that it
permits styles to persist and be tracked across multiple documents, saving the user from having to redefine styles for every new graphic.

-------------------------------------------------------------------------------------------------------------------------------------------------
In order for the registry to uniquely and positively identify a style, its unique ID is used as its key. The unique ID is assigned when the style
first comes into existence and cannot be changed. It is a string representation of a UUID so is guaranteed unique.

UUID's are not very user friendly and should never be exposed by an application's user interface. Thus a style also has an ordinary descriptive
name which can be displayed in the UI. Such names are not guaranteed to be unique however, as the user is free to enter whatever name they wish.
When a style is first registered the name may be changed to avoid a collision with an already registered style having the same name - this is
done by appending 1, 2, 3 etc until the name doesn't collide. However this is just done to disambiguate the style for the user - it is not intended
to guarantee uniqueness so that the name can be used as a key to the object.

A user interface will want to use the ordinary names, but internally must be set up to use the unique ID or the object itself to avoid any confusion
as to which style is actually being referred to. For example a menu of available styles could use the UUID or the object as the represented object
of the menu item. DO NOT USE THE ORDINARY NAME AS A KEY.

-------------------------------------------------------------------------------------------------------------------------------------------------

Locking. Styles in the registry are usually locked. This is to prevent accidental alteration of a style that may be being used across many
documents. When a style is added to the registry, it should be unlocked (because the name might need to be automatically changed) but the
registry will lock the style upon a successful operation.

Styles in a document. Styles used in a document may or may not be registered. A user may never register a style, but still have many styles
defined in a document. Such styles work normally and can be copied and pasted and shared between objects if set to do so - use of styles is not
dependent in any way upon the registry. When the document is saved, a flag as to whether the style was registered or not is saved with it. When
the document is opened again later, such flagged styles will be optionally reconnected to the style registry so that the actual style used is
always the registered style, so if the style is updated, existing documents are offered the opportunity to use the updated version.

As well as any user-defined categories, documents may wish to create a temporary category using the document's name which gives the user a
way to quickly discover the complete set of registered styles used in a document. The category should be removed when the document is closed.
DKDrawDocument implements this behaviour by default, so if your document class is based on it, your app can get this feature for free.

-------------------------------------------------------------------------------------------------------------------------------------------------

Registering a style. The style registry performs the following steps:

1. It checks that the style is not already registered. If it is, it does no more.

2. It checks that the style is unlocked. If not, an exception is thrown.

3. It resolves the style's name so that there are no collisions with any existing style's name, and changes the style's name if needed.

4. It creates any new categories as requested (depends on the particular method used to register the style). If no specific categories are
	requested, the style is added to the default category.

5. It adds the style to the registry using its unique ID as the key.

6. It locks the style.

-------------------------------------------------------------------------------------------------------------------------------------------------

Cut/Paste: cut and paste of styles works independently of the registry, including dealing with shared styles. See DKStyle for more info.
*/
@interface DKStyleRegistry : DKCategoryManager

// retrieving the registry and styles

/** @brief Return the single global style registry object

 A style registry isn't a true singleton but in general there would probably be never any reason
 to create another instance. Other class methods implictly reference the registry returned by this.
 @return the style registry used for all general purpose registration of styles in DK
 */
+ (DKStyleRegistry*)sharedStyleRegistry;

/** @brief Return the style registerd with the given key

 Styles returned by this method are not added to the "recently used" items list
 @param styleID the unique key of the style. Styles return his value from - uniqueKey.
 @return the style if it exists in the registry, otherwise nil
 */
+ (DKStyle*)styleForKey:(NSString*)styleID;

/** @brief Return the style registerd with the given key

 Styles returned by this method are added to the "recently used" items list - usually you will use
 this method when applying a registered style to an object in a real app so that you can make use
 of the "recently used" list
 @param styleID the unique key of the style. Styles return his value from - uniqueKey.
 @return the style if it exists in the registry, otherwise nil
 */
+ (DKStyle*)styleForKeyAddingToRecentlyUsed:(NSString*)styleID;

// registering a style

/** @brief Register the style with the registry

 This method registers styles in the "All User Styles" category only. If the style is already registered
 this does nothing. Registering a style locks it as a side effect (safety feature). The styles is
 registered using the value returned by its -uniqueKey method, which is set once for all time when the
 style is initialized. In general you should not interpret or display these keys. If the style's name
 is the same as another registered style's name, this style' name is changed by appending digits
 until the name collision is resolved. However the name is not the key and shouldn't be used as one.
 @param aStyle the style to register
 */
+ (void)registerStyle:(DKStyle*)aStyle;

/** @brief Register the style with the registry

 See notes for registerStyle:
 if the categories do not exist they are created.
 @param aStyle the style to register
 @param styleCategories a list of one or more categories to list the style in (list of NSStrings)
 */
+ (void)registerStyle:(DKStyle*)aStyle inCategories:(NSArray*)styleCategories;

/** @brief Register a list of styles with the registry

 See notes for registerStyle:
 if the categories do not exist they are created.
 @param styles an array of DKStyle objects to register
 @param styleCategories a list of one or more categories to list the style in (list of NSStrings)
 */
+ (void)registerStylesFromArray:(NSArray*)styles inCategories:(NSArray*)styleCategories;

/** @brief Register a list of styles with the registry

 See notes for registerStyle:
 if the categories do not exist they are created. Note that the "recently added" list is temporarily
 disabled by this method, reflecting the intention that it is used for pre-registering a number of
 styles in bulk.
 @param styles an array of DKStyle objects to register
 @param styleCategories a list of one or more categories to list the style in (list of NSStrings)
 @param ignoreDupes if YES, styles whose names are already known are skipped.
 */
+ (void)registerStylesFromArray:(NSArray*)styles inCategories:(NSArray*)styleCategories ignoringDuplicateNames:(BOOL)ignoreDupes;

/** @brief Remove the style from the registry

 Removed styles are still retained by an objects using them, so they are not dealloced unless
 not in use by any clients at all.
 @param aStyle the style to remove
 */
+ (void)unregisterStyle:(DKStyle*)aStyle;

/** @brief Send a notification that the contents of the registry has changed so any UI displaying it should
 be updated

 The notification's object is the shared style registry
 */
+ (void)setNeedsUIUpdate;
+ (void)setStyleNotificationsEnabled:(BOOL)enable;

// merging sets of styles read in with a document

/** @brief Merge a set of styles with the registry

 This method is for merging sets of styles read in with a document or file. The document will have
 already sorted the loaded styles into those which were formerly registered and those which were not
 - <styles> is the set that was. The doc may elect to create a category with the doc's name, this
 can be passed in <styleCategories>. The options dictate how the merge is to be done - either doc
 styles dominate or reg styles dominate, or else the doc styles are copied and reregistered afresh.
 The returned set is the set that the document should use, and will need to replace styles in the
 document with a matching uniqueKey with those in the set (thus if the reg dominates, it can in
 this way update the document's contents). If the doc wishes to remove the category when it closes,
 it can do so using the category manager API.
 @param styles a set of one or more styles
 @param styleCategories a list of categories to add the styles to if they are added (one or more NSStrings)
 @param options control flags for changing the preferred direction of merging, etc.
 @param aDel an optional delegate object that can make a merge decision for each individual style object
 @return a set of styles that should replace those with the same key in whatever structure made the call.
 can be nil if there is no need to do anything.
 */
+ (NSSet*)mergeStyles:(NSSet*)styles inCategories:(NSArray*)styleCategories options:(DKStyleMergeOptions)options mergeDelegate:(id)aDel;

/** @brief Preflight a set of styles against the registry for a possible future merge operation

 This is a way to test a set of styles against the registry prior to a merge operation (preflight).
 It compares each style in the set with the current registry, and returns a dictionary keyed off
 the style's unique key. The values in the dictionary are NSNumbers indicating whether the style
 is older, the same, newer or unknown. The caller can use this info to make decisions about a merge
 before doing it, if they wish, or to present the info to the user.
 @param styles a set of styles
 @return a dictionary, listing for each style whether it is unknown, older, the same or newer than the
 registry styles having the same keys.
 */
+ (NSDictionary*)compareStylesInSet:(NSSet*)styles;

// high-level data access

/** @brief Return the entire list of keys of the styles in the registry
 @return an array listing all of the keys in the registry
 */
+ (NSArray*)registeredStyleKeys;

/** @brief Return data that can be saved to a file, etc. representing the registry
 @return NSData of the entire registry
 */
+ (NSData*)registeredStylesData;

/** @brief Saves the registry to the current user defaults
 */
+ (void)saveDefaults;

/** @brief Loads the registry from the current user defaults

 If used, this should be called early in the application launch sequence
 */
+ (void)loadDefaults;

/** @brief Reset the registry back to a "first run" condition

 This removes ALL styles from the registry, thereby unregistering them. It then starts over with
 the DK defaults. This puts the registry into the same state that it was in on the very first run
 of the client app, when there are no saved defaults. This method should be used carefully - the
 caller may want to confirm the action beforehand with the user.
 */
+ (void)resetRegistry;

/** @brief Creates a series of fill styles having the solid colours given by the named NSColorList, and
 adds them to the registry using the named category.

 The named color list must exist - see [NSColorList availableColorLists];
 @param name the name of a NSColorList
 @param catName the name of the registry category - if nil, use the colorList name
 */
+ (void)registerSolidColourFillsFromListNamed:(NSString*)name asCategory:(NSString*)catName;

/** @brief Creates a series of stroke styles having the solid colours given by the named NSColorList, and
 adds them to the registry using the named category.

 The named color list must exist - see [NSColorList availableColorLists];
 @param name the name of a NSColorList
 @param catName the name of the registry category - if nil, use the colorList name
 */
+ (void)registerSolidColourStrokesFromListNamed:(NSString*)name asCategory:(NSString*)catName;

/** @brief Sets whether DK defaults category containing the default styles shoul dbe registered when the
 registry is built or reset

 See +resetRgistry
 @param noDKDefaults YES to turn OFF the defaults
 */
+ (void)setShouldNotAddDKDefaultCategory:(BOOL)noDKDefaults;

// getting a fully-managed menu for all styles, organised by category:

+ (NSMenu*)managedStylesMenuWithItemTarget:(id)target itemAction:(SEL)selector;

// low-level instance methods

/** @brief Return the style's name given its key

 The name can be used in a user interface, but the key should not. This gives you an easy way to
 get one from the other if you don't have the style object itself. If the key is unknown to the
 registry, nil is returned.
 @param styleID the style's key
 @return the style's name
 */
- (NSString*)styleNameForKey:(NSString*)styleID;
- (DKStyle*)styleForKey:(NSString*)styleID;

/** @brief Return the set of styles in the given categories

 Being a set, the result is unordered. The result may be the empty set if the categories are unknown
 or empty, and may contain NSNull objects if the style registry is in a state where objects have been
 removed and the category lists not updated (in normal use this should not occur).
 @param cats a list of one or more categories
 @return a set, all of the styles in the requested categories
 */
- (NSSet*)stylesInCategories:(NSArray*)cats;

/** @brief Return a modified name to resolve a collision with names already in use

 Names of styles are changed when a style is registerd to avoid a collision with any already
 registered styles. Names are not keys and this doesn't guarantee uniqueness - it's merely a
 courtesy to the user.
 @param name a candidate name
 @return the same string if no collisiosn, or a modified copy if there was
 */
- (NSString*)uniqueNameForName:(NSString*)name;

/** @brief Return a list of all the registered styles' names, in alphabetical order
 @return a list of names
 */
- (NSArray*)styleNames;

/** @brief Return a list of the registered styles' names in the category, in alphabetical order
 @param catName the name of a single category
 @return a list of names
 */
- (NSArray*)styleNamesInCategory:(NSString*)catName;

/** @brief Write the registry to a file
 @param path the full path of the file to write
 @param atom YES to save safely, NO to overwrite in place
 @return YES if the file was saved sucessfully, NO otherwise
 */
- (BOOL)writeToFile:(NSString*)path atomically:(BOOL)atom;

/** @brief Merge the contents of a file into the registry

 Reads styles from the file at <path> into the registry. Styles are merged as indicated by the
 options, etc. The intention of this method is to load a file containing styles only - either to
 augment or replace the existing registry. It is not used when opening a drawing document.
 If the intention is to replace the reg, the caller should clear out the current one before calling this.
 @param path the full path of the file to write
 @param options merging options
 @param aDel an optional delegate object that can make a merge decision for each individual style object 
 @return YES if the file was read and merged sucessfully, NO otherwise
 */
- (BOOL)readFromFile:(NSString*)path mergeOptions:(DKStyleMergeOptions)options mergeDelegate:(id)aDel;

- (DKStyle*)mergeFromStyle:(DKStyle*)aStyle mergeDelegate:(id)aDel;

/** @brief Set the registry empty

 Removes all styles from the registry, clears the "recently added" and "recently used" lists, and
 removes all categories except the default category.
 */
- (void)removeAllStyles;

- (void)setNeedsUIUpdate;
- (void)styleDidChange:(NSNotification*)note;

/** @brief Creates a new fully managed menu that lists all the styles, organised into categories.

 The returned menu is fully managed, that is, the Style Registry keeps it in synch with all changes
 to the registry and to the styles themselves. The menu can be assigned to UI controls such as a
 represented object is the style, and the item shows a swatch and the style's name. The menus
 are ordered alphabetically.
 This is intended as a very high-level method to support the most common usage. If you need to pass
 different options or wish to handle each item differently, DKCategoryManager has more flexible
 methods that expose more detail.
 @param target the target object assigned to each menu item
 @param selector the action sent by each menu item
 @return a menu
 */
- (NSMenu*)managedStylesMenuWithItemTarget:(id)target itemAction:(SEL)selector;

@end

// default registry category names:

extern NSString* kDKStyleLibraryStylesCategory;
extern NSString* kDKStyleTemporaryDocumentCategory;
extern NSString* kDKStyleRegistryDKDefaultsCategory;
extern NSString* kDKStyleRegistryTextStylesCategory;

// notifications

extern NSString* kDKStyleRegistryDidFlagPossibleUIChange;
extern NSString* kDKStyleWasRegisteredNotification;
extern NSString* kDKStyleWasRemovedFromRegistryNotification;
extern NSString* kDKStyleWasEditedWhileRegisteredNotification;

// delegate informal protocol allows the delegate to decide which of a pair of styles should be used

@interface NSObject (DKStyleRegistryDelegate)

- (DKStyle*)registry:(DKStyleRegistry*)reg shouldReplaceStyle:(DKStyle*)regStyle withStyle:(DKStyle*)docStyle;

@end

@interface NSObject (StyleRegistrySubstitution)

- (DKStyleRegistry*)applicationWillReturnStyleRegistry;

@end
