/**
 @author Jason Jobe
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU LGPL3; see LICENSE
*/

#import "DKEvaluator.h"

@class DKParser;

@interface DKStyleReader : DKEvaluator {
	DKParser* mParser;
}

- (id)evaluateScript:(NSString*)script;
- (id)readContentsOfFile:(NSString*)filenamet;
- (void)loadBuiltinSymbols;

- (void)registerClass:(id)aClass withShortName:(NSString*)sym;

@end
