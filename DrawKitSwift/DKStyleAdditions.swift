//
//  DKStyleAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/10/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKStyle
import DKDrawKit.DKRastGroup

extension DKRastGroup {
	/// Returns a flattened list of renderers of a given class.
	/// - parameter cl: the class to look for
	/// - returns: an array containing the renderers matching `cl`, or `nil`.
	public func renderers<A: DKRasterizer>(of cl: A.Type) -> [A]? {
		return __renderers(of: cl) as? [A]
	}
}
