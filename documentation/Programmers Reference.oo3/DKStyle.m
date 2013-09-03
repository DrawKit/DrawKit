///**********************************************************************************************************************************
///  DKStyle.m
///  DrawKit
///
///  Created by graham on 13/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKStyle.h"
#import "DKStyleRegistry.h"
#import "DKFill.h"
#import "DKFillPattern.h"
#import "DKHatching.h"
#import "DKRoughStroke.h"
#import "DKStyleReader.h"
#import "DKTextAdornment.h"
#import "DKGradient.h"
#import "LogEvent.h"
#import "NSColor+DKAdditions.h"
#import "NSDictionary+DeepCopy.h"
#import "DKUndoManager.h"
#import "DKUniqueID.h"
#import "DKImageAdornment.h"
#import "DKDrawablePath.h"

#pragma mark Contants (Non-localized)

NSString*		kDKStylePasteboardType					= @"net.apptree.drawkit.style";
NSString*		kDKStyleKeyPasteboardType				= @"net.apptree.drawkit.stylekey";

NSString*		kDKStyleWillChangeNotification			= @"kGCDrawingStyleWillChangeNotification";
NSString*		kDKStyleDidChangeNotification			= @"kGCDrawingStyleDidChangeNotification";
NSString*		kDKStyleWasAttachedNotification			= @"kGCDrawingStyleWasAttachedNotification";
NSString*		kDKStyleWillBeDetachedNotification		= @"kGCDrawingStyleWillBeDetachedNotification";
NSString*		kDKStyleLockStateChangedNotification	= @"kDKStyleLockStateChangedNotification";
NSString*		kDKStyleSharableFlagChangedNotification = @"kDKStyleSharableFlagChangedNotification";
NSString*		kDKStyleNameChangedNotification			= @"kDKStyleNameChangedNotification";

// the fixed default styles need to have a predetermined (but still unique) key. We define them here.
// Do not change or interpret these values.

static NSString* kDKBasicStyleDefaultKey				= @"1DFD6D8A-6C8B-4E4B-9186-90F64654F79F";
static NSString* kDKBasicTrackStyleDefaultKey			= @"6B1A0430-204A-4012-B96D-A4EE9890A2A3";

#pragma mark Static Vars

static BOOL					sStylesShared = YES;
static NSMutableDictionary*	sPasteboardRegistry = nil;


#pragma mark -
@implementation DKStyle
#pragma mark As a DKStyle
///*********************************************************************************************************************
///
/// method:			defaultStyle
/// scope:			public class method
/// overrides:
/// description:	returns a very basic style object
/// 
/// parameters:		none
/// result:			a style object
///
/// notes:			style has a 1 pixel black stroke and a light gray fill. Style may be shared if sharing is YES.
///
///********************************************************************************************************************

+ (DKStyle*)		defaultStyle
{
	DKStyle* basic = [DKStyleRegistry styleForKey:kDKBasicStyleDefaultKey];

	if ( basic == nil )
	{
		basic = [self styleWithFillColour:[NSColor veryLightGrey] strokeColour:[NSColor blackColor]];
		[basic setName:NSLocalizedString(@"Basic", @"default name for basic style")];
		
		// because this is a framework default, its unique key must always be recreated the same. This is not something any client
		// code or other part of the framework should ever attempt.
		
		basic->m_uniqueKey = kDKBasicStyleDefaultKey;
		
		[DKStyleRegistry registerStyle:basic inCategories:[NSArray arrayWithObject:kDKStyleRegistryDKDefaultsCategory]];
	}

	return basic;
}


///*********************************************************************************************************************
///
/// method:			defaultTrackStyle
/// scope:			public class method
/// overrides:
/// description:	returns a basic style with a dual stroke, 5.6pt light grey over 8.0pt black
/// 
/// parameters:		none
/// result:			a style object
///
/// notes:			Style may be shared if sharing is YES.
///
///********************************************************************************************************************

+ (DKStyle*)		defaultTrackStyle
{
	DKStyle* deftrack = [DKStyleRegistry styleForKey:kDKBasicTrackStyleDefaultKey];
	
	if ( deftrack == nil )
	{
		deftrack = [[DKStyle styleWithFillColour:nil strokeColour:[NSColor blackColor] strokeWidth:8.0] retain];
		[deftrack addRenderer:[DKStroke strokeWithWidth:5.6 colour:[NSColor veryLightGrey]]];
		
		[deftrack setName:NSLocalizedString(@"Basic Track", @"default name for basic track style")];
		
		// because this is a framework default, its unique key must always be recreated the same. This is not something any client
		// code or other part of the framework should ever attempt.

		deftrack->m_uniqueKey = kDKBasicTrackStyleDefaultKey;
		
		[DKStyleRegistry registerStyle:deftrack inCategories:[NSArray arrayWithObject:kDKStyleRegistryDKDefaultsCategory]];
	}
	
	return deftrack;
}


#pragma mark -
#pragma mark - easy construction of other simple styles
///*********************************************************************************************************************
///
/// method:			styleWithFillColour:strokeColour:
/// scope:			public class method
/// overrides:
/// description:	creates a simple style with fill and strokes of the colours passed
/// 
/// parameters:		<fc> the colour for the solid fill
///					<sc> the colour for the 1.0 pixel wide stroke
/// result:			a style object
///
/// notes:			stroke is drawn "on top" of fill, so rendered width appears true. You can pass nil for either
///					colour to not create the renderer for that attribute, but note that passing nil for BOTH parameters
///					is an error.
///
///********************************************************************************************************************

+ (DKStyle*)		styleWithFillColour:(NSColor*) fc strokeColour:(NSColor*) sc
{
	return [self styleWithFillColour:fc strokeColour:sc strokeWidth:1.0];
}


///*********************************************************************************************************************
///
/// method:			styleWithFillColour:strokeColour:strokeWidth:
/// scope:			public class method
/// overrides:
/// description:	creates a simple style with fill and strokes of the colours passed
/// 
/// parameters:		<fc> the colour for the solid fill
///					<sc> the colour for the stroke
///					<sw> the width of the stroke
/// result:			a style object
///
/// notes:			stroke is drawn "on top" of fill, so rendered width appears true. You can pass nil for either
///					colour to not create the renderer for that attribute, but note that passing nil for BOTH parameters
///					is an error.
///
///********************************************************************************************************************
+ (DKStyle*)		styleWithFillColour:(NSColor*) fc strokeColour:(NSColor*) sc strokeWidth:(float) sw
{
	if( fc == nil && sc == nil )
		[NSException raise:NSInvalidArgumentException format:@"bad argument to [DKStyle styleWithFillColour:strokeColour:] - both colours are nil"];
	
	DKStyle* style = [[DKStyle alloc] init];
	
	if ( fc )
	{
		DKFill* fill = [DKFill fillWithColour:fc];
		[style addRenderer:fill];
	}
	
	if ( sc )
	{
		DKStroke* stroke = [DKStroke strokeWithWidth:sw colour:sc];
		[style addRenderer:stroke];
	}
	
	return [style autorelease];
}


///*********************************************************************************************************************
///
/// method:			styleWithScript:
/// scope:			public class method
/// overrides:
/// description:	creates a style by parsing the style script passed
/// 
/// parameters:		<spec> a properly formatted style script string
/// result:			a style object
///
/// notes:			please see documentation for full description of style scripts
///
///********************************************************************************************************************

+ (DKStyle*)		styleWithScript:(NSString*) spec
{
	NSLog(@"**** WARNING: style scripting is going away - please consider contructing your style in another manner ****");
	
	return (DKStyle*)[DKRastGroup rasterizerGroupWithStyleScript:spec];
}


///*********************************************************************************************************************
///
/// method:			styleFromPasteboard:
/// scope:			public class method
/// overrides:
/// description:	creates a style from data on the pasteboard
/// 
/// parameters:		<pb> a pasteboard
/// result:			a style object
///
/// notes:			Preferentially tries to match the style name in order to preserve style sharing
///
///********************************************************************************************************************

+ (DKStyle*)		styleFromPasteboard:(NSPasteboard*) pb
{
	NSString*		sname = [pb stringForType:kDKStyleKeyPasteboardType];
	DKStyle*	style = [self styleWithPasteboardName:sname];
	
	if ( style == nil )
	{
		// the name isn't known, so fall back on using the archived style data
		
		NSData* sd = [pb dataForType:kDKStylePasteboardType];
		
		if ( sd )
			style = [NSKeyedUnarchiver unarchiveObjectWithData:sd];
	}
	
	return style;
}


#pragma mark -
#pragma mark - pasted styles - separate non-persistent registry
+ (DKStyle*)		styleWithPasteboardName:(NSString*) name
{
	// look for the style in the pasteboard registry. If not there, look in the main registry.
	
	DKStyle*	style = nil;
	
	if ( sPasteboardRegistry )
		style = [sPasteboardRegistry objectForKey:name];

	if( style == nil )
		style = [DKStyleRegistry styleForKey:name];
		
	return style;
}


+ (void)				registerStyle:(DKStyle*) style withPasteboardName:(NSString*) pbname
{
	// put the style into the pasteboard registry
	
	LogEvent_(kStateEvent, @"saving key for paste: %@ '%@'", pbname, [style name]);
	
	if ( sPasteboardRegistry == nil )
		sPasteboardRegistry = [[NSMutableDictionary alloc] init];
		
	[sPasteboardRegistry setObject:style forKey:pbname];
}


#pragma mark -
#pragma mark - default sharing flag
///*********************************************************************************************************************
///
/// method:			setStylesAreSharableByDefault:
/// scope:			public class method
/// overrides:
/// description:	set whether styles are generally shared or not
/// 
/// parameters:		<share> YES to share styles, NO to return unique copies.
/// result:			none
///
/// notes:			sharing styles means that all object that share that style will change when a style property changes,
///					regardless of any other state information, such as selection, layer owner, etc. Styles are set
///					NOT to be shared by default.
///
///********************************************************************************************************************

+ (void)				setStylesAreSharableByDefault:(BOOL) share
{
	sStylesShared = share;
}


///*********************************************************************************************************************
///
/// method:			stylesAreSharableByDefault
/// scope:			public class method
/// overrides:
/// description:	query whether styles are generally shared or not
/// 
/// parameters:		none
/// result:			YES if styles are shared, NO if unique copies will be returned
///
/// notes:			Styles are set NOT to be shared by default.
///
///********************************************************************************************************************

+ (BOOL)				stylesAreSharableByDefault
{
	return sStylesShared;
}


#pragma mark -
#pragma mark - convenient handy things
///*********************************************************************************************************************
///
/// method:			defaultShadow
/// scope:			public class method
/// overrides:
/// description:	returns a default NSShadow object
/// 
/// parameters:		none
/// result:			a shadow object
///
/// notes:			shadows are set as properties of certain renderers, such as DKFill and DKStroke
///
///********************************************************************************************************************

+ (NSShadow*)			defaultShadow
{
	static NSShadow* shadw = nil;
	
	if ( shadw == nil )
	{
		shadw = [[NSShadow alloc] init];
		
		[shadw setShadowColor:[NSColor rgbGrey:0.0 withAlpha:0.5]];
		[shadw setShadowBlurRadius:10.0];
		[shadw setShadowOffset:NSMakeSize( 6, 6)];
	}
	
	return shadw;
}


#pragma mark -
#pragma mark - updating & notifying clients
///*********************************************************************************************************************
///
/// method:			notifyClientsBeforeChange
/// scope:			protected method
/// overrides:		
/// description:	informs clients that a property of the style is about to change
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				notifyClientsBeforeChange
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleWillChangeNotification object:self];
}


///*********************************************************************************************************************
///
/// method:			notifyClientsAfterChange
/// scope:			protected method
/// overrides:		
/// description:	informs clients that a property of the style has just changed
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this method is called in response to any observed change to any renderer the style contains
///
///********************************************************************************************************************

- (void)				notifyClientsAfterChange
{
	// update the timestamp so that style registry can determine which of a pair of similar styles is the more recent
	
	m_lastModTime = [NSDate timeIntervalSinceReferenceDate];

	// invalidate any swatch cache to ensure cache is forced to be rebuilt after a change
	
	[mSwatchCache removeAllObjects];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleDidChangeNotification object:self];
}


///*********************************************************************************************************************
///
/// method:			styleWasAttached:
/// scope:			public method
/// overrides:		
/// description:	called when a style is attached to an object
/// 
/// parameters:		<toObject> the object the style was attached to
/// result:			none
///
/// notes:			the notification's object is the drawable, not the style - the style is passed in the user info
///					dictionary with the key 'style'.
///
///********************************************************************************************************************

- (void)				styleWasAttached:(DKDrawableObject*) toObject
{
	// DKDrawableObject calls these methods in its setStyle: method so that the style can get notified about who
	// is using it. By default these do nothing but send notifications - you can override for other uses.
	
	//LogEvent_(kReactiveEvent, @"style %@ attached to object %@", self, toObject );
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObject:self forKey:@"style"];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleWasAttachedNotification object:toObject userInfo:userInfo];
	
	// keep track of the number of clients using this
	
	++m_clientCount;
}


///*********************************************************************************************************************
///
/// method:			styleWillBeRemoved:
/// scope:			public method
/// overrides:		
/// description:	called when a style is about to be removed from an object
/// 
/// parameters:		<toObject> the object the style was attached to
/// result:			none
///
/// notes:			the notification's object is the drawable, not the style - the style is passed in the user info
///					dictionary with the key 'style'. This permits this to be called by the dealloc method of the
///					drawable, which would not be the case if the drawable was retained by the dictionary.
///
///********************************************************************************************************************

- (void)				styleWillBeRemoved:(DKDrawableObject*) fromObject
{
	//LogEvent_(kReactiveEvent, @"style %@ removed from object %@", self, fromObject );

	NSDictionary* userInfo = [NSDictionary dictionaryWithObject:self forKey:@"style"];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleWillBeDetachedNotification object:fromObject userInfo:userInfo];
	
	// keep track of the number of clients using this

	--m_clientCount;
}


///*********************************************************************************************************************
///
/// method:			countOfClients
/// scope:			public method
/// overrides:		
/// description:	returns the number of client objects using this style
/// 
/// parameters:		none
/// result:			an unsigned integer, the number of clients using this style
///
/// notes:			this is for information only - do not base critical code on this value
///
///********************************************************************************************************************

- (unsigned)			countOfClients
{
	return m_clientCount;
}


#pragma mark -
#pragma mark - (text) attributes - basic support
///*********************************************************************************************************************
///
/// method:			setTextAttributes:
/// scope:			protected method
/// overrides:		
/// description:	sets the text attributes dictionary
/// 
/// parameters:		<attrs> a dictionary of text attributes
/// result:			none
///
/// notes:			objects that display text can use a style's text attributes. This together with sharable styles
///					allows text (labels in particular) to have their styling changed for a whole drawing. See also
///					DKStyle+Text which gives more text-oriented methods that manipulate theses attributes.
///
///********************************************************************************************************************

- (void)				setTextAttributes:(NSDictionary*) attrs
{
	if(! [self locked])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setTextAttributes:[self textAttributes]];
		[self notifyClientsBeforeChange];
		NSDictionary* temp = [attrs copy];
		[m_textAttributes release];
		m_textAttributes = temp;
		[self notifyClientsAfterChange];
	}
}


///*********************************************************************************************************************
///
/// method:			textAttributes
/// scope:			public method
/// overrides:		
/// description:	returns the attributes dictionary
/// 
/// parameters:		none
/// result:			a dictionary of attributes
///
/// notes:			renderers are not considered attributes in this sense
///
///********************************************************************************************************************

- (NSDictionary*)		textAttributes
{
	return m_textAttributes;
}


///*********************************************************************************************************************
///
/// method:			hasTextAttributes
/// scope:			public method
/// overrides:		
/// description:	return wjether the style has any text attributes set
/// 
/// parameters:		none
/// result:			YES if there are any text attributes
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				hasTextAttributes
{
	return ([self textAttributes] != nil && [[self textAttributes] count] > 0);
}


///*********************************************************************************************************************
///
/// method:			removeTextAttributes
/// scope:			public method
/// overrides:		
/// description:	remove all of the style's current text attributes
/// 
/// parameters:		none
/// result:			none
///
/// notes:			does nothing if the style is locked
///
///********************************************************************************************************************

- (void)				removeTextAttributes
{
	[self setTextAttributes:nil];
}


#pragma mark -
#pragma mark - shared and locked status
///*********************************************************************************************************************
///
/// method:			setStyleSharable:
/// scope:			public method
/// overrides:		
/// description:	sets whether the style can be shared among multiple objects, or whether unique copies should be
///					used.
/// 
/// parameters:		<share> YES to share among several objects, NO to make unique copies.
/// result:			none
///
/// notes:			default is copied from class setting +shareStyles. Changing this flag is not undoable and does
///					not inform clients. It does send a notification however.
///
///********************************************************************************************************************

- (void)				setStyleSharable:(BOOL) share
{
	if( share != [self isStyleSharable])
	{
		m_shared = share;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleSharableFlagChangedNotification object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			isStyleSharable
/// scope:			public method
/// overrides:		
/// description:	returns whether the style can be shared among multiple objects, or whether unique copies should be
///					used.
/// 
/// parameters:		none
/// result:			YES to share among several objects, NO to make unique copies.
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isStyleSharable
{
	return m_shared;
}


///*********************************************************************************************************************
///
/// method:			setLocked:
/// scope:			public method
/// overrides:		
/// description:	set whether style is locked (editable)
/// 
/// parameters:		<lock> YES to lock the style
/// result:			none
///
/// notes:			locked styles are intended not to be editable, though this cannot be entirely enforced by the
///					style itself - client code should honour the locked state. You cannot add or remove renderers from a
///					locked style. Styles are normally not locked, but styles that are put in the registry are locked
///					by that action. Changing the lock state doesn't inform clients, since in general this does not
///					cause a visual change.
///
///********************************************************************************************************************

- (void)				setLocked:(BOOL) lock
{
	if ( lock != m_locked )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setLocked:[self locked]];
		m_locked = lock;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleLockStateChangedNotification object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			locked
/// scope:			public method
/// overrides:		
/// description:	returns whether the style is locked and cannot be edited
/// 
/// parameters:		none
/// result:			YES if locked (non-editable)
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				locked
{
	return m_locked;
}


#pragma mark -
#pragma mark - registry info
///*********************************************************************************************************************
///
/// method:			isStyleRegistered
/// scope:			public method
/// overrides:		
/// description:	returns whether the style is registered with the current style registry
/// 
/// parameters:		none
/// result:			YES if known to the registry
///
/// notes:			this method gives a definitive answer about
///					whether the style is registered. Along with locking, this should prevent accidental editing of
///					styles that an app might prefer to consider "read only".
///
///********************************************************************************************************************

- (BOOL)				isStyleRegistered
{
	return [[DKStyleRegistry sharedStyleRegistry] containsKey:[self uniqueKey]];
}


///*********************************************************************************************************************
///
/// method:			registryKeys
/// scope:			public method
/// overrides:		
/// description:	returns the list of keys that the style is registered under (if any)
/// 
/// parameters:		none
/// result:			a list of keys (NSStrings)
///
/// notes:			the returned array may contain no keys if the style isn't registered, or >1 key if the style has
///					been registered multiple times with different keys (not recommended). The key is not intended for
///					display in a user interface and has no relationship to the style's name.
///
///********************************************************************************************************************

- (NSArray*)			registryKeys
{
	return [NSArray arrayWithObject:[self uniqueKey]];  //[[DKStyleRegistry sharedStyleRegistry] keysForObject:self];
}


///*********************************************************************************************************************
///
/// method:			uniqueKey
/// scope:			public method
/// overrides:		
/// description:	returns the unique key of the style
/// 
/// parameters:		none
/// result:			a string
///
/// notes:			the unique key is set once and for all time when the style is initialised, and is guaranteed unique
///					as it is a UUID. 
///
///********************************************************************************************************************

- (NSString*)			uniqueKey
{
	return [[m_uniqueKey copy] autorelease];
}


///*********************************************************************************************************************
///
/// method:			assignUniqueKey
/// scope:			private method
/// overrides:		
/// description:	sets the unique key of the style
/// 
/// parameters:		none
/// result:			none
///
/// notes:			called when the object is inited, this assigns a unique key. The key cannot be reassigned - its
///					purpose is to identify this style regardless of any mutations it otherwise undergoes, including its
///					ordinary name.
///
///********************************************************************************************************************

- (void)				assignUniqueKey
{
	NSAssert( m_uniqueKey == nil, @"unique key already assigned - cannot be changed");
	
	if ( m_uniqueKey == nil )
	{
		m_uniqueKey = [[DKUniqueID uniqueKey] retain];
	//	LogEvent_(kStateEvent, @"assigned unique key: %@", m_uniqueKey);
	}
}


///*********************************************************************************************************************
///
/// method:			requiresRemerge
/// scope:			private method
/// overrides:		
/// description:	query whether the style should be considered for a re-merge with the registry
/// 
/// parameters:		none
/// result:			<YES> if the style should be a candidate for re-merging
///
/// notes:			re-merging is done when a document is opened. Any styles that were registered when it was saved will
///					set this flag when the style is inited from the archive. The document gathers these styles together
///					and remerges them according to the user's settings.
///
///********************************************************************************************************************

- (BOOL)				requiresRemerge
{
	return m_mergeFlag;
}


- (void)				clearRemergeFlag
{
	m_mergeFlag = NO;
}


- (NSTimeInterval)		lastModificationTimestamp
{
	return m_lastModTime;
}


#pragma mark -
#pragma mark - undo
///*********************************************************************************************************************
///
/// method:			setUndoManager
/// scope:			public method
/// overrides:		
/// description:	sets the undo manager that style changes will be recorded by
/// 
/// parameters:		<undomanager> the manager to use
/// result:			none
///
/// notes:			the undo manager is not retained
///
///********************************************************************************************************************

- (void)				setUndoManager:(NSUndoManager*) undomanager
{
	m_undoManagerRef = undomanager;
}


///*********************************************************************************************************************
///
/// method:			undoManager
/// scope:			public method
/// overrides:		
/// description:	returns the undo manager that style changes will be recorded by
/// 
/// parameters:		none
/// result:			the style's current undo manager
///
/// notes:			
///
///********************************************************************************************************************

- (NSUndoManager*)		undoManager
{
	return m_undoManagerRef;
}


///*********************************************************************************************************************
///
/// method:			changeKeyPath:ofObject:toValue:
/// scope:			private method
/// overrides:		
/// description:	vectors undo invocations back to the object from whence they came
/// 
/// parameters:		<keypath> the keypath of the action, relative to the object
///					<object> the real target of the invocation
///					<value> the value being restored by the undo/redo task
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				changeKeyPath:(NSString*) keypath ofObject:(id) object toValue:(id) value
{
	if([value isEqual:[NSNull null]])
		value = nil;
	
	[object setValue:value forKeyPath:keypath];
}


#pragma mark -
#pragma mark - stroke utilities
///*********************************************************************************************************************
///
/// method:			scaleStrokeWidthsBy:
/// scope:			public method
/// overrides:		
/// description:	adjusts all contained stroke widths by the given scale value
/// 
/// parameters:		<scale> the scale factor, e.g. 2.0 will double all stroke widths
///					<quiet> if YES, will ignore locked state and not inform clients. This is done when making hit
///					bitmaps with thin strokes to make them much easier to hit
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				scaleStrokeWidthsBy:(float) scale withoutInformingClients:(BOOL) quiet
{
	if ( quiet || ![self locked])
	{
		if ( ! quiet)
			[self notifyClientsBeforeChange];
		
		NSEnumerator*	iter = [[self renderersOfClass:[DKStroke class]] objectEnumerator];
		DKStroke*		stroke;
		
		while(( stroke = [iter nextObject]))
			[stroke scaleWidthBy:scale];
		
		if ( ! quiet)
			[self notifyClientsAfterChange];
	}
}


///*********************************************************************************************************************
///
/// method:			maxStrokeWidth
/// scope:			public method
/// overrides:		
/// description:	returns the widest stroke width in the style
/// 
/// parameters:		none
/// result:			a number, the width of the widest contained stroke, or 0.0 if there are no strokes.
///
/// notes:			
///
///********************************************************************************************************************

- (float)				maxStrokeWidth
{
	float maxWid = 0.0;
	
	NSArray*	strokes = [self renderersOfClass:[DKStroke class]];
	
	if ( strokes )
	{
		NSEnumerator*	iter = [strokes objectEnumerator];
		DKStroke*		stk;
		
		while(( stk = [iter nextObject]))
		{
			if ([stk width] > maxWid )
				maxWid = [stk width];
		}
	}

	return maxWid;
}


///*********************************************************************************************************************
///
/// method:			maxStrokeWidthDifference
/// scope:			public method
/// overrides:		
/// description:	returns the difference between the widest and narrowest strokes
/// 
/// parameters:		none
/// result:			a number, can be 0.0 if there are no strokes or only one stroke
///
/// notes:			
///
///********************************************************************************************************************

- (float)				maxStrokeWidthDifference
{
	float	maxWid = 0.0;
	float	minWid = 1000.0;
	
	NSArray*	strokes = [self renderersOfClass:[DKStroke class]];
	
	if ( strokes != nil && [strokes count] > 1 )
	{
		NSEnumerator*	iter = [strokes objectEnumerator];
		DKStroke*		stk;
		
		while(( stk = [iter nextObject]))
		{
			if ([stk width] > maxWid )
				maxWid = [stk width];
				
			if ([stk width] < minWid )
				minWid = [stk width];
		}
		
		return maxWid - minWid;
	}
	
	return 0.0;
}


///*********************************************************************************************************************
///
/// method:			applyStrokeAttributesToPath:
/// scope:			public method
/// overrides:		
/// description:	applies the cap, join, mitre limit, dash and line width attributes of the rear-most stroke to the path
/// 
/// parameters:		<path> a bezier path to apply the attributes to
/// result:			none
///
/// notes:			this can be used to set up a path for a Quartz operation such as outlining. The rearmost stroke
///					attribute is used if there is more than one on the basis that this forms the largest element of
///					the stroke. However, for the line width the max stroke is applied. If there are no strokes the
///					path is not changed.
///
///********************************************************************************************************************

- (void)				applyStrokeAttributesToPath:(NSBezierPath*) path
{
	NSAssert( path != nil, @"nil path in applyStrokeAttributesToPath:");
	
	NSArray* strokes = [self renderersOfClass:[DKStroke class]];
	
	if( strokes != nil && [strokes count] > 0 )
	{
		DKStroke* stroke = [strokes objectAtIndex:0];
		[stroke applyAttributesToPath:path];
		[path setLineWidth:[self maxStrokeWidth]];
	}
}


#pragma mark -
#pragma mark - clipboard
///*********************************************************************************************************************
///
/// method:			copyToPasteboard:
/// scope:			public method
/// overrides:		
/// description:	copies the style to the pasteboard
/// 
/// parameters:		<pb> the pasteboard to copy to
/// result:			none
///
/// notes:			puts both the archived style and its key (as a separate type) on the pasteboard. When pasting a
///					style, the key should be used in preference to allow a possible shared style to work as expected.
///
///********************************************************************************************************************

- (void)				copyToPasteboard:(NSPasteboard*) pb
{
	BOOL		registered = [self isStyleRegistered];
	NSString*	key = [self uniqueKey];
	
	if (!registered && [self isStyleSharable])
	{
		// this style is meant to be shared, yet is unregistered. That means that when the style is pasted it won't be found
		// in the registry, and so will not be shared, but copied. To resolve this, we must register it using its unique key
		// in the temporary paste registry
		
		[DKStyle registerStyle:self withPasteboardName:key];
		registered = YES;
	}
	
	NSArray* types;
	
	if ( registered )
		types = [NSArray arrayWithObjects:kDKStyleKeyPasteboardType, kDKStylePasteboardType, nil];
	else
		types = [NSArray arrayWithObject:kDKStylePasteboardType];
		
	[pb declareTypes:types owner:self];

	if ( registered )
		[pb setString:key forType:kDKStyleKeyPasteboardType];

	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:self];
	[pb setData:data forType:kDKStylePasteboardType];
}


///*********************************************************************************************************************
///
/// method:			derivedStyleWithPasteboard:
/// scope:			public method
/// overrides:		
/// description:	returns a style based on the receiver plus any data on the clipboard we are able to use
/// 
/// parameters:		<pb> the pasteboard to take additional data from
/// result:			a new style
///
/// notes:			this method is used when dragging properties such as colours onto an object. The object's existing
///					style is used as a starting point, then any data on the pasteboard we can use such as colours,
///					images, etc, is used to add or change properties of the style. For example if the pb has a colour,
///					it will be set as the first fill colour, or add a fill if there isn't one. Images are converted
///					to image adornments, text to text adornments, etc.
///
///					Note that it's impossible for this method to anticipate what the user is really expecting - it does
///					what it sensibly can, but in some cases it won't be appropriate. It is up to the receiver of the
///					drag itself to make the most appropriate choice about what happens to an object's appearance.
///
///					If the style could not make use of any data on the clipboard, it returns itself, thus avoiding
///					an unnecessary copy of the style when its contents were not actually changed
///
///********************************************************************************************************************

- (DKStyle*)			derivedStyleWithPasteboard:(NSPasteboard*) pb
{
	return [self derivedStyleWithPasteboard:pb withOptions:kDKDerivedStyleDefault];
}


///*********************************************************************************************************************
///
/// method:			derivedStyleWithPasteboard:withOptions:
/// scope:			public method
/// overrides:		
/// description:	returns a style based on the receiver plus any data on the clipboard we are able to use
/// 
/// parameters:		<pb> the pasteboard to take additional data from
///					<options> some hints that can influence the outcome of the operation
/// result:			a new style
///
/// notes:			see notes for derivedStyleWithPasteboard:
///					The options are used to set up renderers in more appropriate ways when the type of object that the
///					style will be attached to is known.
///
///********************************************************************************************************************

- (DKStyle*)			derivedStyleWithPasteboard:(NSPasteboard*) pb withOptions:(DKDerivedStyleOptions) options
{
	DKStyle*	style = [self mutableCopy];
	NSColor*	colour = [NSColor colorFromPasteboard:pb];
	BOOL		wasMutated = NO;
	
	if ( colour != nil )
	{
		// if the style already has a fill, mutate it - otherwise add a new one
	
		DKFill* fill = [[style renderersOfClass:[DKFill class]] lastObject];
		
		if ( fill == nil )
		{
			// no fill, so before adding one, see if we should work on the stroke instead
			
			DKStroke* stroke = [[style renderersOfClass:[DKStroke class]] lastObject];
			
			if ( stroke )
				[stroke setColour:colour];
			else
			{
				fill = [DKFill fillWithColour:colour];
				[style addRenderer:fill];
			}
		}
		else
			[fill setColour:colour];
			
		wasMutated = YES;
	}	
	
	// if there's an image on the pasteboard, work out what to do with it - first see if any existing renderers can
	// use an image - if so, apply the image there. If not, add an image adornment.
	
	if([NSImage canInitWithPasteboard:pb])
	{
		// yes there's an image - what can we do with it? Rasterizers that take an image include DKFillPattern, DKPathDecorator
		// and DKImageAdornment. If the style has any of these, apply it to the frontmost one. If it doesn't, create an image
		// adornment and add it to the front.
		
		NSImage* image = [[NSImage alloc] initWithPasteboard:pb];
		
		if ( image != nil )
		{
			NSEnumerator*	iter = [[style renderList] reverseObjectEnumerator];
			DKRasterizer*	rast = nil;
			
			while(( rast = [iter nextObject]))
			{
				if([rast respondsToSelector:@selector(setImage:)])
				{
					[(id)rast setImage:image];
					break;
				}
			}
			
			if ( rast == nil )
			{
				// no existing rasterizer can handle it - add an adornment. If the hint suggests a path, make a path decorator instead
				DKRasterizer* adorn;
				
				if ( options == kDKDerivedStyleForPathHint )
					adorn = [DKPathDecorator pathDecoratorWithImage:image];
				else
				{
					adorn = [DKImageAdornment imageAdornmentWithImage:image];
					[(DKImageAdornment*)adorn setFittingOption:kGCScaleToFitPreservingAspectRatio];
				}	
				[style addRenderer:adorn];
			}
		
			[image release];
			wasMutated = YES;
		}
	}
	
	// text - if there is text on the pasteboard, set the text of an appropriate renderer, or add a text adornment
	
	NSString* pbString = [pb stringForType:NSStringPboardType];
	
	if ( pbString != nil )
	{
		// look for renderers that can accept a string.  Currently this is only DKTextAdornment
		
		NSArray*			textList = [style renderersOfClass:[DKTextAdornment class]];
		DKTextAdornment*	tr;
		
		if ( textList != nil && [textList count] > 0 )
		{
			tr = [textList lastObject];
			[tr setLabel:pbString];
		}
		else
		{
			tr = [DKTextAdornment textAdornmentWithText:pbString];
			
			// if the style has text attributes, set these as the initial attributes for the adornment
			
			if([self hasTextAttributes])
				[tr setTextAttributes:[self textAttributes]];
			
			// if the options suggest a shape, set the text to block mode and centre it
			
			if( options == kDKDerivedStyleForPathHint )
			{
				[tr setLayoutMode:kGCTextLayoutAlongPath];
				[tr setAlignment:NSLeftTextAlignment];
				[tr setVerticalAlignment:kGCTextShapeVerticalAlignmentTop];
			}
			
			[style addRenderer:tr];
		}
		
		wasMutated = YES;
	}
	
	if ( wasMutated )
		return [style autorelease];
	else
	{
		// nothing was done, so return self to avoid unwanted cloning of the style
		
		[style release];
		return self;
	}
}


#pragma mark -
#pragma mark - query methods to quickly determine general characteristics
///*********************************************************************************************************************
///
/// method:			hasStroke
/// scope:			public method
/// overrides:		
/// description:	queries whether the style has at least one stroke
/// 
/// parameters:		none
/// result:			YES if there are one or more strokes, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				hasStroke
{
	return [self containsRendererOfClass:[DKStroke class]];
}


///*********************************************************************************************************************
///
/// method:			hasFill
/// scope:			public method
/// overrides:		
/// description:	queries whether the style has at least one filling property (fill or pattern)
/// 
/// parameters:		none
/// result:			YES if there are one or more fill properties, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				hasFill
{
	return	[self containsRendererOfClass:[DKFill class]] ||
			[self containsRendererOfClass:[DKFillPattern class]];
}


///*********************************************************************************************************************
///
/// method:			hasHatch
/// scope:			public method
/// overrides:		
/// description:	queries whether the style has at least one hatch property
/// 
/// parameters:		none
/// result:			YES if there are one or more hatches, NO otherwise
///
/// notes:			hatches are not always considered to be 'fills' in the normal sense, so hatches are counted separately
///
///********************************************************************************************************************

- (BOOL)				hasHatch
{
	return [self containsRendererOfClass:[DKHatching class]];
}


///*********************************************************************************************************************
///
/// method:			hasTextAdornment
/// scope:			public method
/// overrides:		
/// description:	queries whether the style has at least one text adornment property
/// 
/// parameters:		none
/// result:			YES if there are one or more text adornments, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				hasTextAdornment
{
	return [self containsRendererOfClass:[DKTextAdornment class]];
}


#pragma mark -
#pragma mark - swatch images
///*********************************************************************************************************************
///
/// method:			styleSwatchWithSize:type:
/// scope:			public method
/// overrides:		
/// description:	creates a thumbnail image of the style
/// 
/// parameters:		<size> the desired size of the thumbnail
///					<type> the type of thumbnail - currently rect and path types are supported, or selected automatically
/// result:			an image of a default path rendered using this style
///
/// notes:			
///
///********************************************************************************************************************

- (NSImage*)			styleSwatchWithSize:(NSSize) size type:(DKStyleSwatchType) type
{
	// return the cached swatch if possible - i.e. size and type are the same and there is a cached swatch. Changes to the
	// style attributes etc should discard the cached swatch
	
	NSString* cacheKey = [self swatchCacheKeyForSize:size type:type];
	
	if ([mSwatchCache objectForKey:cacheKey] != nil )
		return [mSwatchCache objectForKey:cacheKey];
	
	//NSLog(@"building swatch (size: %@) for style '%@'", NSStringFromSize( size ), [self name]);

	// construct the image
	
	NSImage*		image = [[NSImage alloc] initWithSize:size];
	NSBezierPath*	path;
	NSRect			r, br = NSMakeRect( 0, 0, size.width, size.height );
	NSSize			extra = [self extraSpaceNeeded];
	
	// r is the size of the dummy path to be rendered, taking into account how much space the style needs.
	// If r shrinks too small though the style will look silly, so make sure it is at least some size (10 x 10)
	
	r = NSInsetRect( br, extra.width, extra.height );
	
	if ( r.size.width < 10 )
		r.size.width = 10;
		
	if ( r.size.height < 10 )
		r.size.height = 10;

	[image setFlipped:YES];
	
	if( type == kGCStyleSwatchAutomatic )
	{
		if([self hasFill] || [self hasTextAttributes] || [self hasHatch])
			type = kGCStyleSwatchRectanglePath;
		else
			type = kGCStyleSwatchCurvePath;
	}
	
	if (type == kGCStyleSwatchCurvePath )
	{
		// draw a small curved segment
		
		path = [NSBezierPath bezierPath];
		[path moveToPoint:NSMakePoint(NSMinX(r), NSMaxY(r))];
		
		NSPoint		ep, cp1, cp2;
		
		ep = NSMakePoint( NSMaxX(r), NSMinY(r));
		cp1 = NSMakePoint( NSMinX(r) + 6.0, NSMidY(r));
		cp2 = NSMakePoint( NSMaxX(r) - 6.0, NSMidY(r));
		
		[path curveToPoint:ep controlPoint1:cp1 controlPoint2:cp2];
	}
	else
		path = [NSBezierPath bezierPathWithRect:r];
		
	// create a temporary shape that will render using this style and the calculated path
	
	//DKDrawablePath* od = [[DKDrawablePath alloc] initWithBezierPath:path];
	
	DKDrawableShape* od = [DKDrawableShape drawableShapeWithPath:path withStyle:self];
	
	[image lockFocus];
	
	[[NSColor clearColor] set];
	NSRectFill( br );
	
	[od drawContent];
	
	// if there are text attributes, show an example string using these attributes
	
	if ([self hasTextAttributes])
	{
		NSString*	example = @"AaBbCcDdEe";
		[example drawInRect:r withAttributes:[self textAttributes]];
	}
	
	[image unlockFocus];
	//[od release];
	
	// cache the swatch - the image will only be rebuilt if the size or type requested changes,
	// or if the style itself is modified. The cache remembers all previously requested sizes until invalidated. The
	// use of this cache significantly speeds up building of user interfaces where swatches are used a lot, because
	// generating the swatch from scratch is relatively expensive.
	
	[mSwatchCache setObject:image forKey:cacheKey];
	
	return image;
}


///*********************************************************************************************************************
///
/// method:			standardStyleSwatch
/// scope:			public method
/// overrides:		
/// description:	creates a thumbnail image of the style
/// 
/// parameters:		none
/// result:			an image of a path rendered using this style in the default size
///
/// notes:			the swatch returned will have the curve path style if it has no fill, otherwise the rect style.
///
///********************************************************************************************************************

- (NSImage*)			standardStyleSwatch
{
	return [self styleSwatchWithSize:STYLE_SWATCH_SIZE type:kGCStyleSwatchAutomatic];
}


///*********************************************************************************************************************
///
/// method:			swatchCacheKeyForSize
/// scope:			public method
/// overrides:		
/// description:	return a key for the swatch cache for the given size and type of swatch
/// 
/// parameters:		size - the swatch size
///					type - the swatch type
/// result:			a string that is used as the key to the swatches in the cache
///
/// notes:			the key is a simple concatenation of the size and the type, but don't rely on this anywhere - just
///					ask for the swatch you want and if it's cached it will be returned.
///
///********************************************************************************************************************

- (NSString*)			swatchCacheKeyForSize:(NSSize) size type:(DKStyleSwatchType) type
{
	return [NSString stringWithFormat:@"%@_%d", NSStringFromSize( size ), type];
}

#pragma mark -
#pragma mark - currently rendering client
///*********************************************************************************************************************
///
/// method:			currentRenderClient
/// scope:			public method
/// overrides:		
/// description:	returns the current object being rendered by this style
/// 
/// parameters:		none
/// result:			the current rendering object
///
/// notes:			this is only valid when called while rendering is in progress - mainly for the benefit of renderers
///					that are part of this style
///
///********************************************************************************************************************

- (id)					currentRenderClient
{
	return m_renderClientRef;
}


///*********************************************************************************************************************
///
/// method:			hitTestingStyle
/// scope:			public method
/// overrides:		
/// description:	returns a derived style that can be used to draw a hit-testing bitmap offscreen
/// 
/// parameters:		none
/// result:			a new style
///
/// notes:			hit testing bitmaps are black and white bitmaps where hittable areas are black and the rest is white.
///					when an object updates the bitmap, it can use this derived style which substitutes a black fill or
///					stroke in place of any fancy renderer it has. It also widens thin strokes to make the pixels
///					much easier to hit.
///
///********************************************************************************************************************

- (DKStyle*)			hitTestingStyle
{
	// leave all existing "exotic" rasterizers in place in the copy - this gives very precise accuracy when hit-testing. The
	// added rasterizers below then enhance the hittability by providing solid areas that can be hit in addition to the
	// style's own elements.
	
	DKStyle* htStyle = [self mutableCopy];
	
	NSAssert( htStyle != nil, @"hit testing style copy couldn't be created");
	
	[htStyle setStyleSharable:NO];
	
	// strip out fills and strokes - this is just an optimization because ordinary fills and strokes are not going to be
	// contributing anything to the bitmap except execution time. This doesn't go into subgroups though since they may be
	// applying special effects that do spread pixels around.
	
	[htStyle removeRenderersOfClass:[DKFill class] inSubgroups:NO];
	[htStyle removeRenderersOfClass:[DKHatching class] inSubgroups:NO];
	[htStyle removeRenderersOfClass:[DKStroke class] inSubgroups:NO];
	[htStyle removeRenderersOfClass:[DKRoughStroke class] inSubgroups:NO];
	[htStyle removeRenderersOfClass:[DKFillPattern class] inSubgroups:NO];
	[htStyle removeRenderersOfClass:[DKImageAdornment class] inSubgroups:NO];
	
	// manipulate the name just in case this style ever gets out "into the wild".
	// It shouldn't unless misused, but the name gives a clue to its origins.
	
	NSString* sn = [[self name] stringByAppendingString:@".hit_testing"];
	[htStyle setName:sn];
	
	// add a solid black fill
	
	if([self hasFill] || [self hasHatch])
	{
		DKFill* htFill = [DKFill fillWithColour:[NSColor blackColor]];
		[htStyle addRenderer:htFill];
	}
	
	// add a solid black stroke if there is a stroke or path decorator
	
	if([self hasStroke] || [self containsRendererOfClass:[DKPathDecorator class]])
	{
		// widen stroke to a minimum of 4 if the style only does strokes - this makes thin strokes much easier to hit
		
		float maxStrokeWidth = [self maxStrokeWidth];
		
		if(!([self hasFill] || [self hasHatch]))
		{
			if( maxStrokeWidth < 4.0 )
				maxStrokeWidth = 4.0;
		}
			
		DKStroke*	htStroke = [DKStroke strokeWithWidth:maxStrokeWidth colour:[NSColor blackColor]];
		[htStyle addRenderer:htStroke];
	}
	
	// if the style has no renderers at all, the hit bitmap would be empty and the object it is attached to couldn't be hit.
	// this is really a bug, so this style can come to the rescue by supplying a hittable fill. In general though
	// you probably want to avoid this situation arising.
	
	if([self countOfRenderList] == 0 )
	{
		DKFill* htFill = [DKFill fillWithColour:[NSColor blackColor]];
		[htStyle addRenderer:htFill];
	}
	
	return [htStyle autorelease];
}


#pragma mark -
#pragma mark As a DKRastGroup
///*********************************************************************************************************************
///
/// method:			addRenderer:
/// scope:			private method
/// overrides:		DKRastGroup
/// description:	adds a renderer to the style, ensuring internal KVO linkage is established
/// 
/// parameters:		<renderer> the renderer to attach
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				addRenderer:(DKRasterizer*) renderer
{
	if ( ![self locked])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] removeRenderer:renderer];
		[self notifyClientsBeforeChange];
		[super addRenderer:renderer];
		[self notifyClientsAfterChange];
	}
}


///*********************************************************************************************************************
///
/// method:			insertRenderer:atIndex:
/// scope:			private method
/// overrides:		DKRastGroup
/// description:	inserts a renderer into the style, ensuring internal KVO linkage is established
/// 
/// parameters:		<renderer> the renderer to insert
///					<index> the index where the renderer is inserted
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				insertRenderer:(DKRasterizer*) renderer atIndex:(unsigned) indx
{
	if ( ![self locked])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] removeRenderer:renderer];
		[self notifyClientsBeforeChange];
		[super insertRenderer:renderer atIndex:indx];
		[self notifyClientsAfterChange];
	}
}


///*********************************************************************************************************************
///
/// method:			removeRenderer:
/// scope:			private method
/// overrides:		DKRastGroup
/// description:	removes a renderer from the style, ensuring internal KVO linkage is removed
/// 
/// parameters:		<renderer> the renderer to remove
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeRenderer:(DKRasterizer*) renderer
{
	if ( ![self locked])
	{
		unsigned indx = [self indexOfRenderer:renderer];
		
		[[[self undoManager] prepareWithInvocationTarget:self] insertRenderer:renderer atIndex:indx];
		[self notifyClientsBeforeChange];
		[super removeRenderer:renderer];
		[self notifyClientsAfterChange];
	}
}


///*********************************************************************************************************************
///
/// method:			moveRendererAtIndex:toIndex:
/// scope:			private method
/// overrides:		DKRastGroup
/// description:	moves a renderer from one place in the list to another, setting up undo
/// 
/// parameters:		<src> the index being moved
///					<dest> where it will move to
/// result:			none
///
/// notes:			if src == dest, does nothing and no undo is created
///
///********************************************************************************************************************

- (void)				moveRendererAtIndex:(unsigned) src toIndex:(unsigned) dest
{
	if ( ![self locked] && ( src != dest ))
	{
		LogEvent_(kStateEvent, @"moving style component at %d to %d", src, dest );

		[[[self undoManager] prepareWithInvocationTarget:self] moveRendererAtIndex:dest toIndex:src];
		[self notifyClientsBeforeChange];
		[super moveRendererAtIndex:src toIndex:dest];
		[self notifyClientsAfterChange];
	}
}


///*********************************************************************************************************************
///
/// method:			root
/// scope:			private method
/// overrides:		DKRastGroup
/// description:	returns the root of the group tree - which is always self
/// 
/// parameters:		none
/// result:			self
///
/// notes:			
///
///********************************************************************************************************************

- (DKRastGroup*)		root
{
	return self;
}


///*********************************************************************************************************************
///
/// method:			observableWasAdded:
/// scope:			private method
/// overrides:		DKRastGroup
/// description:	informs the style that a new component was added to the tree and needs observing
/// 
/// parameters:		<observable> the object to start watching
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				observableWasAdded:(GCObservableObject*) observable
{
	LogEvent_( kKVOEvent, @"observable %@ will start being observed by %@ ('%@')", [observable description], [self description], [self name]);

	NSAssert( observable != nil, @"observable object was nil");
	[observable setUpKVOForObserver:self];
}


///*********************************************************************************************************************
///
/// method:			observableWillBeRemoved:
/// scope:			private method
/// overrides:		DKRastGroup
/// description:	informs the style that a  component is about to be removed from the tree and should stop being observed
/// 
/// parameters:		<observable> the object to stop watching
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				observableWillBeRemoved:(GCObservableObject*) observable
{
	LogEvent_( kKVOEvent, @"observable %@ will stop being observed by %@ ('%@')", [observable description], [self description], [self name]);
	
	NSAssert( observable != nil, @"observable object was nil");
	[observable tearDownKVOForObserver:self];
}



#pragma mark -
#pragma mark As a DKRasterizer
///*********************************************************************************************************************
///
/// description:	renders the object using this style
///
/// notes:			sets the value of the client for the duration of rendering
///
///********************************************************************************************************************

- (void)				render:(id) object
{
	if([self enabled])
	{
		m_renderClientRef = object;
		[super render:object];
		m_renderClientRef = nil;
	}
}


///*********************************************************************************************************************
///
/// description:	sets the style's name undoably
/// notes:			does not inform the client(s) as this is not typically a visual change, but does send a notification
///
///********************************************************************************************************************

- (void)				setName:(NSString*) name
{
	if(![self locked])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setName:) object:[self name]];
		[super setName:name];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleNameChangedNotification object:self];
	}
}

///*********************************************************************************************************************
///
/// method:			setEnabled:
/// scope:			public method
/// overrides:		DKRasterizer
/// description:	set whether the style is enabled or not
/// 
/// parameters:		<enable> YES to enable, NO to disable
/// result:			none
///
/// notes:			disabled styles don't draw anything
///
///********************************************************************************************************************

- (void)		setEnabled:(BOOL) enable
{
	if ( enable != [self enabled])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setEnabled:[self enabled]];
		[self notifyClientsBeforeChange];
		[super setEnabled:enable];
		[self notifyClientsAfterChange];
		
		if(![[self undoManager] isUndoing] && ![[self undoManager] isRedoing])
		{
			if([self enabled])
				[[self undoManager] setActionName:NSLocalizedString(@"Enable Style", @"undo string for enable style")];
			else
				[[self undoManager] setActionName:NSLocalizedString(@"Disable Style", @"undo string for disable style")];
		}
	}
}



#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	LogEvent_( kKVOEvent, @"style %@ ('%@') is being deallocated, will stop observing all components", self, [self name]);
	
	// stop observing all of the component rasterizers - any group objects in the list will propagate this
	// message down to their subordinate objects.
	
	[[self renderList] makeObjectsPerformSelector:@selector(tearDownKVOForObserver:) withObject:self];
	
	//[[self undoManager] removeAllActionsWithTarget:self];
	
	[mSwatchCache release];
	[m_textAttributes release];
	[m_uniqueKey release];
	
	[super dealloc];
}


- (id)					init
{
	self = [super init];
	if (self != nil)
	{
		m_textAttributes = nil;
		NSAssert(m_undoManagerRef == nil, @"Expected init to zero");
		[self setStyleSharable:[[self class] stylesAreSharableByDefault]]; 
		NSAssert(!m_locked, @"Expected init to NO");
		NSAssert(m_renderClientRef == nil, @"Expected init to zero");
		
		m_mergeFlag = NO;
		[self assignUniqueKey];
		m_lastModTime = [NSDate timeIntervalSinceReferenceDate];
		mSwatchCache = [[NSMutableDictionary alloc] init];
		m_clientCount = 0;
		
		if (m_uniqueKey == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self uniqueKey] forKey:@"DKDrawingStyle_uniqueKey"];
	[coder encodeBool:[self isStyleRegistered] forKey:@"DKDrawingStyle_registeredStyle"];
	[coder encodeDouble:[self lastModificationTimestamp] forKey:@"DKDrawingStyle_lastModTime"];
	
	[coder encodeObject:[self textAttributes] forKey:@"styledict"];
	[coder encodeBool:[self isStyleSharable] forKey:@"shared"];
	[coder encodeBool:[self locked] forKey:@"locked"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		// recover the unique key - older files won't have it so assign one
		
		NSString*	uk = [coder decodeObjectForKey:@"DKDrawingStyle_uniqueKey"];
		
		if ( uk == nil )
		{
			// the style was saved without a key, so assign one - no remerging will be
			// attempted as there's no information to go on. This will only apply to
			// very old files that predate this mechanism.
			
			[self assignUniqueKey];
			m_lastModTime = [NSDate timeIntervalSinceReferenceDate];
			m_mergeFlag = NO;
		}
		else
		{
			m_uniqueKey = [uk retain];
		
			// do not re-register styles immediately. Instead, just flag them as needing a potential remerge with the
			// registry. The user might have other ideas - the document is able to handle the remerge of a document's styles
			// en masse by building a set of styles that have this flag set.
		
			m_mergeFlag = [coder decodeBoolForKey:@"DKDrawingStyle_registeredStyle"];
			m_lastModTime = [coder decodeDoubleForKey:@"DKDrawingStyle_lastModTime"];
		}
		
		[self setTextAttributes:[coder decodeObjectForKey:@"styledict"]];
		NSAssert(m_undoManagerRef == nil, @"Expected init to zero");
		[self setStyleSharable:[coder decodeBoolForKey:@"shared"]];
		[self setLocked:[coder decodeBoolForKey:@"locked"]];
		mSwatchCache = [[NSMutableDictionary alloc] init];
		NSAssert(m_renderClientRef == nil, @"Expected init to zero");
		m_clientCount = 0;
		
		// once the entire style and its rasterizer tree have been unarchived, start observing all of the individual
		// components. Any group items in the tree will propagate this message down to the objects they contain.
		
		[[self renderList] makeObjectsPerformSelector:@selector(setUpKVOForObserver:) withObject:self];
	}

	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
///*********************************************************************************************************************
///
/// notes:			styles should always be copied before use, in order that the shared flag is automatically
///					honoured. Drawable objects do this by default, so within drawkit this 'just works'.
///
///********************************************************************************************************************

- (id)					copyWithZone:(NSZone*) zone
{
	if ([self isStyleSharable])
		return [self retain];
	else
		return [self mutableCopyWithZone:zone];
}


#pragma mark -
#pragma mark As part of NSKeyValueObserving Protocol

/// description:	sets up undo invocations when the value of a contained property is changed

- (void)			observeValueForKeyPath:(NSString*) keypath ofObject:(id) object change:(NSDictionary*) change context:(void*) context
{
	#pragma unused(context)
	
	// this is called whenever a property of a renderer contained in the style is changed. Its job is to consolidate both undo
	// and client object refresh when properties are altered directly, which of course they usually will be. This powerfully
	// means that renderers themselves do not need to know anything about undo or how they fit into the overall scheme of things.
	
	NSKeyValueChange ch = [[change objectForKey:NSKeyValueChangeKindKey] intValue];
	BOOL	wasChanged = NO;
	
	if ( ch == NSKeyValueChangeSetting )
	{
		if(![[change objectForKey:NSKeyValueChangeOldKey] isEqual:[change objectForKey:NSKeyValueChangeNewKey]])
		{
			[[[self undoManager] prepareWithInvocationTarget:self]	changeKeyPath:keypath
																	ofObject:object
																	toValue:[change objectForKey:NSKeyValueChangeOldKey]];
			wasChanged = YES;
		}
	}
	else if ( ch == NSKeyValueChangeInsertion || ch == NSKeyValueChangeRemoval )
	{
		// Cocoa has a bug where array insertion/deletion changes don't properly record the old array.
		// GCObserveableObject gives us a workaround
				
		NSArray* old = [object oldArrayValueForKeyPath:keypath];
		
		[[[self undoManager] prepareWithInvocationTarget:self]	changeKeyPath:keypath
																ofObject:object
																toValue:old];	
																
		wasChanged = YES;
	}
	
	if ( wasChanged && !([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
	{
		if([object respondsToSelector:@selector(actionNameForKeyPath:changeKind:)])
			[[self undoManager] setActionName:[object actionNameForKeyPath:keypath changeKind:ch]];
		else
			[[self undoManager] setActionName:[GCObservableObject actionNameForKeyPath:keypath objClass:[object class]]];
	}
	
	[self notifyClientsAfterChange];
}


#pragma mark -
#pragma mark As part of NSMutableCopying Protocol
///********************************************************************************************************************
/// notes:			the copy's initial name is deliberately not set
///********************************************************************************************************************

- (id)				mutableCopyWithZone:(NSZone*) zone
{
	DKStyle* copy = [super copyWithZone:zone];	
	[copy setLocked:NO];
	[copy setName:nil];
	
	NSDictionary* attribs = [[self textAttributes] deepCopy];
	
	[copy setTextAttributes:attribs];
	[attribs release];
	
	// the copy needs to start observing all of its components:
	
	[[copy renderList] makeObjectsPerformSelector:@selector(setUpKVOForObserver:) withObject:copy];
	
	return copy;
}


@end



