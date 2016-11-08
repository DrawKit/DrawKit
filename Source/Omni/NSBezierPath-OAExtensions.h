// Copyright 2000-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSBezierPath-OAExtensions.h 91941 2007-09-26 20:46:20Z wiml $

#import <AppKit/NSBezierPath.h>

@class NSCountedSet, NSDictionary, NSMutableDictionary;


//#define	DEBUGGING_CURVE_INTERSECTIONS  0

// defines copied over from OmniBase - avoids needing a large dependency on additional code from Omni for this one category

#if !defined(SWAP)
#define SWAP(A, B) do { __typeof__(A) __temp = (A); (A) = (B); (B) = __temp;} while(0)
#endif

#define OBPRECONDITION(expression)
#define OBPOSTCONDITION(expression)
#define OBINVARIANT(expression)
#define OBASSERT(expression)
#define OBASSERT_NOT_REACHED(reason)


void OACGAddRoundedRect(CGContextRef context, NSRect rect, CGFloat topLeft, CGFloat topRight, CGFloat bottomLeft, CGFloat bottomRight);

enum OAIntersectionAspect
{
    intersectionEntryLeft		= -1,	// Other path crosses from left to right
    intersectionEntryAt			= 0,    // Collinear or osculating
    intersectionEntryRight		= 1,	// Other path crosses from right to left
    intersectionEntryBogus		= -2,	// Garbage value for unit testing
};

typedef NSInteger NSBezierPathSegmentIndex;  // It would make more sense for this to be unsigned, but NSBezierPath uses int, and so we follow its lead

typedef struct OABezierPathPosition
{
    NSBezierPathSegmentIndex segment;
    double parameter;
}
OABezierPathPosition;

typedef struct
{
    struct OABezierPathIntersectionHalf
	{
        NSBezierPathSegmentIndex segment;
        double parameter;
        double parameterDistance;
        // Unlike the lower-level calls, these aspects are ordered according to their occurrence on this path, not the other path.
		// So 'firstAspect' is the aspect of the other line where it crosses us at (parameter), and 'secondAspect' is the aspect at (parameter.parameterDistance).
		
        enum OAIntersectionAspect firstAspect, secondAspect;
    }
	left, right;
    NSPoint location;
}
OABezierPathIntersection;

struct OABezierPathIntersectionList
{
    NSUInteger count;
    OABezierPathIntersection *intersections;
};


typedef struct OABezierPathIntersectionList PathIntersectionList;

// Utility functions used internally, may be of use to other callers as well
void				splitBezierCurveTo(const NSPoint *c, CGFloat t, NSPoint *l, NSPoint *r);

@interface NSBezierPath (OAExtensions)

- (NSPoint)			currentpointForSegment:(NSInteger)i;  // Raises an exception if no currentpoint

- (BOOL)			strokesSimilarlyIgnoringEndcapsToPath:(NSBezierPath *)otherPath;
- (NSCountedSet *)	countedSetOfEncodedStrokeSegments;

- (BOOL)			intersectsRect:(NSRect)rect;
- (BOOL)			intersectionWithLine:(NSPoint *)result lineStart:(NSPoint) lineStart lineEnd:(NSPoint) lineEnd;

// Returns the first intersection with the given line (that is, the intersection closest to the start of the receiver's bezier path).
- (BOOL)			firstIntersectionWithLine:(OABezierPathIntersection*) result lineStart:(NSPoint) lineStart lineEnd:(NSPoint) lineEnd;

// Returns a list of all the intersections between the receiver and the specified path. As a special case, if other==self, it does the useful thing and returns only the nontrivial self-intersections.
- (struct OABezierPathIntersectionList)	allIntersectionsWithPath:(NSBezierPath*) other;

- (void)			getWinding:(NSInteger *)clockwiseWindingCount andHit:(NSUInteger *)strokeHitCount forPoint:(NSPoint)point;

- (NSInteger)				segmentHitByPoint:(NSPoint)point padding:(CGFloat)padding;
- (NSInteger)				segmentHitByPoint:(NSPoint)point;  // 0 == no hit, padding == 5
- (BOOL)			isStrokeHitByPoint:(NSPoint)point padding:(CGFloat)padding;
- (BOOL)			isStrokeHitByPoint:(NSPoint)point; // padding == 5

//
- (void)			appendBezierPathWithRoundedRectangle:(NSRect)aRect withRadius:(CGFloat)radius;
- (void)			appendBezierPathWithLeftRoundedRectangle:(NSRect)aRect withRadius:(CGFloat)radius;
- (void)			appendBezierPathWithRightRoundedRectangle:(NSRect)aRect withRadius:(CGFloat)radius;

// The "position" manipulated by these methods divides the range 0..1 equally into segments corresponding to the Bezier's segments, and position within each segment is proportional to the t-parameter (not proportional to linear distance).
- (NSPoint)			getPointForPosition:(CGFloat)position andOffset:(CGFloat)offset;
- (CGFloat)			getPositionForPoint:(NSPoint)point;
- (CGFloat)			getNormalForPosition:(CGFloat)position;

// "Length" is the actual length along the curve
- (double)			lengthToSegment:(NSInteger)seg parameter:(double)parameter totalLength:(double *)totalLengthOut;

// Returns the segment and parameter corresponding to the point a certain distance along the curve. 'outParameter' may be NULL, which can save a small amount of computation if the parameter isn't needed.
- (NSInteger)				segmentAndParameter:(double *)outParameter afterLength:(double)lengthFromStart fractional:(BOOL)lengthIsFractionOfTotal;

// Returns the location of a point specifed as a (segment,parameter) pair.
- (NSPoint)			getPointForPosition:(OABezierPathPosition)pos;

- (BOOL)			isClockwise;

// load and save
- (NSMutableDictionary *)propertyListRepresentation;
- (void)			loadPropertyListRepresentation:(NSDictionary *)dict;

// NSObject overrides
- (BOOL)			isEqual:(NSBezierPath *)otherBezierPath;
- (NSUInteger)	hash;

@end

// private methods are listed in the header because other code in DK can usefully use them. This is different from the situation of using private Cocoa
// methods because the source is right here in DK and can't go away at the hands of Omni or Apple! However, other methods in DK that make use of these
// should be used rather than the private methods directly.

// let's use a type for these structs - untyped structs are a PITA!

typedef struct
{
    NSBezierPath *pathBeingWalked;      // The NSBezierPath we're iterating through
    NSInteger elementCount;                   // [pathBeingWalked elementCount]
    NSPoint startPoint;                 // first point of this subpath, for closepath
    NSBezierPathElement what;           // the type of the current segment/element
    NSPoint points[4];                  // point[0] is currentPoint (derived from previous element)
    NSInteger currentElt;                     // index into pathBeingWalked of currently used element
    BOOL possibleImplicitClosepath;     // Fake up a closepath if needed?
    
    // Note that if currentElt >= elementCount, then 'what' may be a faked-up closepath or other element not actually found in the NSBezierPath.
}
subpathWalkingState;

@interface NSBezierPath (PrivateOAExtensions)

/*
 Defined in NSBezierPath-OAInternal.h
 
struct intersectionInfo {
    double leftParameter, rightParameter;
    double leftParameterDistance, rightParameterDistance;
    enum OAIntersectionAspect leftEntryAspect, leftExitAspect;
};
*/

NSString *	_roundedStringForPoint(NSPoint point);
void		_parameterizeLine(NSPoint *coefficients, NSPoint startPoint, NSPoint endPoint);
void		_parameterizeCurve(NSPoint *coefficients, NSPoint startPoint, NSPoint endPoint, NSPoint controlPoint1, NSPoint controlPoint2);

- (BOOL)	_curvedIntersection:(CGFloat *) length time:(CGFloat *)time curve:(NSPoint *)c line:(NSPoint *)a;

- (BOOL)	_curvedLineHit:(NSPoint) point startPoint:(NSPoint)startPoint endPoint:(NSPoint)endPoint controlPoint1:(NSPoint)controlPoint1 controlPoint2:(NSPoint)controlPoint2 position:(CGFloat *)position padding:(CGFloat)padding;
- (BOOL)	_straightLineIntersection:(CGFloat *) length time:(CGFloat *)time segment:(NSPoint *)s line:(const NSPoint *)l;
- (BOOL)	_straightLineHit:(NSPoint) startPoint :(NSPoint)endPoint :(NSPoint)point  :(CGFloat *)position padding:(CGFloat)padding;
- (NSInteger)		_segmentHitByPoint:(NSPoint) point position:(CGFloat *)position padding:(CGFloat)padding;
- (NSPoint)	_endPointForSegment:(NSInteger) i;

@end


// other functions:

BOOL		initializeSubpathWalkingState( subpathWalkingState *s, NSBezierPath *p, NSInteger startIndex, BOOL implicitClosepath);
BOOL		nextSubpathElement( subpathWalkingState *s);
BOOL		hasNextSubpathElement( subpathWalkingState *s);
void		repositionSubpathWalkingState( subpathWalkingState *s, NSInteger toIndex);


