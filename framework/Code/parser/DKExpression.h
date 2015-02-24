/**
 @author Jason Jobe
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU GPL3; see LICENSE
*/

#import <Foundation/Foundation.h>

@interface DKExpression : NSObject {
	NSString* mType;
	NSMutableArray* mValues;
}

- (void)setType:(NSString*)aType;
- (NSString*)type;
- (BOOL)isSequence;
- (BOOL)isMethodCall;

- (BOOL)isLiteralValue;
- (NSInteger)argCount;

// The value methods dereference pairs if found

- (id)valueAtIndex:(NSInteger)ndx;
- (id)valueForKey:(NSString*)key;

// This method may return a key:value "pair"

- (id)objectAtIndex:(NSInteger)ndx;
- (void)replaceObjectAtIndex:(NSInteger)ndx withObject:(id)obj;

- (void)addObject:(id)aValue;
- (void)addObject:(id)aValue forKey:(NSString*)key;

- (void)applyKeyedValuesTo:(id)anObject;

- (NSString*)selectorFromKeys;

- (NSArray*)allKeys;
- (NSEnumerator*)keyEnumerator;
- (NSEnumerator*)objectEnumerator;

@end

@interface DKExpressionPair : NSObject {
	NSString* key;
	id value;
}

- (id)initWithKey:(NSString*)aKey value:(id)aValue;
- (NSString*)key;
- (id)value;
- (void)setValue:(id)val;

@end

@interface NSObject (DKExpressionSupport)

- (BOOL)isLiteralValue;

@end
