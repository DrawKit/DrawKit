//
//  DKStyleRegistry.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 15/03/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>
#import "DKCategoryManager.h"


@class DKStyle;

// options flags - control behaviour when styles from a document are merged with the registry

typedef enum
{
	kDKIgnoreUnsharedStyles		= ( 1 << 0 ),		// compatibility with old registry - styles with sharing off are ignored
	kDKReplaceExistingStyles	= ( 1 << 1 ),		// styles passed in replace those with the same key (doc -> reg)
	kDKReturnExistingStyles		= ( 1 << 2 ),		// styles in reg with the same keys are returned (reg -> doc)
	kDKAddStylesAsNewVersions	= ( 1 << 3 )		// styles with the same keys are copied and registered again (reg || doc)
}
DKStyleMergeOptions;


// values you can test for in result of compareStylesInSet:

enum
{
	kDKStyleNotRegistered		= 0,
	kDKStyleIsOlder				= 1,
	kDKStyleUnchanged			= 2,
	kDKStyleIsNewer				= 3
};



// class:

@interface DKStyleRegistry : DKCategoryManager

// retrieving the registry and styles

+ (DKStyleRegistry*)		sharedStyleRegistry;
+ (DKStyle*)				styleForKey:(NSString*) styleID;
+ (DKStyle*)				styleForKeyAddingToRecentlyUsed:(NSString*) styleID;

// registering a style

+ (void)					registerStyle:(DKStyle*) aStyle;
+ (void)					registerStyle:(DKStyle*) aStyle inCategories:(NSArray*) styleCategories;
+ (void)					registerStylesFromArray:(NSArray*) styles inCategories:(NSArray*) styleCategories;
+ (void)					registerStylesFromArray:(NSArray*) styles inCategories:(NSArray*) styleCategories ignoringDuplicateNames:(BOOL) ignoreDupes;
+ (void)					unregisterStyle:(DKStyle*) aStyle;
+ (void)					setNeedsUIUpdate;
+ (void)					setStyleNotificationsEnabled:(BOOL) enable;

// merging sets of styles read in with a document

+ (NSSet*)					mergeStyles:(NSSet*) styles inCategories:(NSArray*) styleCategories options:(DKStyleMergeOptions) options mergeDelegate:(id) aDel;
+ (NSDictionary*)			compareStylesInSet:(NSSet*) styles;

// high-level data access

+ (NSArray*)				registeredStyleKeys;
+ (NSData*)					registeredStylesData;
+ (void)					saveDefaults;
+ (void)					loadDefaults;
+ (void)					resetRegistry;

+ (void)					registerSolidColourFillsFromListNamed:(NSString*) name asCategory:(NSString*) catName;
+ (void)					registerSolidColourStrokesFromListNamed:(NSString*) name asCategory:(NSString*) catName;

+ (void)					setShouldNotAddDKDefaultCategory:(BOOL) noDKDefaults;

// getting a fully-managed menu for all styles, organised by category:

+ (NSMenu*)					managedStylesMenuWithItemTarget:(id) target itemAction:(SEL) selector;

// low-level instance methods

- (NSString*)				styleNameForKey:(NSString*) styleID;
- (DKStyle*)				styleForKey:(NSString*) styleID;
- (NSSet*)					stylesInCategories:(NSArray*) cats;

- (NSString*)				uniqueNameForName:(NSString*) name;
- (NSArray*)				styleNames;
- (NSArray*)				styleNamesInCategory:(NSString*) catName;

- (BOOL)					writeToFile:(NSString*) path atomically:(BOOL) atom;
- (BOOL)					readFromFile:(NSString*) path mergeOptions:(DKStyleMergeOptions) options mergeDelegate:(id) aDel;

- (DKStyle*)				mergeFromStyle:(DKStyle*) aStyle mergeDelegate:(id) aDel;

- (void)					removeAllStyles;

- (void)					setNeedsUIUpdate;
- (void)					styleDidChange:(NSNotification*) note;

- (NSMenu*)					managedStylesMenuWithItemTarget:(id) target itemAction:(SEL) selector;

@end


// default registry category names:

extern NSString*		kDKStyleLibraryStylesCategory;
extern NSString*		kDKStyleTemporaryDocumentCategory;
extern NSString*		kDKStyleRegistryDKDefaultsCategory;
extern NSString*		kDKStyleRegistryTextStylesCategory;

// notifications

extern NSString*		kDKStyleRegistryDidFlagPossibleUIChange;
extern NSString*		kDKStyleWasRegisteredNotification;
extern NSString*		kDKStyleWasRemovedFromRegistryNotification;
extern NSString*		kDKStyleWasEditedWhileRegisteredNotification;

// delegate informal protocol allows the delegate to decide which of a pair of styles should be used

@interface NSObject (DKStyleRegistryDelegate)

- (DKStyle*)			registry:(DKStyleRegistry*) reg shouldReplaceStyle:(DKStyle*) regStyle withStyle:(DKStyle*) docStyle;

@end

@interface NSObject (StyleRegistrySubstitution)

- (DKStyleRegistry*)	applicationWillReturnStyleRegistry;

@end


/*

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

