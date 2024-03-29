/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKRastGroup.h"

NS_ASSUME_NONNULL_BEGIN

@class DKDrawableObject, DKUndoManager;

//! swatch types that can be passed to \c -styleSwatchWithSize:type:
typedef NS_ENUM(NSInteger, DKStyleSwatchType) {
	kDKStyleSwatchAutomatic = -1,
	kDKStyleSwatchRectanglePath = 0,
	kDKStyleSwatchCurvePath = 1
};

//! options that can be passed to \c -derivedStyleWithPasteboard:withOptions:
typedef NS_ENUM(NSInteger, DKDerivedStyleOptions) {
	kDKDerivedStyleDefault = 0,
	kDKDerivedStyleForPathHint = 1,
	kDKDerivedStyleForShapeHint = 2
};

#define STYLE_SWATCH_SIZE NSMakeSize(128.0, 128.0)

//! n.b. for style registry API, see DKStyleRegistry.h
@interface DKStyle : DKRastGroup <NSCoding, NSCopying, NSMutableCopying> {
@private
	NSDictionary<NSAttributedStringKey, id>* m_textAttributes; // supports text additions
	NSUndoManager* __weak m_undoManagerRef; // style's undo manager
	BOOL m_shared; // YES if the style is shared
	BOOL m_locked; // YES if style can't be edited
	id m_renderClientRef; // valid only while actually drawing
	NSString* m_uniqueKey; // unique key, set once for all time
	BOOL m_mergeFlag; // set to YES when a style is read in from a file and was saved in a registered state.
	NSTimeInterval m_lastModTime; // timestamp to determine when styles have been updated
	NSUInteger m_clientCount; // keeps count of the clients using the style
	NSMutableDictionary* mSwatchCache; // cache of swatches at various sizes previously requested
}

// basic standard styles:

/** @brief Returns a very basic style object.
 
 Style has a 1 pixel black stroke and a light gray fill. Style may be shared if sharing is <code>YES</code>.
 Very boring, black stroke and light gray fill.
 @return A style object.
 */
+ (DKStyle*)defaultStyle;
/** @brief Returns a basic style with a dual stroke, 5.6pt light grey over 8.0pt black.
 
 Style may be shared if sharing is <code>YES</code>.
 Grey stroke over wider black stroke, no fill.
 @return A style object.
 */
+ (DKStyle*)defaultTrackStyle;

// easy construction of other simple styles:

/** @brief Creates a simple style with fill and strokes of the colours passed.
 
 Stroke is drawn "on top" of fill, so rendered width appears true. You can pass \c nil for either
 colour to not create the renderer for that attribute, but note that passing \c nil for BOTH parameters
 is an error.
 @param fc The colour for the solid fill.
 @param sc The colour for the \c 1.0 pixel wide stroke.
 @return A style object.
 */
+ (DKStyle*)styleWithFillColour:(nullable NSColor*)fc strokeColour:(nullable NSColor*)sc;

/** @brief Creates a simple style with fill and strokes of the colours passed.
 
 Stroke is drawn "on top" of fill, so rendered width appears true. You can pass \c nil for either
 colour to not create the renderer for that attribute, but note that passing \c nil for BOTH parameters
 is an error.
 @param fc The colour for the solid fill.
 @param sc The colour for the stroke.
 @param sw The width of the stroke.
 @return A style object.
 */
+ (DKStyle*)styleWithFillColour:(nullable NSColor*)fc strokeColour:(nullable NSColor*)sc strokeWidth:(CGFloat)sw;

/** @brief Creates a style from data on the pasteboard.
 
 Preferentially tries to match the style name in order to preserve style sharing.
 @param pb A pasteboard.
 @return A style object.
 */
+ (nullable DKStyle*)styleFromPasteboard:(NSPasteboard*)pb;

/** @brief Return a list of types supported by styles for pasteboard operations.
 @return an array listing the pasteboard types usable by DKStyle.
 */
@property (class, readonly, copy) NSArray<NSPasteboardType>* stylePasteboardTypes;
+ (BOOL)canInitWithPasteboard:(NSPasteboard*)pb;

// pasted styles - separate non-persistent registry

/** @brief Look for the style in the pasteboard registry. If not there, look in the main registry.
 */
+ (DKStyle*)styleWithPasteboardName:(NSPasteboardName)name;

/** @brief Put the style into the pasteboard registry.
 */
+ (void)registerStyle:(DKStyle*)style withPasteboardName:(NSPasteboardName)pbname;

// default sharing flag

/** @brief Set whether styles are generally shared or not

 Sharing styles means that all object that share that style will change when a style property changes,
 regardless of any other state information, such as selection, layer owner, etc. Styles are set
 \b not to be shared by default.
 */
@property (class) BOOL stylesAreSharableByDefault;

// shadows:

/** @brief Returns a default NSShadow object.

 Shadows are set as properties of certain renderers, such as \c DKFill and <code>DKStroke</code>.
 @return A shadow object.
 */
+ (NSShadow*)defaultShadow;

/** @brief Set whether shadow attributes within a style should be drawn.

 Drawing shadows is one of the main performance killers, so this provides a way to turn them off
 in certain situations. Rasterizers that have a shadow property should check and honour this setting.
 @param drawShadows \c YES to draw shadows, \c NO to suppress them.
 @return The previous state of this setting.
 */
+ (BOOL)setWillDrawShadows:(BOOL)drawShadows;

/** @brief Set whether shadow attributes within a style should be drawn.

 Drawing shadows is one of the main performance killers, so this provides a way to turn them off
 in certain situations. Rasterizers that have a shadow property should check and honour this setting.
 @return \c YES to draw shadows, \c NO to suppress them.
 */
@property (class, readonly) BOOL willDrawShadows;

// performance options:

/** @brief Set whether drawing should be anti-aliased or not

 Default is <code>YES</code>. Turning off anti-aliasing can speed up drawing at the expense of quality.
 Set to \c YES to anti-alias, \c NO to turn anti-aliasing off.
 */
@property (class) BOOL shouldAntialias;

/** @brief Set whether the style should substitute a simple placeholder when a style is complex and slow to
 render.

 Default is <code>NO</code>. Typically this method causes a style to render a single simple stroke in place of
 its actual components. If the style has a simple stroke, it is used, otherwise a default one is used.
 Set to \c YES to substitute a faster placeholder style for complex styles.
 */
@property (class) BOOL shouldSubstitutePlaceholderStyle;

// updating & notifying clients:

/** @brief Informs clients that a property of the style is about to change. */
- (void)notifyClientsBeforeChange;

/** @brief Informs clients that a property of the style has just changed.

 This method is called in response to any observed change to any renderer the style contains. */
- (void)notifyClientsAfterChange;

/** @brief Called when a style is attached to an object.

 The notification's object is the drawable, not the style - the style is passed in the user info
 dictionary with the key 'style'.
 @param toObject The object the style was attached to.
 */
- (void)styleWasAttached:(DKDrawableObject*)toObject;

/** @brief Called when a style is about to be removed from an object.

 The notification's object is the drawable, not the style - the style is passed in the user info
 dictionary with the key 'style'. This permits this to be called by the dealloc method of the
 drawable, which would not be the case if the drawable was retained by the dictionary.
 @param fromObject The object the style was attached to.
 */
- (void)styleWillBeRemoved:(DKDrawableObject*)fromObject;

/** @brief Returns the number of client objects using this style.

 This is for information only - do not base critical code on this value.
 @return An unsigned integer, the number of clients using this style.
 */
@property (readonly) NSUInteger countOfClients;

// (text) attributes - basic support

/** @brief Sets the text attributes dictionary
 
 Objects that display text can use a style's text attributes. This together with sharable styles
 allows text (labels in particular) to have their styling changed for a whole drawing. See also
 DKStyle+Text which gives more text-oriented methods that manipulate theses attributes.
 */
@property (atomic, copy, nullable) NSDictionary<NSAttributedStringKey, id>* textAttributes;

/** @brief Return wjether the style has any text attributes set.
 @return \c YES if there are any text attributes.
 */
@property (readonly) BOOL hasTextAttributes;

/** @brief Remove all of the style's current text attributes.

 Does nothing if the style is locked.
 */
- (void)removeTextAttributes;

// shared and locked status:

/** @brief Sets whether the style can be shared among multiple objects, or whether unique copies should be
 used.

 Default is copied from class setting +shareStyles. Changing this flag is not undoable and does
 not inform clients. It does send a notification however.
 Set to \c YES to share among several objects, \c NO to make unique copies.
 */
@property (nonatomic, getter=isStyleSharable) BOOL styleSharable;

/** @brief Whether style is locked (editable).

 Locked styles are intended not to be editable, though this cannot be entirely enforced by the
 style itself - client code should honour the locked state. You cannot add or remove renderers from a
 locked style. Styles are normally not locked, but styles that are put in the registry are locked
 by that action. Changing the lock state doesn't inform clients, since in general this does not
 cause a visual change.
 */
@property (nonatomic) BOOL locked;

// registry info:

/** @brief Returns whether the style is registered with the current style registry.

 This method gives a definitive answer about
 whether the style is registered. Along with locking, this should prevent accidental editing of
 styles that an app might prefer to consider "read only".
 Is \c YES if known to the registry.
 */
@property (readonly, getter=isStyleRegistered) BOOL styleRegistered;

/** @brief Returns the list of keys that the style is registered under (if any).

 The returned array may contain no keys if the style isn't registered, or >1 key if the style has
 been registered multiple times with different keys (not recommended). The key is not intended for
 display in a user interface and has no relationship to the style's name.
 */
@property (readonly, copy) NSArray<NSString*>* registryKeys;

/** @brief Returns the unique key of the style.

 The unique key is set once and for all time when the style is initialised, and is guaranteed unique
 as it is a UUID. 
 */
@property (readonly, copy) NSString* uniqueKey;

/** @brief Sets the unique key of the style.

 Called when the object is inited, this assigns a unique key. The key cannot be reassigned - its
 purpose is to identify this style regardless of any mutations it otherwise undergoes, including its
 ordinary name.
 */
- (void)assignUniqueKey;

/** @brief Query whether the style should be considered for a re-merge with the registry.

 Re-merging is done when a document is opened. Any styles that were registered when it was saved will
 set this flag when the style is inited from the archive. The document gathers these styles together
 and remerges them according to the user's settings.
 Is \c YES if the style should be a candidate for re-merging.
 */
@property (readonly) BOOL requiresRemerge;
- (void)clearRemergeFlag;
@property (readonly) NSTimeInterval lastModificationTimestamp;

/** @brief Is this style the same as <code>aStyle</code>?

 Styles are considered equal if they have the same unique ID and the same timestamp.
 @param aStyle A style to compare this with.
 @return \c YES if the styles ar the same, \c NO otherwise.
 */
- (BOOL)isEqualToStyle:(DKStyle*)aStyle;

// undo:

/** @brief Sets the undo manager that style changes will be recorded by.

 The undo manager is not retained.
 */
@property (weak, nullable) NSUndoManager* undoManager;

/** @brief Vectors undo invocations back to the object from whence they came.
 @param keypath The keypath of the action, relative to the object.
 @param object The real target of the invocation.
 */
- (void)changeKeyPath:(NSString*)keypath ofObject:(id)object toValue:(nullable id)value;

// stroke utilities:

/** @brief Adjusts all contained stroke widths by the given scale value
 @param scale The scale factor, e.g. \C 2.0 will double all stroke widths.
 @param quiet If <code>YES</code>, will ignore locked state and not inform clients. This is done when making hit
 bitmaps with thin strokes to make them much easier to hit.
 */
- (void)scaleStrokeWidthsBy:(CGFloat)scale withoutInformingClients:(BOOL)quiet;

/** @brief Returns the widest stroke width in the style.
 
 The width of the widest contained stroke, or \c 0.0 if there are no strokes.
 */
@property (readonly) CGFloat maxStrokeWidth;

/** @brief Returns the difference between the widest and narrowest strokes.
 Can be \c 0.0 if there are no strokes or only one stroke.
 */
@property (readonly) CGFloat maxStrokeWidthDifference;

/** @brief Applies the cap, join, mitre limit, dash and line width attributes of the rear-most stroke to the path.

 This can be used to set up a path for a Quartz operation such as outlining. The rearmost stroke
 attribute is used if there is more than one on the basis that this forms the largest element of
 the stroke. However, for the line width the max stroke is applied. If there are no strokes the
 path is not changed.
 @param path A bezier path to apply the attributes to.
 */
- (void)applyStrokeAttributesToPath:(NSBezierPath*)path;

/** @brief Returns the number of strokes.

 Counts all strokes, including those in subgroups.
 */
@property (readonly) NSUInteger countOfStrokes;

// clipboard:

/** @brief Copies the style to the pasteboard.

 Puts both the archived style and its key (as a separate type) on the pasteboard. When pasting a
 style, the key should be used in preference to allow a possible shared style to work as expected.
 @param pb The pasteboard to copy to.
 */
- (BOOL)copyToPasteboard:(NSPasteboard*)pb;

/** @brief Returns a style based on the receiver plus any data on the clipboard we are able to use.

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
 @param pb The pasteboard to take additional data from.
 @return A new style.
 */
- (DKStyle*)derivedStyleWithPasteboard:(NSPasteboard*)pb;

/** @brief Returns a style based on the receiver plus any data on the clipboard we are able to use.

 See notes for \c derivedStyleWithPasteboard:
 The options are used to set up renderers in more appropriate ways when the type of object that the
 style will be attached to is known.
 @param pb The pasteboard to take additional data from.
 @param options Some hints that can influence the outcome of the operation.
 @return A new style.
 */
- (DKStyle*)derivedStyleWithPasteboard:(NSPasteboard*)pb withOptions:(DKDerivedStyleOptions)options;

// query methods:

/** @brief Queries whether the style has at least one stroke.
 @return \c YES if there are one or more strokes, \c NO otherwise.
 */
@property (readonly) BOOL hasStroke;

/** @brief Queries whether the style has at least one filling property.

 This queries all rasterizers for the \c -isFill property.
 Is \c YES if there are one or more fill properties, \c NO otherwise.
 */
@property (readonly) BOOL hasFill;

/** @brief Queries whether the style has at least one hatch property.

 Hatches are not always considered to be 'fills' in the normal sense, so hatches are counted separately
 Is \c YES if there are one or more hatches, \c NO otherwise.
 */
@property (readonly) BOOL hasHatch;

/** @brief Queries whether the style has at least one text adornment property.
 Is \c YES if there are one or more text adornments, \c NO otherwise.
 */
@property (readonly) BOOL hasTextAdornment;

/** @brief Queries whether the style has any components at all.
 Is \c YES if there are no components and no text attributes, \c NO if there is at least one or has text
 */
@property (readonly, getter=isEmpty) BOOL empty;

// swatch images:

/** @brief Creates a thumbnail image of the style.
 @param size The desired size of the thumbnail.
 @param type The type of thumbnail - currently rect and path types are supported, or selected automatically.
 @return An image of a default path rendered using this style.
 */
- (NSImage*)styleSwatchWithSize:(NSSize)size type:(DKStyleSwatchType)type;

/** @brief Creates a thumbnail image of the style.

 The swatch returned will have the curve path style if it has no fill, otherwise the rect style.
 @return An image of a path rendered using this style in the default size.
 */
- (NSImage*)standardStyleSwatch;
- (nullable NSImage*)image;
- (nullable NSImage*)imageToFitSize:(NSSize)aSize;

@property (readonly, strong) NSImage* standardStyleSwatch;
@property (readonly, strong, nullable) NSImage* image;

/** @brief Return a key for the swatch cache for the given size and type of swatch.

 The key is a simple concatenation of the size and the type, but don't rely on this anywhere - just
 ask for the swatch you want and if it's cached it will be returned.
 @return A string that is used as the key to the swatches in the cache.
 */
- (NSString*)swatchCacheKeyForSize:(NSSize)size type:(DKStyleSwatchType)type;

// currently rendering client (may be queried by renderers)

/** @brief Returns the current object being rendered by this style.

 This is only valid when called while rendering is in progress - mainly for the benefit of renderers
 that are part of this style.
 @return The current rendering object.
 */
- (id)currentRenderClient;

// making derivative styles:

/** @brief Returns a new style formed by copying the rasterizers from the receiver and the other style into one
 object.

 The receiver's rasterizers are copied first, then otherStyles are appended, so they draw after
 (on top) of the receiver's.
 @param otherStyle A style object.
 @return A new style object.
 */
- (DKStyle*)styleByMergingFromStyle:(DKStyle*)otherStyle;

/** @brief Returns a new style formed by copying the rasterizers from the receiver but not those of <code>aClass</code>.
 @param aClass The rasterizer class not to be copied.
 @return A new style object.
 */
- (DKStyle*)styleByRemovingRenderersOfClass:(Class)aClass;

/** @brief Returns a copy of the style having a new unique ID.

 Similar to \c -mutableCopy except \c name is copied and the object is returned autoreleased.
 @return A new style object.
 */
- (id)clone;

@end

// pasteboard types:

extern NSPasteboardType const kDKStylePasteboardType NS_SWIFT_NAME(dkStyle);
extern NSPasteboardType const kDKStyleKeyPasteboardType NS_SWIFT_NAME(dkStyleKey);

// notifications:

extern NSNotificationName const kDKStyleWillChangeNotification;
extern NSNotificationName const kDKStyleDidChangeNotification;
extern NSNotificationName const kDKStyleTextAttributesDidChangeNotification;
extern NSNotificationName const kDKStyleWasAttachedNotification;
extern NSNotificationName const kDKStyleWillBeDetachedNotification;
extern NSNotificationName const kDKStyleLockStateChangedNotification;
extern NSNotificationName const kDKStyleSharableFlagChangedNotification;
extern NSNotificationName const kDKStyleNameChangedNotification;

// preferences keys

extern NSString* const kDKStyleDisplayPerformance_no_anti_aliasing;
extern NSString* const kDKStyleDisplayPerformance_no_shadows;
extern NSString* const kDKStyleDisplayPerformance_substitute_styles;

NS_ASSUME_NONNULL_END
