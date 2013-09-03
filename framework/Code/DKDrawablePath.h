//
//  DKDrawablePath.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 10/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKDrawableObject.h"


@class DKDrawableShape;
@class DKKnob;


// editing modes:

typedef enum
{
	kDKPathCreateModeEditExisting		= 0,		// normal operation - just move points on the existing path
	kDKPathCreateModeLineCreate			= 1,		// create a straight line between two points
	kDKPathCreateModeBezierCreate		= 2,		// create a curved path point by point
	kDKPathCreateModePolygonCreate		= 3,		// create an irreglar polygon pont by point (multiple lines)
	kDKPathCreateModeFreehandCreate		= 4,		// create a curve path by dragging freehand
	kDKPathCreateModeArcSegment			= 5,		// create an arc section
	kDKPathCreateModeWedgeSegment		= 6			// create a wedge section
}
DKDrawablePathCreationMode;

typedef enum
{
	kDKPathNoJoin						= 0,
	kDKPathOtherPathWasAppended			= 1,
	kDKPathOtherPathWasPrepended		= 2,
	kDKPathBothEndsJoined				= 3
}
DKDrawablePathJoinResult;

// path point types that can be passed to pathInsertPointAt:ofType:

typedef enum
{
	kDKPathPointTypeAuto				= 0,		// insert whatever the hit element is already using
	kDKPathPointTypeLine				= 1,		// insert a line segment
	kDKPathPointTypeCurve				= 2,		// insert a curve segment
	kDKPathPointTypeInverseAuto			= 3,		// insert the opposite of whatever hit element is already using
}
DKDrawablePathInsertType;


// the class:


@interface DKDrawablePath : DKDrawableObject <NSCoding, NSCopying>
{
@private
	NSBezierPath*			m_path;
	NSBezierPath*			m_undoPath;
	NSInteger				m_editPathMode;
	CGFloat					m_freehandEpsilon;
	BOOL					m_extending;
}

// convenience constructors:

+ (DKDrawablePath*)		drawablePathWithBezierPath:(NSBezierPath*) path;
+ (DKDrawablePath*)		drawablePathWithBezierPath:(NSBezierPath*) path withStyle:(DKStyle*) aStyle;

// colour for feedback window:

+ (void)				setInfoWindowBackgroundColour:(NSColor*) colour;
+ (NSColor*)			infoWindowBackgroundColour;

+ (void)				setDefaultOnPathHitDetectionPriority:(BOOL) priority;
+ (BOOL)				defaultOnPathHitDetectionPriority;

- (id)					initWithBezierPath:(NSBezierPath*) aPath;
- (id)					initWithBezierPath:(NSBezierPath*) aPath style:(DKStyle*) aStyle;

// setting the path & path info

- (void)				setPath:(NSBezierPath*) path;
- (NSBezierPath*)		path;
- (void)				drawControlPointsOfPath:(NSBezierPath*) path usingKnobs:(DKKnob*) knobs;
- (CGFloat)				length;
- (CGFloat)				lengthForPoint:(NSPoint) mp;
- (CGFloat)				lengthForPoint:(NSPoint) mp tolerance:(CGFloat) tol;
- (BOOL)				isPathClosed;

- (void)				recordPathForUndo;
- (NSBezierPath*)		undoPath;
- (void)				clearUndoPath;

// modifying paths

- (void)				combine:(DKDrawablePath*) anotherPath;
- (NSArray*)			breakApart;
- (BOOL)				pathDeletePointWithPartCode:(NSInteger) pc;
- (BOOL)				pathDeleteElementAtIndex:(NSInteger) indx;
- (BOOL)				pathDeleteElementAtPoint:(NSPoint) loc;

- (NSInteger)			pathInsertPointAt:(NSPoint) loc ofType:(DKDrawablePathInsertType) pathPointType;
- (void)				movePathPartcode:(NSInteger) pc toPoint:(NSPoint) mp event:(NSEvent*) evt;

- (DKDrawablePathJoinResult)	wouldJoin:(DKDrawablePath*) anotherPath tolerance:(CGFloat) tol;
- (DKDrawablePathJoinResult)	join:(DKDrawablePath*) anotherPath tolerance:(CGFloat) tol makeColinear:(BOOL) colin;

- (DKDrawablePath*)		dividePathAtLength:(CGFloat) distance;

// creating paths

- (void)				setPathCreationMode:(DKDrawablePathCreationMode) editPathMode;
- (DKDrawablePathCreationMode)	pathCreationMode;
- (BOOL)				shouldEndPathCreationWithEvent:(NSEvent*) event;

- (BOOL)				isOpenEndPoint:(NSInteger) partcode;
- (void)				setShouldExtendExistingPath:(BOOL) xtend;

- (void)				pathCreateLoop:(NSPoint) initialPoint;
- (void)				lineCreateLoop:(NSPoint) initialPoint;
- (void)				polyCreateLoop:(NSPoint) initialPoint;
- (void)				freehandCreateLoop:(NSPoint) initialPoint;
- (void)				arcCreateLoop:(NSPoint) initialPoint;

- (void)				pathCreationLoopDidEnd;
- (NSEvent*)			postMouseUpAtPoint:(NSPoint) p;

- (void)				setFreehandSmoothing:(CGFloat) fs;
- (CGFloat)				freehandSmoothing;

// converting to other types

- (DKDrawableShape*)	makeShape;
- (BOOL)				canConvertToTrack;
- (DKDrawablePath*)		makeParallelWithOffset:(CGFloat) distance smooth:(BOOL) smooth;

// user level commands this object can respond to:

- (IBAction)			convertToShape:(id) sender;
- (IBAction)			addRandomNoise:(id) sender;
- (IBAction)			convertToOutline:(id) sender;
- (IBAction)			breakApart:(id) sender;
- (IBAction)			roughenPath:(id) sender;
- (IBAction)			smoothPath:(id) sender;
- (IBAction)			smoothPathMore:(id) sender;
- (IBAction)			parallelCopy:(id) sender;
- (IBAction)			curveFit:(id) sender;
- (IBAction)			reversePath:(id) sender;
- (IBAction)			toggleHorizontalFlip:(id) sender;
- (IBAction)			toggleVerticalFlip:(id) sender;
- (IBAction)			closePath:(id) sender;

@end

// special partcode value used to mean snap to the nearest point on the path itself:

enum
{
	kDKSnapToNearestPathPointPartcode	= -99
};

extern NSPoint gMouseForPathSnap;

extern NSString*		kDKPathOnPathHitDetectionPriorityDefaultsKey;

/*

DKDrawablePath is a drawable object that renders a path such as a line or curve (bezigon).

The path is rendered at its stored size, not transformed to its final size like DKDrawableShape. Thus this type of object doesn't
maintain the concept of rotation or scale - it just is what it is.

*/
