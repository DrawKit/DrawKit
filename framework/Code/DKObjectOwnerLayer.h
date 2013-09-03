///**********************************************************************************************************************************
///  DKObjectOwnerLayer.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 21/11/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKLayer.h"
#import "DKObjectStorageProtocol.h"
#import "DKDrawableContainerProtocol.h"

@class DKDrawableObject, DKStyle;

// caching options

typedef enum
{
	kDKLayerCacheNone			= 0,				// no caching
	kDKLayerCacheUsingPDF		= ( 1 << 0 ),		// layer is cached in a PDF Image Rep
	kDKLayerCacheUsingCGLayer	= ( 1 << 1 ),		// layer is cached in a CGLayer bitmap
	kDKLayerCacheObjectOutlines = ( 1 << 2 )		// objects are drawn using a simple outline stroke only
}
DKLayerCacheOption;

// the class


@interface DKObjectOwnerLayer : DKLayer <NSCoding, DKDrawableContainer>
{
@private
	id<DKObjectStorage>		mStorage;				// the object storage
	NSPoint					m_pasteAnchor;			// used when recording the paste/duplication offset
	BOOL					m_allowEditing;			// YES to allow editing of objects, NO to prevent
	BOOL					m_allowSnapToObjects;	// YES to let snapping look for other objects
	DKDrawableObject*		mNewObjectPending;		// temporary object being created - is drawn and handled as a normal object but can be deleted without undo
	DKLayerCacheOption		mLayerCachingOption;	// see constants defined above
	NSRect					mCacheBounds;			// the bounds rect of the cached layer or PDF rep - used to accurately position the cache when drawn
	BOOL					m_inDragOp;				// YES if a drag is happening over the layer
	NSSize					m_pasteOffset;			// distance to offset a pasted object
	BOOL					m_recordPasteOffset;	// set to YES following a paste, and NO following a drag. When YES, paste offset is recorded.
	NSInteger				mPasteboardLastChange;	// last change count recorded during a paste
	NSInteger				mPasteCount;			// number of repeated paste operations since last new paste
@protected
	BOOL					mShowStorageDebugging;	// if YES, draws the debugging path for the storage on top (debugging feature only)
}

+ (void)				setDefaultLayerCacheOption:(DKLayerCacheOption) option;
+ (DKLayerCacheOption)	defaultLayerCacheOption;

// setting the storage (n.b. storage is set by default, this is an advanced feature that you can ignore 99% of the time):

+ (void)				setStorageClass:(Class) aClass;
+ (Class)				storageClass;

- (void)				setStorage:(id<DKObjectStorage>) storage;
- (id<DKObjectStorage>) storage;

// as a container for a DKDrawableObject:

- (DKObjectOwnerLayer*)	layer;

// the list of objects:

- (void)				setObjects:(NSArray*) objs;				// KVC/KVO compliant
- (NSArray*)			objects;								// KVC/KVO compliant
- (NSArray*)			availableObjects;
- (NSArray*)			availableObjectsInRect:(NSRect) aRect;
- (NSArray*)			availableObjectsOfClass:(Class) aClass;

- (NSArray*)			visibleObjects;
- (NSArray*)			visibleObjectsInRect:(NSRect) aRect;
- (NSArray*)			objectsWithStyle:(DKStyle*) style;
- (NSArray*)			objectsReturning:(NSInteger) answer toSelector:(SEL) selector;

// getting objects:

- (NSUInteger)			countOfObjects;							// KVC/KVO compliant
- (DKDrawableObject*)	objectInObjectsAtIndex:(NSUInteger) indx;	// KVC/KVO compliant
- (DKDrawableObject*)	topObject;
- (DKDrawableObject*)	bottomObject;
- (NSUInteger)			indexOfObject:(DKDrawableObject*) obj;

- (NSArray*)			objectsAtIndexes:(NSIndexSet*) set;		// KVC/KVO compliant
- (NSIndexSet*)			indexesOfObjectsInArray:(NSArray*) objs;

// adding and removing objects:
// note that the 'objects' property is fully KVC/KVO compliant because where necessary all methods call some directly KVC/KVO compliant method internally.
// those marked KVC/KVO compliant are *directly* compliant because they follow the standard KVC naming conventions. For observing a change via KVO, an
// observer must use one of the marked methods, but they can be sure they will observe the change even when other code makes use of a non-compliant method.

- (void)				insertObject:(DKDrawableObject*) obj inObjectsAtIndex:(NSUInteger) indx;				// KVC/KVO compliant
- (void)				removeObjectFromObjectsAtIndex:(NSUInteger) indx;										// KVC/KVO compliant
- (void)				replaceObjectInObjectsAtIndex:(NSUInteger) indx withObject:(DKDrawableObject*) obj;	// KVC/KVO compliant
- (void)				insertObjects:(NSArray*) objs atIndexes:(NSIndexSet*) set;							// KVC/KVO compliant
- (void)				removeObjectsAtIndexes:(NSIndexSet*) set;											// KVC/KVO compliant

// general purpose adding/removal (call through to KVC/KVO methods as necessary, but can't be observed directly)

- (void)				addObject:(DKDrawableObject*) obj;
- (void)				addObject:(DKDrawableObject*) obj atIndex:(NSUInteger) index;
- (void)				addObjectsFromArray:(NSArray*) objs;
- (BOOL)				addObjectsFromArray:(NSArray*) objs relativeToPoint:(NSPoint) origin pinToInterior:(BOOL) pin;
- (BOOL)				addObjectsFromArray:(NSArray*) objs bounds:(NSRect) bounds relativeToPoint:(NSPoint) origin pinToInterior:(BOOL) pin;

- (void)				removeObject:(DKDrawableObject*) obj;
- (void)				removeObjectAtIndex:(NSUInteger) indx;
- (void)				removeObjectsInArray:(NSArray*) objs;
- (void)				removeAllObjects;

// enumerating objects (typically for drawing)

- (NSEnumerator*)		objectEnumeratorForUpdateRect:(NSRect) rect inView:(NSView*) aView;
- (NSEnumerator*)		objectEnumeratorForUpdateRect:(NSRect) rect inView:(NSView*) aView options:(DKObjectStorageOptions) options;
- (NSArray*)			objectsForUpdateRect:(NSRect) rect inView:(NSView*) aView;
- (NSArray*)			objectsForUpdateRect:(NSRect) rect inView:(NSView*) aView options:(DKObjectStorageOptions) options;

// updating & drawing objects:

- (void)				drawable:(DKDrawableObject*) obj needsDisplayInRect:(NSRect) rect;
- (void)				drawVisibleObjects;
- (NSImage*)			imageOfObjects;
- (NSData*)				pdfDataOfObjects;

// pending object - used during interactive creation of new objects

- (void)				addObjectPendingCreation:(DKDrawableObject*) pend;
- (void)				removePendingObject;
- (void)				commitPendingObjectWithUndoActionName:(NSString*) actionName;
- (void)				drawPendingObjectInView:(NSView*) aView;
- (DKDrawableObject*)	pendingObject;

// geometry:

- (NSRect)				unionOfAllObjectBounds;
- (void)				refreshObjectsInContainer:(id) container;
- (void)				refreshAllObjects;
- (NSAffineTransform*)	renderingTransform;
- (void)				applyTransformToObjects:(NSAffineTransform*) transform;

// stacking order:

- (void)				moveUpObject:(DKDrawableObject*) obj;
- (void)				moveDownObject:(DKDrawableObject*) obj;
- (void)				moveObjectToTop:(DKDrawableObject*) obj;
- (void)				moveObjectToBottom:(DKDrawableObject*) obj;
- (void)				moveObject:(DKDrawableObject*) obj toIndex:(NSUInteger) indx;

// restacking multiple objects:

- (void)				moveObjectsAtIndexes:(NSIndexSet*) set toIndex:(NSUInteger) indx;
- (void)				moveObjectsInArray:(NSArray*) objs toIndex:(NSUInteger) indx;

// clipboard ops:

- (void)				addObjects:(NSArray*) objects fromPasteboard:(NSPasteboard*) pb atDropLocation:(NSPoint) p;
- (BOOL)				updatePasteCountWithPasteboard:(NSPasteboard*) pb;
- (BOOL)				isRecordingPasteOffset;
- (void)				setRecordingPasteOffset:(BOOL) record;
- (NSInteger)			pasteCount;
- (NSPoint)				pasteOrigin;
- (void)				setPasteOrigin:(NSPoint) po;
- (NSSize)				pasteOffset;
- (void)				setPasteOffset:(NSSize) offset;
- (void)				setPasteOffsetX:(CGFloat) x y:(CGFloat) y;
- (void)				objects:(NSArray*) objects wereDraggedFromPoint:(NSPoint) startPt toPoint:(NSPoint) endPt;

// hit testing:

- (DKDrawableObject*)	hitTest:(NSPoint) point;
- (DKDrawableObject*)	hitTest:(NSPoint) point partCode:(NSInteger*) part;
- (NSArray*)			objectsInRect:(NSRect) rect;
- (void)				drawable:(DKDrawableObject*) obj wasDoubleClickedAtPoint:(NSPoint) mp;

// snapping:

- (NSPoint)				snapPoint:(NSPoint) p toAnyObjectExcept:(DKDrawableObject*) except snapTolerance:(CGFloat) tol;
- (NSPoint)				snappedMousePoint:(NSPoint) mp forObject:(DKDrawableObject*) obj withControlFlag:(BOOL) snapControl;

// options:

- (void)				setAllowsEditing:(BOOL) editable;
- (BOOL)				allowsEditing;
- (void)				setAllowsSnapToObjects:(BOOL) snap;
- (BOOL)				allowsSnapToObjects;

- (void)				setLayerCacheOption:(DKLayerCacheOption) option;
- (DKLayerCacheOption)	layerCacheOption;

- (BOOL)				isHighlightedForDrag;
- (void)				setHighlightedForDrag:(BOOL) highlight;
- (void)				drawHighlightingForDrag;


// user actions:

- (IBAction)			toggleSnapToObjects:(id) sender;
- (IBAction)			toggleShowStorageDebuggingPath:(id) sender;

@end

// deprecated methods

#ifdef DRAWKIT_DEPRECATED

@interface DKObjectOwnerLayer (Deprecated)

- (NSEnumerator*)		objectTopToBottomEnumerator;
- (NSEnumerator*)		objectBottomToTopEnumerator;
- (NSArray*)			nativeObjectsFromPasteboard:(NSPasteboard*) pb;

@end

#endif


extern NSString*		kDKDrawableObjectPasteboardType;
extern NSString*		kDKDrawableObjectInfoPasteboardType;
extern NSString*		kDKLayerDidReorderObjects;

extern NSString*		kDKLayerWillAddObject;
extern NSString*		kDKLayerDidAddObject;
extern NSString*		kDKLayerWillRemoveObject;
extern NSString*		kDKLayerDidRemoveObject;


#define	DEFAULT_PASTE_OFFSET	20




/*

This layer class can be the owner of any number of DKDrawableObjects. It implements the ability to contain and render
these objects.

It does NOT support the concept of a selection, or of a list of selected objects (DKObjectDrawingLayer subclasses this to
provide that functionality).

This split between the owner/renderer layer and selection allows a more fine-grained opportunity to subclass for different
application needs.

Layer caching:

When a layer is NOT active, it may boost drawing performance to cache the layer's contents offscreen. This is especially beneficial
if you are using many layers. By setting the cache option, you can control how caching is done. If set to "none", objects
are never drawn using a cache, but simply drawn in the usual way. If "pdf", the cache is an NSPDFImageRep, which stores the image
as a PDF and so draws it at full vector quality at all zoom scales. If "CGLayer", an offscreen CGLayer is used which gives the
fastest rendering but will show pixellation at higher zooms. If both pdf and CGLayer are set, both caches will be created and
the CGLayer one used when DKDrawing has its "low quality" hint set, and the PDF rep otherwise.

The cache is only used for screen drawing.
 
NOTE: PDF caching has been shown to be actually slower when there are many objects, espcially with advanced storage in use. This is
because it's an all-or-nothing rendering proposition which direct drawing of a layer's objects is not.

*/
