///**********************************************************************************************************************************
///  DKColourQuantizer.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 25/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>


// generic interface and simple quantizer which performs uniform quantization. Results with this quantizer are generally only
// barely acceptable - colours may be mapped to something grossly different from the original since this does not take any notice of
// the pixels actually used in the image, only the basic size of the RGB colour space it is given.

@interface DKColourQuantizer : NSObject
{
	NSUInteger		m_maxColours;
	NSUInteger		m_nBits;
	NSSize			m_imageSize;
	NSMutableArray*	m_cTable;
}

- (id)				initWithBitmapImageRep:(NSBitmapImageRep*) rep maxColours:(NSUInteger) maxColours colourBits:(NSUInteger) nBits;
- (NSUInteger)		indexForRGB:(NSUInteger[]) rgb;
- (NSColor*)		colourForIndex:(NSUInteger) index;
- (NSArray*)		colourTable;
- (NSInteger)				numberOfColours;

- (void)			analyse:(NSBitmapImageRep*) rep;

@end



#pragma mark -


// octree quantizer which does a much better job
// this code is mostly a port of CQuantizer (c)  1996-1997 Jeff Prosise

typedef struct _NODE
{
    BOOL			bIsLeaf;               // YES if node has no children
    NSUInteger		nPixelCount;           // Number of pixels represented by this leaf
    NSUInteger		nRedSum;               // Sum of red components
    NSUInteger		nGreenSum;             // Sum of green components
    NSUInteger		nBlueSum;              // Sum of blue components
    NSUInteger		nAlphaSum;             // Sum of alpha components
    struct _NODE*	pChild[8];				// Pointers to child nodes
    struct _NODE*	pNext;					// Pointer to next reducible node
	NSInteger				indexValue;				// for looking up RGB->index
}
NODE;

typedef struct _rgb_triple
{
	CGFloat r;
	CGFloat g;
	CGFloat b;
}
rgb_triple;


@interface DKOctreeQuantizer : DKColourQuantizer
{
    NODE*		m_pTree;
    NSUInteger	m_nLeafCount;
    NODE*		m_pReducibleNodes[9];
    NSUInteger	m_nOutputMaxColors;
}


- (void)		addNode:(NODE**) ppNode colour:(NSUInteger[]) rgb level:(NSUInteger) level leafCount:(NSUInteger *) leafCount reducibleNodes:(NODE**) redNodes;
- (NODE*)		createNodeAtLevel:(NSUInteger) level leafCount:(NSUInteger *) leafCount reducibleNodes:(NODE**) redNodes;
- (void)		reduceTreeLeafCount:(NSUInteger *) leafCount reducibleNodes:(NODE**) redNodes;
- (void)		deleteTree:(NODE**) ppNode;
- (void)		paletteColour:(NODE*) pTree index:(NSUInteger *) pIndex colour:(rgb_triple[]) rgb;
- (void)		lookUpNode:(NODE*) pTree level:(NSUInteger) level colour:(NSUInteger[]) rgb index:(NSInteger*) index;

@end

