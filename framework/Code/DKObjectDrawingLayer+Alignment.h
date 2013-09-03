///**********************************************************************************************************************************
///  DKObjectDrawingLayer+Alignment.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 18/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKObjectDrawingLayer.h"


@class DKGridLayer;


enum
{
	kDKAlignmentLeftEdge				= 0,
	kDKAlignmentTopEdge					= 1,
	kDKAlignmentRightEdge				= 2,
	kDKAlignmentBottomEdge				= 3,
	kDKAlignmentVerticalCentre			= 4,
	kDKAlignmentHorizontalCentre		= 5,
	kDKAlignmentVerticalDistribution	= 6,
	kDKAlignmentHorizontalDistribution  = 7,
	kDKAlignmentVSpaceDistribution		= 8,
	kDKAlignmentHSpaceDistribution		= 9,
	
	kDKAlignmentAlignLeftEdge			= ( 1 << kDKAlignmentLeftEdge ),
	kDKAlignmentAlignTopEdge			= ( 1 << kDKAlignmentTopEdge ),
	kDKAlignmentAlignRightEdge			= ( 1 << kDKAlignmentRightEdge ),
	kDKAlignmentAlignBottomEdge			= ( 1 << kDKAlignmentBottomEdge ),
	kDKAlignmentAlignVerticalCentre		= ( 1 << kDKAlignmentVerticalCentre ),
	kDKAlignmentAlignHorizontalCentre	= ( 1 << kDKAlignmentHorizontalCentre ),
	kDKAlignmentAlignVDistribution		= ( 1 << kDKAlignmentVerticalDistribution ),
	kDKAlignmentAlignHDistribution		= ( 1 << kDKAlignmentHorizontalDistribution ),
	kDKAlignmentAlignVSpaceDistribution = ( 1 << kDKAlignmentVSpaceDistribution ),
	kDKAlignmentAlignHSpaceDistribution = ( 1 << kDKAlignmentHSpaceDistribution ),
	
	kDKAlignmentAlignNone				= 0,
	kDKAlignmentAlignColocate			= kDKAlignmentAlignVerticalCentre | kDKAlignmentAlignHorizontalCentre,
	kDKAlignmentHorizontalAlignMask		= kDKAlignmentAlignLeftEdge | kDKAlignmentAlignRightEdge | kDKAlignmentAlignHorizontalCentre | kDKAlignmentAlignHDistribution | kDKAlignmentAlignHSpaceDistribution,
	kDKAlignmentVerticalAlignMask		= kDKAlignmentAlignTopEdge | kDKAlignmentAlignBottomEdge | kDKAlignmentAlignVerticalCentre | kDKAlignmentAlignVDistribution | kDKAlignmentAlignVSpaceDistribution,
	kDKAlignmentDistributionMask		= kDKAlignmentAlignVDistribution | kDKAlignmentAlignHDistribution | kDKAlignmentAlignVSpaceDistribution | kDKAlignmentAlignHSpaceDistribution
};


@interface DKObjectDrawingLayer (Alignment)

// setting the key object (used by alignment methods)

- (void)				setKeyObject:(DKDrawableObject*) keyObject;
- (DKDrawableObject*)	keyObject;


- (void)		alignObjects:(NSArray*) objects withAlignment:(NSInteger) align;
- (void)		alignObjects:(NSArray*) objects toMasterObject:(id) object withAlignment:(NSInteger) align;
- (void)		alignObjects:(NSArray*) objects toLocation:(NSPoint) loc withAlignment:(NSInteger) align;

- (void)		alignObjectEdges:(NSArray*) objects toGrid:(DKGridLayer*) grid;
- (void)		alignObjectLocation:(NSArray*) objects toGrid:(DKGridLayer*) grid;

- (CGFloat)		totalVerticalSpace:(NSArray*) objects;
- (CGFloat)		totalHorizontalSpace:(NSArray*) objects;

- (NSArray*)	objectsSortedByVerticalPosition:(NSArray*) objects;
- (NSArray*)	objectsSortedByHorizontalPosition:(NSArray*) objects;

- (BOOL)		distributeObjects:(NSArray*) objects withAlignment:(NSInteger) align;

- (NSUInteger)	alignmentMenuItemRequiredObjects:(id<NSValidatedUserInterfaceItem>) item;

// user actions:

- (IBAction)	alignLeftEdges:(id) sender;
- (IBAction)	alignRightEdges:(id) sender;
- (IBAction)	alignHorizontalCentres:(id) sender;

- (IBAction)	alignTopEdges:(id) sender;
- (IBAction)	alignBottomEdges:(id) sender;
- (IBAction)	alignVerticalCentres:(id) sender;

- (IBAction)	distributeVerticalCentres:(id) sender;
- (IBAction)	distributeVerticalSpace:(id) sender;

- (IBAction)	distributeHorizontalCentres:(id) sender;
- (IBAction)	distributeHorizontalSpace:(id) sender;

- (IBAction)	alignEdgesToGrid:(id) sender;
- (IBAction)	alignLocationToGrid:(id) sender;

- (IBAction)	assignKeyObject:(id) sender;

@end

// alignment helper function:

NSPoint		calculateAlignmentOffset( NSRect mr, NSRect sr, NSInteger alignment );

/*

 This category implements object alignment features for DKObjectDrawingLayer

*/
