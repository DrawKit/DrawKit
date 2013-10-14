/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

@class DKExpression;

@interface NSObject (GraphicsAttributes)

- (id)			initWithExpression:(DKExpression*) expr;
- (void)		setValue:(id) val forNumericParameter:(NSInteger) pnum;

- (NSImage*)	imageResourceNamed:(NSString*) name;

@end
