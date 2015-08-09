/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRastGroup.h"

@class DKDrawableObject, DKUndoManager;

// swatch types that can be passed to -styleSwatchWithSize:type:

typedef enum {
	kDKStyleSwatchAutomatic = -1,
	kDKStyleSwatchRectanglePath = 0,
	kDKStyleSwatchCurvePath = 1
} DKStyleSwatchType;

// options that can be passed to -derivedStyleWithPasteboard:withOptions:

typedef enum {
	kDKDerivedStyleDefault = 0,
	kDKDerivedStyleForPathHint = 1,
	kDKDerivedStyleForShapeHint = 2
} DKDerivedStyleOptions;

#define STYLE_SWATCH_SIZE NSMakeSize(128.0, 128.0)

// n.b. for style registry API, see DKStyleRegistry.h

@interface DKStyle : DKRastGroup <NSCoding, NSCopying, NSMutableCopying> {
@private
	NSDictionary* m_textAttributes; // supports text additions
	NSUndoManager* m_undoManagerRef; // style's undo manager
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

+ (DKStyle*)defaultStyle; // very boring, black stroke and light gray fill
+ (DKStyle*)defaultTrackStyle; // grey stroke over wider black stroke, no fill

// easy construction of other simple styles:

+ (DKStyle*)styleWithFillColour:(NSColor*)fc strokeColour:(NSColor*)sc;
+ (DKStyle*)styleWithFillColour:(NSColor*)fc strokeColour:(NSColor*)sc strokeWidth:(CGFloat)sw;
+ (DKStyle*)styleFromPasteboard:(NSPasteboard*)pb;

/** @brief Return a list of types supported by styles for pasteboard operations
 @return an array listing the pasteboard types usable by DKStyle
 */
+ (NSArray*)stylePasteboardTypes;
+ (BOOL)canInitWithPasteboard:(NSPasteboard*)pb;

// pasted styles - separate non-persistent registry

+ (DKStyle*)styleWithPasteboardName:(NSString*)name;
+ (void)registerStyle:(DKStyle*)style withPasteboardName:(NSString*)pbname;

// default sharing flag

/** @brief Set whether styles are generally shared or not

 Sharing styles means that all object that share that style will change when a style property changes,
 regardless of any other state information, such as selection, layer owner, etc. Styles are set
 NOT to be shared by default.
 @param share YES to share styles, NO to return unique copies.
 */
+ (void)setStylesAreSharableByDefault:(BOOL)share;

/** @brief Query whether styles are generally shared or not

 Styles are set NOT to be shared by default.
 @return YES if styles are shared, NO if unique copies will be returned
 */
+ (BOOL)stylesAreSharableByDefault;

// shadows:

/** @brief Returns a default NSShadow object

 Shadows are set as properties of certain renderers, such as DKFill and DKStroke
 @return a shadow object
 */
+ (NSShadow*)defaultShadow;

/** @brief Set whether shadow attributes within a style should be drawn

 Drawing shadows is one of the main performance killers, so this provides a way to turn them off
 in certain situations. Rasterizers that have a shadow property should check and honour this setting.
 @param drawShadows YES to draw shadows, NO to suppress them
 @return the previous state of this setting
 */
+ (BOOL)setWillDrawShadows:(BOOL)drawShadows;

/** @brief Set whether shadow attributes within a style should be drawn

 Drawing shadows is one of the main performance killers, so this provides a way to turn them off
 in certain situations. Rasterizers that have a shadow property should check and honour this setting.
 @return YES to draw shadows, NO to suppress them
 */
+ (BOOL)willDrawShadows;

// performance options:

/** @brief Set whether drawing should be anti-aliased or not

 Default is YES. Turning off anti-aliasing can speed up drawing at the expense of quality.
 @param aa YES to anti-alias, NO to turn anti-aliasing off
 */
+ (void)setShouldAntialias:(BOOL)aa;

/** @brief Set whether drawing should be anti-aliased or not

 Default is YES. Turning off anti-aliasing can speed up drawing at the expense of quality.
 @return YES to anti-alias, NO to turn anti-aliasing off
 */
+ (BOOL)shouldAntialias;

/** @brief Set whether the style should substitute a simple placeholder when a style is complex and slow to
 render.

 Default is NO. Typically this method causes a style to render a single simple stroke in place of
 its actual components. If the style has a simple stroke, it is used, otherwise a default one is used.
 @param substitute YES to substitute a faster placeholder style for complex styles
 */
+ (void)setShouldSubstitutePlaceholderStyle:(BOOL)substitute;

/** @brief Set whether the style should substitute a simple placeholder when a style is complex and slow to
 render.

 Default is NO. Typically this method causes a style to render a single simple stroke in place of
 its actual components. If the style has a simple stroke, it is used, otherwise a default one is used.
 @return YES to substitute a faster placeholder style for complex styles
 */
+ (BOOL)shouldSubstitutePlaceholderStyle;

// updating & notifying clients:

/** @brief Informs clients that a property of the style is about to change */
- (void)notifyClientsBeforeChange;

/** @brief Informs clients that a property of the style has just changed

 This method is called in response to any observed change to any renderer the style contains */
- (void)notifyClientsAfterChange;

/** @brief Called when a style is attached to an object

 The notification's object is the drawable, not the style - the style is passed in the user info
 dictionary with the key 'style'.
 @param toObject the object the style was attached to
 */
- (void)styleWasAttached:(DKDrawableObject*)toObject;

/** @brief Called when a style is about to be removed from an object

 The notification's object is the drawable, not the style - the style is passed in the user info
 dictionary with the key 'style'. This permits this to be called by the dealloc method of the
 drawable, which would not be the case if the drawable was retained by the dictionary.
 @param toObject the object the style was attached to
 */
- (void)styleWillBeRemoved:(DKDrawableObject*)fromObject;

/** @brief Returns the number of client objects using this style

 This is for information only - do not base critical code on this value
 @return an unsigned integer, the number of clients using this style
 */
- (NSUInteger)countOfClients;

// (text) attributes - basic support

/** @brief Sets the text attributes dictionary

 Objects that display text can use a style's text attributes. This together with sharable styles
 allows text (labels in particular) to have their styling changed for a whole drawing. See also
 DKStyle+Text which gives more text-oriented methods that manipulate theses attributes.
 @param attrs a dictionary of text attributes */
- (void)setTextAttributes:(NSDictionary*)attrs;

/** @brief Returns the attributes dictionary

 Renderers are not considered attributes in this sense
 @return a dictionary of attributes
 */
- (NSDictionary*)textAttributes;

/** @brief Return wjether the style has any text attributes set
 @return YES if there are any text attributes
 */
- (BOOL)hasTextAttributes;

/** @brief Remove all of the style's current text attributes

 Does nothing if the style is locked
 */
- (void)removeTextAttributes;

// shared and locked status:

/** @brief Sets whether the style can be shared among multiple objects, or whether unique copies should be
 used.

 Default is copied from class setting +shareStyles. Changing this flag is not undoable and does
 not inform clients. It does send a notification however.
 @param share YES to share among several objects, NO to make unique copies.
 */
- (void)setStyleSharable:(BOOL)share;

/** @brief Returns whether the style can be shared among multiple objects, or whether unique copies should be
 used.
 @return YES to share among several objects, NO to make unique copies.
 */
- (BOOL)isStyleSharable;

/** @brief Set whether style is locked (editable)

 Locked styles are intended not to be editable, though this cannot be entirely enforced by the
 style itself - client code should honour the locked state. You cannot add or remove renderers from a
 locked style. Styles are normally not locked, but styles that are put in the registry are locked
 by that action. Changing the lock state doesn't inform clients, since in general this does not
 cause a visual change.
 @param lock YES to lock the style
 */
- (void)setLocked:(BOOL)lock;

/** @brief Returns whether the style is locked and cannot be edited
 @return YES if locked (non-editable)
 */
- (BOOL)locked;

// registry info:

/** @brief Returns whether the style is registered with the current style registry

 This method gives a definitive answer about
 whether the style is registered. Along with locking, this should prevent accidental editing of
 styles that an app might prefer to consider "read only".
 @return YES if known to the registry
 */
- (BOOL)isStyleRegistered;

/** @brief Returns the list of keys that the style is registered under (if any)

 The returned array may contain no keys if the style isn't registered, or >1 key if the style has
 been registered multiple times with different keys (not recommended). The key is not intended for
 display in a user interface and has no relationship to the style's name.
 @return a list of keys (NSStrings)
 */
- (NSArray*)registryKeys;

/** @brief Returns the unique key of the style

 The unique key is set once and for all time when the style is initialised, and is guaranteed unique
 as it is a UUID. 
 @return a string
 */
- (NSString*)uniqueKey;

/** @brief Sets the unique key of the style

 Called when the object is inited, this assigns a unique key. The key cannot be reassigned - its
 purpose is to identify this style regardless of any mutations it otherwise undergoes, including its
 ordinary name.
 */
- (void)assignUniqueKey;

/** @brief Query whether the style should be considered for a re-merge with the registry

 Re-merging is done when a document is opened. Any styles that were registered when it was saved will
 set this flag when the style is inited from the archive. The document gathers these styles together
 and remerges them according to the user's settings.
 @return <YES> if the style should be a candidate for re-merging
 */
- (BOOL)requiresRemerge;
- (void)clearRemergeFlag;
- (NSTimeInterval)lastModificationTimestamp;

/** @brief Is this style the same as <aStyle>?

 Styles are considered equal if they have the same unique ID and the same timestamp.
 @param aStyle a style to compare this with
 @return YES if the styles ar the same, NO otherwise
 */
- (BOOL)isEqualToStyle:(DKStyle*)aStyle;

// undo:

/** @brief Sets the undo manager that style changes will be recorded by

 The undo manager is not retained.
 @param undomanager the manager to use
 */
- (void)setUndoManager:(NSUndoManager*)undomanager;

/** @brief Returns the undo manager that style changes will be recorded by
 @return the style's current undo manager
 */
- (NSUndoManager*)undoManager;

/** @brief Vectors undo invocations back to the object from whence they came
 @param keypath the keypath of the action, relative to the object
 @param object the real target of the invocation
 */
- (void)changeKeyPath:(NSString*)keypath ofObject:(id)object toValue:(id)value;

// stroke utilities:

/** @brief Adjusts all contained stroke widths by the given scale value
 @param scale the scale factor, e.g. 2.0 will double all stroke widths
 @param quiet if YES, will ignore locked state and not inform clients. This is done when making hit
 */
- (void)scaleStrokeWidthsBy:(CGFloat)scale withoutInformingClients:(BOOL)quiet;

/** @brief Returns the widest stroke width in the style
 @return a number, the width of the widest contained stroke, or 0.0 if there are no strokes.
 */
- (CGFloat)maxStrokeWidth;

/** @brief Returns the difference between the widest and narrowest strokes
 @return a number, can be 0.0 if there are no strokes or only one stroke
 */
- (CGFloat)maxStrokeWidthDifference;

/** @brief Applies the cap, join, mitre limit, dash and line width attributes of the rear-most stroke to the path

 This can be used to set up a path for a Quartz operation such as outlining. The rearmost stroke
 attribute is used if there is more than one on the basis that this forms the largest element of
 the stroke. However, for the line width the max stroke is applied. If there are no strokes the
 path is not changed.
 @param path a bezier path to apply the attributes to
 */
- (void)applyStrokeAttributesToPath:(NSBezierPath*)path;

/** @brief Returns the number of strokes

 Counts all strokes, including those in subgroups.
 @return the number of stroke rasterizers
 */
- (NSUInteger)countOfStrokes;

// clipboard:

/** @brief Copies the style to the pasteboard

 Puts both the archived style and its key (as a separate type) on the pasteboard. When pasting a
 style, the key should be used in preference to allow a possible shared style to work as expected.
 @param pb the pasteboard to copy to
 */
- (BOOL)copyToPasteboard:(NSPasteboard*)pb;

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
- (DKStyle*)derivedStyleWithPasteboard:(NSPasteboard*)pb;

/** @brief Returns a style based on the receiver plus any data on the clipboard we are able to use

 See notes for derivedStyleWithPasteboard:
 The options are used to set up renderers in more appropriate ways when the type of object that the
 style will be attached to is known.
 @param pb the pasteboard to take additional data from
 @param options some hints that can influence the outcome of the operation
 @return a new style
 */
- (DKStyle*)derivedStyleWithPasteboard:(NSPasteboard*)pb withOptions:(DKDerivedStyleOptions)options;

// query methods:

/** @brief Queries whether the style has at least one stroke
 @return YES if there are one or more strokes, NO otherwise
 */
- (BOOL)hasStroke;

/** @brief Queries whether the style has at least one filling property

 This queries all rasterizers for the -isFill property
 @return YES if there are one or more fill properties, NO otherwise
 */
- (BOOL)hasFill;

/** @brief Queries whether the style has at least one hatch property

 Hatches are not always considered to be 'fills' in the normal sense, so hatches are counted separately
 @return YES if there are one or more hatches, NO otherwise
 */
- (BOOL)hasHatch;

/** @brief Queries whether the style has at least one text adornment property
 @return YES if there are one or more text adornments, NO otherwise
 */
- (BOOL)hasTextAdornment;

/** @brief Queries whether the style has any components at all
 @return YES if there are no components and no text attributes, NO if there is at least 1 or has text 
 */
- (BOOL)isEmpty;

// swatch images:

/** @brief Creates a thumbnail image of the style
 @param size the desired size of the thumbnail
 @param type the type of thumbnail - currently rect and path types are supported, or selected automatically
 @return an image of a default path rendered using this style
 */
- (NSImage*)styleSwatchWithSize:(NSSize)size type:(DKStyleSwatchType)type;

/** @brief Creates a thumbnail image of the style

 The swatch returned will have the curve path style if it has no fill, otherwise the rect style.
 @return an image of a path rendered using this style in the default size
 */
- (NSImage*)standardStyleSwatch;
- (NSImage*)image;
- (NSImage*)imageToFitSize:(NSSize)aSize;

/** @brief Return a key for the swatch cache for the given size and type of swatch

 The key is a simple concatenation of the size and the type, but don't rely on this anywhere - just
 ask for the swatch you want and if it's cached it will be returned.
 @return a string that is used as the key to the swatches in the cache
 */
- (NSString*)swatchCacheKeyForSize:(NSSize)size type:(DKStyleSwatchType)type;

// currently rendering client (may be queried by renderers)

/** @brief Returns the current object being rendered by this style

 This is only valid when called while rendering is in progress - mainly for the benefit of renderers
 that are part of this style
 @return the current rendering object
 */
- (id)currentRenderClient;

// making derivative styles:

/** @brief Returns a new style formed by copying the rasterizers from the receiver and the other style into one
 object

 The receiver's rasterizers are copied first, then otherStyles are appended, so they draw after
 (on top) of the receiver's.
 @param otherStyle a style object
 @return a new style object
 */
- (DKStyle*)styleByMergingFromStyle:(DKStyle*)otherStyle;

/** @brief Returns a new style formed by copying the rasterizers from the receiver but not those of <aClass>
 @param aClass the rasterizer class not to be copied
 @return a new style object
 */
- (DKStyle*)styleByRemovingRenderersOfClass:(Class)aClass;

/** @brief Returns a copy of the style having a new unique ID

 Similar to -mutabelCopy except name is copied and the object is returned autoreleased
 @return a new style object
 */
- (id)clone;

@end

// pasteboard types:

extern NSString* kDKStylePasteboardType;
extern NSString* kDKStyleKeyPasteboardType;

// notifications:

extern NSString* kDKStyleWillChangeNotification;
extern NSString* kDKStyleDidChangeNotification;
extern NSString* kDKStyleTextAttributesDidChangeNotification;
extern NSString* kDKStyleWasAttachedNotification;
extern NSString* kDKStyleWillBeDetachedNotification;
extern NSString* kDKStyleLockStateChangedNotification;
extern NSString* kDKStyleSharableFlagChangedNotification;
extern NSString* kDKStyleNameChangedNotification;

// preferences keys

extern NSString* kDKStyleDisplayPerformance_no_anti_aliasing;
extern NSString* kDKStyleDisplayPerformance_no_shadows;
extern NSString* kDKStyleDisplayPerformance_substitute_styles;
