/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/** @brief This category allows \c -stringValue to be called on a broader range of objects than standard - in fact any object.

 This category allows \c -stringValue to be called on a broader range of objects than standard - in fact any object.

 The most useful is probably NSValue, since this will automatically use NSStringFromRect/Point/Size etc.
*/
@interface NSObject (StringValue)

@property (readonly, copy) NSString* stringValue;
@property (readonly, copy) NSString* address;

@end

@interface NSValue (StringValue)

@property (readonly, copy) NSString* stringValue;

@end

@interface NSColor (StringValue)

@property (readonly, copy) NSString* stringValue;

@end

@interface NSArray (StringValue)

@property (readonly, copy) NSString* stringValue;

@end

@interface NSDictionary (StringValue)

@property (readonly, copy) NSString* stringValue;

@end

@interface NSSet (StringValue)

@property (readonly, copy) NSString* stringValue;

@end

@interface NSString (StringValue)

@property (readonly, copy) NSString* stringValue;

@end

@interface NSDate (StringValue)

@property (readonly, copy) NSString* stringValue;

@end

NS_ASSUME_NONNULL_END
