//
//  MacOSATDriverServerService.swift
//  MacOSATDriverServerService
//
//  Created by Z Goddard on 12/20/23.
//

import Foundation
import os

class MacOSATDriverServerService: NSObject, MacOSATDriverServerServiceProtocol {
  let logger = Logger(subsystem: "com.bocoup.MacOSATDriverServer", category: "service")
  let client = ATDriverClientUnix()

  @objc func postSpeechEvent(speech: String) {
    logger.log("received speech event")
    do {
      try client.sendSpeechEvent(speech: speech)
    } catch {
      logger.error("error sending speech event: \(String(reflecting: error), privacy: .public)")
    }
  }

}
