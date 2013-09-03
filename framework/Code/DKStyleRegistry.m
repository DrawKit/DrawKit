//
//  DKStyleRegistry.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 15/03/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKStyleRegistry.h"

#import "DKStyle.h"
#import "DKStyle+Text.h"
#import "DKUniqueID.h"
#import "LogEvent.h"
#import "NSString+DKAdditions.h"

#pragma mark constants (non-localized)

NSString*		kDKStyleLibraryStylesCategory				= @"All User Styles";
NSString*		kDKStyleTemporaryDocumentCategory			= @"Temporary Document";
NSString*		kDKStyleRegistryDKDefaultsCategory			= @"DrawKit Defaults";
NSString*		kDKStyleRegistryTextStylesCategory			= @"Text Styles";

NSString*		kDKStyleRegistryDidFlagPossibleUIChange		= @"kDKStyleRegistryDidFlagPossibleUIChange";
NSString*		kDKStyleWasRegisteredNotification			= @"kDKDrawingStyleWasRegisteredNotification";
NSString*		kDKStyleWasRemovedFromRegistryNotification	= @"kDKDrawingStyleWasRemovedFromRegistryNotification";
NSString*		kDKStyleWasEditedWhileRegisteredNotification = @"kDKStyleWasEditedWhileRegisteredNotifcation";

#pragma mark -
#pragma mark static functions

static NSInteger SortKeysByReferredName( id a, id b, void* contextInfo )
{
	DKStyleRegistry* reg = (DKStyleRegistry*)contextInfo;
	
	// a and b are keys in the registry - order them by the name of the styles they reference
	
	NSString* nameA = [reg styleNameForKey:a];
	NSString* nameB = [reg styleNameForKey:b];
	
	return [nameA localisedCaseInsensitiveNumericCompare:nameB];
}


#pragma mark -
#pragma mark special private category on DKStyle gives the registry extra privileges.

@interface DKStyle (RegistrySpecialPrivileges)

- (void)		reassignUniqueKey;

@end


#pragma mark -

@implementation DKStyleRegistry

// warning: only access this using +sharedStyleRegistry

static DKStyleRegistry* s_styleRegistry = nil;
static BOOL				s_NoDKDefaults = NO;
	
#pragma mark As a DKStyleRegistry

///*********************************************************************************************************************
///
/// method:			sharedStyleRegistry
/// scope:			public class method
/// overrides:
/// description:	return the single global style registry object
/// 
/// parameters:		none
/// result:			the style registry used for all general purpose registration of styles in DK
///
/// notes:			a style registry isn't a true singleton but in general there would probably be never any reason
///					to create another instance. Other class methods implictly reference the registry returned by this.
///
///********************************************************************************************************************

+ (DKStyleRegistry*)		sharedStyleRegistry
{
	 if ( s_styleRegistry == nil )
	 {
		 // first ask the application's delegate if it will return a specific class here. This allows the app's delegate
		 // to substitute a subclass (esoteric)
		 
		 id appDelegate = [NSApp delegate];
		 
		 if( appDelegate && [appDelegate respondsToSelector:@selector(applicationWillReturnStyleRegistry)])
			 s_styleRegistry = [[appDelegate applicationWillReturnStyleRegistry] retain];
		 
		 // if still nil, make a default one
		 
		 if( s_styleRegistry == nil )
			s_styleRegistry = [[self alloc] init];
	 }
	 
	 return s_styleRegistry;
}



///*********************************************************************************************************************
///
/// method:			styleForKey:
/// scope:			public class method
/// overrides:
/// description:	return the style registerd with the given key
/// 
/// parameters:		<styleID> the unique key of the style. Styles return his value from - uniqueKey.
/// result:			the style if it exists in the registry, otherwise nil
///
/// notes:			styles returned by this method are not added to the "recently used" items list
///
///********************************************************************************************************************

+ (DKStyle*)				styleForKey:(NSString*) styleID
{
	return [[self sharedStyleRegistry] styleForKey:styleID];
}


///*********************************************************************************************************************
///
/// method:			styleForKeyAddingToRecentlyUsed:
/// scope:			public class method
/// overrides:
/// description:	return the style registerd with the given key
/// 
/// parameters:		<styleID> the unique key of the style. Styles return his value from - uniqueKey.
/// result:			the style if it exists in the registry, otherwise nil
///
/// notes:			styles returned by this method are added to the "recently used" items list - usually you will use
///					this method when applying a registered style to an object in a real app so that you can make use
///					of the "recently used" list
///
///********************************************************************************************************************

+ (DKStyle*)				styleForKeyAddingToRecentlyUsed:(NSString*) styleID
{
	// returns the style and also adds it to the "recently used" items list
	
	DKStyle* rs = [self styleForKey:styleID];
	
	if ( rs != nil )
	{
		BOOL update = [[self sharedStyleRegistry] addKey:styleID toRecentList:kDKListRecentlyUsed];
		
		if ( update )
			[self setNeedsUIUpdate];
	}
	return rs;
}



///*********************************************************************************************************************
///
/// method:			registerStyle:
/// scope:			public class method
/// overrides:
/// description:	register the style with the registry
/// 
/// parameters:		<aStyle> the style to register
/// result:			none
///
/// notes:			this method registers styles in the "All User Styles" category only. If the style is already registered
///					this does nothing. Registering a style locks it as a side effect (safety feature). The styles is
///					registered using the value returned by its -uniqueKey method, which is set once for all time when the
///					style is initialized. In general you should not interpret or display these keys. If the style's name
///					is the same as another registered style's name, this style' name is changed by appending digits
///					until the name collision is resolved. However the name is not the key and shouldn't be used as one.
///
///********************************************************************************************************************

+ (void)					registerStyle:(DKStyle*) aStyle
{
	[self registerStyle:aStyle inCategories:[NSArray arrayWithObject:kDKStyleLibraryStylesCategory]]; 
}



///*********************************************************************************************************************
///
/// method:			registerStyle:inCategories:
/// scope:			public class method
/// overrides:
/// description:	register the style with the registry
/// 
/// parameters:		<aStyle> the style to register
///					<styleCategories> a list of one or more categories to list the style in (list of NSStrings)
/// result:			none
///
/// notes:			see notes for registerStyle:
///					if the categories do not exist they are created.
///
///********************************************************************************************************************

+ (void)					registerStyle:(DKStyle*) aStyle inCategories:(NSArray*) styleCategories
{
	// this is the master method for registering a style - all other registration methods call this one
	
	NSAssert( aStyle != nil, @"attempt to register a nil style");
	
	NSString* styleID = [aStyle uniqueKey];
	if ([self styleForKey:styleID] != nil )
		return;		// already registered, do nothing
	
	// the style needs to be unlocked in case we need to mutate its name - after registering it will be
	// locked.
		
	[aStyle setLocked:NO];

	// resolve any name conflicts, including not having a name, etc.
	
	DKStyleRegistry* reg = [self sharedStyleRegistry];
	NSAssert( reg != nil, @"cannot continue - registry could not be initialised");
	
	NSString* name = [aStyle name];
	
	// if name not set or empty, give it a default name
	
	if ( name == nil || [name isEqualToString:@""])
		name = NSLocalizedString(@"untitled style", @"untitled style name");
	
	// then make sure it's unique in the registry by appending digits
			
	name = [reg uniqueNameForName:name];
	[aStyle setName:name];
	
	// add the style to the registry
	
	[reg addObject:aStyle forKey:styleID toCategories:styleCategories createCategories:YES];
	
	LogEvent_(kStateEvent, @"registered new style %@; key = %@ '%@'", aStyle, [aStyle uniqueKey], [aStyle name]);
	
	// finally lock the style to prevent accidental edits to registered styles. (Edits are still possible if the style is unlocked first
	// but this makes sure that has to be a very deliberate act).
	
	[aStyle setLocked:YES];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleWasRegisteredNotification object:[self sharedStyleRegistry]];

	[self setNeedsUIUpdate];
}


///*********************************************************************************************************************
///
/// method:			registerStylesFromArray:inCategories:
/// scope:			public class method
/// overrides:
/// description:	register a list of styles with the registry
/// 
/// parameters:		<styles> an array of DKStyle objects to register
///					<styleCategories> a list of one or more categories to list the style in (list of NSStrings)
/// result:			none
///
/// notes:			see notes for registerStyle:
///					if the categories do not exist they are created.
///
///********************************************************************************************************************

+ (void)					registerStylesFromArray:(NSArray*) styles inCategories:(NSArray*) styleCategories
{
	[self registerStylesFromArray:styles inCategories:styleCategories ignoringDuplicateNames:NO];
}


///*********************************************************************************************************************
///
/// method:			registerStylesFromArray:inCategories:ignoringDuplicateNames:
/// scope:			public class method
/// overrides:
/// description:	register a list of styles with the registry
/// 
/// parameters:		<styles> an array of DKStyle objects to register
///					<styleCategories> a list of one or more categories to list the style in (list of NSStrings)
///					<ignoreDupes> if YES, styles whose names are already known are skipped.
/// result:			none
///
/// notes:			see notes for registerStyle:
///					if the categories do not exist they are created. Note that the "recently added" list is temporarily
///					disabled by this method, reflecting the intention that it is used for pre-registering a number of
///					styles in bulk.
///
///********************************************************************************************************************

+ (void)					registerStylesFromArray:(NSArray*) styles inCategories:(NSArray*) styleCategories ignoringDuplicateNames:(BOOL) ignoreDupes
{
	NSAssert( styles != nil, @"array of styles was nil - can't register");
	
	NSEnumerator*	iter = [styles objectEnumerator];
	DKStyle*		style;
	NSArray*		stNames = nil;
	
	[[self sharedStyleRegistry] setRecentlyAddedListEnabled:NO];
	
	while(( style = [iter nextObject]))
	{
		if( ignoreDupes )
		{
			if( stNames == nil )
				stNames = [[self sharedStyleRegistry] styleNames];
				
			if([stNames containsObject:[style name]])
				continue;
		}
		
		[self registerStyle:style inCategories:styleCategories];
	}
	
	[[self sharedStyleRegistry] setRecentlyAddedListEnabled:YES];
}


///*********************************************************************************************************************
///
/// method:			unregisterStyle:
/// scope:			public class method
/// overrides:
/// description:	remove the style from the registry
/// 
/// parameters:		<aStyle> the style to remove
/// result:			none
///
/// notes:			removed styles are still retained by an objects using them, so they are not dealloced unless
///					not in use by any clients at all.
///
///********************************************************************************************************************

+ (void)					unregisterStyle:(DKStyle*) aStyle
{
	[[self sharedStyleRegistry] removeObjectForKey:[aStyle uniqueKey]];
	[self setNeedsUIUpdate];
}


///*********************************************************************************************************************
///
/// method:			setNeedsUIUpdate
/// scope:			public class method
/// overrides:
/// description:	send a notification that the contents of the registry has changed so any UI displaying it should
///					be updated
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the notification's object is the shared style registry
///
///********************************************************************************************************************

+ (void)					setNeedsUIUpdate
{
	[[self sharedStyleRegistry] setNeedsUIUpdate];
}


+ (NSMenu*)					managedStylesMenuWithItemTarget:(id) target itemAction:(SEL) selector
{
	return [[self sharedStyleRegistry] managedStylesMenuWithItemTarget:target itemAction:selector];
}



#pragma mark -


///*********************************************************************************************************************
///
/// method:			mergeStyles:inCategories:options:mergeDelegate:
/// scope:			public class method
/// overrides:
/// description:	merge a set of styles with the registry
/// 
/// parameters:		<styles> a set of one or more styles
///					<styleCategories> a list of categories to add the styles to if they are added (one or more NSStrings)
///					<options> control flags for changing the preferred direction of merging, etc.
///					<aDel> an optional delegate object that can make a merge decision for each individual style object
/// result:			a set of styles that should replace those with the same key in whatever structure made the call.
///					can be nil if there is no need to do anything.
///
/// notes:			this method is for merging sets of styles read in with a document or file. The document will have
///					already sorted the loaded styles into those which were formerly registered and those which were not
///					- <styles> is the set that was. The doc may elect to create a category with the doc's name, this
///					can be passed in <styleCategories>. The options dictate how the merge is to be done - either doc
///					styles dominate or reg styles dominate, or else the doc styles are copied and reregistered afresh.
///					The returned set is the set that the document should use, and will need to replace styles in the
///					document with a matching uniqueKey with those in the set (thus if the reg dominates, it can in
///					this way update the document's contents). If the doc wishes to remove the category when it closes,
///					it can do so using the category manager API.
///
///********************************************************************************************************************

+ (NSSet*)					mergeStyles:(NSSet*) styles inCategories:(NSArray*) styleCategories options:(DKStyleMergeOptions) options mergeDelegate:(id) aDel
{
	NSAssert( styles != nil, @"cannot merge a nil set of styles");
	
	NSEnumerator*	iter = [styles objectEnumerator];
	DKStyle*		style;
	DKStyle*		regStyle;
	NSMutableSet*	changedStyles = nil;
	
	while(( style = [iter nextObject]))
	{
		// this option relates to the old registry's behaviour, and is mostly inappropriate for this one. Whether a style is sharable or not
		// generally has no connection to how it is registered in the current model.
		
		if ((options & kDKIgnoreUnsharedStyles) != 0 && ![style isStyleSharable])
			continue;
		
		// if the style is unknown to the registry, simply register it - in this case there's no need to do any complex merging or
		// further analysis.
		
		regStyle = [self styleForKey:[style uniqueKey]];
		
		if ( regStyle == nil )
			[self registerStyle:style inCategories:styleCategories];
		else
		{
			if (( options & kDKReplaceExistingStyles ) != 0 )
			{
				// style is known to us, so a merge is required, overwriting the registered style with the new one. Any clients of the
				// modified style will be updated automatically.
				
				regStyle = [[self sharedStyleRegistry] mergeFromStyle:style mergeDelegate:aDel];
				
				if ( regStyle != nil )
				{
					if ( changedStyles == nil )
						changedStyles = [NSMutableSet set];

					[changedStyles addObject:regStyle];
				
					// add to the requested categories if needed
				
					[[self sharedStyleRegistry] addKey:[regStyle uniqueKey] toCategories:styleCategories createCategories:YES];
				}
			}
			else if (( options & kDKReturnExistingStyles ) != 0)
			{
				// here the options request that the registered styles have priority, so the existing style is added to the return set
				
				if ( changedStyles == nil )
					changedStyles = [NSMutableSet set];
				
				[changedStyles addObject:regStyle];
			
				// add to the requested categories if needed
				
				[[self sharedStyleRegistry] addKey:[regStyle uniqueKey] toCategories:styleCategories createCategories:YES];
			}
			else if ((options & kDKAddStylesAsNewVersions) != 0 )
			{
				// here the options request that the document styles are to be re-registered as new styles. This leaves both document and
				// existing registered styles unaffected but can massively multiply the registry with many duplicates. In general this
				// options should be used sparingly, if at all.
				
				// to make these look like new styles, the unique key must be reassigned. Normally this is disallowed, but the style registry
				// has special privileges (and a special private method) to make it possible:
				
				[style reassignUniqueKey];
				[self registerStyle:style inCategories:styleCategories];
				
				// there's nothing to return in this case
			}
		}
	}
	
	[self setNeedsUIUpdate];
	
	return changedStyles;
}


///*********************************************************************************************************************
///
/// method:			compareStylesInSet:
/// scope:			public class method
/// overrides:
/// description:	preflight a set of styles against the registry for a possible future merge operation
/// 
/// parameters:		<styles> a set of styles
/// result:			a dictionary, listing for each style whether it is unknown, older, the same or newer than the
///					registry styles having the same keys.
///
/// notes:			this is a way to test a set of styles against the registry prior to a merge operation (preflight).
///					It compares each style in the set with the current registry, and returns a dictionary keyed off
///					the style's unique key. The values in the dictionary are NSNumbers indicating whether the style
///					is older, the same, newer or unknown. The caller can use this info to make decisions about a merge
///					before doing it, if they wish, or to present the info to the user.
///
///********************************************************************************************************************

+ (NSDictionary*)			compareStylesInSet:(NSSet*) styles
{
	NSAssert( styles != nil, @"can't preflight a nil set");
	
	NSMutableDictionary*	info = [NSMutableDictionary dictionary];
	NSEnumerator*			iter = [styles objectEnumerator];
	DKStyle*				style;
	DKStyle*				regStyle;
	NSString*				key;
	NSNumber*				infoValue;
	
	while(( style = [iter nextObject]))
	{
		key = [style uniqueKey];
		regStyle = [self styleForKey:key];
		
		if ( regStyle == nil )
		{
			// unknown style
			
			infoValue = [NSNumber numberWithInteger:kDKStyleNotRegistered];
		}
		else
		{
			// known - compare timestamps. Note that for timestamp comparison to work,
			// it is essential that the styles being tested have not in any way been touched
			// such that their timestamps have been bumped.
			
			NSTimeInterval a, b;
			
			a = [style lastModificationTimestamp];
			b = [regStyle lastModificationTimestamp];
			
			if ( a > b )
				infoValue = [NSNumber numberWithInteger:kDKStyleIsNewer];
			else if ( a < b )
				infoValue = [NSNumber numberWithInteger:kDKStyleIsOlder];
			else
				infoValue = [NSNumber numberWithInteger:kDKStyleUnchanged];
		}
		
		[info setObject:infoValue forKey:key];
	}
	
	return info;
}


///*********************************************************************************************************************
///
/// method:			registeredStyleKeys
/// scope:			public class method
/// overrides:
/// description:	return the entire list of keys of the styles in the registry
/// 
/// parameters:		none
/// result:			an array listing all of the keys in the registry
///
/// notes:			
///
///********************************************************************************************************************

+ (NSArray*)				registeredStyleKeys
{
	return [[self sharedStyleRegistry] allKeysInCategory:kDKDefaultCategoryName];
}


///*********************************************************************************************************************
///
/// method:			registeredStylesData
/// scope:			public class method
/// overrides:
/// description:	return data that can be saved to a file, etc. representing the registry
/// 
/// parameters:		none
/// result:			NSData of the entire registry
///
/// notes:			
///
///********************************************************************************************************************

+ (NSData*)					registeredStylesData
{
	return [[self sharedStyleRegistry] data];
}


///*********************************************************************************************************************
///
/// method:			saveDefaults
/// scope:			public class method
/// overrides:
/// description:	saves the registry to the current user defaults
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

+ (void)					saveDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[self registeredStylesData] forKey:@"DKStyleRegistry_stylesLibrary"];
}


///*********************************************************************************************************************
///
/// method:			loadDefaults
/// scope:			public class method
/// overrides:
/// description:	loads the registry from the current user defaults
/// 
/// parameters:		none
/// result:			none
///
/// notes:			if used, this should be called early in the application launch sequence
///
///********************************************************************************************************************

+ (void)					loadDefaults
{
	NSData*	lib = [[NSUserDefaults standardUserDefaults] objectForKey:@"DKStyleRegistry_stylesLibrary"];
	
	if ( lib )
		[[self sharedStyleRegistry] appendContentsWithData:lib];
}


///*********************************************************************************************************************
///
/// method:			resetRegistry
/// scope:			public class method
/// overrides:
/// description:	reset the registry back to a "first run" condition
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this removes ALL styles from the registry, thereby unregistering them. It then starts over with
///					the DK defaults. This puts the registry into the same state that it was in on the very first run
///					of the client app, when there are no saved defaults. This method should be used carefully - the
///					caller may want to confirm the action beforehand with the user.
///
///********************************************************************************************************************

+ (void)					resetRegistry
{
	[[self sharedStyleRegistry] removeAllStyles];
	
	// reinsert the framework defaults
	
	if( !s_NoDKDefaults)
	{
		NSArray*		defaultCategories = [NSArray arrayWithObject:kDKStyleRegistryDKDefaultsCategory];
		DKStyle* style;
		
		style = [DKStyle defaultStyle];
		if ( style != nil )
		{
			[style setLocked:NO];
			[self registerStyle:style inCategories:defaultCategories];
		}
		
		style = [DKStyle defaultTrackStyle];
		if ( style != nil )
		{
			[style setLocked:NO];
			[self registerStyle:style inCategories:defaultCategories];
		}
		
		style = [DKStyle defaultTextStyle];
		if ( style != nil )
		{
			[style setLocked:NO];
			[self registerStyle:style inCategories:defaultCategories];
		}
	}

	[self setNeedsUIUpdate];
}


///*********************************************************************************************************************
///
/// method:			registerSolidColourFillsFromListNamed:asCategory:
/// scope:			public class method
/// overrides:
/// description:	creates a series of fill styles having the solid colours given by the named NSColorList, and
///					adds them to the registry using the named category.
/// 
/// parameters:		<name> the name of a NSColorList
///					<catName> the name of the registry category - if nil, use the colorList name
/// result:			none
///
/// notes:			the named color list must exist - see [NSColorList availableColorLists];
///
///********************************************************************************************************************

+ (void)					registerSolidColourFillsFromListNamed:(NSString*) name asCategory:(NSString*) catName
{
	NSAssert( name != nil, @"colour list name was nil" );
	
	//NSLog(@"loading colours from '%@'", name );
	
	NSColorList* list = [NSColorList colorListNamed:name];
	
	if( catName == nil )
		catName = name;
	
	if ( list != nil )
	{
		NSEnumerator*	iter = [[list allKeys] objectEnumerator];
		NSColor*		colour;
		NSString*		key;
		DKStyle*		style;
		NSArray*		cats;
		NSMutableArray*	styles = [NSMutableArray array];
		
		cats = [NSArray arrayWithObject:catName];
		
		while(( key = [iter nextObject]))
		{
			colour = [list colorWithKey:key];
			
			style = [DKStyle styleWithFillColour:colour strokeColour:nil];
			
			if( style != nil )
			{
				[style setName:[NSString stringWithFormat:@"%@ - fill", key]];
				[styles addObject:style];
			}
		}
		
		[self registerStylesFromArray:styles inCategories:cats ignoringDuplicateNames:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			registerSolidColourStrokesFromListNamed:asCategory:
/// scope:			public class method
/// overrides:
/// description:	creates a series of stroke styles having the solid colours given by the named NSColorList, and
///					adds them to the registry using the named category.
/// 
/// parameters:		<name> the name of a NSColorList
///					<catName> the name of the registry category - if nil, use the colorList name
/// result:			none
///
/// notes:			the named color list must exist - see [NSColorList availableColorLists];
///
///********************************************************************************************************************

+ (void)					registerSolidColourStrokesFromListNamed:(NSString*) name asCategory:(NSString*) catName
{
	NSAssert( name != nil, @"colour list name was nil" );
	
	NSColorList* list = [NSColorList colorListNamed:name];
	
	if( catName == nil )
		catName = name;
	
	if ( list != nil )
	{
		NSEnumerator*	iter = [[list allKeys] objectEnumerator];
		NSColor*		colour;
		NSString*		key;
		DKStyle*		style;
		NSArray*		cats;
		NSMutableArray*	styles = [NSMutableArray array];
		
		cats = [NSArray arrayWithObject:catName];
		
		while(( key = [iter nextObject]))
		{
			colour = [list colorWithKey:key];
			
			style = [DKStyle styleWithFillColour:nil strokeColour:colour];
			
			if( style != nil )
			{
				[style setName:[NSString stringWithFormat:@"%@ - stroke", key]];
				[styles addObject:style];
			}
		}
		[self registerStylesFromArray:styles inCategories:cats ignoringDuplicateNames:YES];

	}
}


///*********************************************************************************************************************
///
/// method:			setShouldNotAddDKDefaultCategory:
/// scope:			public class method
/// overrides:
/// description:	sets whether DK defaults category containing the default styles shoul dbe registered when the
///					registry is built or reset
/// 
/// parameters:		<noDKDefaults> YES to turn OFF the defaults
/// result:			none
///
/// notes:			see +resetRgistry
///
///********************************************************************************************************************

+ (void)					setShouldNotAddDKDefaultCategory:(BOOL) noDKDefaults;
{
	s_NoDKDefaults = noDKDefaults;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			styleNameForKey:
/// scope:			public instance method
/// overrides:
/// description:	return the style's name given its key
/// 
/// parameters:		<styleID> the style's key
/// result:			the style's name
///
/// notes:			the name can be used in a user interface, but the key should not. This gives you an easy way to
///					get one from the other if you don't have the style object itself. If the key is unknown to the
///					registry, nil is returned.
///
///********************************************************************************************************************

- (NSString*)				styleNameForKey:(NSString*) styleID
{
	return [[self styleForKey:styleID] name];
}



///*********************************************************************************************************************
///
/// method:			styleForKey:
/// scope:			public instance method
/// overrides:
/// description:	return the style given its key
/// 
/// parameters:		<styleID> the style's key
/// result:			the style
///
/// notes:			
///
///********************************************************************************************************************

- (DKStyle*)			styleForKey:(NSString*) styleID
{
	return [self objectForKey:styleID];
}


///*********************************************************************************************************************
///
/// method:			stylesInCategories:
/// scope:			public instance method
/// overrides:
/// description:	return the set of styles in the given categories
/// 
/// parameters:		<cats> a list of one or more categories
/// result:			a set, all of the styles in the requested categories
///
/// notes:			being a set, the result is unordered. The result may be the empty set if the categories are unknown
///					or empty, and may contain NSNull objects if the style registry is in a state where objects have been
///					removed and the category lists not updated (in normal use this should not occur).
///
///********************************************************************************************************************

- (NSSet*)					stylesInCategories:(NSArray*) cats
{
	return [NSSet setWithArray:[self objectsInCategories:cats]];
}


///*********************************************************************************************************************
///
/// method:			uniqueNameForName:
/// scope:			public instance method
/// overrides:
/// description:	return a modified name to resolve a collision with names already in use
/// 
/// parameters:		<name> a candidate name
/// result:			the same string if no collisiosn, or a modified copy if there was
///
/// notes:			names of styles are changed when a style is registerd to avoid a collision with any already
///					registered styles. Names are not keys and this doesn't guarantee uniqueness - it's merely a
///					courtesy to the user.
///
///********************************************************************************************************************

- (NSString*)				uniqueNameForName:(NSString*) name
{
	// if <name> already exists among the registerd styles, append a number to it until it is not found.
	
	NSInteger			numeral = 0;
	BOOL		found = YES;
	NSString*	temp = name;
	NSArray*	keys = [self styleNames];
	
	while( found )
	{
		NSInteger	k = [keys indexOfObject:temp];
		
		if ( k == NSNotFound )
			found = NO;
		else
			temp = [NSString stringWithFormat:@"%@ %ld", name, (long)++numeral];
	}
	
	return temp;
}



///*********************************************************************************************************************
///
/// method:			styleNames
/// scope:			public instance method
/// overrides:
/// description:	return a list of all the registered styles' names, in alphabetical order
/// 
/// parameters:		none
/// result:			a list of names
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)				styleNames
{
	NSEnumerator*	iter = [[self allObjects] objectEnumerator];
	DKStyle*		style;
	NSMutableArray*	names = [NSMutableArray array];
	
	while(( style = [iter nextObject]))
		[names addObject:[style name]];
	
	[names sortUsingSelector:@selector(caseInsensitiveCompare:)];

	return names;
}


///*********************************************************************************************************************
///
/// method:			styleNamesInCategory:
/// scope:			public instance method
/// overrides:
/// description:	return a list of the registered styles' names in the category, in alphabetical order
/// 
/// parameters:		<catName> the name of a single category
/// result:			a list of names
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)				styleNamesInCategory:(NSString*) catName
{
	// returns an alphabetical list of the styles' names in the given category
	
	NSEnumerator*	iter = [[self allKeysInCategory:catName] objectEnumerator];
	NSMutableArray* names = [NSMutableArray array];
	NSString*		key;
	
	while(( key = [iter nextObject]))
		[names addObject:[self styleNameForKey:key]];
		
	[names sortUsingSelector:@selector(localisedCaseInsensitiveNumericCompare:)];
	
	return names;
}


///*********************************************************************************************************************
///
/// method:			writeToFile:atomically:
/// scope:			public instance method
/// overrides:
/// description:	write the registry to a file
/// 
/// parameters:		<path> the full path of the file to write
///					<atom> YES to save safely, NO to overwrite in place
/// result:			YES if the file was saved sucessfully, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)					writeToFile:(NSString*) path atomically:(BOOL) atom
{
	NSAssert( path != nil, @"path can't be nil");
	
	BOOL result = NO;
	
	NSData* data = [self data];
	if ( data != nil )
		result = [data writeToFile:path atomically:atom];
		
	return result;
}


///*********************************************************************************************************************
///
/// method:			readFromFile:mergeOptions:mergeDelegate:
/// scope:			public instance method
/// overrides:
/// description:	merge the contents of a file into the registry
/// 
/// parameters:		<path> the full path of the file to write
///					<options> merging options
///					<aDel> an optional delegate object that can make a merge decision for each individual style object 
/// result:			YES if the file was read and merged sucessfully, NO otherwise
///
/// notes:			reads styles from the file at <path> into the registry. Styles are merged as indicated by the
///					options, etc. The intention of this method is to load a file containing styles only - either to
///					augment or replace the existing registry. It is not used when opening a drawing document.
///					If the intention is to replace the reg, the caller should clear out the current one before calling this.
///
///********************************************************************************************************************

- (BOOL)					readFromFile:(NSString*) path mergeOptions:(DKStyleMergeOptions) options mergeDelegate:(id) aDel
{
	NSAssert( path != nil, @"cannot read file - path is nil");
	
	BOOL	readOK = NO;
	NSData* styleData = [NSData dataWithContentsOfFile:path];
	
	if ( styleData != nil && [styleData length] > 0 )
	{
		// because we are merging the file, a temporary registry object is created and that is used to populate the "real" one.
		
		DKStyleRegistry* regTemp = [[DKStyleRegistry alloc] initWithData:styleData];
		
		if ( regTemp != nil )
		{
			NSEnumerator*	iter = [[regTemp allObjects] objectEnumerator];
			DKStyle*	style;
			NSSet*			styles;
			NSArray*		cats;
			
			while(( style = [iter nextObject]))
			{
				cats = [regTemp categoriesContainingKey:[style uniqueKey]];
				styles = [NSSet setWithObject:style];

				[[self class] mergeStyles:styles inCategories:cats options:options mergeDelegate:aDel];
					
				readOK = YES;
			}
			
			[regTemp release];
		}
	}
	
	return readOK;
}


///*********************************************************************************************************************
///
/// method:			mergeFromStyle:mergeDelegate:
/// scope:			public instance method
/// overrides:
/// description:	attempt to merge a style into the registry
/// 
/// parameters:		<aStyle> a style object
///					<aDel> an optional delegate object that can make a merge decision for each individual style object 
/// result:			a style if the merge modified an existing one, otherwise nil
///
/// notes:			given <aStyle>, and a registered style having the same key, this replaces the contents of the
///					registered style with the contents of <aStyle>, provided they really are different objects. This
///					is done when merging styles in from a document where initially copies of formerly registered
///					styles exist. By replacing the contents, there is no need for clients that own the style to have
///					to adopt the new style - instead they are just  notified of the change. The modified style is
///					returned so that it can replace the temporary style in the specific document that is performing
///					the merge - the document contains the only set of style clients that need actual new objects.
///
///********************************************************************************************************************

- (DKStyle*)			mergeFromStyle:(DKStyle*) aStyle mergeDelegate:(id) aDel
{
	NSAssert( aStyle != nil, @"attempting to merge nil style");
	
	DKStyle* existingStyle = [self styleForKey:[aStyle uniqueKey]];
	
	if ( existingStyle == nil || existingStyle == aStyle )
		return nil;		// this is really an error - the style is already registered, or is unregistered
		
	// if the timestamps of the styles are the same, there's nothing to do as no modification has been done to the style -
	// so only replace the internals of the style if really needed
	
	if ([aStyle lastModificationTimestamp] != [existingStyle lastModificationTimestamp])
	{	
		// before we commit to this, ask the delegate. The delegate can compare the timestamps and go with newer or older as desired.
		
		DKStyle* repStyle = aStyle;
		
		if (aDel != nil && [aDel respondsToSelector:@selector(registry:shouldReplaceStyle:withStyle:)])
			repStyle = [aDel registry:self shouldReplaceStyle:existingStyle withStyle:aStyle];
		
		// if the delegate returned the existing style, there's nothing to do except return it
				
		if ( repStyle != existingStyle )
		{
			LogEvent_(kReactiveEvent, @"will swap guts of %@ with %@; key = %@ '%@'", existingStyle, repStyle, [repStyle uniqueKey], [existingStyle name]);
		
			// about to swap out the guts of the style - notify any clients
					
			[existingStyle notifyClientsBeforeChange];
			NSArray* guts = [repStyle renderList];
			
			// avoid propagating a damaged style - better to go with what we have in that case
			
			if ( guts != nil )
				[existingStyle setRenderList:guts];
			
			// set the contents of the style being merged to nil so that they cannot be accidentally mutated
			
			[aStyle setRenderList:nil];
			
			// also replace any text attributes
			
			NSDictionary* textAttrs = [repStyle textAttributes];
			[existingStyle setTextAttributes:textAttrs];
			[aStyle setTextAttributes:nil];
			
			// the existing style retains the same name and other status flags
			
			[existingStyle notifyClientsAfterChange];
			
			// drawing *should* now replace the temporary styles with the existing ones as returned, but to help prompt the programmer/user
			// that things haven't gone to plan if this doesn't take place, set the name of the old style to something different
			
			[aStyle setName:@"Temp style - if you can read this the programmer forgot something!"];
		}
	}
	return existingStyle;
}


///*********************************************************************************************************************
///
/// method:			removeAllStyles
/// scope:			public instance method
/// overrides:
/// description:	set the registry empty
/// 
/// parameters:		none
/// result:			none
///
/// notes:			removes all styles from the registry, clears the "recently added" and "recently used" lists, and
///					removes all categories except the default category.
///
///********************************************************************************************************************

- (void)					removeAllStyles
{
	// called from the +resetRegistry method - simply discards everything then reinserts the defaults. For efficiency does not iterate over the objects.
	
	[self removeAllCategories];
	[self addDefaultCategories];
}



- (void)					setNeedsUIUpdate
{
	// UI clients can listen for this notification and update any UI that relies on the registry. Note that this is not required if you are using managed menus
	// sincethey are automaticaly kept up to date as the registry changes. This notification is only needed for other UIs that display the registry.

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleRegistryDidFlagPossibleUIChange object:self];
}



+ (void)					setStyleNotificationsEnabled:(BOOL) enable
{
	// typically the style registry will need to observe style changes but in many cases this isn't needed and adds an overhead that you might
	// prefer to do without. Thus this must be explicitly enabled as needed. Default is OFF, which differs from b5 and earlier.
	
	if( enable )
	{
		[[NSNotificationCenter defaultCenter] addObserver:[self sharedStyleRegistry] selector:@selector(styleDidChange:) name:kDKStyleDidChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:[self sharedStyleRegistry] selector:@selector(styleDidChange:) name:kDKStyleNameChangedNotification object:nil];
	}
	else
		[[NSNotificationCenter defaultCenter] removeObserver:[self sharedStyleRegistry]];
}


- (void)					styleDidChange:(NSNotification*) note
{
	// when any style changes, this is notified. If the style is in the registry, use its key to update any managed menus directly.
	// doing this is significantly more efficient than just rebuilding the entire menu, as only the individual menu items affected
	// are touched. In fact if your registry UI is only a cat manager menu, there is no longer any external management required
	// apart from implementing the callback protocol.

	DKStyle* style = [note object];
	NSString* key = [style uniqueKey];
	
	if([self styleForKey:key] == style)
	{
		[self updateMenusForKey:key];
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObject:style forKey:@"style"];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleWasEditedWhileRegisteredNotification object:self userInfo:userInfo];
	}
}



///*********************************************************************************************************************
///
/// method:			newManagedStylesMenuWithItemTarget:itemAction:
/// scope:			public instance method
/// overrides:
/// description:	creates a new fully managed menu that lists all the styles, organised into categories.
/// 
/// parameters:		<target> the target object assigned to each menu item
///					<selector> the action sent by each menu item
/// result:			a menu
///
/// notes:			the returned menu is fully managed, that is, the Style Registry keeps it in synch with all changes
///					to the registry and to the styles themselves. The menu can be assigned to UI controls such as a
///					pop-up button. Each menu item sends the same target/action as specified here. The item's
///					represented object is the style, and the item shows a swatch and the style's name. The menus
///					are ordered alphabetically.
///
///					This is intended as a very high-level method to support the most common usage. If you need to pass
///					different options or wish to handle each item differently, DKCategoryManager has more flexible
///					methods that expose more detail.
///
///********************************************************************************************************************

- (NSMenu*)					managedStylesMenuWithItemTarget:(id) target itemAction:(SEL) selector
{
	DKCategoryMenuOptions options = kDKIncludeRecentlyAddedItems | kDKIncludeRecentlyUsedItems | kDKMenuIsPopUpMenu;
	
	return [self createMenuWithItemDelegate:self itemTarget:target itemAction:selector options:options];
}


#pragma mark -
#pragma mark As a DKCategoryManager

///*********************************************************************************************************************
///
/// method:			allSortedKeysInCategory:
/// scope:			public instance method
/// overrides:		DKCategoryManager
/// description:	return the keys in the given category sorted appropriately for a UI
/// 
/// parameters:		<catName> the name of a category
/// result:			a list of the keys in the category, sorted alphabetically by the name of the styles to which they refer
///
/// notes:			this is called by the UI/Menu building methods so that the keys are arranged by style name
///
///********************************************************************************************************************

- (NSArray*)				allSortedKeysInCategory:(NSString*) catName
{
	NSAssert( catName != nil, @"cannot have a nil category name");
	
	NSArray* keys = [self allKeysInCategory:catName];
	return [keys sortedArrayUsingFunction:SortKeysByReferredName context:self];
}

///*********************************************************************************************************************
///
/// method:			allSortedNamesInCategory:
/// scope:			public method
/// overrides:
/// description:	return all of the names in a given category, sorted into some useful order
/// 
/// parameters:		<catName> the category name
/// result:			an array, the list of names indicated by the category. May be empty.
///
/// notes:			Returns a list of sorted style names in the category
///
///********************************************************************************************************************

- (NSArray*)			allSortedNamesInCategory:(NSString*) catName
{
	return [self styleNamesInCategory:catName];
}


///*********************************************************************************************************************
///
/// method:			fileType
/// scope:			public method
/// overrides:
/// description:	return the filetype (for saving, etc)
/// 
/// parameters:		none
/// result:			a string, the filetype of the saved/opened data
///
/// notes:			subclasses should override to change the filetype used for specific examples of this object
///
///********************************************************************************************************************

- (NSString*)			fileType
{
	return @"stylelib";
}


///*********************************************************************************************************************
///
/// method:			categoryManagerKeyForObject
/// scope:			public method
/// overrides:		DKCategoryManager
/// description:	return the key appropriate to the object being merged/added
/// 
/// parameters:		<obj> an object being added
/// result:			the object's key for managing it within the registry
///
/// notes:			
///
///********************************************************************************************************************

+ (NSString*)			categoryManagerKeyForObject:(id) obj
{
	return [obj uniqueKey];
}




#pragma mark -
#pragma mark - as a CategoryManagerMenuItemDelegate

- (void)			menuItem:(NSMenuItem*) item wasAddedForObject:(id) object inCategory:(NSString*) category
{
	#pragma unused(category)
	
	if( object == self )
	{
		[item setTitle:NSLocalizedString(@"Style", @"")];
	}
	else
	{
		// fetch swatch at a large size and scale down to menu icon size - this gives a better impression of most styles
		// than trying to render the icon at 1:1 size using the style
		
		if( object != nil && [object isKindOfClass:[DKStyle class]])
		{
			NSImage* swatch = [[object styleSwatchWithSize:NSMakeSize( 112, 112 ) type:kDKStyleSwatchAutomatic] copy];
			
			if( swatch != nil )
			{
				[swatch setScalesWhenResized:YES];
				[swatch setSize:NSMakeSize( 28, 28 )];
				[swatch lockFocus];
				[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationLow];
				[swatch unlockFocus];
				[item setImage:swatch];
				[swatch release];
			}
			
			// set the menu item to the object's name
			
			if ([object name] != nil )
				[item setTitle:[object name]];
		}
	}
}



#pragma mark -
#pragma mark As a NSObject


- (void)					dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


@end


#pragma mark -

@implementation DKStyle (RegistrySpecialPrivileges)

///*********************************************************************************************************************
///
/// method:			reassignUniqueKey
/// scope:			very private method
/// overrides:		
/// description:	reassigns a style's unique key
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this is a very special privileged operation that client code must not use. UniqueKeys are assigned
///					once for all time when a style is initialized - the style registry has one special situation where
///					a key needs to be reassigned and this method gives it a way to do it. DO NOT USE!
///
///********************************************************************************************************************

- (void)		reassignUniqueKey
{
	[m_uniqueKey release];
	m_uniqueKey = [[DKUniqueID uniqueKey] retain];
}


@end

#pragma mark -

@implementation NSObject (DKStyleRegistryDelegate)

///*********************************************************************************************************************
///
/// method:			registry:shouldReplaceStyle:withStyle:
/// scope:			delegate callback method
/// overrides:		
/// description:	determines which of a pair of styles should be used over the other
/// 
/// parameters:		<reg> the registry making the call
///					<regStyle> the currently registered style in question
///					<docStyle> a style having the same key that has been loaded, which may be older, newer or the same
/// result:			the style that should prevail
///
/// notes:			a delegate can implement this method and return whichever of the two styles it thinks should be used
///					in preference to the other. It can compare timestamps, contents or any other property of the style
///					to work this out. The default implementation simply returns <docStyle>, which is what the merge does
///					anyway in the case of having no delegate.
///	
///					note that the calling code permits this method to return a completely different style whose contents
///					will be used to replace <regStyle>. However this is a very unusual and specialised usage.
///
///********************************************************************************************************************

- (DKStyle*)		registry:(DKStyleRegistry*) reg shouldReplaceStyle:(DKStyle*) regStyle withStyle:(DKStyle*) docStyle
{
	#pragma unused(reg)
	#pragma unused(regStyle)
	
	return docStyle;
}

@end

