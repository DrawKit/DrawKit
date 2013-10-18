/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Jason Jobe
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

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
