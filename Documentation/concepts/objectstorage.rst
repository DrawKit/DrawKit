Object Storage
==============

`DKObjectOwnerLayer` abstracts the actual storage of the drawables it owns into a further class, based on the `DKObjectStorage` formal protocol. Concrete objects that implement this protocol currently are `DKLinearObjectStorage` and `DKBSPObjectStorage`. The storage abstraction is entirely transparent to applications, but the ability to use different types of storage can have useful advantages for the programmer.

The storage class for new instances of `DKObjectOwnerLayer` can be set using +setStorageClass: The default is `DKLInearObjectStorage`.

The layer will return, on demand, a list of objects to be drawn based on a rect or a view needing update. This list is built by the storage using whatever internal algorithm it implements. The result is always the same - a list of objects to be drawn, in bottom-to-top order.

`DKLinearObjectStorage`
-----------------------

Linear storage is very simple and reliable - all objects are simply kept in a single list (array). Such an array strictly defines the back-to-front ordering of objects (Z-ordering). For many uses, linear storage is entirely adequate, providing good performance up to a few hundred objects per layer. Conceptually, the indexed nature of linear storage is what all storage "looks like" to client code (such as `DKObjectOwnerLayer`).

`DKBSPObjectStorage`
--------------------

The drawback of linear storage starts to become noticeable when the data sets become much larger than a few hundred objects. While DrawKit always avoids drawing objects that it doesn't need to draw by carefully using `NSView`'s update rects mechanism, when data sets are large there is still the issue of having to iterate over the entire objects list to determine which objects should be drawn.

BSP (Binary Search Partition) Storage improves performance on larger data sets by avoiding the need to iterate all objects to find those that need to be drawn. BSP storage uses a tree structure which conceptually repeatedly subdivides the overall drawing space into smaller and smaller binary partitions. When an area needs updating, the tree is used to rapidly determine which partitions and hence which objects are affected. Thus while the returned list of objects to be drawn is the same as for the linear storage, the time to build that list can be much less. In theory data sets having hundreds of thousands of objects should be possible, and performance will only be dictated by the objects that are currently visible.

`DKBSPObjectStorage` subclasses `DKLinearObjectStorage` so objects are still stored in a single array, but the BSP tree is used to efficiently index it on a spatial basis. Z-ordering is thus strictly defined as for the linear case. DK's implementation dynamically sizes the BSP Tree as needed to maintain efficiency as objects are added and removed, though the programmer has the option to set a fixed-size tree if they wish (Note - a fixed-size tree can still store any number of objects, but efficiency may decline if the number of objects greatly exceeds the optimal tree depth).

`DKRStarTreeObjectStorage`
--------------------------

R\*-Trees are another way to spatially index objects to improve efficiency when dealing with very large data sets. R\*-Trees are able to efficiently store millions of objects. This class is currently under development.