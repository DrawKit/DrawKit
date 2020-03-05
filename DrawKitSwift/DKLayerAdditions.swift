//
//  DKLayerAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 3/8/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

import DKDrawKit.DKLayer

extension DKLayer {
	/// Mark multiple parts of the drawing as needing update
	///
	/// The layer call with `NSRect.zero` is to ensure the layer's caches work
	/// - parameter setOfRects: An array of `NSRect`s to be updated.
	public func setNeedsDisplay(in setOfRects: [NSRect]) {
		let orderedVals = setOfRects.map({NSValue(rect: $0)})
		let unorderedVals = Set(orderedVals)
		__setNeedsDisplayInRects(unorderedVals)
	}
	
	/// Mark multiple parts of the drawing as needing update
	///
	/// The layer call with `NSRect.zero` is to ensure the layer's caches work.
	/// - parameter setOfRects: An array of `NSRect`s to be updated.
	/// - parameter padding: Some additional margin added to each rect before marking as needing update.
	public func setNeedsDisplay(in setOfRects: [NSRect], withExtraPadding padding: NSSize) {
		let orderedVals = setOfRects.map({NSValue(rect: $0)})
		let unorderedVals = Set(orderedVals)
		__setNeedsDisplayInRects(unorderedVals, withExtraPadding: padding)
	}
		
	@available(*, unavailable, renamed: "setNeedsDisplay(in:)")
	public func setNeedsDisplayInRects(_ setOfRects: [NSRect]) {
		setNeedsDisplay(in: setOfRects)
	}
	
	@available(*, unavailable, renamed: "setNeedsDisplay(in:withExtraPadding:)")
	public func setNeedsDisplayInRects(_ setOfRects: [NSRect], withExtraPadding padding: NSSize) {
		setNeedsDisplay(in: setOfRects, withExtraPadding: padding)
	}
}
