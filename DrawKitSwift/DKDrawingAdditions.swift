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

	/// Margins
	///
	/// Margins inset the drawing area within the `papersize` set.
	public var margins: (left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) {
		get {
			return (leftMargin, topMargin, rightMargin, bottomMargin)
		}
		set {
			setMargins(left: newValue.left, top: newValue.top, right: newValue.right, bottom: newValue.bottom)
		}
	}
	
	/// The drawing info metadata of the drawing.
	///
	/// The drawing info contains whatever you want, but a number of standard fields are defined and can be
	/// interpreted by a `DKDrawingInfoLayer`, if there is one. Note this inherits the storage from
	/// `DKLayer`.
	public var drawingInfo: [String: Any]? {
		get {
			return __drawingInfo as NSDictionary? as? [String: Any]
		}
		set {
			if let nv = newValue {
				__drawingInfo = NSMutableDictionary(dictionary: nv)
			} else {
				__drawingInfo = nil
			}
		}
	}
	
	/// Returns a dictionary containing some standard drawing info attributes.
	///
	/// This is usually called by the drawing object itself when built new. Usually you'll want to replace
	/// its contents with your own info. A `DKDrawingInfoLayer` can interpret some of the standard values and
	/// display them in its info box.
	open class var defaultDrawingInfo: [String: Any] {
		return __defaultDrawingInfo as NSDictionary as! [String: Any]
	}
}
