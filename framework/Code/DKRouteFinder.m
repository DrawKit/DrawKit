//
//  DKRouteFinder.m
//  GCDrawKit
//
//  Created by graham on 30/07/2008.
//  Copyright 2008 Apptree.net. All rights reserved.
//

#import "DKRouteFinder.h"

static CGFloat		anneal( CGFloat x[], CGFloat y[], NSInteger iorder[], NSInteger ncity, NSInteger annealingSteps, const void* context );
static void			progressCallback( CGFloat iteration, CGFloat maxIterations, const void* context );
static DKDirection	directionOfAngle( const CGFloat angle );

@interface DKRouteFinder (Private)

- (id)				initWithArray:(NSArray*) array;
- (void)			notifyProgress:(CGFloat) value;
- (NSUInteger)		nearestNeighbourInArray:(NSArray*) arrayOfPoint toPoint:(NSPoint) cvp inDirection:(DKDirection) direction;
- (NSArray*)		sortArrayUsingNearestNeighbour:(NSArray*) points;
- (CGFloat)			pathLengthOfArray:(NSArray*) points;
- (NSUInteger)		indexOfTopLeftPointInArray:(NSArray*) points;
- (void)			performSortIfNeeded;

@end

#pragma mark -

static DKRouteAlgorithmType s_Algorithm = kDKUseNearestNeighbour;//kDKUseSimulatedAnnealing;

@implementation DKRouteFinder


+ (void)			setAlgorithm:(DKRouteAlgorithmType) algType
{
	// sets the algorithm to use for subsequent DKRouteFinder instances. Algorithm must be
	// set prior to instantiating the route finder.
	
	s_Algorithm = algType;
}


+ (DKRouteFinder*)	routeFinderWithArrayOfPoints:(NSArray*) arrayOfPoints
{
	NSAssert( arrayOfPoints != nil, @"cannot operate on a nil array");
	
	DKRouteFinder* tsp = [[self alloc] initWithArray:arrayOfPoints];
	
	return [tsp autorelease];
}


+ (DKRouteFinder*)	routeFinderWithObjects:(NSArray*) objects withValueForKey:(NSString*) key
{
	// given a list of arbitrary objects, this builds an array of point values by querying each object using valueForKey:key. The key should
	// correspond to a method that does indeed return an NSPoint value, otherwise the result is undefined.
	
	NSAssert( objects != nil, @"cannot operate on a nil array");
	NSAssert( key != nil, @"key was nil, cannot proceed");

	return [self routeFinderWithArrayOfPoints:[objects valueForKey:key]];
}


+ (NSArray*)		sortedArrayOfObjects:(NSArray*) objects byShortestRouteForKey:(NSString*) key
{
	// ultra-easy method to sort objects into the shortest route based on the key (which must reference a NSPoint property)
	
	NSAssert( objects != nil, @"cannot operate on a nil array");
	NSAssert( key != nil, @"key was nil, cannot proceed");

	DKRouteFinder*	tsp = [self routeFinderWithObjects:objects withValueForKey:key];
	return [tsp sortedArrayFromArray:objects];
}


- (NSArray*)		shortestRoute
{
	// returns the original points reordered into the shortest route
	return [self sortedArrayFromArray:mInput];
}


- (NSArray*)		shortestRouteOrder
{
	// returns a list of integers which specifies the shortest route between the original points
	// perform the calculation if not already done
		
	[self performSortIfNeeded];
	
	NSMutableArray*	routeOrder = [NSMutableArray array];
	NSUInteger		k;
	NSNumber*		num;
	
	for( k = 1; k <= [mInput count]; ++k )
	{
		num = [NSNumber numberWithInteger:mOrder[k] - 1];
		[routeOrder addObject:num];
	}
	
	return routeOrder;
}


- (NSArray*)		sortedArrayFromArray:(NSArray*) anArray
{
	// sorts <anArray> according to the sort order calculated and returns the sorted copy
	
	NSAssert( anArray != nil, @"can't sort a nil array");
	
	NSMutableArray*	result = nil;
	
	if([anArray count] == [mInput count])
	{
		result = [NSMutableArray array];
		
		// perform the calculation if not already done
		[self performSortIfNeeded];
				
		NSUInteger	k, n, m;
		id			object;
		
		n = [mInput count];
		k = 0; m = 1;
		
		// to meet the requirement that both arrays start on the same object, find the index in mOrder that
		// contains the value 1.

		while( k < n && mOrder[++k] != 1 ){ ++m; }
		
		// copy the objects across in <mOrder> order, starting from m.
		
		for( k = 0; k < n; ++k )
		{
			object = [anArray objectAtIndex:mOrder[1 + ((k + m - 1) % n)] - 1];
			[result addObject:object];
		}
	}
	return result;
}


- (CGFloat)			pathLength
{
	// return the computed path length for the set method. Note this doesn't return a valid result
	// during a progress callback, only after the sort has completed.
	
	[self performSortIfNeeded];
	
	return mPathLength;
}


- (DKRouteAlgorithmType) algorithm
{
	return mAlgorithm;
}


- (void)			setProgressDelegate:(id) aDelegate
{
	// set a delegate that will be called with progress information as the route finder proceeds. Note that
	// on a modern machine, this is actually very fast for ordinary numbers (100s) of objects. Once you get
	// about 1000 or more it starts to take noticeable time, at which point a progress bar could be worth it.
	
	mProgressDelegate = aDelegate;
}




#pragma mark -
#pragma mark - private methods

- (id)				initWithArray:(NSArray*) array
{
	self = [super init];
	if( self != nil )
	{
		NSAssert( array != nil, @"cannot initialise with a nil array");
		
		mAlgorithm = s_Algorithm;
		
		// set the initial search direction - east is good when starting at top, left. Or set
		// kDirectionAny to use non-directional NN algorithm (which is definitely not as good)
		
		mDirection = kDirectionEast;
		
		// if there are less than three objects, there is no route to find that isn't trivial. However,
		// anneal algorithm requires at least four.
		
		if([array count] < 4 )
		{
			[self autorelease];
			return nil;
		}
		
		mCalculationDone = NO;
		mInput = [array retain];
		mAnnealingSteps = kDKDefaultAnnealingSteps;
		
		// prepare for the computation by allocating C arrays and populating them from the input.
		// for some reason these arrays are 1-based, so must allow for that.
		
		NSUInteger n = [array count] + 1;
		
#warning 64BIT: Inspect use of sizeof
		mOrder = malloc( sizeof(NSInteger) * n );
		NSInteger kludge = 1;
#warning 64BIT: Inspect use of sizeof
		memset_pattern4(mOrder, &kludge, sizeof(NSInteger) * n);
		
		if(( mAlgorithm & kDKUseSimulatedAnnealing ) != 0 )
		{
#warning 64BIT: Inspect use of sizeof
			mX = malloc( sizeof(CGFloat) * n );
#warning 64BIT: Inspect use of sizeof
			mY = malloc( sizeof(CGFloat) * n );
			
			NSInteger	k = 0;
			NSEnumerator*	iter = [array objectEnumerator];
			NSValue*		val;
			
			while((val = [iter nextObject]))
			{
				++k;	// preincrement, start loading arrays from 1
				
				if( strcmp([val objCType], @encode(NSPoint)) == 0 )
				{
					mX[k] = [val pointValue].x;
					mY[k] = [val pointValue].y;
				}
				else
				{
					[self autorelease];
					[NSException raise:NSInternalInconsistencyException format:@"NSValue passed did not contain NSPoint"];
				}
					
				mOrder[k] = k;
			}
		}
	}
	
	return self;
}

- (void)			dealloc
{
	[mInput release];
	[mVisited release];
	
	if( mX )
		free(mX);
		
	if( mY )
		free(mY);
		
	if( mOrder )
		free(mOrder);
	
	[super dealloc];
}


- (void)			notifyProgress:(CGFloat) value
{
	if( mProgressDelegate && [mProgressDelegate respondsToSelector:@selector(routeFinder:progressHasReached:)])
		[mProgressDelegate routeFinder:self progressHasReached:value];
		
	//NSLog(@"RF progress: %.3f", value );
}


- (NSUInteger)		nearestNeighbourInArray:(NSArray*) arrayOfPoint toPoint:(NSPoint) cvp inDirection:(DKDirection) direction
{
	// given a list of NSPoint values, this returns the index of the point being the nearest neighbour to the point <p>
	// this is one step in the nearest-neightbour (NN) algorithm. <p> should not be listed in the array. If <direction> is not any,
	// this rejects neighbours that fall outside of a region bounded by lines at 45 degrees to the direction specified. If no
	// neighbours are found under these constraints, the method returns NSNotFound.
	
	NSUInteger	nn = NSNotFound, k;
	NSPoint		p;
	CGFloat		dist, shortestDistanceSoFar = HUGE_VAL;
	
	for( k = 0; k < [arrayOfPoint count]; ++k )
	{
		p = [[arrayOfPoint objectAtIndex:k] pointValue];
			
		dist = hypotf( p.x - cvp.x, p.y - cvp.y );
		
		if( dist < shortestDistanceSoFar )
		{
			// could be a candidate - check whether it falls within the direction limits
			
			if( direction == kDirectionAny )
			{
				shortestDistanceSoFar = dist;
				nn = k;
			}
			else
			{
				DKDirection ad = directionOfAngle(atan2f( p.y - cvp.y, p.x - cvp.x ));
				
				if ( ad == direction )
				{
					shortestDistanceSoFar = dist;
					nn = k;
				}
			}
		}
	}
	
	return nn;
}


- (NSArray*)		sortArrayUsingNearestNeighbour:(NSArray*) points
{
	// given an array of point values, this sorts them into order according to nearest neighbour (NN)
	// the MO is to start with the first point and find its nearest neighbour. That point is then added to the visited list
	// and removed from the working list. The search is repeated until all points have been exhausted. The order of
	// points in the visited list is the result.
	
	// A straight NN algorithm is used if mDirection == kDirectionAny. This can return some pretty non-optimal paths. A modified
	// NN algorithm is used if mDirection is some definite direction (N,S,E or W). In this case, neighbours are only considered if they lie
	// ahead of the current vertex in the direction set (bounded by 45 degrees either side of the cardinal point). If no neighbour is
	// found in that direction, another direction is tried, etc. The directions are switched so as to form a scanning pattern tracking
	// down and alternately east and west, only going north if all other directions have been exhausted. The result is to find a nice scan
	// route for a regular grid, while still finding a reasonable path for arbitrarily placed objects.
	
	// this also sets the mOrder array as for a SA sort, so that the same code can be used to extract results from an NN sort.
	
	NSMutableArray*	workingList = [points mutableCopy];
	
	// start at point 0, so it has already been "visited"
	
	if ( mVisited == nil )
		mVisited = [[NSMutableArray alloc] init];
		
	[mVisited removeAllObjects];
	[mVisited addObject:[points objectAtIndex:0]];
	[workingList removeObjectAtIndex:0];
	
	// update progress
	
	[self notifyProgress:0.0];
	
	
	BOOL		phase = YES;	// sets alternate E/W scan
	NSUInteger	k = 0;	// tracks the index into mOrder
	mOrder[++k] = 1;
	
	do
	{
		[self notifyProgress:(CGFloat)k/(CGFloat)[points count]];

		NSPoint		currentVertex = [[mVisited lastObject] pointValue];
		NSUInteger	nn;
		
		do
		{
			nn = [self nearestNeighbourInArray:workingList toPoint:currentVertex inDirection:mDirection];
			
			// if nn is not found, there are no more neighbours in the direction being tracked, so switch to another direction and try again.
			if ( mDirection != kDirectionAny )
			{
				if ( nn == NSNotFound )
				{
					if( mDirection == kDirectionEast || mDirection == kDirectionWest )
						mDirection = kDirectionSouth;
					else if ( mDirection == kDirectionSouth )
						mDirection = kDirectionNorth;
					else if ( mDirection == kDirectionNorth )
					{
						mDirection = phase? kDirectionWest : kDirectionEast;
						phase = !phase;
					}
				}
				else
				{
					if ( mDirection == kDirectionSouth || mDirection == kDirectionNorth )
					{
						mDirection = phase? kDirectionWest : kDirectionEast;
						phase = !phase;
					}
				}
			}
		}
		while( nn == NSNotFound );
		
		// move this to the visited list - it is the current vertex for the next iteration.
		// remove from the working list
		
		[mVisited addObject:[workingList objectAtIndex:nn]];
		[workingList removeObjectAtIndex:nn];
		
		//NSLog(@"nearest neighbour to point %@ was = %d (k = %d)", NSStringFromPoint( currentVertex), nn, k );
		
		// record order in mOrder. 1-based, so add 1 to index.
		
		mOrder[++k] = [points indexOfObject:[mVisited lastObject]] + 1;	
	}
	while([workingList count] > 0 );

	[workingList release];
	[self notifyProgress:1.0];
	
	// mVisited is the sorted list of original points
	
	return mVisited;
}


- (CGFloat)			pathLengthOfArray:(NSArray*) points
{
	NSEnumerator*	iter = [points objectEnumerator];
	NSValue*		val;
	CGFloat			pl = 0.0;
	NSPoint			pp, pt;
	
	pp = [[iter nextObject] pointValue];
	
	while(( val = [iter nextObject]))
	{
		pt = [val pointValue];
		pl += hypotf( pt.x - pp.x, pt.y - pp.y );
		pp = pt;
	}
	
	return pl;
}


- (NSUInteger)		indexOfTopLeftPointInArray:(NSArray*) points
{
	// return the index of the point having the lowest x,y value. (TO DO)
	
	#pragma unused(points)

	return 0;
}


- (void)			performSortIfNeeded
{
	if( !mCalculationDone )
	{
		mCalculationDone = YES;
		
		if(( mAlgorithm & kDKUseSimulatedAnnealing ) != 0 )
		{
			anneal( mX, mY, mOrder, [mInput count], mAnnealingSteps, self );
			mPathLength = [self pathLengthOfArray:[self shortestRoute]];
		}
		
		if(( mAlgorithm & kDKUseNearestNeighbour ) != 0 )
		{
			[self sortArrayUsingNearestNeighbour:mInput];
			mPathLength = [self pathLengthOfArray:mVisited];
		}
	}
}


@end


void progressCallback( CGFloat iteration, CGFloat maxIterations, const void* context )
{
	DKRouteFinder* rf = (DKRouteFinder*)context;
	
	if( rf != nil )
		[rf notifyProgress:iteration/maxIterations];
}


static DKDirection	directionOfAngle( const CGFloat angle )
{
	// given an angle in radians, returns its basic direction.
	
	CGFloat fortyFiveDegrees = pi * 0.25f;
	CGFloat oneThirtyFiveDegrees = pi * 0.75f;
	
	if( angle >= -fortyFiveDegrees && angle < fortyFiveDegrees )
		return kDirectionEast;
	else if ( angle >= fortyFiveDegrees && angle < oneThirtyFiveDegrees )
		return kDirectionSouth;
	else if ( angle >= oneThirtyFiveDegrees || angle < -oneThirtyFiveDegrees )
		return kDirectionWest;
	else
		return kDirectionNorth;
}

#pragma mark -
#pragma mark - from Numerical Recipes in C (2nd ed. Ch 10. p448)

#warning 64BIT: Inspect use of long
#warning 64BIT: Inspect use of long
static NSInteger*		ivector(long nl, long nh);
#warning 64BIT: Inspect use of long
#warning 64BIT: Inspect use of long
static void		free_ivector(NSInteger *v, long nl, long nh);
#warning 64BIT: Inspect use of long
static CGFloat	ran3(long *idum);
#warning 64BIT: Inspect use of unsigned long
static NSInteger		irbit1(unsigned long *iseed);
static NSInteger		metrop(CGFloat de,CGFloat t); 
#warning 64BIT: Inspect use of long
static CGFloat	ran3(long* idum); 
static CGFloat	revcst(CGFloat x[], CGFloat y[], NSInteger iorder[], NSInteger ncity, NSInteger n[]); 
static void		reverse(NSInteger iorder[], NSInteger ncity, NSInteger n[]); 
static CGFloat	trncst(CGFloat x[], CGFloat y[], NSInteger iorder[], NSInteger ncity, NSInteger n[]); 
static void		trnspt(NSInteger iorder[], NSInteger ncity, NSInteger n[]); 

#pragma mark -
#define NR_END 1
#define FREE_ARG char*


/* allocate an int vector with subscript range v[nl..nh] */

#warning 64BIT: Inspect use of long
#warning 64BIT: Inspect use of long
NSInteger*	ivector(long nl, long nh)
{
	NSInteger *v;

#warning 64BIT: Inspect use of sizeof
	v=(NSInteger *)malloc((size_t) ((nh-nl+1+NR_END)*sizeof(NSInteger)));
	if ( v != NULL )
		return v-nl+NR_END;
	else
		return NULL;
}


/* free an int vector allocated with ivector() */

#warning 64BIT: Inspect use of long
#warning 64BIT: Inspect use of long
void	free_ivector(NSInteger *v, long nl, long nh)
{
	#pragma unused(nh)
	
	free((FREE_ARG) (v+nl-NR_END));
}


#define MBIG 1000000000
#define MSEED 161803398
#define MZ 0
#define FAC (1.0/MBIG)

#warning 64BIT: Inspect use of long
CGFloat ran3(long *idum)
{
	static NSInteger inext,inextp;
#warning 64BIT: Inspect use of long
	static long ma[56];
	static NSInteger iff=0;
#warning 64BIT: Inspect use of long
	long mj,mk;
	NSInteger i,ii,k;

	if (*idum < 0 || iff == 0)
	{
		iff = 1;
		mj = MSEED - (*idum < 0 ? -*idum : *idum);
		mj %= MBIG;
		ma[55] = mj;
		mk = 1;
		
		for (i=1; i<=54; i++)
		{
			ii=(21*i) % 55;
			ma[ii]=mk;
			mk=mj-mk;
			if (mk < MZ)
				mk += MBIG;
			mj=ma[ii];
		}
		
		for (k=1; k<=4; k++)
		{
			for (i=1; i<=55; i++)
			{
				ma[i] -= ma[1+(i+30) % 55];
				if (ma[i] < MZ) ma[i] += MBIG;
			}
		}
		inext=0;
		inextp=31;
		*idum=1;
	}
	
	if (++inext == 56)
		inext=1;
		
	if (++inextp == 56)
		inextp=1;
		
	mj=ma[inext]-ma[inextp];
	
	if (mj < MZ)
		mj += MBIG;
		
	ma[inext]=mj;
	
	return mj*FAC;
}


#define IB1 1
#define IB2 2
#define IB5 16
#define IB18 131072
#define MASK (IB1+IB2+IB5)

#warning 64BIT: Inspect use of unsigned long
NSInteger irbit1(unsigned long *iseed)
{
#warning 64BIT: Inspect use of unsigned long
	unsigned long newbit;

	newbit = (*iseed & IB18) >> 17
		^ (*iseed & IB5) >> 4
		^ (*iseed & IB2) >> 1
		^ (*iseed & IB1);
	*iseed=(*iseed << 1) | newbit;
	return (NSInteger) newbit;
}



/*
This algorithm ﬁnds the shortest round-trip path to ncity cities whose coordinates are in the 
arrays x[1..ncity], y[1..ncity]. The array iorder[1..ncity] speciﬁes the order in 
which the cities are visited. On input, the elements of iorder may be set to any permutation 
of the numbers 1 to ncity. This routine will return the best alternative path it can ﬁnd. 

function result is the final path length
*/

#pragma mark -
#define	TFACTR 0.9		// Annealing schedule: reduce t by this factor on each step. 
#define	ALEN(a,b,c,d)	_CGFloatSqrt(((b)-(a))*((b)-(a))+((d)-(c))*((d)-(c))) 

CGFloat	anneal( CGFloat x[], CGFloat y[], NSInteger iorder[], NSInteger ncity, NSInteger annealingSteps, const void* context ) 
{ 
	NSInteger		ans, nover, nlimit, i1, i2; 
	NSInteger		i, j, k, nsucc, nn, idec; 

	static			NSInteger n[7]; 
#warning 64BIT: Inspect use of long
	static long		idum = -1; 
#warning 64BIT: Inspect use of unsigned long
	static unsigned long	iseed = 111; 
	CGFloat			path, de, t, previousPath; 

	nover	= 100 * ncity;	// Maximum number of paths tried at any temperature. 
	nlimit	= 20 * ncity;	// Maximum number of successful path changes before continuing. 
	path	= 0.0; 
	t		= 0.5; 
	
	progressCallback( 0, annealingSteps, context );

	for( i = 1; i < ncity; ++i )
	{
		// Calculate initial path length. 
		i1 = iorder[i]; 
		i2 = iorder[i+1]; 
		path += ALEN(x[i1],x[i2],y[i1],y[i2]); 
	}
	
	i1 = iorder[ncity];		// Close the loop by tying path ends together. 
	i2 = iorder[1]; 
	path += ALEN(x[i1],x[i2],y[i1],y[i2]); 
	//idum = -1; 
	//iseed = 111;
	
	previousPath = path;
	 
	for( j = 1; j <= annealingSteps; ++j )
	{
		progressCallback( j, annealingSteps, context );
		
		// Try up to <annealingSteps> temperature steps. 
		
		nsucc = 0; 
		for( k = 1; k <= nover; ++k )
		{ 
			if ( path != previousPath )
			{
				// path changed, so make a progress report
				
				previousPath = path;
				CGFloat kprog = (CGFloat)k/(CGFloat)nover;
				
				progressCallback((CGFloat)j + kprog, (CGFloat)annealingSteps, context );	// for testing only - remove for production it slows this down too much
			}
			
			do
			{ 
				n[1] = 1+(NSInteger)(ncity * ran3(&idum));		// Choose beginning of segment..
				n[2] = 1+(NSInteger)((ncity -1) * ran3(&idum));	// ..and end of segment. 
				if( n[2] >= n[1] )
					++n[2]; 
					
				nn = 1+((n[1] - n[2] + ncity -1) % ncity); // nn is the number of cities not on the segment. 
			}
			while( nn < 3 ); 
			
			idec = irbit1( &iseed );
			
			// Decide whether to do a segment reversal or transport. 
			if( idec == 0 )
			{
				// Do a transport. 
				n[3] = n[2] + (NSInteger)(abs( nn-2 ) * ran3( &idum )) +1; 
				n[3] = 1+(( n[3]-1 ) % ncity); 
				
				// Transport to a location not on the path. 
				de = trncst( x, y, iorder, ncity, n);	// Calculate cost. 
				ans = metrop( de, t );					// Consult the oracle. 
				if( ans )
				{ 
					++nsucc; 
					path += de; 
					trnspt( iorder, ncity, n );			// Carry out the transport. 
				} 
			}
			else
			{
				// Do a path reversal. 
				de = revcst( x, y, iorder, ncity, n);	// Calculate cost. 
				ans = metrop( de, t );					// Consult the oracle. 

				if( ans )
				{ 
					++nsucc; 
					path += de; 
					reverse( iorder, ncity, n);			// Carry out the reversal. 
				} 
			} 
			
			//if( nsucc >= nlimit)
			//	break;									// Finish early if we have enough successful changes. 
		} 
		//printf("\n%s%10.6f%s%12.6f\n","T=",t, " PathLength=",path); 
		//printf("SuccessfulMoves:%6d\n",nsucc); 
		
		t *= TFACTR;									// Annealing schedule. 
		if( nsucc == 0)
		{
			progressCallback( annealingSteps, annealingSteps, context );
			return path;										// If no success, we are done. 
		}
	} 
	
	return path;
} 


/*
This function returns the value of the cost function for a proposed path reversal. ncity is the 
number of cities, and arrays x[1..ncity], y[1..ncity] give the coordinates of these cities. 
iorder[1..ncity] holds the present itinerary. The ﬁrst two values n[1] and n[2] of array 
n give the starting and ending cities along the path segment which is to be reversed. On output, 
de is the cost of making the reversal. The actual reversal is not performed by this routine. 
*/

CGFloat revcst(CGFloat x[], CGFloat y[], NSInteger iorder[], NSInteger ncity, NSInteger n[]) 
{ 
	CGFloat	xx[5], yy[5], de; 
	NSInteger		j, ii; 
	
	n[3] = 1+(( n[1] + ncity -2) % ncity);			// Find the city before n[1].. 
	n[4] = 1+(n[2] % ncity);						// .. and the city after n[2]. 

	for( j = 1; j <= 4; ++j)
	{ 
		ii = iorder[n[j]];							// Find coordinates for the four cities involved. 
		xx[j] = x[ii]; 
		yy[j] = y[ii]; 
	} 
	
	de = -ALEN(xx[1],xx[3],yy[1],yy[3]);			// Calculate cost of disconnecting the segment at both ends and reconnecting in the opposite order. 
	de -= ALEN(xx[2],xx[4],yy[2],yy[4]); 
	de += ALEN(xx[1],xx[4],yy[1],yy[4]); 
	de += ALEN(xx[2],xx[3],yy[2],yy[3]); 
	
	return de; 
} 


/*
This routine performs a path segment reversal. iorder[1..ncity] is an input array giving the 
present itinerary. The vector n has as its ﬁrst four elements the ﬁrst and last cities n[1],n[2] 
of the path segment to be reversed, and the two cities n[3] and n[4] that immediately 
precede and follow this segment. n[3]and n[4] are found by function revcst. On output, 
iorder[1..ncity] contains thesegment from n[1] t on[2] in reversed order. 
*/

void reverse( NSInteger iorder[], NSInteger ncity, NSInteger n[]) 
{ 
	NSInteger nn, j, k, l, itmp; 

	nn = (1+(( n[2] - n[1] + ncity) % ncity))/2;		// This many cities must be swapped to eﬀect the reversal. 
	
	for( j = 1; j <= nn; ++j)
	{ 
		k = 1+ ((n[1] + j -2) % ncity);					// Start at the ends of the segment and swap pairs of cities, moving toward the center. 
		l = 1+ ((n[2] - j +ncity) % ncity); 
		itmp = iorder[k]; 
		iorder[k] = iorder[l]; 
		iorder[l] = itmp; 
	} 
}

/*
This routine returns the value of the cost function for a proposed path segment transport. ncity 
is the number of cities, and arrays x[1..ncity] and y[1..ncity] give the city coordinates. 
iorder[1..ncity] is an array giving the present itinerary. The ﬁrst three elements of array 
n give the starting and ending cities of the path to be transported, and the point among the 
remaining cities after which it is to be inserted. On output, de is the cost of the change. The 
actual transport is not performed by this routine. 
*/

CGFloat	trncst(CGFloat x[], CGFloat y[], NSInteger iorder[], NSInteger ncity, NSInteger n[]) 
{ 
	CGFloat	xx[7], yy[7], de; 
	NSInteger		j, ii; 
	
	n[4] = 1+(n[3] % ncity);							// Find the city following n[3].. 
	n[5] = 1+((n[1] + ncity -2) % ncity);				// ..and the one preceding n[1].. 
	n[6] = 1+(n[2] % ncity);							// ..and the one following n[2]. 

	for( j = 1; j <= 6; ++j)
	{ 
		ii = iorder[n[j]];								// Determine coordinates for the six cities involved. 
		xx[j] = x[ii]; 
		yy[j] = y[ii]; 
	} 
	
	de = -ALEN(xx[2],xx[6],yy[2],yy[6]);				// Calculate the cost of disconnecting the path segment from n[1] to n[2], 
														// opening a space between n[3] and n[4], connecting the segment in the 
														// space, and connecting n[5] to n[6]. 
	de -= ALEN(xx[1],xx[5],yy[1],yy[5]); 
	de -= ALEN(xx[3],xx[4],yy[3],yy[4]); 
	de += ALEN(xx[1],xx[3],yy[1],yy[3]); 
	de += ALEN(xx[2],xx[4],yy[2],yy[4]); 
	de += ALEN(xx[5],xx[6],yy[5],yy[6]); 

	return de; 
} 


/* 
This routine does the actual path transport, once metrop has approved. iorder[1..ncity] 
is an input array giving the present itinerary. The array n has as its six elements the beginning 
n[1] and end n[2] of the path to be transported, the adjacent cities n[3] and n[4] between 
which the path is to be placed, and the cities n[5] and n[6] tha tprecede and follow the path. 
n[4], n[5], and n[6] are calculated by function trncst. On output, iorder is modiﬁed to 
reﬂect the movement of the path segment. 
*/

void	trnspt( NSInteger iorder[], NSInteger ncity, NSInteger n[])
{ 
	NSInteger	m1, m2, m3, nn, j, jj, *jorder; 
	jorder = ivector(1, ncity); 
	
	m1 = 1+((n[2] - n[1] +ncity) % ncity);						// Find number of cities from n[1] to n[2] 
	m2 = 1+((n[5] - n[4] +ncity) % ncity);						// ...and the number from n[4] to n[5] 
	m3 = 1+((n[3] - n[6] +ncity) % ncity);						// ...and the number from n[6] to n[3]. 
	nn = 1; 

	for( j = 1; j <= m1; ++j )
	{ 
		jj = 1+((j + n[1] -2) % ncity);							// Copy the chosen segment. 
		jorder[nn++] = iorder[jj]; 
	} 

	for( j = 1; j <= m2; ++j)
	{
		// The ncopy the segment from n[4]to n[5]. 
		jj = 1+((j + n[4] -2) % ncity); 
		jorder[nn++] = iorder[jj]; 
	}
	 
	for( j = 1; j <= m3; ++j)
	{
		// Finally, the segment from n[6] to n[3]. 
		jj = 1+((j + n[6] -2) % ncity); 
		jorder[nn++] = iorder[jj]; 
	} 
	
	for( j = 1; j <= ncity; ++j)
	{
		// Copy jorder back into iorder. 
		iorder[j] = jorder[j];
	}
	
	free_ivector( jorder, 1, ncity ); 
}


/*
Metropolis algorithm. metrop returns a boolean variable that issues a verdict on whether 
to accept a reconﬁguration that leads to a changed e in the objective function e. If de < 0, 
metrop = 1(true), while if de > 0, metrop is only true with probability exp(-de/t), where 
t is a temperature determined by the annealing schedule. 
*/

NSInteger	metrop(CGFloat de, CGFloat t) 
{ 
#warning 64BIT: Inspect use of long
	static long gljdum = 1; 
	
	return de < 0.0 || ran3(&gljdum) < _CGFloatExp(-de/t); 
} 
 

