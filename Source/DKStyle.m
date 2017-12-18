/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKStyle.h"
#import "DKStyleRegistry.h"
#import "DKFill.h"
#import "DKFillPattern.h"
#import "DKHatching.h"
#import "DKRoughStroke.h"
#import "DKTextAdornment.h"
#import "DKGradient.h"
#import "LogEvent.h"
#import "NSColor+DKAdditions.h"
#import "NSDictionary+DeepCopy.h"
#import "DKUndoManager.h"
#import "DKUniqueID.h"
#import "DKImageAdornment.h"
#import "DKDrawablePath.h"
#import "DKDrawableShape.h"
#import "DKGeometryUtilities.h"
#import "NSImage+DKAdditions.h"

#pragma mark Contants(Non - localized)

NSString* kDKStylePasteboardType = @"net.apptree.drawkit.style";
NSString* kDKStyleKeyPasteboardType = @"net.apptree.drawkit.stylekey";

NSString* kDKStyleWillChangeNotification = @"kDKDrawingStyleWillChangeNotification";
NSString* kDKStyleDidChangeNotification = @"kDKDrawingStyleDidChangeNotification";
NSString* kDKStyleWasAttachedNotification = @"kDKDrawingStyleWasAttachedNotification";
NSString* kDKStyleWillBeDetachedNotification = @"kDKDrawingStyleWillBeDetachedNotification";
NSString* kDKStyleLockStateChangedNotification = @"kDKStyleLockStateChangedNotification";
NSString* kDKStyleSharableFlagChangedNotification = @"kDKStyleSharableFlagChangedNotification";
NSString* kDKStyleNameChangedNotification = @"kDKStyleNameChangedNotification";
NSString* kDKStyleTextAttributesDidChangeNotification = @"kDKStyleTextAttributesDidChangeNotification";

NSString* kDKStyleDisplayPerformance_no_anti_aliasing = @"kDKStyleDisplayPerformance_no_anti_aliasing";
NSString* kDKStyleDisplayPerformance_no_shadows = @"kDKStyleDisplayPerformance_no_shadows";
NSString* kDKStyleDisplayPerformance_substitute_styles = @"kDKStyleDisplayPerformance_substitute_styles";

// the fixed default styles need to have a predetermined (but still unique) key. We define them here.
// Do not change or interpret these values.

static NSString* kDKBasicStyleDefaultKey = @"1DFD6D8A-6C8B-4E4B-9186-90F64654F79F";
static NSString* kDKBasicTrackStyleDefaultKey = @"6B1A0430-204A-4012-B96D-A4EE9890A2A3";

#pragma mark Static Vars

static BOOL sStylesShared = YES;
static NSMutableDictionary* sPasteboardRegistry = nil;
static BOOL sShouldDrawShadows = YES;
static BOOL sAntialias = YES;
static BOOL sSubstitute = NO;

@interface DKStyle (Private)

- (NSSize)extraSpaceNeededIgnoringMitreLimit;

@end

#pragma mark -
@implementation DKStyle
#pragma mark As a DKStyle

/** @brief Returns a very basic style object

 Style has a 1 pixel black stroke and a light gray fill. Style may be shared if sharing is YES.
 @return a style object
 */
+ (DKStyle*)defaultStyle
{
	DKStyle* basic = [DKStyleRegistry styleForKey:kDKBasicStyleDefaultKey];

	if (basic == nil) {
		basic = [self styleWithFillColour:[NSColor veryLightGrey]
							 strokeColour:[NSColor blackColor]];
		[basic setName:NSLocalizedString(@"Basic", @"default name for basic style")];

		// because this is a framework default, its unique key must always be recreated the same. This is not something any client
		// code or other part of the framework should ever attempt.

		basic->m_uniqueKey = kDKBasicStyleDefaultKey;

		[DKStyleRegistry registerStyle:basic
						  inCategories:@[kDKStyleCategoryRegistryDKDefaults]];
	}

	return basic;
}

/** @brief Returns a basic style with a dual stroke, 5.6pt light grey over 8.0pt black

 Style may be shared if sharing is YES.
 @return a style object
 */
+ (DKStyle*)defaultTrackStyle
{
	DKStyle* deftrack = [DKStyleRegistry styleForKey:kDKBasicTrackStyleDefaultKey];

	if (deftrack == nil) {
		deftrack = [DKStyle styleWithFillColour:nil
								   strokeColour:[NSColor blackColor]
									strokeWidth:8.0];
		[deftrack addRenderer:[DKStroke strokeWithWidth:5.6
												 colour:[NSColor veryLightGrey]]];

		[deftrack setName:NSLocalizedString(@"Basic Track", @"default name for basic track style")];

		// because this is a framework default, its unique key must always be recreated the same. This is not something any client
		// code or other part of the framework should ever attempt.

		deftrack->m_uniqueKey = kDKBasicTrackStyleDefaultKey;

		[DKStyleRegistry registerStyle:deftrack
						  inCategories:@[kDKStyleCategoryRegistryDKDefaults]];
	}

	return deftrack;
}

#pragma mark -
#pragma mark - easy construction of other simple styles

/** @brief Creates a simple style with fill and strokes of the colours passed

 Stroke is drawn "on top" of fill, so rendered width appears true. You can pass nil for either
 colour to not create the renderer for that attribute, but note that passing nil for BOTH parameters
 is an error.
 @param fc the colour for the solid fill
 @param sc the colour for the 1.0 pixel wide stroke
 @return a style object
 */
+ (DKStyle*)styleWithFillColour:(NSColor*)fc strokeColour:(NSColor*)sc
{
	return [self styleWithFillColour:fc
						strokeColour:sc
						 strokeWidth:1.0];
}

/** @brief Creates a simple style with fill and strokes of the colours passed

 Stroke is drawn "on top" of fill, so rendered width appears true. You can pass nil for either
 colour to not create the renderer for that attribute, but note that passing nil for BOTH parameters
 is an error.
 @param fc the colour for the solid fill
 @param sc the colour for the stroke
 @param sw the width of the stroke
 @return a style object
 */
+ (DKStyle*)styleWithFillColour:(NSColor*)fc strokeColour:(NSColor*)sc strokeWidth:(CGFloat)sw
{
	if (fc == nil && sc == nil) {
		NSLog(@"DKStyle was passed nil for both colour arguments - will substitute a light gray fill (please fix)");
		fc = [NSColor lightGrayColor];
	}

	DKStyle* style = [[DKStyle alloc] init];

	if (fc) {
		DKFill* fill = [DKFill fillWithColour:fc];
		[style addRenderer:fill];
	}

	if (sc) {
		DKStroke* stroke = [DKStroke strokeWithWidth:sw
											  colour:sc];
		[style addRenderer:stroke];
	}

	return style;
}

/** @brief Creates a style from data on the pasteboard

 Preferentially tries to match the style name in order to preserve style sharing
 @param pb a pasteboard
 @return a style object
 */
+ (DKStyle*)styleFromPasteboard:(NSPasteboard*)pb
{
	NSString* sname = [pb stringForType:kDKStyleKeyPasteboardType];
	DKStyle* style = [self styleWithPasteboardName:sname];

	if (style == nil) {
		// the name isn't known, so fall back on using the archived style data

		NSData* sd = [pb dataForType:kDKStylePasteboardType];

		if (sd)
			style = [NSKeyedUnarchiver unarchiveObjectWithData:sd];
	}

	return style;
}

/** @brief Return a list of types supported by styles for pasteboard operations
 @return an array listing the pasteboard types usable by DKStyle
 */
+ (NSArray*)stylePasteboardTypes
{
	static NSArray* spTypes = nil;

	if (spTypes == nil)
		spTypes = @[kDKStyleKeyPasteboardType, kDKStylePasteboardType];

	return spTypes;
}

/** @brief Determine if the pasteboard carries a style
 @param pb a pasteboard
 @return YES if a style can be made from the pastebaord
 */
+ (BOOL)canInitWithPasteboard:(NSPasteboard*)pb
{
	return ([pb availableTypeFromArray:[self stylePasteboardTypes]] != nil);
}

#pragma mark -
#pragma mark - pasted styles - separate non - persistent registry
+ (DKStyle*)styleWithPasteboardName:(NSString*)name
{
	// look for the style in the pasteboard registry. If not there, look in the main registry.

	DKStyle* style = nil;

	if (sPasteboardRegistry)
		style = [sPasteboardRegistry objectForKey:name];

	if (style == nil)
		style = [DKStyleRegistry styleForKey:name];

	return style;
}

+ (void)registerStyle:(DKStyle*)style withPasteboardName:(NSString*)pbname
{
	// put the style into the pasteboard registry

	LogEvent_(kStateEvent, @"saving key for paste: %@ '%@'", pbname, [style name]);

	if (sPasteboardRegistry == nil)
		sPasteboardRegistry = [[NSMutableDictionary alloc] init];

	[sPasteboardRegistry setObject:style
							forKey:pbname];
}

#pragma mark -
#pragma mark - default sharing flag

/** @brief Set whether styles are generally shared or not

 Sharing styles means that all object that share that style will change when a style property changes,
 regardless of any other state information, such as selection, layer owner, etc. Styles are set
 NOT to be shared by default.
 @param share YES to share styles, NO to return unique copies.
 */
+ (void)setStylesAreSharableByDefault:(BOOL)share
{
	sStylesShared = share;
}

/** @brief Query whether styles are generally shared or not

 Styles are set NOT to be shared by default.
 @return YES if styles are shared, NO if unique copies will be returned
 */
+ (BOOL)stylesAreSharableByDefault
{
	return sStylesShared;
}

#pragma mark -
#pragma mark - convenient handy things

/** @brief Returns a default NSShadow object

 Shadows are set as properties of certain renderers, such as DKFill and DKStroke
 @return a shadow object
 */
+ (NSShadow*)defaultShadow
{
	NSShadow* shadw = [[NSShadow alloc] init];

	[shadw setShadowColor:[NSColor rgbGrey:0.0
								 withAlpha:0.5]];
	[shadw setShadowBlurRadius:10.0];
	[shadw setShadowOffset:NSMakeSize(6, 6)];

	return shadw;
}

/** @brief Set whether shadow attributes within a style should be drawn

 Drawing shadows is one of the main performance killers, so this provides a way to turn them off
 in certain situations. Rasterizers that have a shadow property should check and honour this setting.
 @param drawShadows YES to draw shadows, NO to suppress them
 @return the previous state of this setting
 */
+ (BOOL)setWillDrawShadows:(BOOL)drawShadows
{
	BOOL willDrawOld = sShouldDrawShadows;
	sShouldDrawShadows = drawShadows;
	[[NSUserDefaults standardUserDefaults] setBool:!drawShadows
											forKey:kDKStyleDisplayPerformance_no_shadows];

	return willDrawOld;
}

/** @brief Set whether shadow attributes within a style should be drawn

 Drawing shadows is one of the main performance killers, so this provides a way to turn them off
 in certain situations. Rasterizers that have a shadow property should check and honour this setting.
 @return YES to draw shadows, NO to suppress them
 */
+ (BOOL)willDrawShadows
{
	return sShouldDrawShadows;
}

#pragma mark -
#pragma mark - performance settings

/** @brief Set whether drawing should be anti-aliased or not

 Default is YES. Turning off anti-aliasing can speed up drawing at the expense of quality.
 @param aa YES to anti-alias, NO to turn anti-aliasing off
 */
+ (void)setShouldAntialias:(BOOL)aa
{
	sAntialias = aa;
	[[NSUserDefaults standardUserDefaults] setBool:!aa
											forKey:kDKStyleDisplayPerformance_no_anti_aliasing];
}

/** @brief Set whether drawing should be anti-aliased or not

 Default is YES. Turning off anti-aliasing can speed up drawing at the expense of quality.
 @return YES to anti-alias, NO to turn anti-aliasing off
 */
+ (BOOL)shouldAntialias
{
	return sAntialias;
}

/** @brief Set whether the style should substitute a simple placeholder when a style is complex and slow to
 render.

 Default is NO. Typically this method causes a style to render a single simple stroke in place of
 its actual components. If the style has a simple stroke, it is used, otherwise a default one is used.
 @param substitute YES to substitute a faster placeholder style for complex styles
 */
+ (void)setShouldSubstitutePlaceholderStyle:(BOOL)substitute
{
	sSubstitute = substitute;
	[[NSUserDefaults standardUserDefaults] setBool:substitute
											forKey:kDKStyleDisplayPerformance_substitute_styles];
}

/** @brief Set whether the style should substitute a simple placeholder when a style is complex and slow to
 render.

 Default is NO. Typically this method causes a style to render a single simple stroke in place of
 its actual components. If the style has a simple stroke, it is used, otherwise a default one is used.
 @return YES to substitute a faster placeholder style for complex styles
 */
+ (BOOL)shouldSubstitutePlaceholderStyle
{
	return sSubstitute;
}

#pragma mark -
#pragma mark - updating& notifying clients

/** @brief Informs clients that a property of the style is about to change */
- (void)notifyClientsBeforeChange
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleWillChangeNotification
														object:self];
}

/** @brief Informs clients that a property of the style has just changed

 This method is called in response to any observed change to any renderer the style contains */
- (void)notifyClientsAfterChange
{
	// update the timestamp so that style registry can determine which of a pair of similar styles is the more recent

	m_lastModTime = [NSDate timeIntervalSinceReferenceDate];

	// invalidate any swatch cache to ensure cache is forced to be rebuilt after a change

	[mSwatchCache removeAllObjects];

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleDidChangeNotification
														object:self];
}

/** @brief Called when a style is attached to an object

 The notification's object is the drawable, not the style - the style is passed in the user info
 dictionary with the key 'style'.
 @param toObject the object the style was attached to
 */
- (void)styleWasAttached:(DKDrawableObject*)toObject
{
	// DKDrawableObject calls these methods in its setStyle: method so that the style can get notified about who
	// is using it. By default these do nothing but send notifications - you can override for other uses.

	//LogEvent_(kReactiveEvent, @"style %@ attached to object %@", self, toObject );

	NSDictionary* userInfo = @{@"style": self};
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleWasAttachedNotification
														object:toObject
													  userInfo:userInfo];

	// keep track of the number of clients using this

	++m_clientCount;
}

/** @brief Called when a style is about to be removed from an object

 The notification's object is the drawable, not the style - the style is passed in the user info
 dictionary with the key 'style'. This permits this to be called by the dealloc method of the
 drawable, which would not be the case if the drawable was retained by the dictionary.
 @param toObject the object the style was attached to
 */
- (void)styleWillBeRemoved:(DKDrawableObject*)fromObject
{
	//LogEvent_(kReactiveEvent, @"style %@ removed from object %@", self, fromObject );

	NSDictionary* userInfo = @{@"style": self};
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleWillBeDetachedNotification
														object:fromObject
													  userInfo:userInfo];

	// keep track of the number of clients using this

	--m_clientCount;
}

#if 0
/** @brief Returns the number of client objects using this style

 This is for information only - do not base critical code on this value
 @return an unsigned integer, the number of clients using this style
 */
- (NSUInteger)countOfClients
{
	return m_clientCount;
}
#endif

@synthesize countOfClients=m_clientCount;

#pragma mark -
#pragma mark - (text) attributes - basic support

/** @brief Sets the text attributes dictionary

 Objects that display text can use a style's text attributes. This together with sharable styles
 allows text (labels in particular) to have their styling changed for a whole drawing. See also
 DKStyle+Text which gives more text-oriented methods that manipulate theses attributes.
 @param attrs a dictionary of text attributes */
- (void)setTextAttributes:(NSDictionary*)attrs
{
	if (![self locked]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setTextAttributes:[self textAttributes]];
		[self notifyClientsBeforeChange];
		NSDictionary* temp = [attrs copy];
		m_textAttributes = temp;
		[self notifyClientsAfterChange];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleTextAttributesDidChangeNotification
															object:self];
	}
}

@synthesize textAttributes=m_textAttributes;

/** @brief Return wjether the style has any text attributes set
 @return YES if there are any text attributes
 */
- (BOOL)hasTextAttributes
{
	return ([self textAttributes] != nil && [[self textAttributes] count] > 0);
}

/** @brief Remove all of the style's current text attributes

 Does nothing if the style is locked
 */
- (void)removeTextAttributes
{
	[self setTextAttributes:nil];
}

#pragma mark -
#pragma mark - shared and locked status

/** @brief Sets whether the style can be shared among multiple objects, or whether unique copies should be
 used.

 Default is copied from class setting +shareStyles. Changing this flag is not undoable and does
 not inform clients. It does send a notification however.
 @param share YES to share among several objects, NO to make unique copies.
 */
- (void)setStyleSharable:(BOOL)share
{
	if (share != [self isStyleSharable]) {
		m_shared = share;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleSharableFlagChangedNotification
															object:self];
	}
}

@synthesize styleSharable = m_shared;

/** @brief Set whether style is locked (editable)

 Locked styles are intended not to be editable, though this cannot be entirely enforced by the
 style itself - client code should honour the locked state. You cannot add or remove renderers from a
 locked style. Styles are normally not locked, but styles that are put in the registry are locked
 by that action. Changing the lock state doesn't inform clients, since in general this does not
 cause a visual change.
 @param lock YES to lock the style
 */
- (void)setLocked:(BOOL)lock
{
	if (lock != m_locked) {
		[[[self undoManager] prepareWithInvocationTarget:self] setLocked:[self locked]];
		m_locked = lock;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleLockStateChangedNotification
															object:self];
	}
}

#if 0
/** @brief Returns whether the style is locked and cannot be edited
 @return YES if locked (non-editable)
 */
- (BOOL)locked
{
	return m_locked;
}
#endif
@synthesize locked=m_locked;

#pragma mark -
#pragma mark - registry info

/** @brief Returns whether the style is registered with the current style registry

 This method gives a definitive answer about
 whether the style is registered. Along with locking, this should prevent accidental editing of
 styles that an app might prefer to consider "read only".
 @return YES if known to the registry
 */
- (BOOL)isStyleRegistered
{
	return [[DKStyleRegistry sharedStyleRegistry] containsKey:[self uniqueKey]];
}

/** @brief Returns the list of keys that the style is registered under (if any)

 The returned array may contain no keys if the style isn't registered, or >1 key if the style has
 been registered multiple times with different keys (not recommended). The key is not intended for
 display in a user interface and has no relationship to the style's name.
 @return a list of keys (NSStrings)
 */
- (NSArray*)registryKeys
{
	return @[[self uniqueKey]]; //[[DKStyleRegistry sharedStyleRegistry] keysForObject:self];
}

#if 0
/** @brief Returns the unique key of the style

 The unique key is set once and for all time when the style is initialised, and is guaranteed unique
 as it is a UUID.
 @return a string
 */
- (NSString*)uniqueKey
{
	return [m_uniqueKey copy];
}
#else
@synthesize uniqueKey=m_uniqueKey;
#endif

/** @brief Sets the unique key of the style

 Called when the object is inited, this assigns a unique key. The key cannot be reassigned - its
 purpose is to identify this style regardless of any mutations it otherwise undergoes, including its
 ordinary name.
 */
- (void)assignUniqueKey
{
	NSAssert(m_uniqueKey == nil, @"unique key already assigned - cannot be changed");

	if (m_uniqueKey == nil) {
		m_uniqueKey = [DKUniqueID uniqueKey];
		//	LogEvent_(kStateEvent, @"assigned unique key: %@", m_uniqueKey);
	}
}

/** @brief Query whether the style should be considered for a re-merge with the registry

 Re-merging is done when a document is opened. Any styles that were registered when it was saved will
 set this flag when the style is inited from the archive. The document gathers these styles together
 and remerges them according to the user's settings.
 @return <YES> if the style should be a candidate for re-merging
 */
- (BOOL)requiresRemerge
{
	return m_mergeFlag;
}

- (void)clearRemergeFlag
{
	m_mergeFlag = NO;
}

@synthesize lastModificationTimestamp=m_lastModTime;

/** @brief Is this style the same as <aStyle>?

 Styles are considered equal if they have the same unique ID and the same timestamp.
 @param aStyle a style to compare this with
 @return YES if the styles ar the same, NO otherwise
 */
- (BOOL)isEqualToStyle:(DKStyle*)aStyle
{
	BOOL same = NO;

	if ([[self uniqueKey] isEqualToString:[aStyle uniqueKey]])
		same = ([self lastModificationTimestamp] == [aStyle lastModificationTimestamp]);

	return same;
}

#pragma mark -
#pragma mark - undo

@synthesize undoManager=m_undoManagerRef;

/** @brief Vectors undo invocations back to the object from whence they came
 @param keypath the keypath of the action, relative to the object
 @param object the real target of the invocation
 */
- (void)changeKeyPath:(NSString*)keypath ofObject:(id)object toValue:(id)value
{
	if ([value isEqual:[NSNull null]])
		value = nil;

	[object setValue:value
		  forKeyPath:keypath];
}

#pragma mark -
#pragma mark - stroke utilities

/** @brief Adjusts all contained stroke widths by the given scale value
 @param scale the scale factor, e.g. 2.0 will double all stroke widths
 @param quiet if YES, will ignore locked state and not inform clients. This is done when making hit
 */
- (void)scaleStrokeWidthsBy:(CGFloat)scale withoutInformingClients:(BOOL)quiet
{
	if (quiet || ![self locked]) {
		if (!quiet)
			[self notifyClientsBeforeChange];

		for (DKStroke* stroke in [self renderersOfClass:[DKStroke class]]) {
			[stroke scaleWidthBy:scale];
		}

		if (!quiet)
			[self notifyClientsAfterChange];
	}
}

/** @brief Returns the widest stroke width in the style
 @return a number, the width of the widest contained stroke, or 0.0 if there are no strokes.
 */
- (CGFloat)maxStrokeWidth
{
	CGFloat maxWid = 0.0;

	NSArray* strokes = [self renderersOfClass:[DKStroke class]];

	if (strokes) {
		for (DKStroke* stk in strokes) {
			if ([stk width] > maxWid) {
				maxWid = [stk width];
			}
		}
	}

	return maxWid;
}

/** @brief Returns the difference between the widest and narrowest strokes
 @return a number, can be 0.0 if there are no strokes or only one stroke
 */
- (CGFloat)maxStrokeWidthDifference
{
	CGFloat maxWid = 0.0;
	CGFloat minWid = 1000.0;

	NSArray* strokes = [self renderersOfClass:[DKStroke class]];

	if (strokes != nil && [strokes count] > 1) {
		for (DKStroke* stk in strokes) {
			if ([stk width] > maxWid) {
				maxWid = [stk width];
			}

			if ([stk width] < minWid) {
				minWid = [stk width];
			}
		}

		return maxWid - minWid;
	}

	return 0.0;
}

/** @brief Applies the cap, join, mitre limit, dash and line width attributes of the rear-most stroke to the path

 This can be used to set up a path for a Quartz operation such as outlining. The rearmost stroke
 attribute is used if there is more than one on the basis that this forms the largest element of
 the stroke. However, for the line width the max stroke is applied. If there are no strokes the
 path is not changed.
 @param path a bezier path to apply the attributes to
 */
- (void)applyStrokeAttributesToPath:(NSBezierPath*)path
{
	NSAssert(path != nil, @"nil path in applyStrokeAttributesToPath:");

	NSArray* strokes = [self renderersOfClass:[DKStroke class]];

	if (strokes != nil && [strokes count] > 0) {
		DKStroke* stroke = [strokes objectAtIndex:0];
		[stroke applyAttributesToPath:path];
		[path setLineWidth:[self maxStrokeWidth]];
	}
}

/** @brief Returns the number of strokes

 Counts all strokes, including those in subgroups.
 @return the number of stroke rasterizers
 */
- (NSUInteger)countOfStrokes
{
	return [[self renderersOfClass:[DKStroke class]] count];
}

#pragma mark -
#pragma mark - clipboard

/** @brief Copies the style to the pasteboard

 Puts both the archived style and its key (as a separate type) on the pasteboard. When pasting a
 style, the key should be used in preference to allow a possible shared style to work as expected.
 @param pb the pasteboard to copy to
 */
- (BOOL)copyToPasteboard:(NSPasteboard*)pb
{
	BOOL registered = [self isStyleRegistered];
	NSString* key = [self uniqueKey];

	if (!registered && [self isStyleSharable]) {
		// this style is meant to be shared, yet is unregistered. That means that when the style is pasted it won't be found
		// in the registry, and so will not be shared, but copied. To resolve this, we must register it using its unique key
		// in the temporary paste registry

		[DKStyle registerStyle:self
			withPasteboardName:key];
		registered = YES;
	}

	NSArray* types;

	if (registered)
		types = @[kDKStyleKeyPasteboardType, kDKStylePasteboardType];
	else
		types = @[kDKStylePasteboardType];

	[pb addTypes:types
		   owner:self];

	if (registered)
		[pb setString:key
			  forType:kDKStyleKeyPasteboardType];

	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:self];
	return [pb setData:data
			   forType:kDKStylePasteboardType];
}

/** @brief Returns a style based on the receiver plus any data on the clipboard we are able to use

 This method is used when dragging properties such as colours onto an object. The object's existing
 style is used as a starting point, then any data on the pasteboard we can use such as colours,
 images, etc, is used to add or change properties of the style. For example if the pb has a colour,
 it will be set as the first fill colour, or add a fill if there isn't one. Images are converted
 to image adornments, text to text adornments, etc.
 Note that it's impossible for this method to anticipate what the user is really expecting - it does
 what it sensibly can, but in some cases it won't be appropriate. It is up to the receiver of the
 drag itself to make the most appropriate choice about what happens to an object's appearance.
 If the style could not make use of any data on the clipboard, it returns itself, thus avoiding
 an unnecessary copy of the style when its contents were not actually changed
 @param pb the pasteboard to take additional data from
 @return a new style
 */
- (DKStyle*)derivedStyleWithPasteboard:(NSPasteboard*)pb
{
	return [self derivedStyleWithPasteboard:pb
								withOptions:kDKDerivedStyleDefault];
}

/** @brief Returns a style based on the receiver plus any data on the clipboard we are able to use

 See notes for derivedStyleWithPasteboard:
 The options are used to set up renderers in more appropriate ways when the type of object that the
 style will be attached to is known.
 @param pb the pasteboard to take additional data from
 @param options some hints that can influence the outcome of the operation
 @return a new style
 */
- (DKStyle*)derivedStyleWithPasteboard:(NSPasteboard*)pb withOptions:(DKDerivedStyleOptions)options
{
	DKStyle* style = [self mutableCopy];
	NSColor* colour = [NSColor colorFromPasteboard:pb];
	BOOL wasMutated = NO;

	if (colour != nil) {
		// if the style already has a fill, mutate it - otherwise add a new one

		DKFill* fill = (DKFill*)[[style renderersOfClass:[DKFill class]] lastObject];

		if (fill == nil) {
			// no fill, so before adding one, see if we should work on the stroke instead

			DKStroke* stroke = (DKStroke*)[[style renderersOfClass:[DKStroke class]] lastObject];

			if (stroke)
				[stroke setColour:colour];
			else {
				fill = [DKFill fillWithColour:colour];
				[style addRenderer:fill];
			}
		} else
			[fill setColour:colour];

		wasMutated = YES;
	}

	// if there's an image on the pasteboard, work out what to do with it - first see if any existing renderers can
	// use an image - if so, apply the image there. If not, add an image adornment.

	if ([NSImage canInitWithPasteboard:pb]) {
		// yes there's an image - what can we do with it? Rasterizers that take an image include DKFillPattern, DKPathDecorator
		// and DKImageAdornment. If the style has any of these, apply it to the frontmost one. If it doesn't, create an image
		// adornment and add it to the front.

		NSImage* image = [[NSImage alloc] initWithPasteboard:pb];

		if (image != nil) {
			NSEnumerator* iter = [[style renderList] reverseObjectEnumerator];
			DKRasterizer* rast = nil;

			for (rast in iter) {
				if ([rast respondsToSelector:@selector(setImage:)]) {
					[(id)rast setImage:image];
					break;
				}
			}

			if (rast == nil) {
				// no existing rasterizer can handle it - add an adornment. If the hint suggests a path, make a path decorator instead
				DKRasterizer* adorn;

				if (options == kDKDerivedStyleForPathHint)
					adorn = [DKPathDecorator pathDecoratorWithImage:image];
				else {
					adorn = [DKImageAdornment imageAdornmentWithImage:image];
					[(DKImageAdornment*)adorn setFittingOption:kDKScaleToFitPreservingAspectRatio];
				}
				[style addRenderer:adorn];
			}

			wasMutated = YES;
		}
	}

	// text - if there is text on the pasteboard, set the text of an appropriate renderer, or add a text adornment

	NSString* pbString = [pb stringForType:NSStringPboardType];

	if (pbString != nil) {
		// look for renderers that can accept a string.  Currently this is only DKTextAdornment

		NSArray* textList = [style renderersOfClass:[DKTextAdornment class]];
		DKTextAdornment* tr;

		if (textList != nil && [textList count] > 0) {
			tr = [textList lastObject];
			[tr setLabel:pbString];
		} else {
			tr = [DKTextAdornment textAdornmentWithText:pbString];

			// if the style has text attributes, set these as the initial attributes for the adornment

			if ([self hasTextAttributes])
				[tr setTextAttributes:[self textAttributes]];

			// if the options suggest a shape, set the text to block mode and centre it

			if (options == kDKDerivedStyleForPathHint) {
				[tr setLayoutMode:kDKTextLayoutAlongPath];
				[tr setAlignment:NSJustifiedTextAlignment];
				[tr setVerticalAlignment:kDKTextShapeVerticalAlignmentTop];
			}

			[style addRenderer:tr];
		}

		wasMutated = YES;
	}

	if (wasMutated)
		return style;
	else {
		// nothing was done, so return self to avoid unwanted cloning of the style

		return self;
	}
}

#pragma mark -
#pragma mark - query methods to quickly determine general characteristics

/** @brief Queries whether the style has at least one stroke
 @return YES if there are one or more strokes, NO otherwise
 */
- (BOOL)hasStroke
{
	return [self containsRendererOfClass:[DKStroke class]];
}

/** @brief Queries whether the style has at least one filling property

 This queries all rasterizers for the -isFill property
 @return YES if there are one or more fill properties, NO otherwise
 */
- (BOOL)hasFill
{
	return [self isFill];
}

/** @brief Queries whether the style has at least one hatch property

 Hatches are not always considered to be 'fills' in the normal sense, so hatches are counted separately
 @return YES if there are one or more hatches, NO otherwise
 */
- (BOOL)hasHatch
{
	return [self containsRendererOfClass:[DKHatching class]];
}

/** @brief Queries whether the style has at least one text adornment property
 @return YES if there are one or more text adornments, NO otherwise
 */
- (BOOL)hasTextAdornment
{
	return [self containsRendererOfClass:[DKTextAdornment class]];
}

/** @brief Queries whether the style has any components at all
 @return YES if there are no components and no text attributes, NO if there is at least 1 or has text
 */
- (BOOL)isEmpty
{
	return [self countOfRenderList] == 0 && ![self hasTextAttributes];
}

#pragma mark -
#pragma mark - swatch images

/** @brief Creates a thumbnail image of the style
 @param size the desired size of the thumbnail
 @param type the type of thumbnail - currently rect and path types are supported, or selected automatically
 @return an image of a default path rendered using this style
 */
- (NSImage*)styleSwatchWithSize:(NSSize)size type:(DKStyleSwatchType)type
{
	// return the cached swatch if possible - i.e. size and type are the same and there is a cached swatch. Changes to the
	// style attributes etc should discard the cached swatch

	NSString* cacheKey = [self swatchCacheKeyForSize:size
												type:type];

	if ([mSwatchCache objectForKey:cacheKey] != nil)
		return [mSwatchCache objectForKey:cacheKey];

	//NSLog(@"building swatch (size: %@) for style '%@'", NSStringFromSize( size ), [self name]);

	// construct the image

	NSImage* image = [[NSImage alloc] initWithSize:size];
	NSBezierPath* path;
	NSRect r, br = NSMakeRect(0, 0, size.width, size.height);

	// note that because we know that the path drawn will be a rectangle, we can ignore the mitre limit and get more space.

	NSSize extra = [self extraSpaceNeededIgnoringMitreLimit];

	// r is the size of the dummy path to be rendered, taking into account how much space the style needs.
	// If r shrinks too small though the style will look silly, so make sure it is at least some size (10 x 10)

	r = NSInsetRect(br, extra.width, extra.height);

	if (r.size.width < 10)
		r.size.width = 10;

	if (r.size.height < 10)
		r.size.height = 10;

	[image setFlipped:YES];

	if (type == kDKStyleSwatchAutomatic) {
		if ([self hasFill] || [self hasTextAttributes] || [self hasHatch] || [self countOfRenderList] == 0)
			type = kDKStyleSwatchRectanglePath;
		else
			type = kDKStyleSwatchCurvePath;
	}

	if (type == kDKStyleSwatchCurvePath) {
		// draw a small curved segment

		path = [NSBezierPath bezierPath];
		[path moveToPoint:NSMakePoint(NSMinX(r), NSMaxY(r))];

		NSPoint ep, cp1, cp2;

		ep = NSMakePoint(NSMaxX(r), NSMinY(r));
		cp1 = NSMakePoint(NSMinX(r) + 6.0, NSMidY(r));
		cp2 = NSMakePoint(NSMaxX(r) - 6.0, NSMidY(r));

		[path curveToPoint:ep
			 controlPoint1:cp1
			 controlPoint2:cp2];
	} else
		path = [NSBezierPath bezierPathWithRect:r];

	// create a temporary shape that will render using this style and the calculated path

	DKDrawableShape* od = [DKDrawableShape drawableShapeWithBezierPath:path
															 withStyle:self];

	[image lockFocus];

	//[[NSColor clearColor] set];
	//NSRectFill( br );

	[od drawContent];

	// if there are text attributes, show an example string using these attributes. Use a text adornment so that any private attributes such
	// as knockout is displayed

	if ([self hasTextAttributes]) {
		NSAttributedString* example = [[NSAttributedString alloc] initWithString:@"AaBbCcDdEe"
																	  attributes:[self textAttributes]];
		DKTextAdornment* ta = [DKTextAdornment textAdornmentWithText:example];
		[ta setLayoutMode:kDKTextLayoutInBoundingRect];

		[ta drawInRect:r];

		//[example drawInRect:r withAttributes:[self textAttributes]];
	}

	[image unlockFocus];

	// cache the swatch - the image will only be rebuilt if the size or type requested changes,
	// or if the style itself is modified. The cache remembers all previously requested sizes until invalidated. The
	// use of this cache significantly speeds up building of user interfaces where swatches are used a lot, because
	// generating the swatch from scratch is relatively expensive.

	if (image)
		[mSwatchCache setObject:image
						 forKey:cacheKey];

	return image;
}

/** @brief Creates a thumbnail image of the style

 The swatch returned will have the curve path style if it has no fill, otherwise the rect style.
 @return an image of a path rendered using this style in the default size
 */
- (NSImage*)standardStyleSwatch
{
	return [self styleSwatchWithSize:STYLE_SWATCH_SIZE
								type:kDKStyleSwatchAutomatic];
}

- (NSImage*)imageToFitSize:(NSSize)aSize
{
	//NSLog(@"request for image, size = %@", NSStringFromSize( aSize ));

	NSString* cacheKey = [self swatchCacheKeyForSize:aSize
												type:kDKStyleSwatchAutomatic];
	NSImage* swatch;

	swatch = [mSwatchCache objectForKey:cacheKey];

	if (swatch != nil)
		return swatch;

	swatch = [self standardStyleSwatch];

	// if size is non-zero, image is scaled down to fit that size preserving the aspect ratio. This is good for making icons

	if (swatch != nil && !NSEqualSizes(aSize, NSZeroSize)) {
		// scale down if necessary keeping the same aspect ratio. If image is smaller than icon, just centre it.

		NSImage* iconImage = [NSImage imageFromImage:swatch
											withSize:aSize];
		[mSwatchCache setObject:iconImage
						 forKey:cacheKey];

		return iconImage;
	}

	return swatch;
}

- (NSImage*)image
{
	return [self imageToFitSize:NSMakeSize(128, 128)];
}

/** @brief Return a key for the swatch cache for the given size and type of swatch

 The key is a simple concatenation of the size and the type, but don't rely on this anywhere - just
 ask for the swatch you want and if it's cached it will be returned.
 @return a string that is used as the key to the swatches in the cache
 */
- (NSString*)swatchCacheKeyForSize:(NSSize)size type:(DKStyleSwatchType)type
{
	return [NSString stringWithFormat:@"%@_%ld", NSStringFromSize(size), (long)type];
}

/** @brief As -extraSpaceNeeded but any mitre limit applied by renderes are ignored

 Used when drawing swatches as path is known to have non-acute angles where the mitre limit matters
 @return the space needed for the style without mitre limit
 */
- (NSSize)extraSpaceNeededIgnoringMitreLimit
{
	NSSize rs, accSize = NSZeroSize;

	if ([self enabled]) {
		for (DKRasterizer* rend in self.renderList) {
			if ([rend respondsToSelector:_cmd]) {
				rs = [(id)rend extraSpaceNeededIgnoringMitreLimit];
			} else {
				rs = [rend extraSpaceNeeded];
			}

			if (rs.width > accSize.width) {
				accSize.width = rs.width;
			}

			if (rs.height > accSize.height) {
				accSize.height = rs.height;
			}
		}
	}

	return accSize;
}

#pragma mark -
#pragma mark - currently rendering client

/** @brief Returns the current object being rendered by this style

 This is only valid when called while rendering is in progress - mainly for the benefit of renderers
 that are part of this style
 @return the current rendering object
 */
- (id)currentRenderClient
{
	return m_renderClientRef;
}

/** @brief Returns a new style formed by copying the rasterizers from the receiver and the other style into one
 object

 The receiver's rasterizers are copied first, then otherStyles are appended, so they draw after
 (on top) of the receiver's.
 @param otherStyle a style object
 @return a new style object
 */
- (DKStyle*)styleByMergingFromStyle:(DKStyle*)otherStyle
{
	NSAssert(otherStyle != nil, @"can't merge a nil style");

	DKStyle* newStyle = [self mutableCopy];

	for (DKRasterizer* rast in otherStyle.renderList) {
		[newStyle addRenderer:[rast copy]];
	}

	return newStyle;
}

/** @brief Returns a new style formed by copying the rasterizers from the receiver but not those of <aClass>
 @param aClass the rasterizer class not to be copied
 @return a new style object
 */
- (DKStyle*)styleByRemovingRenderersOfClass:(Class)aClass
{
	DKStyle* newStyle = [self mutableCopy];

	[newStyle removeRenderersOfClass:aClass
						 inSubgroups:YES];

	return newStyle;
}

/** @brief Returns a copy of the style having a new unique ID

 Similar to -mutabelCopy except name is copied and the object is returned autoreleased
 @return a new style object
 */
- (id)clone
{
	DKStyle* clone = [self mutableCopy];
	[clone setName:[self name]];
	return clone;
}

#pragma mark -
#pragma mark As a DKRastGroup

/** @brief Adds a renderer to the style, ensuring internal KVO linkage is established
 @param renderer the renderer to attach
 */
- (void)addRenderer:(DKRasterizer*)renderer
{
	if (![self locked]) {
		[[[self undoManager] prepareWithInvocationTarget:self] removeRenderer:renderer];
		[self notifyClientsBeforeChange];
		[super addRenderer:renderer];
		[self notifyClientsAfterChange];
	}
}

/** @brief Inserts a renderer into the style, ensuring internal KVO linkage is established
 @param renderer the renderer to insert
 @param indx the index where the renderer is inserted
 */
- (void)insertRenderer:(DKRasterizer*)renderer atIndex:(NSUInteger)indx
{
	if (![self locked]) {
		[[[self undoManager] prepareWithInvocationTarget:self] removeRenderer:renderer];
		[self notifyClientsBeforeChange];
		[super insertRenderer:renderer
					  atIndex:indx];
		[self notifyClientsAfterChange];
	}
}

/** @brief Removes a renderer from the style, ensuring internal KVO linkage is removed
 @param renderer the renderer to remove
 */
- (void)removeRenderer:(DKRasterizer*)renderer
{
	if (![self locked]) {
		NSUInteger indx = [self indexOfRenderer:renderer];

		[[[self undoManager] prepareWithInvocationTarget:self] insertRenderer:renderer
																	  atIndex:indx];
		[self notifyClientsBeforeChange];
		[super removeRenderer:renderer];
		[self notifyClientsAfterChange];
	}
}

/** @brief Moves a renderer from one place in the list to another, setting up undo

 If src == dest, does nothing and no undo is created
 @param src the index being moved
 @param dest where it will move to
 */
- (void)moveRendererAtIndex:(NSUInteger)src toIndex:(NSUInteger)dest
{
	if (![self locked] && (src != dest)) {
		LogEvent_(kStateEvent, @"moving style component at %lu to %lu", (unsigned long)src, (unsigned long)dest);

		[[[self undoManager] prepareWithInvocationTarget:self] moveRendererAtIndex:dest
																		   toIndex:src];
		[self notifyClientsBeforeChange];
		[super moveRendererAtIndex:src
						   toIndex:dest];
		[self notifyClientsAfterChange];
	}
}

/** @brief Returns the root of the group tree - which is always self
 @return self
 */
- (DKRastGroup*)root
{
	return self;
}

/** @brief Informs the style that a new component was added to the tree and needs observing
 @param observable the object to start watching
 */
- (void)observableWasAdded:(GCObservableObject*)observable
{
	LogEvent_(kKVOEvent, @"observable %@ will start being observed by %@ ('%@')", [observable description], [self description], [self name]);

	NSAssert(observable != nil, @"observable object was nil");
	[observable setUpKVOForObserver:self];
}

/** @brief Informs the style that a  component is about to be removed from the tree and should stop being observed
 @param observable the object to stop watching
 */
- (void)observableWillBeRemoved:(GCObservableObject*)observable
{
	LogEvent_(kKVOEvent, @"observable %@ will stop being observed by %@ ('%@')", [observable description], [self description], [self name]);

	NSAssert(observable != nil, @"observable object was nil");
	[observable tearDownKVOForObserver:self];
}

#pragma mark -
#pragma mark As a DKRasterizer

/** @brief Renders the object using this style

 Sets the value of the client for the duration of rendering */
- (void)render:(id<DKRenderable>)object
{
	if (![object conformsToProtocol:@protocol(DKRenderable)])
		return;

	if ([self enabled]) {
		@autoreleasepool {

			if (![[self class] shouldAntialias] && [NSGraphicsContext currentContextDrawingToScreen]) {
				[[NSGraphicsContext currentContext] setShouldAntialias:NO];
				[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
			}

			m_renderClientRef = object;

			@try
			{
				[super render:object];
			}
			@catch (NSException* exception)
			{
				// exceptions thrown during drawing can cause a lot of problems that multiply a minor bug into a major one.
				// Each renderer should ideally take steps to catch an yexceptions and deal with them appropriately - if it does not
				// this catch will log the problem, but NOT rethrown, so higher level drawing code doesn't see the exception. If you
				// see this log, the problem should be investigated.

				NSLog(@"An exception occurred while rendering the style - PLEASE FIX - %@. Exception = %@", self, exception);
			}
			m_renderClientRef = nil;

		}
	}
}

/** @brief Sets the style's name undoably

 Does not inform the client(s) as this is not typically a visual change, but does send a notification */
- (void)setName:(NSString*)name
{
	if (![self locked]) {
		[[self undoManager] registerUndoWithTarget:self
										  selector:@selector(setName:)
											object:[self name]];
		[super setName:name];
		[[self undoManager] setActionName:NSLocalizedString(@"Style Name", nil)];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKStyleNameChangedNotification
															object:self];
	}
}

/** @brief Set whether the style is enabled or not

 Disabled styles don't draw anything
 @param enable YES to enable, NO to disable
 */
- (void)setEnabled:(BOOL)enable
{
	if (enable != [self enabled]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setEnabled:[self enabled]];
		[self notifyClientsBeforeChange];
		[super setEnabled:enable];
		[self notifyClientsAfterChange];

		if (![[self undoManager] isUndoing] && ![[self undoManager] isRedoing]) {
			if ([self enabled])
				[[self undoManager] setActionName:NSLocalizedString(@"Enable Style", @"undo string for enable style")];
			else
				[[self undoManager] setActionName:NSLocalizedString(@"Disable Style", @"undo string for disable style")];
		}
	}
}

#pragma mark -
#pragma mark As a GCObservableObject

+ (NSArray*)observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:@[@"locked", @"styleSharable"]];
}

#pragma mark -
#pragma mark As a NSObject

+ (void)initialize
{
	sShouldDrawShadows = ![[NSUserDefaults standardUserDefaults] boolForKey:kDKStyleDisplayPerformance_no_shadows];
	sAntialias = ![[NSUserDefaults standardUserDefaults] boolForKey:kDKStyleDisplayPerformance_no_anti_aliasing];
	sSubstitute = [[NSUserDefaults standardUserDefaults] boolForKey:kDKStyleDisplayPerformance_substitute_styles];
}

- (void)dealloc
{
	LogEvent_(kKVOEvent, @"style %@ ('%@') is being deallocated, will stop observing all components", self, [self name]);

	// stop observing all of the component rasterizers - any group objects in the list will propagate this
	// message down to their subordinate objects.

	[[self renderList] makeObjectsPerformSelector:@selector(tearDownKVOForObserver:)
									   withObject:self];
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
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

		if (m_uniqueKey == nil) {
			return nil;
		}
	}
	return self;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@ <0x%p> '%@' [%@]", NSStringFromClass([self class]), self, [self name], [self uniqueKey]];
}

// n.b. isEqual: defines equality more loosely than isEqualToStyle: which also considers the timestamp

- (BOOL)isEqual:(id)anObject
{
	if ([anObject respondsToSelector:@selector(uniqueKey)])
		return [[self uniqueKey] isEqualToString:[anObject uniqueKey]];
	else
		return NO;
}

- (NSUInteger)hash
{
	return [[self uniqueKey] hash];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeObject:[self uniqueKey]
				 forKey:@"DKDrawingStyle_uniqueKey"];
	[coder encodeBool:[self isStyleRegistered]
			   forKey:@"DKDrawingStyle_registeredStyle"];
	[coder encodeDouble:[self lastModificationTimestamp]
				 forKey:@"DKDrawingStyle_lastModTime"];

	[coder encodeObject:[self textAttributes]
				 forKey:@"styledict"];
	[coder encodeBool:[self isStyleSharable]
			   forKey:@"shared"];
	[coder encodeBool:[self locked]
			   forKey:@"locked"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		// recover the unique key - older files won't have it so assign one

		NSString* uk = [coder decodeObjectForKey:@"DKDrawingStyle_uniqueKey"];

		if (uk == nil) {
			// the style was saved without a key, so assign one - no remerging will be
			// attempted as there's no information to go on. This will only apply to
			// very old files that predate this mechanism.

			[self assignUniqueKey];
			m_lastModTime = [NSDate timeIntervalSinceReferenceDate];
			m_mergeFlag = NO;
		} else {
			m_uniqueKey = uk;

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

		[[self renderList] makeObjectsPerformSelector:@selector(setUpKVOForObserver:)
										   withObject:self];
	}

	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol

/**
 Styles should always be copied before use, in order that the shared flag is automatically
 honoured. Drawable objects do this by default, so within drawkit this 'just works'. */
- (id)copyWithZone:(NSZone*)zone
{
	if ([self isStyleSharable])
		return self;
	else
		return [self mutableCopyWithZone:zone];
}

#pragma mark -
#pragma mark As part of NSKeyValueObserving Protocol

/** @brief Sets up undo invocations when the value of a contained property is changed */
- (void)observeValueForKeyPath:(NSString*)keypath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
#pragma unused(context)

	// this is called whenever a property of a renderer contained in the style is changed. Its job is to consolidate both undo
	// and client object refresh when properties are altered directly, which of course they usually will be. This powerfully
	// means that renderers themselves do not need to know anything about undo or how they fit into the overall scheme of things.

	NSKeyValueChange ch = [[change objectForKey:NSKeyValueChangeKindKey] integerValue];
	BOOL wasChanged = NO;

	if (ch == NSKeyValueChangeSetting) {
		if (![[change objectForKey:NSKeyValueChangeOldKey] isEqual:[change objectForKey:NSKeyValueChangeNewKey]]) {
			[[[self undoManager] prepareWithInvocationTarget:self] changeKeyPath:keypath
																		ofObject:object
																		 toValue:[change objectForKey:NSKeyValueChangeOldKey]];
			wasChanged = YES;
		}
	} else if (ch == NSKeyValueChangeInsertion || ch == NSKeyValueChangeRemoval) {
		// Cocoa has a bug where array insertion/deletion changes don't properly record the old array.
		// GCObserveableObject gives us a workaround

		NSArray* old = [object oldArrayValueForKeyPath:keypath];

		[[[self undoManager] prepareWithInvocationTarget:self] changeKeyPath:keypath
																	ofObject:object
																	 toValue:old];

		wasChanged = YES;
	}

	if (wasChanged && !([[self undoManager] isUndoing] || [[self undoManager] isRedoing])) {
		if ([object respondsToSelector:@selector(actionNameForKeyPath:
														   changeKind:)])
			[[self undoManager] setActionName:[object actionNameForKeyPath:keypath
																changeKind:ch]];
		else
			[[self undoManager] setActionName:[GCObservableObject actionNameForKeyPath:keypath
																			  objClass:[object class]]];
	}

	[self notifyClientsAfterChange];
}

#pragma mark -
#pragma mark As part of NSMutableCopying Protocol

/**
 The copy's initial name is deliberately not set */
- (id)mutableCopyWithZone:(NSZone*)zone
{
	DKStyle* copy = [super copyWithZone:zone];
	[copy setLocked:NO];
	[copy setName:nil];
	[copy setStyleSharable:[self isStyleSharable]];

	NSDictionary* attribs = [[self textAttributes] deepCopy];

	[copy setTextAttributes:attribs];

	// the copy needs to start observing all of its components:

	[[copy renderList] makeObjectsPerformSelector:@selector(setUpKVOForObserver:)
									   withObject:copy];

	return copy;
}

@end
