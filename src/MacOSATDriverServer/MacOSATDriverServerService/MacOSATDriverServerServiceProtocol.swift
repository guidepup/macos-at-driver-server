//
//  MacOSATDriverServerServiceProtocol.swift
//  MacOSATDriverServerService
//
//  Created by Z Goddard on 12/20/23.
//

import Foundation

@objc protocol MacOSATDriverServerServiceProtocol {
  func postSpeechEvent(speech: String)
}
