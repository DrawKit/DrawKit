//
//  DKGeometryUtilitiesAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 3/8/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

import DKDrawKit.DKGeometryUtilities

@available(*, unavailable, renamed: "UnionOfRects(in:)")
public func UnionOfRectsInSet(in aSet: [NSRect]) -> NSRect {
	fatalError("Unavailable function \(#function) called!")
}

/// Returns the smallest rect that encloses all rects in the array.
/// - parameter aSet: An array of `NSRect`s.
/// - returns: The rectangle that encloses all rects.
public func UnionOfRects(in aSet: [NSRect]) -> NSRect {
	var ur = NSRect.zero
	
	for val in aSet {
		ur = UnionOfTwoRects(ur, val)
	}
	return ur
}

/// Returns the area that is different between two input rects, as a list of rects
///
/// This can be used to optimize upates. If `a` and `b` are "before and after" rects of a visual change,
/// the resulting list is the area to update assuming that nothing changed in the common area,
/// which is frequently so. If a and b are equal, the result is empty. If `a` and `b` do not intersect,
/// the result contains `a` and `b`.
/// - parameter a: The first rect.
/// - parameter b: The second rect.
/// - returns: An array of `NSRect`s. The values are in no particular order.
public func DifferenceOfTwoRects(_ a: NSRect, _ b: NSRect) -> [NSRect] {
	let preRetVal = __DifferenceOfTwoRects(a, b)
	return preRetVal.map({$0.rectValue})
}

/// Subtracts `b` from `a`, returning the pieces left over.
///
/// Subtracts `b` from `a`, returning the pieces left over. If `a` and `b` don't intersect, the result is correct
/// but unnecessary, so the caller should test for intersection first.
public func SubtractTwoRects(_ a: NSRect, _ b: NSRect) -> [NSRect] {
	let preRetVal = __SubtractTwoRects(a, b)
	return preRetVal.map({$0.rectValue})
}
