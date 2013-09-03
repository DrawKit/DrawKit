//
//  DKStyleReader.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 3/16/07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKEvaluator.h"


@class DKParser;


@interface DKStyleReader : DKEvaluator
{
	DKParser*	mParser;
}

- (id)			evaluateScript:(NSString*) script;
- (id)			readContentsOfFile:(NSString*) filenamet;
- (void)		loadBuiltinSymbols;

- (void)		registerClass:(id) aClass withShortName:(NSString*) sym;

@end
