/**
 @author Jason Jobe
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
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
