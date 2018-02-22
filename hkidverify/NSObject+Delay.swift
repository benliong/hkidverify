//
//  NSObject+Delay.swift
//  gaifong
//
//  Created by Ben Liong on 12/1/2018.
//  Copyright © 2018 Gaifong (HK) Limited. All rights reserved.
//

import UIKit

typealias SimpleCompletionClosure = () -> Void

extension NSObject {
    func delay(delay:Double, completion:@escaping SimpleCompletionClosure) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
            completion()
        })
    }
}
