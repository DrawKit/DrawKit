/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Jason Jobe
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
