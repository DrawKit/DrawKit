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

@interface DKEvaluator : NSObject {
	NSMutableDictionary* mSymbolTable;
}

- (void)addValue:(id)value forSymbol:(NSString*)symbol;

- (id)evaluateSymbol:(NSString*)symbol;
- (id)evaluateObject:(id)anObject;
- (id)evaluateExpression:(DKExpression*)expr;
- (id)evaluateSimpleExpression:(DKExpression*)expr;

@end
