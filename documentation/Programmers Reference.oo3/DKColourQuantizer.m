///**********************************************************************************************************************************
///  DKColourQuantizer.m
///  DrawKit
///
///  Created by graham on 25/06/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKColourQuantizer.h"

#import "DKDrawKitMacros.h"
#import "LogEvent.h"


// colour mapping macros rgb->index->rgb. Note that these only do the most primitive colour mapping which is bit truncation and concatenation.
// TO DO: try the same using a YUV colourspace???

#define		RGB_TO_INDEX_332( p )	((p[0] & 0xE0)			| ((p[1] & 0xE0) >> 3 ) | ((p[2] & 0xC0) >> 6 ))
#define		RGB_TO_INDEX_322( p )	(((p[0] & 0xE0) >> 1 )	| ((p[1] & 0xC0) >> 4 ) | ((p[2] & 0xC0) >> 6 ))
#define		RGB_TO_INDEX_222( p )	(((p[0] & 0xC0) >> 2 )	| ((p[1] & 0xC0) >> 4 ) | ((p[2] & 0xC0) >> 6 ))
#define		RGB_TO_INDEX_221( p )	(((p[0] & 0xC0) >> 3 )	| ((p[1] & 0xC0) >> 5 ) | ((p[2] & 0x80) >> 7 ))
#define		RGB_TO_INDEX_211( p )	(((p[0] & 0xC0) >> 4 )	| ((p[1] & 0x80) >> 6 ) | ((p[2] & 0x80) >> 7 ))
#define		RGB_TO_INDEX_111( p )	(((p[0] & 0x80) >> 5 )	| ((p[1] & 0x80) >> 6 ) | ((p[2] & 0x80) >> 7 ))

#pragma mark -
#pragma mark Static Functions
static inline void indexToRGB_111( unsigned i, unsigned rgb[3] )
{
	rgb[0] = (i & 4)? 0xFF : 0;
	rgb[1] = (i & 2)? 0xFF : 0;
	rgb[2] = (i & 1)? 0xFF : 0;
}


static inline void indexToRGB_211( unsigned i, unsigned rgb[3] )
{
	rgb[0] = ((i & 0x0C) << 6) | ((i & 0x0C) << 4) | (i & 0x0C) | ((i & 0x0C) >> 2);
	rgb[1] = (i & 2)? 0xFF : 0;
	rgb[2] = (i & 1)? 0xFF : 0;
}


static inline void indexToRGB_221( unsigned i, unsigned rgb[3] )
{
	rgb[0] = ((i & 0x18) << 3) | ((i & 0x18) << 1) | ((i & 0x18) >> 1) | ((i & 0x18) >> 3);
	rgb[1] = ((i & 0x06) << 5) | ((i & 0x06) << 3) | ((i & 0x06) << 1) | ((i & 0x06) >> 1);
	rgb[2] = (i & 1)? 0xFF : 0;
}


static inline void indexToRGB_222( unsigned i, unsigned rgb[3] )
{
	rgb[0] = ((i & 0x30) << 2) | (i & 0x30) | ((i & 0x30) >> 2) | ((i & 0x30) >> 4);
	rgb[1] = ((i & 0x0C) << 4) | ((i & 0x0C) << 2) | (i & 0x0C) | ((i & 0x0C) >> 2);
	rgb[2] = ((i & 0x03) << 6) | ((i & 0x03) << 4) | ((i & 0x03) << 2) | (i & 0x03);
}


static inline void indexToRGB_322( unsigned i, unsigned rgb[3] )
{
	rgb[0] = ((i & 0x70) << 1) | ((i & 0x70) >> 2) | ((i & 0x70) >> 5);
	rgb[1] = ((i & 0x0C) << 4) | ((i & 0x0C) << 2) | (i & 0x0C) | ((i & 0x0C) >> 2);
	rgb[2] = ((i & 0x03) << 6) | ((i & 0x03) << 4) | ((i & 0x03) << 2) | (i & 0x03);
}


static inline void indexToRGB_332( unsigned i, unsigned rgb[3] )
{
	rgb[0] = (i & 0xE0) | ((i & 0xE0) >> 3) | ((i & 0xE0) >> 6);
	rgb[1] = ((i & 0x1C) << 3) | (i & 0x1C) | ((i & 0x1C) >> 3);
	rgb[2] = ((i & 0x03) << 6) | ((i & 0x03) << 4) | ((i & 0x03) << 2) | (i & 0x03);
}


#pragma mark -
@implementation DKColourQuantizer
#pragma mark As a DKColourQuantizer
- (id)				initWithBitmapImageRep:(NSBitmapImageRep*) rep maxColours:(unsigned) maxColours colourBits:(unsigned) nBits
{
	NSAssert(rep != nil, @"Expected valid rep");
	self = [super init];
	if (self != nil)
	{
		m_maxColours = LIMIT( maxColours, 16, 256 ); //MAX( 16, MIN( 256, maxColours ));
		m_nBits = MIN( (unsigned)8, nBits );
		m_imageSize = [rep size];
		m_cTable = [[NSMutableArray alloc] init];
		
		if (m_cTable == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	
	return self;
}


- (unsigned)		indexForRGB:(unsigned int[]) rgb
{
	switch( m_nBits )
	{
		case 3:
			return RGB_TO_INDEX_111( rgb );

		case 4:
			return RGB_TO_INDEX_211( rgb );

		case 5:
			return RGB_TO_INDEX_221( rgb );

		case 6:
			return RGB_TO_INDEX_222( rgb );

		case 7:
			return RGB_TO_INDEX_322( rgb );
		
		default:
		case 8:
			return RGB_TO_INDEX_332( rgb );
	}
}


- (NSColor*)		colourForIndex:(unsigned int) indx
{
	return [[self colourTable] objectAtIndex:indx];
}


- (NSArray*)		colourTable
{
	if ([m_cTable count] == 0)
	{
		unsigned		indx;
		unsigned		rgb[3];
		float			r, g, b;
		
		for( indx = 0; indx < m_maxColours; ++indx )
		{
			switch ( m_nBits )
			{
				case 3:
					indexToRGB_111( indx, rgb );
					break;
				case 4:
					indexToRGB_211( indx, rgb );
					break;
				case 5:
					indexToRGB_221( indx, rgb );
					break;
				case 6:
					indexToRGB_222( indx, rgb );
					break;
				case 7:
					indexToRGB_322( indx, rgb );
					break;

				case 8:
				default:
					indexToRGB_332( indx, rgb );
					break;
					
			}
			
			r = (float)rgb[0] / 255.0f;
			g = (float)rgb[1] / 255.0f;
			b = (float)rgb[2] / 255.0f;
	
			[m_cTable addObject:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0]];
		}
	}
	
	return m_cTable;
}


- (int)				numberOfColours
{
	return m_maxColours;
}


#pragma mark -
- (void)			analyse:(NSBitmapImageRep*) rep
{
	#pragma unused(rep)
	
	// the basic quantizer does no analysis of the image - it only works on the size of the RGB space. Override for more
	// sophisticated quantizers. Upside: it's very fast ;-)
}

#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	[m_cTable release];
	
	[super dealloc];
}


@end



#pragma mark -

@implementation DKOctreeQuantizer


static unsigned	mask[8]	= {	0x80, 0x40,	0x20, 0x10,	0x08, 0x04,	0x02, 0x01 };


- (void)			addNode:(NODE**) ppNode colour:(unsigned[]) rgb level:(unsigned) level leafCount:(unsigned*) leafCount reducibleNodes:(NODE**) redNodes
{

	// If the node doesn't exist, create it.
	
	if (*ppNode	== NULL)
		*ppNode	= [self createNodeAtLevel:level leafCount:leafCount reducibleNodes:redNodes];

	// Update color	information	if it's	a leaf node.
	
	if ((*ppNode)->bIsLeaf)
	{
		(*ppNode)->nPixelCount++;
		(*ppNode)->nRedSum		+= rgb[0];
		(*ppNode)->nGreenSum	+= rgb[1];
		(*ppNode)->nBlueSum		+= rgb[2];
		(*ppNode)->nAlphaSum	+= rgb[3];
	}
	else
	{
		// Recurse a level deeper if the node is not a leaf.
		
		int	shift =	7 -	level;
		int	nIndex = (((rgb[0] & mask[level]) >> shift) << 2) |
					 (((rgb[1] & mask[level]) >> shift) << 1) |
					 (( rgb[2] & mask[level]) >> shift);
					 
		[self addNode:&((*ppNode)->pChild[nIndex]) colour:rgb level:level + 1 leafCount:leafCount reducibleNodes:redNodes];
	}
}


- (NODE*)			createNodeAtLevel:(unsigned) level leafCount:(unsigned*) leafCount reducibleNodes:(NODE**) redNodes
{
	NODE* pnode = (NODE*) calloc( 1, sizeof(NODE));

	if ( pnode == NULL)
		return NULL;

	pnode->bIsLeaf = ( level ==	m_nBits );
	pnode->indexValue = -1;	// means not set
	
	if (pnode->bIsLeaf)
		(*leafCount)++;
	else
	{
		pnode->pNext = redNodes[level];
		redNodes[level]	= pnode;
	}
	
	return pnode;
}


- (void)		reduceTreeLeafCount:(unsigned*) leafCount reducibleNodes:(NODE**) redNodes
{
	// Find	the	deepest	level containing at	least one reducible	node.
	
	int i;
	
	for	( i = m_nBits -	1; (i > 0) && (redNodes[i] == NULL); i-- );

	// Reduce the node most	recently added to the list at level	i.
	
	NODE* pnode	= redNodes[i];
	redNodes[i] = pnode->pNext;

	unsigned nRedSum = 0;
	unsigned nGreenSum = 0;
	unsigned nBlueSum =	0;
	unsigned nAlphaSum = 0;
	unsigned nChildren = 0;

	for	(i = 0; i < 8; i++)
	{
		if (pnode->pChild[i] !=	NULL)
		{
			nRedSum		+= pnode->pChild[i]->nRedSum;
			nGreenSum	+= pnode->pChild[i]->nGreenSum;
			nBlueSum	+= pnode->pChild[i]->nBlueSum;
			nAlphaSum	+= pnode->pChild[i]->nAlphaSum;
			pnode->nPixelCount += pnode->pChild[i]->nPixelCount;
			
			free( pnode->pChild[i] );
			pnode->pChild[i] = NULL;
			
			nChildren++;
		}
	}

	pnode->bIsLeaf = YES;
	pnode->nRedSum = nRedSum;
	pnode->nGreenSum = nGreenSum;
	pnode->nBlueSum	= nBlueSum;
	pnode->nAlphaSum = nAlphaSum;
	
	*leafCount -= (nChildren - 1);
}


- (void)		deleteTree:(NODE**) ppNode
{
	int i;
	
	for	(i = 0; i < 8; i++)
	{
		if ((*ppNode)->pChild[i] !=	NULL)
			[self deleteTree:&((*ppNode)->pChild[i])];
	}
	
	free(*ppNode);
	*ppNode	= NULL;
}


- (void)		paletteColour:(NODE*) pTree index:(unsigned*) pindex colour:(rgb_triple[]) rgb
{
	if (pTree)
	{
		if (pTree->bIsLeaf)
		{
			float	divs = ((float)(pTree->nPixelCount) * 255.0f);//(float) m_maxColours);
			
			rgb[*pindex].r = (float)(pTree->nRedSum)	/ divs;
			rgb[*pindex].g = (float)(pTree->nGreenSum)	/ divs;
			rgb[*pindex].b = (float)(pTree->nBlueSum)	/ divs;
			pTree->indexValue = *pindex;	// record index for rapid RGB lookup
			
		//	LogEvent_(kInfoEvent, @"index %d, rgb = { %f, %f, %f }", *pIndex, rgb[*pIndex].r, rgb[*pIndex].g, rgb[*pIndex].b);
			(*pindex)++;
		}
		else
		{
			int i;
			
			for	( i = 0; i < 8; i++)
			{
				if (pTree->pChild[i] !=	NULL)
					[self paletteColour:pTree->pChild[i] index:pindex colour:rgb];
			}
		}
	}
}


- (void)		lookUpNode:(NODE*) pTree level:(unsigned) level colour:(unsigned[]) rgb index:(int*) indx
{
	if (pTree->bIsLeaf)
	{
		*indx = pTree->indexValue;
	}
	else
	{
		// Recurse a level deeper if the node is not a leaf.
		
		int	shift =	7 -	level;
		int	nIndex = (((rgb[0] & mask[level]) >> shift) << 2) |
					 (((rgb[1] & mask[level]) >> shift) << 1) |
					 (( rgb[2] & mask[level]) >> shift);
					 
		[self lookUpNode:pTree->pChild[nIndex] level:level + 1 colour:rgb index:indx];
	}
}


#pragma mark -
#pragma mark As a DKColourQuantizer
- (void)			analyse:(NSBitmapImageRep*) rep
{
	int			i, j;
	unsigned	rgb[4];
	
	[m_cTable removeAllObjects];

	for	( i = 0; i < m_imageSize.height; ++i )
	{
		for	( j = 0; j < m_imageSize.width; ++j )
		{
			[rep getPixel:rgb atX:j y:i];
			
			[self addNode:&m_pTree colour:rgb level:0 leafCount:&m_nLeafCount reducibleNodes:m_pReducibleNodes];

			while ( m_nLeafCount > m_maxColours )
				[self reduceTreeLeafCount:&m_nLeafCount reducibleNodes:m_pReducibleNodes];
		}
	}
}


- (NSArray*)		colourTable
{
	if ([m_cTable count] == 0)
	{
		// convert all the rgb records in the octree to NSColors and store them in the table
		
		rgb_triple*	rgb;
		unsigned	i, indx = 0;
		NSColor*	colour;
		
		rgb = (rgb_triple*) malloc( m_nLeafCount * sizeof(rgb_triple));
		[self paletteColour:m_pTree index:&indx colour:rgb];
	
		// loop over the list and convert to NSColors
		
		for( i = 0; i < indx; ++i )
		{
			colour = [NSColor colorWithCalibratedRed:rgb[i].r green:rgb[i].g blue:rgb[i].b alpha:1.0];
			[m_cTable addObject:colour];
		}
		
		free( rgb );
	}
	
	return m_cTable;
}


- (unsigned)		indexForRGB:(unsigned[]) rgb
{
	int		indx = 0;
	
	// force computation of the indexes if not done already:
	[self colourTable];
	
	// recursive lookup:
	[self lookUpNode:m_pTree level:0 colour:rgb index:&indx];
	
	if ( indx != -1 )
		return indx;
	else
		return NSNotFound;
}


- (id)				initWithBitmapImageRep:(NSBitmapImageRep*) rep maxColours:(unsigned) maxColours colourBits:(unsigned) nBits
{
	NSAssert(rep != nil, @"Expected valid rep");
	self == [super initWithBitmapImageRep:rep maxColours:maxColours colourBits:nBits];
	if (self != nil)
	{
		NSAssert(m_pTree == NULL, @"Expected init to zero");
		NSAssert(m_nLeafCount == 0, @"Expected init to zero");
		
		int i = 0;
		for	( ; i < 9; ++i)
		{
			m_pReducibleNodes[i] = NULL;
		}
			
		m_nOutputMaxColors = m_maxColours;
	}
	
	return self;
}


- (int)				numberOfColours
{
	return m_nLeafCount;
}


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	if (m_pTree	!= NULL)
	{
		[self deleteTree:&m_pTree];
	}

	[super dealloc];
}


@end
