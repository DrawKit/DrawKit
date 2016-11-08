/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKObjectStorageProtocol.h"

/** @brief Basic storage class stores objects in a standard array.

Basic storage class stores objects in a standard array. For many uses this will be entirely adequate, but may be substituted for scalability or
 special uses.
 
 Note regarding NSCoding: currently the storage itself is no longer archived - only its objects are. The storage class is selected at runtime. However for
 a brief period (beta 5), the storage was archived. To support files written at that time, this class and its derivatives currently support NSCoding (for reading)
 so that the files can be correctly dearchived. Re-saving the files will update to the new approach. Archiving of the storage isn't curremtly done, and attempting to
 archive will throw an exception.
*/
@interface DKLinearObjectStorage : NSObject <DKObjectStorage, NSCoding> {
@private
	NSMutableArray* mObjects;
}

@end
