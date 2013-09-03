///**********************************************************************************************************************************
///  DKPathInsertDeleteTool.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 09/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKPathInsertDeleteTool.h"

#import "DKDrawablePath.h"
#import "DKObjectDrawingLayer.h"
#import "LogEvent.h"


NSString*	kDKInsertPathPointCursorImageName		= @"Insert Path Point";
NSString*	kDKDeletePathPointCursorImageName		= @"Delete Path Point";
NSString*	kDKDeletePathElementCursorImageName		= @"Delete Path Element";

@implementation DKPathInsertDeleteTool
#pragma mark As a DKPathInsertDeleteTool

+ (DKDrawingTool*)		pathDeletionTool
{
	DKPathInsertDeleteTool* tool = [[DKPathInsertDeleteTool alloc] init];
	
	[tool setMode:kDKPathDeletePointMode];
	return [tool autorelease];
}


+ (DKDrawingTool*)		pathInsertionTool
{
	DKPathInsertDeleteTool* tool = [[DKPathInsertDeleteTool alloc] init];
	
	[tool setMode:kDKPathInsertPointMode];
	return [tool autorelease];
}


+ (DKDrawingTool*)		pathElementDeletionTool;
{
	DKPathInsertDeleteTool* tool = [[DKPathInsertDeleteTool alloc] init];
	
	[tool setMode:kDKPathDeleteElementMode];
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
#pragma mark - As part of DKDrawingTool Protocol


+ (BOOL)			toolPerformsUndoableAction
{
	return YES;
}


- (NSString*)		actionName
{
	switch([self mode])
	{
		case kDKPathDeletePointMode:
			return NSLocalizedString( @"Delete Path Point", @"undo string for delete path point" );
		
		case kDKPathInsertPointMode:
			return NSLocalizedString( @"Insert Path Point", @"undo string for insert path point" );
			
		case kDKPathDeleteElementMode:
			return NSLocalizedString( @"Delete Path Segment", @"undo string for delete path segment" );
			
		default:
			return @"";
	}
}


- (NSCursor*)		cursor
{
	NSImage* img;
	
	switch([self mode])
	{
		case kDKPathDeletePointMode:
			img = [NSImage imageNamed:kDKDeletePathPointCursorImageName];
			break;
			
		case kDKPathInsertPointMode:
			img = [NSImage imageNamed:kDKInsertPathPointCursorImageName];
			break;
			
		case kDKPathDeleteElementMode:
			img = [NSImage imageNamed:kDKDeletePathElementCursorImageName];
			break;
			
		default:
			img = nil;
			break;
	}
	
	NSCursor* curs = [[NSCursor alloc] initWithImage:img hotSpot:NSMakePoint( 1, 1 )];	
	return [curs autorelease];
}


- (NSInteger)				mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(layer)
	#pragma unused(event)
	#pragma unused(aDel)
	
	// the mouse down works out whether the operation can be actually done.
	
	NSInteger pc = kDKDrawingNoPart;
	m_performedAction = NO;
	mTargetRef = nil;
	
	if ([obj isKindOfClass:[DKDrawablePath class]])
	{
		mTargetRef = (DKDrawablePath*)obj;
		
		pc = [obj hitPart:p];
		
		LogEvent_(kUserEvent, @"insert/delete tool got mouse down, target = %@, mode = %d, partcode = %d", obj, m_mode, pc );
		
		// if the pc was not an on-path point and we are deleting, the operation won't work so return 0
		
		if ( pc == kDKDrawingEntireObjectPart && [self mode] == kDKPathDeletePointMode )
			pc = kDKDrawingNoPart;
	}
	
	return pc;
}


- (BOOL)			mouseUpAtPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(aDel)
			
	if (mTargetRef != nil)
	{
		if ([self mode] == kDKPathDeletePointMode)
		{
			// delete the point <pc>
			
			if ( pc != kDKDrawingNoPart )
			{
				m_performedAction = [mTargetRef pathDeletePointWithPartCode:pc];
			}
		}
		else if([self mode] == kDKPathInsertPointMode)
		{
			// insert - option key will insert point type opposite to that of the element type hit
			
			if ( pc == kDKDrawingEntireObjectPart )
			{ 
				BOOL option = ([event modifierFlags] & NSAlternateKeyMask) != 0;
				pc = [mTargetRef pathInsertPointAt:p ofType:option? kDKPathPointTypeInverseAuto : kDKPathPointTypeAuto];
				m_performedAction = ( pc != kDKDrawingNoPart && pc != kDKDrawingEntireObjectPart );
			}
		}
		else if([self mode] == kDKPathDeleteElementMode)
		{
			m_performedAction = [mTargetRef pathDeleteElementAtPoint:p];
		}
	
		if( !m_performedAction )
			NSBeep();

		if(![(DKObjectDrawingLayer*)layer isSelectedObject:mTargetRef] && m_performedAction )
		{
			[(DKObjectDrawingLayer*)layer replaceSelectionWithObject:mTargetRef];
		}
		
	}
	
	mTargetRef = nil;
	return m_performedAction;
}


- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	return [aLayer isKindOfClass:[DKObjectDrawingLayer class]];
}



@end
