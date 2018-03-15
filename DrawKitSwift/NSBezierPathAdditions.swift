//
//  NSBezierPathAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 3/8/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

import DKDrawKit.DKAdditions.NSBezierPath.Text
import DKDrawKit.DKAdditions.NSBezierPath.Editing
import DKDrawKit.DKAdditions.NSBezierPath

extension NSBezierPath {
	/// Determines the positions of any descender breaks for drawing underlines.
	///
	/// In order to correctly and accurately interrupt an underline where a glyph descender 'cuts' through
	/// it, the locations of the start and end of each break must be computed. This does that by finding
	/// the intersections of the glyph paths and a notional underline path. As such it is computationally
	/// expensive (but is cached at a higher level).
	/// - parameter str: The string in question.
	/// - parameter range: The range of characters of interest within the string.
	/// - parameter offset: The distance between the text baseline and the underline.
	/// - returns: A list of descender break positions (`NSPoint`s).
	public func descenderBreaks(for str: NSAttributedString, range: NSRange, underlineOffset offset: CGFloat) -> [NSPoint] {
		return __descenderBreaks(for: str, range: range, underlineOffset: offset).map({$0.pointValue})
	}

	/// Converts all the information about an underline into a path that can be drawn.
	///
	/// Where descender breaks are passed in, the gap on either side of the break is widened by a factor
	/// based on gt, which in turn is usually derived from the text size. This allows the breaks to size
	/// proportionally to give pleasing results. The result may differ from Apple's standard text block
	/// rendition (but note that for some fonts, DK's way works where Apple's does not, e.g. Zapfino).
	/// - parameter mask: The underline attributes mask value.
	/// - parameter sp: The starting position for the underline on the path.
	/// - parameter length: The length of the underline on the path.
	/// - parameter offset: The distance between the text baseline and the underline.
	/// - parameter lineThickness: The thickness of the underline.
	/// - parameter breaks: An array of descender breakpoints, or `nil`.
	/// - parameter gt: Threshold value to suppress inclusion of very short "bits" of underline (a.k.a "grot").
	/// - returns: A path. Stroking this path draws the underline.
	public func textLinePath(withMask mask: NSUnderlineStyle, startPosition sp: CGFloat, length: CGFloat, offset: CGFloat, lineThickness: CGFloat, descenderBreaks breaks: [NSPoint]?, grotThreshold gt: CGFloat) -> NSBezierPath? {
		let convBreaks: [NSValue]?
		if let breaks = breaks {
			convBreaks = breaks.map({return NSValue(point: $0)})
		} else {
			convBreaks = nil
		}
		return __textLinePath(withMask: mask, startPosition: sp, length: length, offset: offset, lineThickness: lineThickness, descenderBreaks: convBreaks, grotThreshold: gt)
	}

	/// Find the points where a line drawn horizontally across the path will intersect it.
	///
	/// This works by approximating the curve as a series of straight lines and testing each one for
	/// intersection with the line at `y`. This is the primitive method used to determine line layout
	/// rectangles - a series of calls to this is needed for each line (incrementing `y` by the
	/// `lineheight`) and then rects forming from the resulting points. See `lineFragmentRects(forFixedLineheight:)`.
	/// This is also used when calculating descender breaks for underlining text on a path. This method is
	/// guaranteed to return an even number of (or none) results.
	/// - parameter yPosition: The distance between the top edge of the bounds and the line to test.
	/// - returns: A list of `NSPoint`s.
	public func intersectingPointsWithHorizontalLineAt(y yPosition: CGFloat) -> [NSPoint]? {
		guard let preToRet = __intersectingPointsWithHorizontalLineAt(y: yPosition) else {
			return nil
		}
		return preToRet.map({$0.pointValue})
	}
	
	
	/// Find rectangles within which text can be laid out to place the text within the path.
	///
	/// Given a lineheight value, this returns an array of `NSRect`s which are the ordered line
	/// layout rects from left to right and top to bottom within the shape to layout text in. This is
	/// computationally intensive, so the result should probably be cached until the shape is actually changed.
	/// This works with a fixed `lineheight`, where every line is the same. Note that this method isn't really
	/// suitable for use with `NSTextContainer` or Cocoa's text system in general - for flowing text using
	/// `NSLayoutManager`, use `DKBezierTextContainer` which calls the `lineFragmentRect(forProposedRect:remaining:)`
	/// method.
	/// - parameter lineHeight: the lineheight for the lines of text.
	/// - returns: A list of `NSRect`s.
	public func lineFragmentRects(forFixedLineheight lineHeight: CGFloat) -> [NSRect] {
		let preToRet = __lineFragmentRects(forFixedLineheight: lineHeight)
		return preToRet.map({$0.rectValue})
	}

}

extension NSBezierPath {
	public func boundingBoxes(forPartcode pc: Int) -> [NSRect] {
		let valueBoundBoxes = __boundingBoxes(forPartcode: pc)
		let boxes = valueBoundBoxes.map({$0.rectValue})
		return boxes
	}
	
	public func allBoundingBoxes() -> [NSRect] {
		let valueBoundBoxes = __allBoundingBoxes()
		let boxes = valueBoundBoxes.map({$0.rectValue})
		return boxes
	}

}
