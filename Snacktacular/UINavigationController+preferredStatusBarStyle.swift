//
//  UINavigationController+preferredStatusBarStyle.swift
//  Snacktacular
//
//  Created by Linda Chen on 11/29/17.
//  Copyright © 2017 Synestha. All rights reserved.
//

import Foundation
import UIKit

extension UINavigationController {
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return topViewController?.preferredStatusBarStyle ?? .default
        
    }
    
}
