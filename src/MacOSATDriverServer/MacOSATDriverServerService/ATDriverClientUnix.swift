//
//  ATDriverClientUnix.swift
//  MacOSATDriverServer
//
//  Created by Z Goddard on 1/4/24.
//

import Foundation

class ATDriverClientUnix {

  class SocketResource {
    var descriptor: Int32
    init() throws {
      descriptor = socket(
        AF_UNIX,
        SOCK_STREAM,
        0)
      guard descriptor > -1 else {
        throw ATDriverEventError.badSocketSettings(posixErrorString())
      }
    }
    deinit {
      close(descriptor)
    }
  }

  static let pipe = "/tmp/at_driver_generic/driver.socket"

  func sendSpeechEvent(speech: String) throws {
    try self._sendEvent(name: "speech", data: speech)
  }

  func _connect() throws -> SocketResource {
    let socket = try SocketResource()

    var unixAddr = sockaddr_un()
    let pathSize = size_t(MemoryLayout.size(ofValue: unixAddr.sun_path))
    unixAddr.sun_family = sa_family_t(AF_UNIX)
    ATDriverClientUnix.pipe.withCString { pipeAddress in
      withUnsafeMutableBytes(of: &unixAddr.sun_path) { pathBytes in
        pathBytes.initializeMemory(as: UInt8.self, repeating: 0)
        let destination = pathBytes.bindMemory(to: CChar.self)
        var index = 0
        while index < pathSize && pipeAddress[index] != 0 {
          destination[index] = pipeAddress[index]
          index += 1
        }
      }
    }

    let unixAddrSize = socklen_t(MemoryLayout.size(ofValue: unixAddr))
    // Get UnsafePointer to addr
    try withUnsafePointer(to: &unixAddr) { unsafeUnixAddr in
      // Cast UnsafePointer<sockaddr_un> to UnsafePointer<sockaddr>
      try unsafeUnixAddr.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
        guard connect(socket.descriptor, addr, unixAddrSize) > -1 else {
          throw ATDriverEventError.didNotConnect(posixErrorString())
        }
      }
    }

    return socket
  }

  func _makeMessage(name: String, data: String) -> String {
    return "\(name):\(data)"
  }

  func _sendEvent(name: String, data: String) throws {
    let socket = try _connect()

    let message = _makeMessage(name: name, data: data)

    try message.utf8CString.withUnsafeBufferPointer { unsafeMessageBuffer in
      let unsafeMessage = unsafeMessageBuffer.baseAddress!
      guard write(socket.descriptor, unsafeMessage, strlen(unsafeMessage)) > -1 else {
        throw ATDriverEventError.sendFailure(posixErrorString())
      }
    }
  }
}
