/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

typedef enum {
    kDKUseSimulatedAnnealing = 1,
    kDKUseNearestNeighbour = 2
} DKRouteAlgorithmType;

typedef enum {
    kDirectionEast = 0,
    kDirectionSouth = 1,
    kDirectionWest = 2,
    kDirectionNorth = 3,
    kDirectionAny = -1
} DKDirection;

/** @brief This object implements an heuristic solution to the travelling salesman problem.

This object implements an heuristic solution to the travelling salesman problem. The algorithm is based on simulated annealing
and is due to "Numerical Recipes in C", Chapter 10.

To use, initialise with an array of NSValues containing NSPoints. Then request the shortestRoute. The order of points returned by -shortestRoute
will be the shortest route as determined by the algorithm. The first point object in both input and output arrays is the same - in other words
the zeroth element of the input array sets the starting point of the path.

For uses with other object types, the -shortestRouteOrder might be more useful. This returns an array of integers which is the order of the
objects. This can then be used to reorder arbitrary objects.

Most simply, the +sortedArrayOfObjects:byShortestRouteForKey: will deal with any objects as long as they have a KVC-compliant property that 
resolves to an NSPoint return value, and is given by <key>. The result is a new array of the same objects sorted according to the TSP solution.
*/
@interface DKRouteFinder : NSObject {
@private
    NSArray* mInput; // input list of NSPoint values
    DKRouteAlgorithmType mAlgorithm; // which algorithm to use
    NSInteger* mOrder; // final sort order (1-based)
    BOOL mCalculationDone; // flag whether the sort was run
    id mProgressDelegate; // a progress delegate, if any
    // for SA
    CGFloat* mX; // for SA, list of input x coordinates
    CGFloat* mY; // for SA, list of input y coordinates
    NSInteger mAnnealingSteps; // for SA, the number of steps in the outer loop
    CGFloat mPathLength; // the path length
    // for NN
    NSMutableArray* mVisited; // for NN, the list of visited points in visit order
    DKDirection mDirection; // limit search for NN to this direction
}

+ (DKRouteFinder*)routeFinderWithArrayOfPoints:(NSArray*)arrayOfPoints;
+ (DKRouteFinder*)routeFinderWithObjects:(NSArray*)objects withValueForKey:(NSString*)key;
+ (NSArray*)sortedArrayOfObjects:(NSArray*)objects byShortestRouteForKey:(NSString*)key;
+ (void)setAlgorithm:(DKRouteAlgorithmType)algType;

- (NSArray*)shortestRoute;
- (NSArray*)shortestRouteOrder;
- (NSArray*)sortedArrayFromArray:(NSArray*)anArray;
- (CGFloat)pathLength;
- (DKRouteAlgorithmType)algorithm;

- (void)setProgressDelegate:(id)aDelegate;

@end

#define kDKDefaultAnnealingSteps 100

// informal protocol that an object can implement to be called back as the route finding progresses.
// <value> is in the range 0..1

@interface NSObject (DKRouteFinderProgressDelegate)

- (void)routeFinder:(DKRouteFinder*)rf progressHasReached:(CGFloat)value;

@end
