/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Jason Jobe
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

@class DKExpression;

@interface NSColor (DKStyleExpressions)

+ (NSColor*)instantiateFromExpression:(DKExpression*)expr;
- (NSString*)styleScript;

@end

@interface NSShadow (DKStyleExpressions)

+ (NSShadow*)instantiateFromExpression:(DKExpression*)expr;
- (NSString*)styleScript;

@end
