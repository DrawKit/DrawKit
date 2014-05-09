/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawableObject.h"

@class DKDrawableShape;
@class DKKnob;

// editing modes:

typedef enum {
    kDKPathCreateModeEditExisting = 0, // normal operation - just move points on the existing path
    kDKPathCreateModeLineCreate = 1, // create a straight line between two points
    kDKPathCreateModeBezierCreate = 2, // create a curved path point by point
    kDKPathCreateModePolygonCreate = 3, // create an irreglar polygon pont by point (multiple lines)
    kDKPathCreateModeFreehandCreate = 4, // create a curve path by dragging freehand
    kDKPathCreateModeArcSegment = 5, // create an arc section
    kDKPathCreateModeWedgeSegment = 6 // create a wedge section
} DKDrawablePathCreationMode;

typedef enum {
    kDKPathNoJoin = 0,
    kDKPathOtherPathWasAppended = 1,
    kDKPathOtherPathWasPrepended = 2,
    kDKPathBothEndsJoined = 3
} DKDrawablePathJoinResult;

// path point types that can be passed to pathInsertPointAt:ofType:

typedef enum {
    kDKPathPointTypeAuto = 0, // insert whatever the hit element is already using
    kDKPathPointTypeLine = 1, // insert a line segment
    kDKPathPointTypeCurve = 2, // insert a curve segment
    kDKPathPointTypeInverseAuto = 3, // insert the opposite of whatever hit element is already using
} DKDrawablePathInsertType;

// the class:

/** @brief DKDrawablePath is a drawable object that renders a path such as a line or curve (bezigon).

DKDrawablePath is a drawable object that renders a path such as a line or curve (bezigon).

The path is rendered at its stored size, not transformed to its final size like DKDrawableShape. Thus this type of object doesn't
maintain the concept of rotation or scale - it just is what it is.
*/
@interface DKDrawablePath : DKDrawableObject <NSCoding, NSCopying> {
@private
    NSBezierPath* m_path;
    NSBezierPath* m_undoPath;
    NSInteger m_editPathMode;
    CGFloat m_freehandEpsilon;
    BOOL m_extending;
}

// convenience constructors:

/** @brief Creates a drawable path object for an existing NSBezierPath

 Convenience method allows you to turn any path into a drawable that can be added to a drawing
 @param path the path to use
 @return a new drawable path object which has the path supplied
 */
+ (DKDrawablePath*)drawablePathWithBezierPath:(NSBezierPath*)path;

/** @brief Creates a drawable path object for an existing NSBezierPath and style

 Convenience method allows you to turn any path into a drawable that can be added to a drawing
 @param path the path to use
 @param aStyle a style to apply to the path
 @return a new drawable path object which has the path supplied
 */
+ (DKDrawablePath*)drawablePathWithBezierPath:(NSBezierPath*)path withStyle:(DKStyle*)aStyle;

// colour for feedback window:

/** @brief Set the background colour to use for the info window displayed when interacting with paths
 @param colour the colour to use
 */
+ (void)setInfoWindowBackgroundColour:(NSColor*)colour;

/** @brief Return the background colour to use for the info window displayed when interacting with paths
 @return the colour to use
 */
+ (NSColor*)infoWindowBackgroundColour;

/** @brief Set whether the default hit-detection behaviour is to prioritise on-path points or off-path points

 Affects hit-detection when on-path and off-path points are coincident. Normally off-path points
 have priority, but an alternative approach is to have on-path points have priority, and the off-path
 points require the use of the command modifier key to be hit-detected. DK has previously always
 prioritised off-path points, but this setting allows you to change that for your app.
 @param priority if YES, on-path points have priority by default. 
 */
+ (void)setDefaultOnPathHitDetectionPriority:(BOOL)priority;

/** @brief Returns whether the default hit-detection behaviour is to prioritise on-path points or off-path points

 Affects hit-detection when on-path and off-path points are coincident. Normally off-path points
 have priority, but an alternative approach is to have on-path points have priority, and the off-path
 points require the use of the command modifier key to be hit-detected. DK has previously always
 prioritised off-path points, but this setting allows you to change that for your app.
 @return if YES, on-path points have priority by default
 */
+ (BOOL)defaultOnPathHitDetectionPriority;

- (id)initWithBezierPath:(NSBezierPath*)aPath;

/** @brief Initialises a drawable path object from an existing path with the given style

 The path is retained, not copied
 @param aPath the path to use
 @param aStyle the style to use
 @return the drawable path object
 */
- (id)initWithBezierPath:(NSBezierPath*)aPath style:(DKStyle*)aStyle;

/** @brief Set the angle of constraint for new paths
 
 @param radians the angle to constrain by; multiples of angle are used
 */
+ (void)setAngularConstraintAngle:(CGFloat)radians;

/** @brief Angle of constraint for new paths
 */
+ (CGFloat)angularConstraintAngle;

/** @brief Should the angle of the path be constrained?
 
 Returns yes if the shift key is currently held down, otherwise no.
 */
- (BOOL)constrainWithEvent:(NSEvent*)anEvent;

// setting the path & path info

- (void)setPath:(NSBezierPath*)path;
- (NSBezierPath*)path;
- (void)drawControlPointsOfPath:(NSBezierPath*)path usingKnobs:(DKKnob*)knobs;

/** @brief Return the length of the path

 Length is accurately computed by summing the segment distances.
 @return the path's length
 */
- (CGFloat)length;
- (CGFloat)lengthForPoint:(NSPoint)mp;
- (CGFloat)lengthForPoint:(NSPoint)mp tolerance:(CGFloat)tol;

/** @brief Discover whether the path is open or closed

 A path is closed if it has a closePath element or its first and last points are coincident.
 @return YES if the path is closed, NO if open
 */
- (BOOL)isPathClosed;

- (void)recordPathForUndo;
- (NSBezierPath*)undoPath;
- (void)clearUndoPath;

// modifying paths

/** @brief Merges two paths by simply appending them

 This simply appends the part of the other object to this one and recomputes the bounds, etc.
 the result can act like a union, difference or XOR according to the relative placements of the
 paths and the winding rules in use.
 @param anotherPath another drawable path object like this one
 */
- (void)combine:(DKDrawablePath*)anotherPath;

/** @brief Converts each subpath in the current path to a separate object

 A subpath is a path delineated by a moveTo opcode. Each one is made a separate new path. If there
 is only one subpath (common) then the result will have just one entry.
 @return an array of DKDrawablePath objects
 */
- (NSArray*)breakApart;

/** @brief Delete the point from the path with the given part code

 Only on-path points of a curve are allowed to be deleted, not control points. The partcodes will
 be renumbered by this, so do not cache the partcode beyond this point.
 @param pc the partcode to delete
 @return YES if the point could be deleted, NO if not */
- (BOOL)pathDeletePointWithPartCode:(NSInteger)pc;

/** @brief Delete a segment from the path at the given index

 If the element id removed from the middle, the path is split into two subpaths. If removed at
 either end, the path is shortened. Partcodes will change.
 @param indx the index of the element to delete
 @return YES if the element was deleted, NO if not
 */
- (BOOL)pathDeleteElementAtIndex:(NSInteger)indx;

/** @brief Delete a segment from the path at the given point

 Finds the element hit by the point and calls -pathDeleteElementAtIndex:
 @param loc a point
 @return YES if the element was deleted, NO if not
 */
- (BOOL)pathDeleteElementAtPoint:(NSPoint)loc;

- (NSInteger)pathInsertPointAt:(NSPoint)loc ofType:(DKDrawablePathInsertType)pathPointType;

/** @brief Move a single control point to a new position

 Essential interactive editing method
 @param pc the partcode for the point to be moved
 @param mp the point to move it to
 @param evt the event (used to grab modifier flags) */
- (void)movePathPartcode:(NSInteger)pc toPoint:(NSPoint)mp event:(NSEvent*)evt;

/** @brief Preflights a potential join to determine if the join would be made

 Allows a join operation to be preflighted without actually performing the join.
 @param anotherPath another drawable path object like this one
 @param tol a value used to determine if the end points are placed sufficiently close to be joinable
 @return a join result value, indicating which end(s) would be joined, if any
 */
- (DKDrawablePathJoinResult)wouldJoin:(DKDrawablePath*)anotherPath tolerance:(CGFloat)tol;
- (DKDrawablePathJoinResult)join:(DKDrawablePath*)anotherPath tolerance:(CGFloat)tol makeColinear:(BOOL)colin;

/** @brief Splits a path into two paths at a specific point

 The new path has the same style and user info as the original, but is not added to the layer
 by this method. If <distance> is <= 0 or >= length, nil is returned.
 @param distance the position from the start of the path to make the split
 @return a new path, being the section of the original path from <distance> to the end.
 */
- (DKDrawablePath*)dividePathAtLength:(CGFloat)distance;

// creating paths

/** @brief Sets the "mode" of operation for creating new path objects

 Paths are created by tools usually so this will be rarely needed. Pass 0 for the defalt mode which
 is to edit an existing path (once created all paths are logically the same)
 @param editPathMode a constant indicating how a new path should be constructed.
 */
- (void)setPathCreationMode:(DKDrawablePathCreationMode)editPathMode;

/** @brief Gets the "mode" of operation for creating new path objects
 */
- (DKDrawablePathCreationMode)pathCreationMode;

/** @brief Test for the ending criterion of a path loop

 Currently only checks for a double-click
 @param event an event
 @return YES to end the loop, NO to continue
 */
- (BOOL)shouldEndPathCreationWithEvent:(NSEvent*)event;

/** @brief Discover whether the given partcode is an open end point of the path

 A closed path always returns NO, as it has no open end points. An open path will return YES for
 only the first and last points.
 @param partcode a partcode to test
 @return YES if the partcode is one of the endpoints, NO otherwise
 */
- (BOOL)isOpenEndPoint:(NSInteger)partcode;

/** @brief Set whether the object should extend its path or start from scratch

 When YES, this affects the starting partcode for the creation process. Normally paths are started
 from scratch, but if YES, this extends the existing path from its end if the path is open. The
 tool that coordinates the creation of new objects is reposnsible for managing this appropriately.
 @param xtend YES to extend the path, NO for normal creation
 */
- (void)setShouldExtendExistingPath:(BOOL)xtend;

/** @brief Event loop for creating a curved path point by point

 Keeps control until the ending criteria are met (double-click or click on first point).
 @param initialPoint where to start
 */
- (void)pathCreateLoop:(NSPoint)initialPoint;

/** @brief Event loop for creating a single straight line

 Keeps control until the ending criteria are met (second click).
 @param initialPoint where to start
 */
- (void)lineCreateLoop:(NSPoint)initialPoint;

/** @brief Event loop for creating a polygon consisting of straight line sections

 Keeps control until the ending criteria are met (double-click or click on start point).
 @param initialPoint where to start
 */
- (void)polyCreateLoop:(NSPoint)initialPoint;

/** @brief Event loop for creating a curved path by fitting it to a series of sampled points

 Keeps control until the ending criteria are met (mouse up).
 @param initialPoint where to start
 */
- (void)freehandCreateLoop:(NSPoint)initialPoint;

/** @brief Event loop for creating an arc or a wedge

 Keeps control until the ending criteria are met (second click).
 @param initialPoint where to start
 */
- (void)arcCreateLoop:(NSPoint)initialPoint;

/** @brief Overrideable hook at the end of path creation
 */
- (void)pathCreationLoopDidEnd;
- (NSEvent*)postMouseUpAtPoint:(NSPoint)p;

/** @brief Set the smoothness of paths created in freehand mode

 The bigger the number, the smoother but less accurate the path. The value is the distance in
 base units that a point has to be to the path to be considered a fit. Typical values are between 1 and 20
 @param fs a smoothness value
 */
- (void)setFreehandSmoothing:(CGFloat)fs;

/** @brief Get the smoothness valueof paths created in freehand mode
 @return the smoothness value
 */
- (CGFloat)freehandSmoothing;

// converting to other types

/** @brief Make a copy of the path into a shape object

 Called by -convertToShape, a higher level operation. Note that the actual class of object returned
 can be modified by customising the interconversion table.
 @return a DKDrawableShape object, identical to this
 */
- (DKDrawableShape*)makeShape;
- (BOOL)canConvertToTrack;

/** @brief Make a copy of the path but with a parallel offset
 @param distance the distance from the original that the path is offset (negative forupward displacement)
 @param smooth if YES, also smooths the resulting path
 @return a DKDrawablePath object
 */
- (DKDrawablePath*)makeParallelWithOffset:(CGFloat)distance smooth:(BOOL)smooth;

// user level commands this object can respond to:

/** @brief Converts this object to he equivalent shape

 Undoably replaces itself in its current layer by the equivalent shape object
 @param sender the action's sender
 */
- (IBAction)convertToShape:(id)sender;

/** @brief Adds some random offset to every point on the path

 Just a fun effect
 @param sender the action's sender
 */
- (IBAction)addRandomNoise:(id)sender;

/** @brief Replaces the path with an outline of the path

 The result depends on the style - specifically the maximum stroke width. The path is replaced by
 a path whose edges are where the edge of the stroke of the original path lie. The topmost stroke
 is used to set the fill of the resulting object's style. The result is similar but not always
 identical to the original. For complex styles you will lose a lot of information.
 @param sender the action's sender
 */
- (IBAction)convertToOutline:(id)sender;

/** @brief Replaces the object with new objects, one for each subpath in the original
 @param sender the action's sender
 */
- (IBAction)breakApart:(id)sender;
- (IBAction)roughenPath:(id)sender;

/** @brief Tries to smooth a path by curve fitting. If the path is already made up from bezier elements,
 this will have no effect. vector paths can benefit however.

 The current set smoothness value is used
 @param sender the action's sender
 */
- (IBAction)smoothPath:(id)sender;

/** @brief Tries to smooth a path by curve fitting. If the path is already made up from bezier elements,
 this will have no effect. vector paths can benefit however.

 The current set smoothness value x4 is used
 @param sender the action's sender
 */
- (IBAction)smoothPathMore:(id)sender;

/** @brief Adds a copy of the receiver to the drawing with a parallel offset path

 This is really just a test of the algorithm
 @param sender the action's sender
 */
- (IBAction)parallelCopy:(id)sender;

/** @brief Attempts to curve-fit the object's path

 The path might not change, depending on how it is made up
 @param sender the action's sender
 */
- (IBAction)curveFit:(id)sender;

/** @brief Reverses the direction of the object's path

 Does not change the path's appearance directly, but may depending on the current style, e.g. arrows
 will flip to the other end.
 @param sender the action's sender
 */
- (IBAction)reversePath:(id)sender;

/** @brief Flips the path horizontally

 The path is flipped directly
 @param sender the action's sender
 */
- (IBAction)toggleHorizontalFlip:(id)sender;

/** @brief Flips the path vertically

 The path is flipped directly
 @param sender the action's sender
 */
- (IBAction)toggleVerticalFlip:(id)sender;

/** @brief Closes the path if not already closed

 Paths created using the bezier tool are always left open by default
 @param sender the action's sender
 */
- (IBAction)closePath:(id)sender;

@end

// special partcode value used to mean snap to the nearest point on the path itself:

enum {
    kDKSnapToNearestPathPointPartcode = -99
};

extern NSPoint gMouseForPathSnap;

extern NSString* kDKPathOnPathHitDetectionPriorityDefaultsKey;
