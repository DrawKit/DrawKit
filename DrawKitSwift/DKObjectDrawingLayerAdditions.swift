//
//  DKObjectDrawingLayerAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/10/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKObjectDrawingLayer

extension DKObjectDrawingLayer {
	///  Returns the objects that are not locked, visible and selected and which have the given class
	///
	/// See comments for `selectedAvailableObjects`.
	/// - parameter aClass: Class of the desired objects.
	/// - returns: An array, objects of the given class that can be acted upon by a command as a set.
	public func selectedAvailableObjects<A: DKDrawableObject>(of aClass: A.Type) -> [A]? {
		return __selectedAvailableObjects(of: aClass) as? [A]
	}
}
