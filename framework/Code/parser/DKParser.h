/**
 @author Jason Jobe
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU GPL3; see LICENSE
*/

#import <Foundation/Foundation.h>

#include "reader_g.tab.h"
#define SCOPE static
#include "reader_s.h"

@class DKExpression;

@interface DKParser : NSObject {
	Scanner scanr;
	NSMutableDictionary* mFactories;
	NSMutableArray* mParseStack;
	id mDelegate;

	// Formatters
	NSNumberFormatter* numberFormatter;

	// Processing flags
	BOOL throwErrorIfMissingFactory;
}

- (void)registerFactoryClass:(id)fClass forKey:(NSString*)key;

- (id)parseContentsOfFile:(NSString*)filename;
- (id)parseString:(NSString*)inString;

- (id)delegate;
- (void)setDelegate:(id)anObject;

// Settings
- (void)setThrowErrorIfMissingFactory:(BOOL)flag;
- (BOOL)willThrowErrorIfMissingFactory;

// Parser interface
- (id)currentToken;

- (NSArray*)parseStack;

- (void)push:(id)value;
- (id)pop;
- (id)instantiate:(NSString*)type;
- (void)setNodeValue:(id)value forKey:(NSString*)key;
- (void)addNode:(id)node;

@end

@interface DKParser (ParserDebugging)

- (void)setGrammarDebug:(BOOL)flag;

@end

@interface NSObject (DKParserProtocols)

- (id)initWithExpression:(DKExpression*)params;
- (id)instantiateObjectWithShortName:(NSString*)shortname parameters:(DKExpression*)dict;

@end

#define TK_NO_TOKEN (-1)
