//
//  TestBSPStorage.m
//  GCDrawKit
//
//  Created by graham on 10/03/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "TestBSPStorage.h"


@interface DKBSPDirectObjectStorage (Private)

- (void)					sortObjectsByZ:(NSMutableArray*) objects;
- (void)					renumberObjectsFromIndex:(NSUInteger) indx;
- (void)					unmarkAll:(NSArray*) objects;
- (BOOL)					checkForTreeRebuild;
- (void)					loadBSPTree;

@end


@interface					DKBSPDirectTree (Private)
- (NSArray*) leaves;
@end

@interface					DKBSPIndexTree (Private)
- (NSArray*) leaves;
@end


static CGFloat randomFloat( CGFloat minVal, CGFloat maxVal )
{
	CGFloat rf = fmodf((CGFloat)random(), maxVal - minVal);
	
	return minVal + rf;
}


static NSUInteger randomUnsigned( NSUInteger minVal, NSUInteger maxVal )
{
	NSUInteger ru = ((NSUInteger)random() % (maxVal - minVal));
	
	return minVal + ru;
}


@implementation TestBSPStorage


#define NUMBER_OF_OBJECTS			300
#define	NUMBER_OF_RETRIEVAL_TESTS	24
#define	MOVE_OBJECTS_FOR_TEST_MOD	11
#define	NUMBER_OF_MAIN_TESTS		5
#define	MAX_OBJECT_SIZE				250

- (void)	testBSPStorage
{
	// unit test for the DKBSPDirectStorage object. This creates a standalone storage object, populates it with random objects, randomly adds, deletes and moves objects and verifies
	// the integrity of the storage system.
	
	NSLog(@"starting 'testBSPStorage'...");
	
	srandomdev();
	
	NSSize canvasSize = NSMakeSize( 2000, 2000 );
	
	DKBSPDirectObjectStorage* testStorage = [[DKBSPDirectObjectStorage alloc] init];
	
	[testStorage setCanvasSize:canvasSize];
	
	DKBSPDirectTree* tree = [testStorage tree];
	
	STAssertNotNil( tree, @"failed to create the internal tree instance");
	STAssertTrue( NSEqualSizes([tree canvasSize], canvasSize ), @"tree canvas size does not match set size (%@)", NSStringFromSize([tree canvasSize]));
	
	// populate with a fairly large number of initial random objects, whose bounds are assigned randomly but wrapped within the set canvas size.
	
	[self populateStorage:testStorage canvasSize:canvasSize];
	[self verifyStorageIntegrity:testStorage];
	
	NSUInteger v, u = NUMBER_OF_MAIN_TESTS;
	
	for( v = 0; v < u; ++v )
	{
#warning 64BIT: Check formatting arguments
		NSLog(@" =========  beginning main test loop, #%d =========", v );
		
		[self deletionTest:testStorage];
		[self verifyRenumbering:testStorage];
		[self verifyStorageIntegrity:testStorage];
		
		// insertion test - create another random 100 objects and insert them at random indexes
		
		[self insertionTest:testStorage canvasSize:canvasSize];
		[self verifyRenumbering:testStorage];
		[self verifyStorageIntegrity:testStorage];
		[self verifyIndexSpotcheck:testStorage];
		
		// next we test the retrieval of objects. To do this, we generate random rectangles and compare the results of a brute-force search for intersecting objects
		// with the result from the storage for the same rect. We expect the results to be the same.
		
		[self retrievalTest:testStorage canvasSize:canvasSize];
		[self verifyStorageIntegrity:testStorage];
		
		// test replacement
		
		[self replacementTest:testStorage canvasSize:canvasSize];
		[self verifyRenumbering:testStorage];
		[self verifyStorageIntegrity:testStorage];
		[self verifyIndexSpotcheck:testStorage];
		
		// more insertion
		
		[self insertionTest:testStorage canvasSize:canvasSize];
		[self verifyRenumbering:testStorage];
		[self verifyStorageIntegrity:testStorage];
		
		// reordering
		
		[self reorderingTest:testStorage];
		[self verifyRenumbering:testStorage];
		[self verifyStorageIntegrity:testStorage];
		[self verifyIndexSpotcheck:testStorage];
		
		// more deletion
		
		[self deletionTest:testStorage];
		[self verifyRenumbering:testStorage];
		[self verifyStorageIntegrity:testStorage];
		
		
		// more retrieval
		
		[self retrievalTest:testStorage canvasSize:canvasSize];
		
		// reorder again
		
		[self reorderingTest:testStorage];
		[self verifyRenumbering:testStorage];
		[self verifyStorageIntegrity:testStorage];
		
		// point retrieval
		
		[self pointRetrievalTest:testStorage canvasSize:canvasSize];
		[self verifyIndexSpotcheck:testStorage];
		[self verifyRenumbering:testStorage];
		[self verifyStorageIntegrity:testStorage];

		// change the tree depth on each iteration
		
		[testStorage setTreeDepth:10 + v];
	}
	
	[testStorage release];
	NSLog(@"testBSPStorage complete.");
}


- (void)	testIndexedBSPStorage
{
	NSLog(@"starting 'testIndexedBSPStorage'...");
	
	srandomdev();
	
	NSSize canvasSize = NSMakeSize( 2000, 2000 );
	
	DKBSPObjectStorage* testStorage = [[DKBSPObjectStorage alloc] init];
	
	[testStorage setCanvasSize:canvasSize];
	
	DKBSPIndexTree* tree = [testStorage tree];
	
	STAssertNotNil( tree, @"failed to create the internal tree instance");
	STAssertTrue( NSEqualSizes([tree canvasSize], canvasSize ), @"tree canvas size does not match set size (%@)", NSStringFromSize([tree canvasSize]));
	
	// populate with a fairly large number of initial random objects, whose bounds are assigned randomly but wrapped within the set canvas size.
	
	[self populateStorage:testStorage canvasSize:canvasSize];
	[self verifyIndexedStorageIntegrity:testStorage];
	
	NSUInteger v, u = NUMBER_OF_MAIN_TESTS;
	
	for( v = 0; v < u; ++v )
	{
#warning 64BIT: Check formatting arguments
		NSLog(@" =========  beginning main test loop, #%d =========", v );
		
		[self deletionTest:testStorage];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// insertion test - create another random 100 objects and insert them at random indexes
		
		[self insertionTest:testStorage canvasSize:canvasSize];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// next we test the retrieval of objects. To do this, we generate random rectangles and compare the results of a brute-force search for intersecting objects
		// with the result from the storage for the same rect. We expect the results to be the same.
		
		[self retrievalTest:testStorage canvasSize:canvasSize];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// test replacement
		
		[self replacementTest:testStorage canvasSize:canvasSize];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// more insertion
		
		[self insertionTest:testStorage canvasSize:canvasSize];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// reordering
		
		[self reorderingTest:testStorage];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// more deletion
		
		[self deletionTest:testStorage];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// more retrieval
		
		[self retrievalTest:testStorage canvasSize:canvasSize];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// reorder again
		
		[self reorderingTest:testStorage];
		[self verifyIndexedStorageIntegrity:testStorage];
		
		// point retrieval
		
		[self pointRetrievalTest:testStorage canvasSize:canvasSize];
		[self verifyIndexedStorageIntegrity:testStorage];
	}
	
	[testStorage release];
	NSLog(@"testIndexedBSPStorage complete.");
}


- (void)	populateStorage:(id<DKObjectStorage>) storage canvasSize:(NSSize) canvasSize
{
	NSUInteger	i, m = NUMBER_OF_OBJECTS;
	NSRect		br;
	CGFloat		t, l, w, h;
	testStorableObject* tso;
	
	for( i = 0; i < m; ++i )
	{
		l = randomFloat( 0, canvasSize.width );
		t = randomFloat( 0, canvasSize.height );
		w = randomFloat( 1, MAX_OBJECT_SIZE );
		h = randomFloat( 1, MAX_OBJECT_SIZE );
		
		br = NSMakeRect( l, t, w, h );
		
		tso = [[testStorableObject alloc] init];
		[tso setBounds:br];
		
		[storage insertObject:tso inObjectsAtIndex:i];
		[tso release];
		
		STAssertEqualObjects([tso storage], storage, @"storage back pointer was not correctly assigned");
		
		if([storage isKindOfClass:[DKBSPDirectObjectStorage class]])
			STAssertEquals([tso index], i, @"storage index was incorrectly assigned (should be %d, was %d)", i, [tso index]);
	}
	
	STAssertEquals([storage countOfObjects], m, @"total number of objects stored was mismatched (was %d, should be %d)", [storage countOfObjects], m );
	
#warning 64BIT: Check formatting arguments
	NSLog(@"%d objects added to storage", m );
}


- (void)	deletionTest:(id<DKObjectStorage>) storage
{
	NSMutableIndexSet* remIndexSet = [[NSMutableIndexSet alloc] init];
	NSUInteger i, m;
	
	m = [storage countOfObjects];
	
	for( i = 0; i < ( m / 3 ); ++i )
	{
		NSUInteger ix = randomUnsigned( 0, m );
		[remIndexSet addIndex:ix];
	}
	
	NSLog(@"deletion test with indexes: %@", remIndexSet);
	
	NSUInteger numberToDelete = [remIndexSet count];
	[storage removeObjectsAtIndexes:remIndexSet];
	
	STAssertEquals([storage countOfObjects], m - numberToDelete, @"deletion failed - number of objects remaining = %d, should be %d", [storage countOfObjects], m - numberToDelete );
	
	[remIndexSet release];
}


- (void)	insertionTest:(id<DKObjectStorage>) storage canvasSize:(NSSize) canvasSize
{
	NSMutableIndexSet*		remIndexSet = [[NSMutableIndexSet alloc] init];
	NSMutableArray*			insertObjects = [[NSMutableArray alloc] init];
	testStorableObject*		tso;
	CGFloat					t, l, w, h;
	
	NSUInteger i, m, numIndexes = 0;
	m = [storage countOfObjects];
	
	for( i = 0; i < ( m / 3); ++i )
	{
		NSUInteger ix = randomUnsigned( 0, m );
		[remIndexSet addIndex:ix];
		
		// indexes are assigned randomly so may not cause a change to the # of indexes - only add an object if a new index was added
		
		if([remIndexSet count] == numIndexes + 1)
		{
			numIndexes = [remIndexSet count];
			
			l = randomFloat( 0, canvasSize.width );
			t = randomFloat( 0, canvasSize.height );
			w = randomFloat( 1, MAX_OBJECT_SIZE );
			h = randomFloat( 1, MAX_OBJECT_SIZE );
			
			NSRect br = NSMakeRect( l, t, w, h );
			
			tso = [[testStorableObject alloc] init];
			[tso setBounds:br];
			
			[insertObjects addObject:tso];
			[tso release];
		}
	}
	
#warning 64BIT: Check formatting arguments
	NSLog(@"insertion test, %d objects with indexes: %@", [insertObjects count], remIndexSet);
	[storage insertObjects:insertObjects atIndexes:remIndexSet];
	
	m += [insertObjects count];
	[insertObjects release];
	
	STAssertEquals( m, [storage countOfObjects], @"count of objects mismatched, expected %d, got %d", m, [storage countOfObjects]);
	
	[remIndexSet release];
}



- (void)	replacementTest:(id<DKObjectStorage>) storage canvasSize:(NSSize) canvasSize
{
	NSLog(@"starting replacement test...");
	
	testStorableObject*		tso;
	testStorableObject*		orig;
	CGFloat					t, l, w, h;
	
	NSUInteger i, m;
	m = [storage countOfObjects];
	
	for( i = 0; i < ( m / 3); ++i )
	{
		NSUInteger ix = randomUnsigned( 0, m );
			
		l = randomFloat( 0, canvasSize.width );
		t = randomFloat( 0, canvasSize.height );
		w = randomFloat( 1, MAX_OBJECT_SIZE );
		h = randomFloat( 1, MAX_OBJECT_SIZE );
		
		NSRect br = NSMakeRect( l, t, w, h );
		
		tso = [[testStorableObject alloc] init];
		[tso setBounds:br];
		
		orig = [[storage objectInObjectsAtIndex:ix] retain];
		[storage replaceObjectInObjectsAtIndex:ix withObject:tso];
		
		if([storage isKindOfClass:[DKBSPDirectObjectStorage class]])
		{
			STAssertEquals([orig index], [tso index], @"replacement object index mismatch, expected %d, got %d", [orig index], [tso index]);
			STAssertEquals(ix, [tso index], @"replacement object index mismatch, expected %d, got %d", ix, [tso index]);
		}
		
		STAssertEqualObjects([tso storage], storage, @"storage back-pointer incorrect after replacement (%@)", [tso storage] );
		STAssertNil([orig storage], @"replaced object does not have a nil back-pointer");
		
		[orig release];
		[tso release];
	}
}



- (void)	retrievalTest:(id<DKObjectStorage>) storage canvasSize:(NSSize) canvasSize
{
	NSArray*				objects = [storage objects], *bspResults;
	NSMutableArray*			bruteForceSearchResults = [[NSMutableArray alloc] init];
	testStorableObject*		tso;
	NSUInteger				i;
	CGFloat					t, l, w, h;
	NSRect					retrievalRect;
	
	for( i = 0; i < NUMBER_OF_RETRIEVAL_TESTS; ++i )
	{
		NSAutoreleasePool* pool = [NSAutoreleasePool new];
		
		l = randomFloat( 0, canvasSize.width );
		t = randomFloat( 0, canvasSize.height );
		w = randomFloat( 0, canvasSize.width / 2 );
		h = randomFloat( 0, canvasSize.height / 2 );
		retrievalRect = NSMakeRect( l, t, w, h );
		
		// ensure the retrieval rect stays within the bounds of the canvas
		
		retrievalRect = NSIntersectionRect( retrievalRect, NSMakeRect( 0, 0, canvasSize.width, canvasSize.height ));
		
#warning 64BIT: Check formatting arguments
		NSLog(@"retrieval test %d, rect = %@", i, NSStringFromRect( retrievalRect ));
		
		// move some of the objects to random new locations for some of the tests

		if(( i % MOVE_OBJECTS_FOR_TEST_MOD ) == 0 && i > 0)
		{
#warning 64BIT: Check formatting arguments
			NSLog(@"repositioning objects for test #%d", i );
			[self repositioningTest:storage canvasSize:canvasSize];
		}

		[bruteForceSearchResults removeAllObjects];
		
		// do the brute force search first. These should be in the right z-order.
		
		NSEnumerator* iter = [objects objectEnumerator];
		while(( tso = [iter nextObject]))
		{
			if( NSIntersectsRect( retrievalRect, [tso bounds]))
				[bruteForceSearchResults addObject:tso];
		}
		
		// retrieve what should be the same objects the clever way:
		
		bspResults = [storage objectsIntersectingRect:retrievalRect inView:nil options:0];
		
		// now check they are what they should be:
		
		STAssertEquals([bspResults count], [bruteForceSearchResults count], @"object counts do not match, brute force = %d, bsp = %d", [bruteForceSearchResults count], [bspResults count]);
		
		// check each object is the same
		
		NSUInteger j, k = [bspResults count];
		
		for( j = 0; j < k; ++j )
		{
			id<DKStorableObject> bruteObject;
			
			bruteObject = [bruteForceSearchResults objectAtIndex:j];
			tso = [bspResults objectAtIndex:j];
			
			STAssertEqualObjects( bruteObject, tso, @"objects at index %d do not match - bf = %@, bsp = %@", j, bruteObject, tso );
			STAssertFalse([tso isMarked], @"retrieved object still has marked flag set, index = %d", j );
		}
		
		[pool drain];
	}
	
	// a final retrieval test - if the retrieval rect is the whole canvas, number returned should equal entire object count
	
	retrievalRect = NSMakeRect( 0, 0, canvasSize.width, canvasSize.height );
	
	bspResults = [storage objectsIntersectingRect:retrievalRect inView:nil options:0];
	STAssertEquals([bspResults count], [objects count], @"object count mismatched when retrieving using the whole canvas size (expected %d, got %d)", [objects count], [bspResults count]);
	
	[bruteForceSearchResults release];
}


- (void)	pointRetrievalTest:(id<DKObjectStorage>) storage canvasSize:(NSSize) canvasSize
{
	NSArray*				objects = [storage objects];
	NSMutableArray*			bruteForceSearchResults = [[NSMutableArray alloc] init];
	testStorableObject*		tso;
	NSUInteger				i;
	CGFloat					t, l;
	
	for( i = 0; i < NUMBER_OF_RETRIEVAL_TESTS; ++i )
	{
		NSAutoreleasePool* pool = [NSAutoreleasePool new];
		
		l = randomFloat( 0, canvasSize.width );
		t = randomFloat( 0, canvasSize.height );
		NSPoint retrievalPoint = NSMakePoint( l, t );
		
#warning 64BIT: Check formatting arguments
		NSLog(@"point retrieval test %d, pt = %@", i, NSStringFromPoint( retrievalPoint ));
		
		// move some of the objects to random new locations for some of the tests
		
		if(( i % MOVE_OBJECTS_FOR_TEST_MOD ) == 0 && i > 0)
		{
#warning 64BIT: Check formatting arguments
			NSLog(@"repositioning objects for test #%d", i );
			[self repositioningTest:storage canvasSize:canvasSize];
		}
		
		[bruteForceSearchResults removeAllObjects];
		
		// do the brute force search first. These should be in the right z-order.
		
		NSEnumerator* iter = [objects objectEnumerator];
		while(( tso = [iter nextObject]))
		{
			if( NSPointInRect( retrievalPoint, [tso bounds]))
				[bruteForceSearchResults addObject:tso];
		}
		
		// retrieve what should be the same objects the clever way:
		
		NSArray* bspResults = [storage objectsContainingPoint:retrievalPoint];
		
		// now check they are what they should be:
		
		STAssertEquals([bspResults count], [bruteForceSearchResults count], @"object counts do not match, brute force = %d, bsp = %d", [bruteForceSearchResults count], [bspResults count]);
		
		// check each object is the same
		
		NSUInteger j, k = [bspResults count];
		
		for( j = 0; j < k; ++j )
		{
			id<DKStorableObject> bruteObject;
			
			bruteObject = [bruteForceSearchResults objectAtIndex:j];
			tso = [bspResults objectAtIndex:j];
			
			STAssertEqualObjects( bruteObject, tso, @"objects at index %d do not match - bf = %@, bsp = %@", j, bruteObject, tso );
			STAssertFalse([tso isMarked], @"retrieved object still has marked flag set, index = %d", j );
		}
		
		[pool drain];
	}
	
	[bruteForceSearchResults release];
}



- (void)	repositioningTest:(id<DKObjectStorage>) storage canvasSize:(NSSize) canvasSize
{
	NSArray* objects = [storage objects];
	NSUInteger r, s = [objects count];
	CGFloat	l, t, w, h;
	testStorableObject* tso;
	
	for( r = 0; r < s; ++r )
	{
		NSRect newBounds;
		
		l = randomFloat( 0, canvasSize.width );
		t = randomFloat( 0, canvasSize.height );
		w = randomFloat( 1, MAX_OBJECT_SIZE );
		h = randomFloat( 1, MAX_OBJECT_SIZE );
		
		newBounds = NSMakeRect( l, t, w, h );
		
		if( !NSIsEmptyRect(newBounds ))
		{
			tso = [objects objectAtIndex:r];
			
			if([storage isKindOfClass:[DKBSPDirectObjectStorage class]])
				STAssertEquals([tso index], r, @"before repositioning index was incorrect - expected %d, got %d (%@)", r, [tso index], tso);
			
			[tso setBounds:newBounds];
			
			if([storage isKindOfClass:[DKBSPDirectObjectStorage class]])
				STAssertEquals([tso index], r, @"after repositioning index was incorrect - expected %d, got %d", r, [tso index]);

			STAssertEqualObjects([tso storage], storage, @"after repositioning storage was incorrect, got %@", [tso storage]);
			STAssertTrue(NSEqualRects( newBounds, [tso bounds]), @"bounds mismatch, should be %@", NSStringFromRect( newBounds ));
		}
	}
}


- (void)	reorderingTest:(id<DKObjectStorage>) storage
{
	// changes the order of a random selection of objects and verifies the indexing.
	
	NSMutableIndexSet* srcIndexes = [[NSMutableIndexSet alloc] init];
	NSMutableIndexSet* destIndexes = [[NSMutableIndexSet alloc] init];
	testStorableObject* tso;
	NSUInteger i, m, ix, dx;
	
	m = [storage countOfObjects];
	
	for( i = 0; i < ( m / 4 ); ++i )
	{
		ix = randomUnsigned( 0, m );
		[srcIndexes addIndex:ix];

		ix = randomUnsigned( 0, m );
		[destIndexes addIndex:ix];
	}
	
	m = MIN([srcIndexes count], [destIndexes count]);
	
#warning 64BIT: Check formatting arguments
	NSLog(@"performing reordering test (%d objects). Src indexes = %@", m, srcIndexes);

	ix = [srcIndexes firstIndex];
	dx = [destIndexes firstIndex];
	
	for( i = 0; i < m; ++i )
	{
		tso = [storage objectInObjectsAtIndex:ix];
		
		if([storage isKindOfClass:[DKBSPDirectObjectStorage class]])
			STAssertEquals([tso index], ix, @"object index was incorrect before reordering - expected %d, was %d (%@)", ix, [tso index], tso);
		
		[storage moveObject:tso toIndex:dx];
		
		if([storage isKindOfClass:[DKBSPDirectObjectStorage class]])
			STAssertEquals([tso index], dx, @"object index was incorrect after reordering - expected %d, was %d (original = %d, %@)", dx, [tso index], ix, tso);
		
		ix = [srcIndexes indexGreaterThanIndex:ix];
		dx = [destIndexes indexGreaterThanIndex:dx];
	}
	
	[srcIndexes release];
	[destIndexes release];
}


#pragma mark -


- (void)	verifyRenumbering:(DKBSPDirectObjectStorage*) storage
{
	NSLog(@"checking renumbering...");
	
	testStorableObject* tso;
	NSUInteger i, m = [storage countOfObjects];
	
	for( i = 0; i < m; ++i )
	{
		tso = [storage objectInObjectsAtIndex:i];
		
		STAssertEquals([tso index], i, @"renumbering error - index = %d, stored index = %d", i, [tso index]);
	}
}


- (void)	verifyStorageIntegrity:(DKBSPDirectObjectStorage*) storage
{
	// this examines objects in the linear array and the tree's internal storage and checks that there is no object in one that is not in the other.
	
	NSLog(@"checking storage integrity...");
	
	NSEnumerator*			iter = [[storage objects] objectEnumerator];
	testStorableObject*		tso;
	NSArray*				leafArray, *leaves = [[storage tree] leaves];
	NSUInteger				foundCount = 0;
	
	while(( tso = [iter nextObject]))
	{
		NSAutoreleasePool* pool = [NSAutoreleasePool new];
		NSEnumerator*		leafEnum = [leaves objectEnumerator];
		
		while(( leafArray = [leafEnum nextObject]))
		{
			if([leafArray containsObject:tso])
			{
				foundCount++;
				break;
			}
		}
		STAssertNotNil([tso storage], @"a storage back-pointer was nil (%@)", tso );
		STAssertEqualObjects([tso storage], storage, @"a storage back-pointer wasn't pointing to the storage (%@)", tso);
		
		[pool drain];
	}
	
	STAssertEquals( foundCount, [storage countOfObjects], @"number of objects in tree is not equal to number in linear storage, expected %d, got %d", [storage countOfObjects], foundCount );
	
	// if not equal, try and find out where the problem is...
	
	if( foundCount != [storage countOfObjects])
	{
		iter = [[storage objects] objectEnumerator];
		NSUInteger	linIndex = 0;

		while(( tso = [iter nextObject]))
		{
			NSAutoreleasePool* pool = [NSAutoreleasePool new];

			NSEnumerator*		leafEnum = [leaves objectEnumerator];
			BOOL				found = NO;
			
			while(( leafArray = [leafEnum nextObject]))
			{
				if([leafArray containsObject:tso])
				{
					found = YES;
					break;
				}
			}
			
			[pool drain];
			
			if( !found )
			{
#warning 64BIT: Check formatting arguments
				NSLog(@"first object not found in tree is: %@ (index = %d, bounds = %@, array index = %d)", tso, [tso index], NSStringFromRect([tso bounds]), linIndex );
				break;
			}
			
			++linIndex;
		}
	}
	
	// now perform the inverse test, which checks that every object in <leaves> is present in the main array
	
	foundCount = 0;
	
	iter = [leaves objectEnumerator];
	while(( leafArray = [iter nextObject]))
	{
		NSAutoreleasePool* pool = [NSAutoreleasePool new];
		
		NSEnumerator* leafIter = [leafArray objectEnumerator];
		while(( tso = [leafIter nextObject]))
		{
			STAssertTrue([[storage objects] containsObject:tso], @"an object was present in the tree but not in the linear array: %@ (leaf index = %d)", tso, foundCount );
			STAssertNotNil([tso storage], @"a storage back-pointer was nil (%@)", tso );
			STAssertEquals([tso storage], storage, @"a storage back-pointer wasn't pointing to the storage");
		}
		++foundCount;
		
		[pool drain];
	}
}


- (void)	verifyIndexSpotcheck:(DKBSPDirectObjectStorage*) storage
{
	NSLog(@"performing index spot-check...");
	
	// generates random indexes, retrives those objects and chacks that their indexes match
	
	NSMutableIndexSet* remIndexSet = [[NSMutableIndexSet alloc] init];
	NSUInteger i, m, ix;
	
	m = [storage countOfObjects];
	
	for( i = 0; i < ( m / 5 ); ++i )
	{
		ix = randomUnsigned( 0, m );
		[remIndexSet addIndex:ix];
	}
	
	NSLog(@"spotcheck with indexes: %@", remIndexSet);
	
	NSArray* objects = [storage objectsAtIndexes:remIndexSet];
	ix = [remIndexSet firstIndex];
	testStorableObject* tso;
	
	for( i = 0; i < [objects count]; ++i )
	{
		tso = [objects objectAtIndex:i];
		
		STAssertEquals([tso index], ix, @"mismatch of object index in spotcheck, expected %d, got %d (%@)", ix, [tso index], tso );
		
		ix = [remIndexSet indexGreaterThanIndex:ix];
	}
	
	[remIndexSet release];
}



- (void)	verifyIndexedStorageIntegrity:(DKBSPObjectStorage*) storage
{
	// for indexed storage, this checks that all indexes in the tree are in range
	
	DKBSPIndexTree*		tree = [storage tree];
	NSArray*			leaves = [tree leaves];
	NSIndexSet*			leaf;
	NSArray*			objs = [storage objects];
	NSMutableIndexSet*	allIndexes = [[NSMutableIndexSet alloc] init];
	NSUInteger			minIndex, maxIndex;
	
	NSEnumerator*	iter = [leaves objectEnumerator];
	while(( leaf = [iter nextObject]))
	{
		minIndex = [leaf firstIndex];
		maxIndex = [leaf lastIndex];
		
		if( minIndex != NSNotFound )
			STAssertTrue( minIndex < [objs count], @"a leaf index is out of range. Index = %d", minIndex );
		
		if( maxIndex != NSNotFound )
			STAssertTrue( maxIndex < [objs count], @"a leaf index is out of range. Index = %d", maxIndex );
		
		[allIndexes addIndexes:leaf];
	}
	
	// allIndexes should have every index that is present in the main array
	
	minIndex = [allIndexes firstIndex];
	maxIndex = [allIndexes lastIndex];
	
	if([objs count] > 0 )
	{
		STAssertEquals( minIndex, 0U, @"the lowest index in the tree is not 0");
		STAssertEquals( maxIndex, [objs count] - 1, @"the highest index in the tree is not the count -1");
	}
}


@end



#pragma mark -


@implementation testStorableObject

- (id<DKObjectStorage>)		storage
{
	return _storage;
}


- (void)					setStorage:(id<DKObjectStorage>) storage
{
	_storage = storage;
}



- (NSUInteger)				index
{
	return _index;
}


- (void)					setIndex:(NSUInteger) indx
{
	_index = indx;
}



- (void)					setMarked:(BOOL) markIt
{
	_marked = markIt;
}


- (BOOL)					isMarked
{
	return _marked;
}

- (BOOL)					visible
{
	return YES;
}


- (NSRect)					bounds
{
	return _bounds;
}


- (void)					setBounds:(NSRect) newBounds
{
	if( ! NSEqualRects([self bounds], newBounds))
	{
		NSRect oldBounds = [self bounds];
		_bounds = newBounds;
		[[self storage] object:self didChangeBoundsFrom:oldBounds];
	}
}

- (id)						initWithCoder:(NSCoder*) coder
{
#pragma unused(coder)
	return self;
}


- (void)					encodeWithCoder:(NSCoder*) coder
{
#pragma unused(coder)
}


- (id)						copyWithZone:(NSZone*) zone
{
	testStorableObject* copy = [[[self class] allocWithZone:zone] init];
	
	[copy setBounds:[self bounds]];
	return copy;
}

@end

#pragma mark -


@implementation					DKBSPDirectTree (Private)

- (NSArray*) leaves
{
	return mLeaves;
}

@end



@implementation					DKBSPIndexTree (Private)

- (NSArray*) leaves
{
	return mLeaves;
}

@end


