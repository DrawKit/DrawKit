//
//  DKDrawingAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/10/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKDrawing

extension DKDrawing {
	/// Returns the active layer if it matches the requested class
	/// - parameter aClass: the class of layer sought.
	/// - returns: Returns the active layer if it matches the requested class
	public func activeLayer<A: DKLayer>(of aClass: A.Type) -> A? {
		return __activeLayer(of: aClass) as? A
	}
	
	/// Finds the first layer of the given class that can be activated.
	///
	/// Looks through all subgroups
	/// - parameter cl: the class of layer to look for
	/// - returns: the first such layer that returns `true` to `-layerMayBecomeActive`.
	public func firstActivateableLayer<A: DKLayer>(of cl: A.Type) -> A? {
		return __firstActivateableLayer(of: cl) as? A
	}

	//- (void)setMarginsLeft:(CGFloat)l top:(CGFloat)t right:(CGFloat)r bottom:(CGFloat)b;
	public var margins: (left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) {
		get {
			return (leftMargin, topMargin, rightMargin, bottomMargin)
		}
		set {
			setMargins(left: newValue.left, top: newValue.top, right: newValue.right, bottom: newValue.bottom)
		}
	}
}
