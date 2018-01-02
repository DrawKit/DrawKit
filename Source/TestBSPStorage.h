/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <XCTest/XCTest.h>
#import <DKDrawKit/DKBSPDirectObjectStorage.h>

/** @brief Unit Test for the BSP storage sub-system.

Unit Test for the BSP storage sub-system. This works by populating a storage instance with dummy objects (instances of testStorableObject) then randomly operating on them.
 The objects are randomly deleted, inserted, moved, reordered and retrieved many times. If any problems with the storage exist this should throw light on it.
 
 The dummy objects conform to the storable protocol as they are required to do but otherwise merely store their parameters. This ensures that the tests here truly apply to the
 storage, and not to real storable objects. Other unit tests may test real storables in isolation.
*/
@interface TestBSPStorage : XCTestCase

/** unit test for the \c DKBSPDirectStorage object. This creates a standalone storage object, populates it with random objects, randomly adds, deletes and moves objects and verifies
 the integrity of the storage system.
 */
- (void)testBSPStorage;
- (void)testIndexedBSPStorage;

- (void)populateStorage:(id<DKObjectStorage>)storage canvasSize:(NSSize)canvasSize;
- (void)deletionTest:(id<DKObjectStorage>)storage;
- (void)insertionTest:(id<DKObjectStorage>)storage canvasSize:(NSSize)canvasSize;
- (void)replacementTest:(id<DKObjectStorage>)storage canvasSize:(NSSize)canvasSize;
- (void)retrievalTest:(id<DKObjectStorage>)storage canvasSize:(NSSize)canvasSize;
- (void)pointRetrievalTest:(id<DKObjectStorage>)storage canvasSize:(NSSize)canvasSize;
- (void)repositioningTest:(id<DKObjectStorage>)storage canvasSize:(NSSize)canvasSize;
- (void)reorderingTest:(id<DKObjectStorage>)storage;

- (void)verifyRenumbering:(DKBSPDirectObjectStorage*)storage;
- (void)verifyStorageIntegrity:(DKBSPDirectObjectStorage*)storage;
- (void)verifyIndexSpotcheck:(DKBSPDirectObjectStorage*)storage;

- (void)verifyIndexedStorageIntegrity:(DKBSPObjectStorage*)storage;

@end

@interface testStorableObject : NSObject <DKStorableObject> {
	NSRect _bounds;
	NSUInteger _index;
	BOOL _marked;
	id<DKObjectStorage> _storage;
}

- (void)setBounds:(NSRect)newBounds;

@end
