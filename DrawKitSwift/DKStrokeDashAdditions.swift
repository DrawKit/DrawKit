//
//  DKStrokeDashAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 2/2/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

import DKDrawKit.DKStrokeDash

public extension DKStrokeDash {
	var pattern: [CGFloat] {
		get {
			var c = 0
			var d = [CGFloat](repeating: 1, count: 8)
			getPattern(&d, count: &c)
			if c == 0 {
				return []
			}
			return Array(d[0..<c])
		}
		set {
			let count = min(newValue.count, 8)
			setPattern(newValue, count: count)
		}
	}
}
