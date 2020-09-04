//
//  DKObjectOwnerLayerAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/10/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKObjectOwnerLayer

extension DKObjectOwnerLayer {

	/// Returns objects that are available to the user of the given class.
	///
	/// If the layer itself is locked, returns an empty list.
	/// - parameter aClass: Class of the desired objects.
	/// - returns: An array of available objects.
    // swiftlint:disable force_cast
	public func availableObjects<A: DKDrawableObject>(of aClass: A.Type) -> [A] {
		return __availableObjects(of: aClass) as! [A]
	}
}
