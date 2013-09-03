//
//  DKSymbol.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 4/25/05.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>


@interface DKSymbol : NSString <NSCopying>
{
    NSString*		mString;
    NSInteger				mIndex;
}

+ (NSMutableDictionary*)	symbolMap;
+ (DKSymbol*)				symbolForString:(NSString*) str;
+ (DKSymbol*)				symbolForCString:(const char*) cstr length:(NSInteger) len;

- (id)						initWithString:(NSString*) str index:(NSInteger) ndx;

-(NSInteger)						index;
-(NSString*)				string;

@end
