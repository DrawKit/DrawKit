//
//  DKEvaluator.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 2007-03-07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>


@class DKExpression;


@interface DKEvaluator : NSObject
{
	NSMutableDictionary*	mSymbolTable;
}


- (void)	addValue:(id) value forSymbol:(NSString*)symbol;

- (id)		evaluateSymbol:(NSString*) symbol;
- (id)		evaluateObject:(id) anObject;
- (id)		evaluateExpression:(DKExpression*) expr;
- (id)		evaluateSimpleExpression:(DKExpression*) expr;

@end
