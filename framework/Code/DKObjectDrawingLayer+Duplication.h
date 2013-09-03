///**********************************************************************************************************************************
///  DKObjectDrawingLayer+Duplication.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 22/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKObjectDrawingLayer.h"


@interface DKObjectDrawingLayer (Duplication)

- (NSArray*)	polarDuplicate:(NSArray*) objectsToDuplicate
				centre:(NSPoint) centre
				numberOfCopies:(NSInteger) nCopies
				incrementAngle:(CGFloat) incRadians
				rotateCopies:(BOOL) rotCopies;
				
- (NSArray*)	linearDuplicate:(NSArray*) objectsToDuplicate
				offset:(NSSize) offset
				numberOfCopies:(NSInteger) nCopies;
				
- (NSArray*)	autoPolarDuplicate:(DKDrawableObject*) object
				centre:(NSPoint) centre;
				
- (NSArray*)	concentricDuplicate:(NSArray*) objectsToDuplicate
				centre:(NSPoint) centre
				numberOfCopies:(NSInteger) nCopies
				insetBy:(CGFloat) inset;
				

@end



/*

Some handy methods for implementing various kinds of object duplications.





*/
