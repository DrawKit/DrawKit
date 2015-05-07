/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU LGPL3; see LICENSE
*/

#import <Cocoa/Cocoa.h>

@class DKExpression;

@interface NSObject (GraphicsAttributes)

- (id)initWithExpression:(DKExpression*)expr;
- (void)setValue:(id)val forNumericParameter:(NSInteger)pnum;

- (NSImage*)imageResourceNamed:(NSString*)name;

@end
