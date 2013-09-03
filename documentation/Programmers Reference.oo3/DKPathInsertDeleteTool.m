///**********************************************************************************************************************************
///  DKPathInsertDeleteTool.m
///  DrawKit
///
///  Created by graham on 09/06/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKPathInsertDeleteTool.h"

#import "DKDrawablePath.h"
#import "DKObjectDrawingLayer.h"
#import "LogEvent.h"


@implementation DKPathInsertDeleteTool
#pragma mark As a DKPathInsertDeleteTool

+ (DKDrawingTool*)		pathDeletionTool
{
	DKPathInsertDeleteTool* tool = [[DKPathInsertDeleteTool alloc] init];
	
	[tool setMode:kGCPathDeletePointMode];
	return [tool autorelease];
}


+ (DKDrawingTool*)		pathInsertionTool
{
	DKPathInsertDeleteTool* tool = [[DKPathInsertDeleteTool alloc] init];
	
	[tool setMode:kGCPathInsertPointMode];
	return [tool autorelease];
}


#pragma mark -
- (void)				setMode:(DKPathToolMode) m
{
	m_mode = m;
}


- (DKPathToolMode)		mode
{
	return m_mode;
}


#pragma mark -
#pragma mark As an NSObject
- (id)					init
{
	self = [super init];
	if(self != nil)
	{
		NSAssert(m_mode == kGCPathDeletePointMode, @"Expected init to zero");
		NSAssert(!m_performedAction, @"Expected init to NO");
	}
	return self;
}


#pragma mark -
#pragma mark - As part of DKDrawingTool Protocol


+ (BOOL)			toolPerformsUndoableAction
{
	return YES;
}


- (NSString*)		actionName
{
	if ([self mode] == kGCPathDeletePointMode )
		return NSLocalizedString( @"Delete Path Point", @"undo string for delete path point" );
	else
		return NSLocalizedString( @"Insert Path Point", @"undo string for insert path point" );
}


- (NSCursor*)		cursor
{
	NSImage* img;
	
	if([self mode] == kGCPathDeletePointMode)
		img = [NSImage imageNamed:@"Delete Path Point"];
	else
		img = [NSImage imageNamed:@"Insert Path Point"];
	
	NSCursor* curs = [[NSCursor alloc] initWithImage:img hotSpot:NSMakePoint( 1, 1 )];	
	return [curs autorelease];
}


- (int)				mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)
	
	// the mouse down works out whether the operation can be actually done.
	
	int pc = kGCDrawingNoPart;
	m_performedAction = NO;
	
	if ([obj isKindOfClass:[DKDrawablePath class]])
	{
		mTargetRef = (DKDrawablePath*)obj;
		
		LogEvent_(kUserEvent, @"insert/delete tool got mouse down, target = %@, mode = %d", obj, m_mode );
		
		pc = [obj hitPart:p];
		
		// if the pc was not an on-path point and we are deleting, the operation won't work so return 0
		
		if ( pc == kGCDrawingEntireObjectPart && [self mode] == kGCPathDeletePointMode )
			pc = kGCDrawingNoPart;
	}
	else
		mTargetRef = nil;
	
	return pc;
}


- (BOOL)			mouseUpAtPoint:(NSPoint) p partCode:(int) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(p)
	#pragma unused(pc)
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)
			
	if (mTargetRef != nil)
	{
		if ([self mode] == kGCPathDeletePointMode)
		{
			// delete the point <pc>
			
			if ( pc != kGCDrawingNoPart )
				m_performedAction = [mTargetRef pathDeletePointWithPartCode:pc];
		}
		else
		{
			// insert - option key will insert point type opposite to that of the element type hit
			
			if ( pc == kGCDrawingEntireObjectPart )
			{ 
				BOOL option = ([event modifierFlags] & NSAlternateKeyMask) != 0;
				pc = [mTargetRef pathInsertPointAt:p ofType:option? kGCPathPointTypeInverseAuto : kGCPathPointTypeAuto];
				m_performedAction = ( pc != kGCDrawingNoPart && pc != kGCDrawingEntireObjectPart );
			}
		}
	
		if(![(DKObjectDrawingLayer*)layer isSelectedObject:mTargetRef] && m_performedAction )
		{
			[(DKObjectDrawingLayer*)layer replaceSelectionWithObject:mTargetRef];
		}
		
	}

	return m_performedAction;
}


- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	return [aLayer isKindOfClass:[DKObjectDrawingLayer class]];
}



@end
