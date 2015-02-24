/**
 @author Jason Jobe
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU GPL3; see LICENSE
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
