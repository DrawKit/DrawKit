/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKLayerGroup.h"

@class DKGridLayer, DKGuideLayer, DKKnob, DKViewController, DKImageDataManager, DKUndoManager;
@protocol DKDrawingDelegate;

/** @brief A DKDrawing is the model data for the drawing system.

Usually a document will own one of these. A drawing consists of one or more DKLayers,
each of which contains any number of drawable objects, or implements some special feature such as a grid or guides, etc.

A drawing can have multiple views, though typically it will have only one. Each view is managed by a single view controller, either an instance
or subclass of DKViewController. Drawing updates refersh all views via their controllers, and input from the views is directed to the current
active layer through the controller. The drawing owns the controllers, but the views are owned as normal by their respective superviews. The controller
provides only weak references to both drawing and view to prevent potential retain cycles when a view owns a drawing for the automatic backend scenario.
 
The drawing and the attached views must all have the same bounds size (though the views are free to have any desired frame). Setting the
drawing size will adjust the views' bounds automatically.

The active layer will receive mouse events from any of the attached views via its controller. (Because the user can't mouse in more than one view
at a time, there is no contention here.) The commands will go to whichever view is the current responder and be passed on appropriately.

Drawings can be saved simply by archiving them, thus all parts of the drawing need to adopt the NSCoding protocol.
*/
@interface DKDrawing : DKLayerGroup <NSCoding, NSCopying> {
@private
	NSString* m_units; /**< user readable drawing units string, e.g. "millimetres" */
	DKLayer* m_activeLayerRef; /**< which one is active for editing, etc */
	NSColor* m_paperColour; /**< underlying colour of the "paper" */
	DKUndoManager* m_undoManager; /**< undo manager to use for data changes */
	NSColorSpace* mColourSpace; /**< the colour space of the drawing as a whole (nil means use default) */
	NSSize m_size; /**< dimensions of the drawing */
	CGFloat m_leftMargin; /**< margins */
	CGFloat m_rightMargin;
	CGFloat m_topMargin;
	CGFloat m_bottomMargin;
	CGFloat m_unitConversionFactor; /**< how many pixels does 1 unit cover? */
	BOOL mFlipped; /**< YES if Y coordinates increase downwards, NO if they increase upwards */
	BOOL m_snapsToGrid; /**< YES if grid snapping enabled */
	BOOL m_snapsToGuides; /**< YES if guide snapping enabled */
	BOOL m_useQandDRendering; /**< if YES, renderers have the option to use a fast but low quality drawing method */
	BOOL m_isForcedHQUpdate; /**< YES while refreshing to HQ after a LQ series */
	BOOL m_qualityModEnabled; /**< YES if the quality modulation is enabled */
	BOOL mPaperColourIsPrinted; /**< YES if paper colour should be printed (default is NO) */
	NSTimer* m_renderQualityTimer; /**< a timer used to set up high or low quality rendering dynamically */
	NSTimeInterval m_lastRenderTime; /**< time the last render operation occurred */
	NSTimeInterval mTriggerPeriod; /**< the time interval to use to trigger low quality rendering */
	NSRect m_lastRectUpdated; /**< for refresh in HQ mode */
	NSMutableSet* mControllers; /**< the set of current controllers */
	DKImageDataManager* mImageManager; /**< internal object used to substantially improve efficiency of image archiving */
	id mDelegateRef; /**< delegate, if any */
	id mOwnerRef; /**< back pointer to document or view that owns this */
}

/** @brief Return the current version number of the framework
 @return a number formatted in 8-4-4 bit format representing the current version number
 */
+ (NSUInteger)drawkitVersion;

/** @brief Return the current version number and release status as a preformatted string

 This is intended for occasional display, rather than testing for the framework version.
 @return a string, e.g. "1.0.b6"
 */
+ (NSString*)drawkitVersionString;

/** @brief Return the current release status of the framework
 @return a string, either "alpha", "beta", "release candidate" or nil (final)
 */
+ (NSString*)drawkitReleaseStatus;

@property (class, readonly) NSUInteger drawkitVersion;
@property (class, readonly, copy) NSString *drawkitVersionString;
@property (class, readonly, copy) NSString *drawkitReleaseStatus;

/** @brief Constructs the default drawing system when the system isn't prebuilt "by hand"

 As a convenience for users of DrawKit, if you set up a DKDrawingView in IB, and do nothing else,
 you'll get a fully working, prebuilt drawing system behind that view. This can be very handy for all
 sorts of uses. However, it is more usual to build the system the other way around - start with a
 drawing object within a document (say) and attach views to it. This gives you the flexibility to
 do it either way. For automatic construction, this method is called to supply the drawing.
 @param aSize - the size of the drawing to create
 @return a fully constructed default drawing system
 */
+ (DKDrawing*)defaultDrawingWithSize:(NSSize)aSize;

/** @brief Creates a drawing from a lump of data
 @param drawingData data representing an archived drawing
 @return the unarchived drawing
 */
+ (DKDrawing*)drawingWithData:(NSData*)drawingData;

/** @brief Return the default derachiving helper for deaerchiving a drawing

 This helper is a delegate of the dearchiver during dearchiving and translates older or obsolete
 classes into modern ones, etc. The default helper deals with older DrawKit classes, but can be
 replaced to provide the same functionality for application-specific classes.
 @return the dearchiving helper
 */
+ (id)dearchivingHelper;

/** @brief Replace the default dearchiving helper for deaerchiving a drawing

 This helper is a delegate of the dearchiver during dearchiving and translates older or obsolete
 classes into modern ones, etc. The default helper deals with older DrawKit classes, but can be
 replaced to provide the same functionality for application-specific classes.
 @param helper a suitable helper object
 */
+ (void)setDearchivingHelper:(id)helper;

@property (class, retain) id dearchivingHelper;

/** @brief Returns a new drawing number by incrementing the current default seed value
 @return a new drawing number
 */
+ (NSUInteger)newDrawingNumber;

/** @brief Returns a dictionary containing some standard drawing info attributes

 This is usually called by the drawing object itself when built new. Usually you'll want to replace
 its contents with your own info. A DKDrawingInfoLayer can interpret some of the standard values and
 display them in its info box.
 @return a mutable dictionary of standard drawing info
 */
+ (NSMutableDictionary*)defaultDrawingInfo;

/** @brief Sets the abbreviation for the given drawing units string

 This allows special abbreviations to be set for units if desired. The setting writes to the user
 defaults so is persistent.
 @param abbrev the abbreviation for the unit
 @param fullString the full name of the drawing units
 */
+ (void)setAbbreviation:(NSString*)abbrev forDrawingUnits:(NSString*)fullString;

/** @brief Returns the abbreviation for the given drawing units string
 @param fullString the full name of the drawing units
 @return a string - the abbreviated form
 */
+ (NSString*)abbreviationForDrawingUnits:(NSString*)fullString;

/** @brief designated initializer */
- (id)initWithSize:(NSSize)size;

// owner (document or view)

/** @brief Returns the "owner" of this drawing.

 The owner is usually either a document, a window controller or a drawing view.
 @return the owner
 */
- (id)owner;

/** @brief Sets the "owner" of this drawing.

 The owner is usually either a document, a window controller or a drawing view. It is not required to
 be set at all, though some higher-level conveniences may depend on it.
 @param owner the owner for this object
 */
- (void)setOwner:(id)owner;

@property (assign) id owner;

/** @name basic drawing parameters
 *	@{ */

- (void)setDrawingSize:(NSSize)aSize;
- (NSSize)drawingSize;
- (void)setDrawingSizeWithPrintInfo:(NSPrintInfo*)printInfo;

@property (nonatomic) NSSize drawingSize;

- (void)setMarginsLeft:(CGFloat)l top:(CGFloat)t right:(CGFloat)r bottom:(CGFloat)b NS_SWIFT_NAME(setMargins(left:top:right:bottom:));
- (void)setMarginsWithPrintInfo:(NSPrintInfo*)printInfo;
- (CGFloat)leftMargin;
- (CGFloat)rightMargin;
- (CGFloat)topMargin;
- (CGFloat)bottomMargin;
- (NSRect)interior;
- (NSPoint)pinPointToInterior:(NSPoint)p;

@property (readonly) CGFloat leftMargin;
@property (readonly) CGFloat rightMargin;
@property (readonly) CGFloat topMargin;
@property (readonly) CGFloat bottomMargin;

- (void)setFlipped:(BOOL)flipped;
- (BOOL)isFlipped;

@property (getter=isFlipped) BOOL flipped;

/** @brief Sets the destination colour space for the whole drawing

 Colours set by styles and so forth are converted to this colourspace when rendering. A value of
 nil will use whatever is set in the colours used by the styles.
 @param cSpace the colour space 
 */
- (void)setColourSpace:(NSColorSpace*)cSpace;

/** @brief Returns the colour space for the whole drawing

 Colours set by styles and so forth are converted to this colourspace when rendering. A value of
 nil will use whatever is set in the colours used by the styles.
 @return the colour space
 */
- (NSColorSpace*)colourSpace;

@property (retain) NSColorSpace *colourSpace;

/**
 @}
 @name setting the rulers to the grid
 @{ */

- (void)setDrawingUnits:(NSString*)units unitToPointsConversionFactor:(CGFloat)conversionFactor;
- (NSString*)drawingUnits;
- (NSString*)abbreviatedDrawingUnits;
- (CGFloat)unitToPointsConversionFactor;
- (CGFloat)effectiveUnitToPointsConversionFactor;
- (void)synchronizeRulersWithUnits:(NSString*)unitString;

/** @} */
/** @name setting the delegate */

- (void)setDelegate:(id<DKDrawingDelegate>)aDelegate;
- (id<DKDrawingDelegate>)delegate;
@property (nonatomic, assign) id<DKDrawingDelegate> delegate;

/** @name the drawing's view controllers
 @{ */

- (NSSet<DKViewController*>*)controllers;
- (void)addController:(DKViewController*)aController;
- (void)removeController:(DKViewController*)aController;

@property (readonly, copy) NSSet<DKViewController*> *controllers;

/** @brief Removes all controller from the drawing

 Typically controllers are removed when necessary - there is little reason to call this yourself
 */
- (void)removeAllControllers;

/** @}
 @name passing information to the views
 @{ */

- (void)invalidateCursors;
- (void)scrollToRect:(NSRect)rect;
- (void)exitTemporaryTextEditingMode;

- (void)objectDidNotifyStatusChange:(id)object;

/** @} */
/** @name dynamically adjusting the rendering quality:
 @{ */

/** @brief Set whether drawing quality modulation is enabled or not

 Rasterizers are able to use a low quality drawing mode for rapid updates when DKDrawing detects
 the need for it. This flag allows that behaviour to be turned on or off.
 */
- (void)setDynamicQualityModulationEnabled:(BOOL)qmEnabled;
- (BOOL)dynamicQualityModulationEnabled;

@property BOOL dynamicQualityModulationEnabled;

/** @brief Advise whether drawing should be done in best quality or not
 
 Rasterizers in DK can query this flag to check if they can use a fast quick rendering method.
 this is set while zooming, scrolling or other operations that require many rapid updates. Speed
 under these conditions can be improved by using bitmap caches, etc rather than drawing at best
 quality.
 @param quickAndDirty YES to offer low quality faster rendering
 */
- (void)setLowRenderingQuality:(BOOL)quickAndDirty;

/** @brief Advise whether drawing should be done in best quality or not
 
 Renderers in drawkit can query this flag to check if they can use a fast quick rendering method.
 this is set while zooming, scrolling or other operations that require many rapid updates. Speed
 under these conditions can be inmproved by using bitmap caches, etc rather than drawing at best
 quality.
 @return YES if low quality is an option
 */
- (BOOL)lowRenderingQuality;

@property BOOL lowRenderingQuality;
- (void)checkIfLowQualityRequired;
- (void)qualityTimerCallback:(NSTimer*)timer;
@property NSTimeInterval lowQualityTriggerInterval;

/** @} */
/** @name setting the undo manager:
 @{ */

/** @brief Sets the undoManager that will be used for all undo actions that occur in this drawing.
 
 The undoManager is retained. It is passed down to all levels that need undoable actions. The
 default is nil, so nothing will be undoable unless you set it. In a document-based app, the
 document's undoManager should be used. Otherwise, the view's or window's undoManager can be used.
 @param um the undo manager to use
 */
- (void)setUndoManager:(id)um;

/** @brief Returns the undo manager for the drawing
 @return the currently used undo manager
 */
- (id)undoManager;

@property (nonatomic, retain) id undoManager;

/** @} */
/** @name drawing meta-data:
 @{ */

- (void)setDrawingInfo:(NSMutableDictionary*)info;
- (NSMutableDictionary*)drawingInfo;

/** @name rendering the drawing:
 @{ */

/** @brief Sets the background colour of the entire drawing
 
 Default is white
 @param colour the colour to set for the drawing's background (paper) colour
 */
- (void)setPaperColour:(NSColor*)colour;

/** @brief The curremt paper colour of the drawing
 
 Default is white
 @return the current colour of the background (paper)
 */
- (NSColor*)paperColour;

@property (nonatomic, retain) NSColor *paperColour;

/** @brief Set whether the paper colour is printed or not
 
 Default is NO
 @param printIt YES to include the paper colour when printing
 */
- (void)setPaperColourIsPrinted:(BOOL)printIt;
/** @brief Whether the paper colour is printed or not
 
 Default is NO
 @return YES if the paper colour is included when printing
 */
- (BOOL)paperColourIsPrinted;
@property BOOL paperColourIsPrinted;

/** @} */
/** @name active layer
 @{ */
- (BOOL)setActiveLayer:(DKLayer*)aLayer;
- (BOOL)setActiveLayer:(DKLayer*)aLayer withUndo:(BOOL)undo;
/** @brief Returns the current active layer
 @return a DKLayer object, or subclass, which is the current active layer
 */
- (DKLayer*)activeLayer;
- (__kindof DKLayer*)activeLayerOfClass:(Class)aClass NS_REFINED_FOR_SWIFT;

@property (nonatomic, assign, readonly) DKLayer *activeLayer;

/** @} */
/** @name high level methods that help support a UI
 @{ */

- (void)addLayer:(DKLayer*)aLayer andActivateIt:(BOOL)activateIt;
- (void)removeLayer:(DKLayer*)aLayer andActivateLayer:(DKLayer*)anotherLayer;
- (__kindof DKLayer*)firstActivateableLayerOfClass:(Class)cl NS_REFINED_FOR_SWIFT;

/** @} */
/** @name interaction with grid and guides
 @{ */

- (void)setSnapsToGrid:(BOOL)snaps;
- (BOOL)snapsToGrid;
- (void)setSnapsToGuides:(BOOL)snaps;
- (BOOL)snapsToGuides;

@property BOOL snapsToGrid;
@property BOOL snapsToGuides;

- (NSPoint)snapToGrid:(NSPoint)p withControlFlag:(BOOL)snapControl;
- (NSPoint)snapToGrid:(NSPoint)p ignoringUserSetting:(BOOL)ignore;
- (NSPoint)snapToGuides:(NSPoint)p;
- (NSRect)snapRectToGuides:(NSRect)r includingCentres:(BOOL)cent;
- (NSSize)snapPointsToGuide:(NSArray*)points;

- (NSPoint)nudgeOffset;

- (DKGridLayer*)gridLayer;
- (DKGuideLayer*)guideLayer;
- (CGFloat)convertLength:(CGFloat)len;
- (NSPoint)convertPoint:(NSPoint)pt;
- (NSPoint)convertPointFromDrawingToBase:(NSPoint)pt;
- (CGFloat)convertLengthFromDrawingToBase:(CGFloat)len;

/** @brief Convert a distance in quartz coordinates to the units established by the drawing grid

 This wraps up length conversion and formatting for display into one method, which also calls the
 delegate if it implements the relevant method.
 @param len a distance in base points (pixels)
 @return a string containing a fully formatted distance plus the units abbreviation
 */
- (NSString*)formattedConvertedLength:(CGFloat)len;

/** @brief Convert a point in quartz coordinates to the units established by the drawing grid

 This wraps up length conversion and formatting for display into one method, which also calls the
 delegate if it implements the relevant method. The result is an array with two strings - the first
 is the x coordinate, the second is the y co-ordinate
 @param pt a point in base points (pixels)
 @return a pair of strings containing a fully formatted distance plus the units abbreviation
 */
- (NSArray<NSString*>*)formattedConvertedPoint:(NSPoint)pt;

/** @} */
/** @name export
 @{ */

- (void)finalizePriorToSaving;
- (BOOL)writeToFile:(NSString*)filename atomically:(BOOL)atom;
- (NSData*)drawingAsXMLDataAtRoot;
- (NSData*)drawingAsXMLDataForKey:(NSString*)key;
- (NSData*)drawingData;
- (NSData*)pdf;

/** @} */
/** @name image manager
 @{ */

/** @brief Returns the image manager

 The image manager is an object that is used to improve archiving efficiency of images. Classes
 that have images, such as DKImageShape, use this to cache image data.
 @return the drawing's image manager
 */
- (DKImageDataManager*)imageManager;

/** @} */
@end

/** @name notifications
 @memberof DKDrawing
 @{ */

extern NSNotificationName kDKDrawingActiveLayerWillChange;
extern NSNotificationName kDKDrawingActiveLayerDidChange;
extern NSNotificationName kDKDrawingWillChangeSize;
extern NSNotificationName kDKDrawingDidChangeSize;
extern NSNotificationName kDKDrawingUnitsWillChange;
extern NSNotificationName kDKDrawingUnitsDidChange;
extern NSNotificationName kDKDrawingWillChangeMargins;
extern NSNotificationName kDKDrawingDidChangeMargins;
extern NSNotificationName kDKDrawingWillBeSavedOrExported;

/** @}
 @name keys for standard drawing info items:
 @memberof DKDrawing
 @{ */

extern NSString* kDKDrawingInfoUserInfoKey; /**< the key for the drawing info dictionary within the user info */

extern NSString* kDKDrawingInfoDrawingNumber; /**< data type NSString */
extern NSString* kDKDrawingInfoDrawingNumberUnformatted; /**< data type NSNumber (integer) */
extern NSString* kDKDrawingInfoDrawingRevision; /**< data type NSNumber (integer) */
extern NSString* kDKDrawingInfoDrawingPrefix; /**< data type NSString */
extern NSString* kDKDrawingInfoDraughter; /**< data type NSString */
extern NSString* kDKDrawingInfoCreationDate; /**< data type NSDate */
extern NSString* kDKDrawingInfoLastModificationDate; /**< data type NSDate */
extern NSString* kDKDrawingInfoModificationHistory; /**< data type NSArray */
extern NSString* kDKDrawingInfoOriginalFilename; /**< data type NSString */
extern NSString* kDKDrawingInfoTitle; /**< data type NSString */
extern NSString* kDKDrawingInfoDrawingDimensions; /**< data type NSSize */
extern NSString* kDKDrawingInfoDimensionsUnits; /**< data type NSString */
extern NSString* kDKDrawingInfoDimensionsShortUnits; /**< data type NSString */

/** @}
 @brief keys for user defaults items
 @{ */
extern NSString* kDKDrawingSnapToGridUserDefault; /**< BOOL */
extern NSString* kDKDrawingSnapToGuidesUserDefault; /**< BOOL */
extern NSString* kDKDrawingUnitAbbreviationsUserDefault; /**< NSDictionary */

/** @} */

/** @brief Delegate methods */
@protocol DKDrawingDelegate <NSObject>
@optional

- (void)drawing:(DKDrawing*)drawing willDrawRect:(NSRect)rect inView:(DKDrawingView*)aView;
- (void)drawing:(DKDrawing*)drawing didDrawRect:(NSRect)rect inView:(DKDrawingView*)aView;
- (NSPoint)drawing:(DKDrawing*)drawing convertLocationToExternalCoordinates:(NSPoint)drawingPt;
- (CGFloat)drawing:(DKDrawing*)drawing convertDistanceToExternalCoordinates:(CGFloat)drawingDistance;
- (NSString*)drawing:(DKDrawing*)drawing willReturnAbbreviationForUnit:(NSString*)unit;
- (NSString*)drawing:(DKDrawing*)drawing willReturnFormattedCoordinateForDistance:(CGFloat)drawingDistance;
- (CGFloat)drawingWillReturnUnitToPointsConversonFactor:(DKDrawing*)drawing;

@end

/** @brief additional methods
*/
@interface DKDrawing (UISupport)

- (NSWindow*)windowForSheet;

@end

/** @brief deprecated methods */
@interface DKDrawing (Deprecated)

+ (DKDrawing*)drawingWithContentsOfFile:(NSString*)filepath;
+ (DKDrawing*)drawingWithData:(NSData*)drawingData fromFileAtPath:(NSString*)filepath;

/** @brief Saves the static class defaults for ALL classes in the drawing system

 Deprecated - no longer does anything
 */
+ (void)saveDefaults;

/** @brief Loads the static user defaults for all classes in the drawing system

 Deprecated - no longer does anything
 */
+ (void)loadDefaults;

@end
