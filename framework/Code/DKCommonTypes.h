/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

// functional types, as passed to drawKnobAtPoint:ofType:userInfo:
// locked flag can be ORed in to pass signal the locked property - any other state info used by subclasses
// should be passed in the userInfo.

typedef enum {
	kDKInvalidKnobType = 0,
	kDKControlPointKnobType = 1,
	kDKOnPathKnobType = 2,
	kDKBoundingRectKnobType = 3,
	kDKRotationKnobType = 4,
	kDKCentreTargetKnobType = 5,
	kDKHotspotKnobType = 6,
	kDKOffPathKnobType = kDKControlPointKnobType,
	kDKMoreTextIndicatorKnobType = 8,
	//--------------------------------------------
	kDKKnobIsDisabledFlag = (1 << 16),
	kDKKnobIsInactiveFlag = (1 << 17),
	kDKKnobIsSelectedFlag = (1 << 18),
	//--------------------------------------------
	kDKKnobTypeMask = 0xFFFF
} DKKnobType;

// an object that lays claim to own the knob class (e.g. DKLayer) needs to implement the following protocol:

@protocol DKKnobOwner <NSObject>

- (CGFloat)knobsWantDrawingScale;
- (BOOL)knobsWantDrawingActiveState;

@end

// constants that can be passed to pasteboardTypesForOperation:  OR together to combine types

typedef enum {
	kDKWritableTypesForCopy = (1 << 0), // return the types that are written for a cut or copy operation
	kDKWritableTypesForDrag = (1 << 1), // return the types that are written for a drag operation (drag OUT)
	kDKReadableTypesForPaste = (1 << 2), // return the types that can be received by a paste operation
	kDKReadableTypesForDrag = (1 << 3), // return the types that can be received by a drag operation (drag IN)
	kDKAllReadableTypes = kDKReadableTypesForDrag | kDKReadableTypesForPaste,
	kDKAllWritableTypes = kDKWritableTypesForCopy | kDKWritableTypesForDrag,
	kDKAllDragTypes = kDKReadableTypesForDrag | kDKWritableTypesForDrag,
	kDKAllCopyPasteTypes = kDKReadableTypesForPaste | kDKWritableTypesForCopy,
	kDKAllPasteboardTypes = 0xFF
} DKPasteboardOperationType;

// text vertical alignment options

typedef enum {
	kDKTextShapeVerticalAlignmentTop = 0,
	kDKTextShapeVerticalAlignmentCentre = 1,
	kDKTextShapeVerticalAlignmentBottom = 2,
	kDKTextShapeVerticalAlignmentProportional = 3,
	kDKTextPathVerticalAlignmentCentredOnPath = 4,
	kDKTextShapeAlignTextToPoint = 27
} DKVerticalTextAlignment;

// layout modes, used by DKTextShape, DKTextAdornment:

typedef enum {
	kDKTextLayoutInBoundingRect = 0, // simple text block ignores path shape (but can be clipped to it)
	kDKTextLayoutAlongPath = 1, // this usually results in "outside path"
	kDKTextLayoutAlongReversedPath = 2, // will allow text inside circle for example, i.e. "inside path"
	kDKTextLayoutFlowedInPath = 3, // flows the text by wrapping within the path's shape
	kDKTextLayoutAtCentroid = 40, // positions a label centred on an object's centroid (requires external code)
	kDKTextLayoutFirstLineOnly = 64 // can be ORed in to only lay out the first line
} DKTextLayoutMode;

// text capitalization, used by DKTextAdornment, DKTextShape, DKTextPath:

typedef enum {
	kDKTextCapitalizationNone = 0, // no modification to the strings is performed
	kDKTextCapitalizationUppercase = 1, // text is made upper case
	kDKTextCapitalizationLowercase = 2, // text is made lower case
	kDKTextCapitalizationCapitalize = 3 // first letter of each word in text is capitalized, otherwise lowercase
} DKTextCapitalization;

// greeking, used by DKGreekingLayoutManager and DKTextAdornment

typedef enum {
	kDKGreekingNone = 0, // do not use greeking
	kDKGreekingByLineRectangle = 1, // greek by filling line rects
	kDKGreekingByGlyphRectangle = 2 // greek by filling glyph rects
} DKGreeking;
