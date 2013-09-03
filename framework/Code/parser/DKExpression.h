//*******************************************************************************************
//  DKExpression.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 1/28/07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//
//*******************************************************************************************/

#import <Foundation/Foundation.h>


@interface DKExpression : NSObject
{
	NSString*		mType;
	NSMutableArray* mValues;
}

- (void)			setType:(NSString*) aType;
- (NSString*)		type;
- (BOOL)			isSequence;
- (BOOL)			isMethodCall;

- (BOOL)			isLiteralValue;
- (NSInteger)				argCount;

// The value methods dereference pairs if found

- (id)				valueAtIndex:(NSInteger) ndx;
- (id)				valueForKey:(NSString*)key;

// This method may return a key:value "pair"

- (id)				objectAtIndex:(NSInteger) ndx;
- (void)			replaceObjectAtIndex:(NSInteger) ndx withObject:(id) obj;

- (void)			addObject:(id) aValue;
- (void)			addObject:(id) aValue forKey:(NSString*) key;

- (void)			applyKeyedValuesTo:(id) anObject;

- (NSString*)		selectorFromKeys;

- (NSArray*)        allKeys;
- (NSEnumerator*)   keyEnumerator;
- (NSEnumerator*)   objectEnumerator;

@end


@interface DKExpressionPair : NSObject
{
	NSString*		key;
	id				value;
}

- (id)				initWithKey:(NSString*) aKey value:(id) aValue;
- (NSString*)		key;
- (id)				value;
- (void)			setValue:(id) val;

@end


@interface NSObject (DKExpressionSupport)

- (BOOL)			isLiteralValue;

@end

