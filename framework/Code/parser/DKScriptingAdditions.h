//
//  DKScriptingAdditions.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 3/16/07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>

@class DKExpression;


@interface NSColor (DKStyleExpressions)

+ (NSColor*)	instantiateFromExpression:(DKExpression*)expr;
- (NSString*)	styleScript;

@end

@interface NSShadow (DKStyleExpressions)

+ (NSShadow*)	instantiateFromExpression:(DKExpression*) expr;
- (NSString*)	styleScript;

@end
