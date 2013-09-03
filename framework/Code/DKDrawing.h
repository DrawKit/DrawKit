///**********************************************************************************************************************************
///  DKDrawing.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 14/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKLayerGroup.h"


@class DKGridLayer, DKGuideLayer, DKKnob, DKViewController, DKImageDataManager, DKUndoManager;


@interface DKDrawing : DKLayerGroup <NSCoding, NSCopying>
{
@private
	NSString*				m_units;				// user readable drawing units string, e.g. "millimetres"
	DKLayer*				m_activeLayerRef;		// which one is active for editing, etc
	NSColor*				m_paperColour;			// underlying colour of the "paper"
	DKUndoManager*			m_undoManager;			// undo manager to use for data changes
	NSColorSpace*			mColourSpace;			// the colour space of the drawing as a whole (nil means use default)
	NSSize					m_size;					// dimensions of the drawing
	CGFloat					m_leftMargin;			// margins
	CGFloat					m_rightMargin;
	CGFloat					m_topMargin;
	CGFloat					m_bottomMargin;
	CGFloat					m_unitConversionFactor;	// how many pixels does 1 unit cover?
	BOOL					mFlipped;				// YES if Y coordinates increase downwards, NO if they increase upwards
	BOOL					m_snapsToGrid;			// YES if grid snapping enabled
	BOOL					m_snapsToGuides;		// YES if guide snapping enabled
	BOOL					m_useQandDRendering;	// if YES, renderers have the option to use a fast but low quality drawing method
	BOOL					m_isForcedHQUpdate;		// YES while refreshing to HQ after a LQ series
	BOOL					m_qualityModEnabled;	// YES if the quality modulation is enabled
	BOOL					mPaperColourIsPrinted;	// YES if paper colour should be printed (default is NO)
	NSTimer*				m_renderQualityTimer;	// a timer used to set up high or low quality rendering dynamically
	NSTimeInterval			m_lastRenderTime;		// time the last render operation occurred
	NSTimeInterval			mTriggerPeriod;			// the time interval to use to trigger low quality rendering
	NSRect					m_lastRectUpdated;		// for refresh in HQ mode
	NSMutableSet*			mControllers;			// the set of current controllers
	DKImageDataManager*		mImageManager;			// internal object used to substantially improve efficiency of image archiving
	id						mDelegateRef;			// delegate, if any
	id						mOwnerRef;				// back pointer to document or view that owns this
}

+ (NSUInteger)				drawkitVersion;
+ (NSString*)				drawkitVersionString;
+ (NSString*)				drawkitReleaseStatus;

+ (DKDrawing*)				defaultDrawingWithSize:(NSSize) aSize;

+ (DKDrawing*)				drawingWithData:(NSData*) drawingData;

+ (id)						dearchivingHelper;
+ (void)					setDearchivingHelper:(id) helper;

+ (NSUInteger)				newDrawingNumber;
+ (NSMutableDictionary*)	defaultDrawingInfo;

+ (void)					setAbbreviation:(NSString*) abbrev forDrawingUnits:(NSString*) fullString;
+ (NSString*)				abbreviationForDrawingUnits:(NSString*) fullString;

// designated initializer:

- (id)						initWithSize:(NSSize) size;

// owner (document or view)

- (id)						owner;
- (void)					setOwner:(id) owner;

// basic drawing parameters:

- (void)					setDrawingSize:(NSSize) aSize;
- (NSSize)					drawingSize;
- (void)					setDrawingSizeWithPrintInfo:(NSPrintInfo*) printInfo;

- (void)					setMarginsLeft:(CGFloat) l top:(CGFloat) t right:(CGFloat) r bottom:(CGFloat) b;
- (void)					setMarginsWithPrintInfo:(NSPrintInfo*) printInfo;
- (CGFloat)					leftMargin;
- (CGFloat)					rightMargin;
- (CGFloat)					topMargin;
- (CGFloat)					bottomMargin;
- (NSRect)					interior;
- (NSPoint)					pinPointToInterior:(NSPoint) p;

- (void)					setFlipped:(BOOL) flipped;
- (BOOL)					isFlipped;

- (void)					setColourSpace:(NSColorSpace*) cSpace;
- (NSColorSpace*)			colourSpace;

// setting the rulers to the grid:

- (void)					setDrawingUnits:(NSString*) units unitToPointsConversionFactor:(CGFloat) conversionFactor;
- (NSString*)				drawingUnits;
- (NSString*)				abbreviatedDrawingUnits;
- (CGFloat)					unitToPointsConversionFactor;
- (CGFloat)					effectiveUnitToPointsConversionFactor;
- (void)					synchronizeRulersWithUnits:(NSString*) unitString;

// setting the delegate:

- (void)					setDelegate:(id) aDelegate;
- (id)						delegate;

// the drawing's view controllers

- (NSSet*)					controllers;
- (void)					addController:(DKViewController*) aController;
- (void)					removeController:(DKViewController*) aController;
- (void)					removeAllControllers;

// passing information to the views:

- (void)					invalidateCursors;
- (void)					scrollToRect:(NSRect) rect;
- (void)					exitTemporaryTextEditingMode;

- (void)					objectDidNotifyStatusChange:(id) object;

// dynamically adjusting the rendering quality:

- (void)					setDynamicQualityModulationEnabled:(BOOL) qmEnabled;
- (BOOL)					dynamicQualityModulationEnabled;

- (void)					setLowRenderingQuality:(BOOL) quickAndDirty;
- (BOOL)					lowRenderingQuality;
- (void)					checkIfLowQualityRequired;
- (void)					qualityTimerCallback:(NSTimer*) timer;
- (void)					setLowQualityTriggerInterval:(NSTimeInterval) t;
- (NSTimeInterval)			lowQualityTriggerInterval;

// setting the undo manager:

- (void)					setUndoManager:(id) um;
- (id)						undoManager;

// drawing meta-data:

- (void)					setDrawingInfo:(NSMutableDictionary*) info;
- (NSMutableDictionary*)	drawingInfo;

// rendering the drawing:

- (void)					setPaperColour:(NSColor*) colour;
- (NSColor*)				paperColour;
- (void)					setPaperColourIsPrinted:(BOOL) printIt;
- (BOOL)					paperColourIsPrinted;

// active layer

- (BOOL)					setActiveLayer:(DKLayer*) aLayer;
- (BOOL)					setActiveLayer:(DKLayer*) aLayer withUndo:(BOOL) undo;
- (DKLayer*)				activeLayer;
- (id)						activeLayerOfClass:(Class) aClass;

// high level methods that help support a UI

- (void)					addLayer:(DKLayer*) aLayer andActivateIt:(BOOL) activateIt;
- (void)					removeLayer:(DKLayer*) aLayer andActivateLayer:(DKLayer*) anotherLayer;
- (DKLayer*)				firstActivateableLayerOfClass:(Class) cl;

// interaction with grid and guides

- (void)					setSnapsToGrid:(BOOL) snaps;
- (BOOL)					snapsToGrid;
- (void)					setSnapsToGuides:(BOOL) snaps;
- (BOOL)					snapsToGuides;

- (NSPoint)					snapToGrid:(NSPoint) p withControlFlag:(BOOL) snapControl;
- (NSPoint)					snapToGrid:(NSPoint) p ignoringUserSetting:(BOOL) ignore;
- (NSPoint)					snapToGuides:(NSPoint) p;
- (NSRect)					snapRectToGuides:(NSRect) r includingCentres:(BOOL) cent;
- (NSSize)					snapPointsToGuide:(NSArray*) points;

- (NSPoint)					nudgeOffset;

- (DKGridLayer*)			gridLayer;
- (DKGuideLayer*)			guideLayer;
- (CGFloat)					convertLength:(CGFloat) len;
- (NSPoint)					convertPoint:(NSPoint) pt;
- (NSPoint)					convertPointFromDrawingToBase:(NSPoint) pt;
- (CGFloat)					convertLengthFromDrawingToBase:(CGFloat) len;

- (NSString*)				formattedConvertedLength:(CGFloat) len;
- (NSArray*)				formattedConvertedPoint:(NSPoint) pt;

// export:

- (void)					finalizePriorToSaving;
- (BOOL)					writeToFile:(NSString*) filename atomically:(BOOL) atom;
- (NSData*)					drawingAsXMLDataAtRoot;
- (NSData*)					drawingAsXMLDataForKey:(NSString*) key;
- (NSData*)					drawingData;
- (NSData*)					pdf;

// image manager

- (DKImageDataManager*)		imageManager;

@end

// notifications:

extern NSString*		kDKDrawingActiveLayerWillChange;
extern NSString*		kDKDrawingActiveLayerDidChange;
extern NSString*		kDKDrawingWillChangeSize;
extern NSString*		kDKDrawingDidChangeSize;
extern NSString*		kDKDrawingUnitsWillChange;
extern NSString*		kDKDrawingUnitsDidChange;
extern NSString*		kDKDrawingWillChangeMargins;
extern NSString*		kDKDrawingDidChangeMargins;
extern NSString*		kDKDrawingWillBeSavedOrExported;

// keys for standard drawing info items:

extern NSString*		kDKDrawingInfoUserInfoKey;				// the key for the drawing info dictionary within the user info

extern NSString*		kDKDrawingInfoDrawingNumber;			// data type NSString
extern NSString*		kDKDrawingInfoDrawingNumberUnformatted;	// data type NSNumber (integer)
extern NSString*		kDKDrawingInfoDrawingRevision;			// data type NSNumber (integer)
extern NSString*		kDKDrawingInfoDrawingPrefix;			// data type NSString
extern NSString*		kDKDrawingInfoDraughter;				// data type NSString
extern NSString*		kDKDrawingInfoCreationDate;				// data type NSDate
extern NSString*		kDKDrawingInfoLastModificationDate;		// data type NSDate
extern NSString*		kDKDrawingInfoModificationHistory;		// data type NSArray
extern NSString*		kDKDrawingInfoOriginalFilename;			// data type NSString
extern NSString*		kDKDrawingInfoTitle;					// data type NSString
extern NSString*		kDKDrawingInfoDrawingDimensions;		// data type NSSize
extern NSString*		kDKDrawingInfoDimensionsUnits;			// data type NSString
extern NSString*		kDKDrawingInfoDimensionsShortUnits;		// data type NSString

// keys for user defaults items

extern NSString*		kDKDrawingSnapToGridUserDefault;		// BOOL
extern NSString*		kDKDrawingSnapToGuidesUserDefault;		// BOOL
extern NSString*		kDKDrawingUnitAbbreviationsUserDefault;	// NSDictionary

// delegate methods

@interface NSObject (DKDrawingDelegate)

- (void)				drawing:(DKDrawing*) drawing willDrawRect:(NSRect) rect inView:(DKDrawingView*) aView;
- (void)				drawing:(DKDrawing*) drawing didDrawRect:(NSRect) rect inView:(DKDrawingView*) aView;
- (NSPoint)				drawing:(DKDrawing*) drawing convertLocationToExternalCoordinates:(NSPoint) drawingPt;
- (CGFloat)				drawing:(DKDrawing*) drawing convertDistanceToExternalCoordinates:(CGFloat) drawingDistance;
- (NSString*)			drawing:(DKDrawing*) drawing willReturnAbbreviationForUnit:(NSString*) unit;
- (NSString*)			drawing:(DKDrawing*) drawing willReturnFormattedCoordinateForDistance:(CGFloat) drawingDistance;
- (CGFloat)				drawingWillReturnUnitToPointsConversonFactor:(DKDrawing*) drawing;

@end


// additional methods

@interface DKDrawing (UISupport)

- (NSWindow*)			windowForSheet;

@end


// deprecated methods

@interface DKDrawing (Deprecated)

+ (DKDrawing*)			drawingWithContentsOfFile:(NSString*) filepath;
+ (DKDrawing*)			drawingWithData:(NSData*) drawingData fromFileAtPath:(NSString*) filepath;
+ (void)				saveDefaults;
+ (void)				loadDefaults;

@end



/*

A DKDrawing is the model data for the drawing system. Usually a document will own one of these. A drawing consists of one or more DKLayers,
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
