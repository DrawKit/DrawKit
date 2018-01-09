//
//  DKCategoryManagerAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 1/9/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

import DKDrawKit.DKCategoryManager

extension DKCategoryManager where ObjectType == DKStyle {
	/// Return all of the objects belonging to a given category.
	///
	/// Returned objects are in no particular order, but do match the key order obtained by
	/// `-allkeysInCategory`. Should any key not exist (which should never normally occur), the entry will
	/// be represented by a `nil`.
	/// - parameter catName: The category name.
	/// - returns: An array, the list of objects indicated by the category. May be empty.
	public func objects(inCategory catName: DKCategoryName) -> [ObjectType?] {
		return (__objects(inCategory: catName) as [AnyObject]).map({ (obj) -> ObjectType? in
			if obj is NSNull {
				return nil
			}
			return obj as? ObjectType
		})
	}

	/// @brief Return all of the objects belonging to the given categories
	///
	/// Returned objects are in no particular order, but do match the key order obtained by
	/// `-allKeysInCategories:`. Should any key not exist (which should never normally occur), the entry will
	/// be represented by a `nil`.
	/// - parameter catNames: list of categories
	/// - returns: An array, the list of objects indicated by the categories. May be empty.
	public func objects(inCategories catNames: [DKCategoryName]) -> [ObjectType?] {
		return (__objects(inCategories: catNames) as [AnyObject]).map({ (obj) -> ObjectType? in
			if obj is NSNull {
				return nil
			}
			return obj as? ObjectType
		})
	}
}
