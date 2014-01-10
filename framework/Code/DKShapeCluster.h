/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKShapeGroup.h"

/** @brief A CLUSTER is a specialised form of group.

A CLUSTER is a specialised form of group. The idea is to allow a set of shapes to be associated with a main "master" object
around which the others are subordinated. Selecting the cluster selects the main object, but the subordinate objects
will be sized to match as needed.

One use for this is to allow automatic dimensioning of objects to work while the shape itself is edited - the shape itself is
the master and the dimensions are subordinate objects within the cluster. As the shape's size and angle change, the dimensions
adjust to match.

The main differences from a group are that when selected the main object acts as a proxy for the cluster as a whole, and the
cluster size and angle are controlled by the user's hits on the main object. Clusters need to be programatically created
since the master object must be nominated when creating the cluster.
*/
@interface DKShapeCluster : DKShapeGroup {
@private
    DKDrawableShape* m_masterObjRef;
}

/** @brief Creates a new cluster from a set of objects

 The master object must be also one of the objects in the list of objects, and must be a shape.
 @param objects the list of objects to be added to the cluster
 @param master the master object
 @return a new autoreleased cluster object, which should be added to a suitable drawing layer before use
 */
+ (DKShapeCluster*)clusterWithObjects:(NSArray*)objects masterObject:(DKDrawableShape*)master;

/** @brief Sets the master object for the cluster

 The master object must already be one of the objects in the group, and it must be a shape
 @param master the master object
 */
- (void)setMasterObject:(DKDrawableShape*)master;

/** @brief What is the cluster's master object?
 @return the master object for this cluster
 */
- (DKDrawableShape*)masterObject;

@end
