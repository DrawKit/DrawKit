/*
 *  DKCommonTypes.h
 *  DrawKit
 *
 *  Created by graham on 11/03/2008.
 *  Copyright 2008 Apptree.net. All rights reserved.
 *
 */

// functional types, as passed to drawKnobAtPoint:ofType:userInfo:
// locked flag can be ORed in to pass signal the locked property - any other state info used by subclasses
// should be passed in the userInfo.

typedef enum
{
	kDKControlPointKnobType			= 1,
	kDKOnPathKnobType				= 2,
	kDKBoundingRectKnobType			= 3,
	kDKRotationKnobType				= 4,
	kDKCentreTargetKnobType			= 5,
	kDKHotspotKnobType				= 6,
	//--------------------------------------------
	kDKKnobIsDisabledFlag			= ( 1 << 16 ),
	kDKKnobIsInactiveFlag			= ( 1 << 17 ),
	kDKKnobIsSelectedFlag			= ( 1 << 18 ),
	//--------------------------------------------
	kDKKnobTypeMask					= 0xFFFF
}
DKKnobType;

// an object that lays claim to own the knob class (e.g. DKLayer) needs to implement the following protocol:

@protocol DKKnobOwner <NSObject>

- (float)		knobsWantDrawingScale;
- (BOOL)		knobsWantDrawingActiveState;

@end


// constants that can be passed to pasteboardTypesForOperation:  OR together to combine types

typedef enum
{
	kDKWritableTypesForCopy		= ( 1 << 0 ),				// return the types that are written for a cut or copy operation
	kDKWritableTypesForDrag		= ( 1 << 1 ),				// return the types that are written for a drag operation (drag OUT)
	kDKReadableTypesForPaste	= ( 1 << 2 ),				// return the types that can be received by a paste operation
	kDKReadableTypesForDrag		= ( 1 << 3 ),				// return the types that can be received by a drag operation (drag IN)
	kDKAllReadableTypes			= kDKReadableTypesForDrag | kDKReadableTypesForPaste,
	kDKAllWritableTypes			= kDKWritableTypesForCopy | kDKWritableTypesForDrag,
	kDKAllDragTypes				= kDKReadableTypesForDrag | kDKWritableTypesForDrag,
	kDKAllCopyPasteTypes		= kDKReadableTypesForPaste | kDKWritableTypesForCopy,
	kDKAllPasteboardTypes		= 0xFF
}
DKPasteboardOperationType;

