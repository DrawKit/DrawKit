/**
 @author Jason Jobe
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@interface DKSymbol : NSString <NSCopying> {
	NSString* mString;
	NSInteger mIndex;
}

+ (NSMutableDictionary*)symbolMap;
+ (DKSymbol*)symbolForString:(NSString*)str;
+ (DKSymbol*)symbolForCString:(const char*)cstr length:(NSInteger)len;

- (id)initWithString:(NSString*)str index:(NSInteger)ndx;

- (NSInteger)index;
- (NSString*)string;

@end
