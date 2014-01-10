/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "NSMutableArray+DKAdditions.h"

@implementation NSMutableArray (DKAdditions)

/** 
 */
- (void)addUniqueObjectsFromArray:(NSArray*)array
{
    // adds objects from <array> to the receiver, but only those not already contained by it

    NSEnumerator* iter = [array objectEnumerator];
    id obj;

    while ((obj = [iter nextObject])) {
        if (![self containsObject:obj])
            [self addObject:obj];
    }
}

@end
