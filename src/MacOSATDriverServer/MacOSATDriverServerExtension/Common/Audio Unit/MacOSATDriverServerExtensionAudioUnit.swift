//
//  MacOSATDriverServerExtensionAudioUnit.swift
//  MacOSATDriverServerExtension
//
//  Created by Z Goddard on 12/14/23.
//

// NOTE:- An Audio Unit Speech Extension (ausp) is rendered offline, so it is safe to use
// Swift in this case. It is not recommended to use Swift in other AU types.

import AVFoundation
import Darwin
import Foundation
import os

public class MacOSATDriverServerExtensionAudioUnit: AVSpeechSynthesisProviderAudioUnit
{
    private static let voiceIdentifier =
        "com.bocoup.MacOSATDriverServer.MacOSATDriverServerExtension.MacOSATDriverServerExtension"
    private let logger = Logger(subsystem: "com.bocoup.MacOSATDriverServer", category: "audio-unit")
    private var messenger = NSXPCConnection(serviceName: "com.bocoup.MacOSATDriverServerService")

    private var outputBus: AUAudioUnitBus
    private var _outputBusses: AUAudioUnitBusArray!
    
    private var request: AVSpeechSynthesisProviderRequest?

    private var format:AVAudioFormat

    @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        let basicDescription = AudioStreamBasicDescription(mSampleRate: 22050.0,
														   mFormatID: kAudioFormatLinearPCM,
														   mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
														   mBytesPerPacket: 4,
														   mFramesPerPacket: 1,
														   mBytesPerFrame: 4,
														   mChannelsPerFrame: 1,
														   mBitsPerChannel: 32,
														   mReserved: 0);

        self.format = AVAudioFormat(cmAudioFormatDescription: try! CMAudioFormatDescription(audioStreamBasicDescription: basicDescription));

        outputBus = try AUAudioUnitBus(format: self.format)
        try super.init(componentDescription: componentDescription, options: options)
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus])
        
        messenger.remoteObjectInterface = NSXPCInterface(with: MacOSATDriverServerServiceProtocol.self)
        messenger.interruptionHandler = { [logger] in
            logger.error("XPC service interrupted")
        }
        messenger.invalidationHandler = { [logger] in
            logger.error("XPC service invalidated")
        }
        messenger.resume()
        logger.log("initialized")
    }
    
    public override var channelCapabilities: [NSNumber]? {
        // Specifies that the Audio Unit supports no input channels and exactly one output channel.
        return [0, 1]
    }

    deinit {
        messenger.invalidate()
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }
    
    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
    }

	// MARK:- Rendering
	/*
	 NOTE:- It is only safe to use Swift for audio rendering in this case, as Audio Unit Speech Extensions process offline. 
	 (Swift is not usually recommended for processing on the realtime audio thread)
	 */
    public override var internalRenderBlock: AUInternalRenderBlock
    {
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputAudioBufferList, _, _ in
            // this is the audio buffer we are going to fill up
            let unsafeBuffer = UnsafeMutableAudioBufferListPointer(outputAudioBufferList)[0];
            let frames = unsafeBuffer.mData!.assumingMemoryBound(to: Float32.self)
        
            for frame in 0..<frameCount {
                frames[Int(frame)] = 0.0;
            }
            
            actionFlags.pointee = .offlineUnitRenderAction_Complete;
            
            return noErr;
           
        }
    }
    
    public override func synthesizeSpeechRequest(_ speechRequest: AVSpeechSynthesisProviderRequest) {
        logger.log("synthesizeSpeechRequest")
        logger.log("SSML: \(speechRequest.ssmlRepresentation, privacy: .public)")

        self.request = speechRequest
        let speechText: String
        if let utterance = AVSpeechUtterance(ssmlRepresentation: speechRequest.ssmlRepresentation) {
            speechText = utterance.speechString
        } else {
            let ssml = speechRequest.ssmlRepresentation
            if let data = ssml.data(using: .utf8),
               let document = try? XMLDocument(data: data, options: []),
               let text = document.stringValue,
               !text.isEmpty {
                speechText = text
            } else {
                speechText = ssml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            }
        }

        guard !speechText.isEmpty else {
            logger.error("could not extract speech text from provider request")
            return
        }

        logger.log("speech text: \(speechText, privacy: .public)")
        do {
            try sendSpeechEvent(speechText)
        } catch {
            logger.error("direct socket send failed: \(String(reflecting: error), privacy: .public)")
        }
        
        if let proxy = messenger.remoteObjectProxy as? MacOSATDriverServerServiceProtocol {
            proxy.postSpeechEvent(speech: speechText)
        } else {
            logger.error("XPC service proxy unavailable")
        }
    }

    private func sendSpeechEvent(_ speech: String) throws {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { close(descriptor) }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = "/tmp/at_driver_generic/driver.socket"
        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENAMETOOLONG))
        }
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            bytes.initializeMemory(as: CChar.self, repeating: 0)
            for (index, byte) in pathBytes.enumerated() {
                if index >= bytes.count { break }
                bytes[index] = UInt8(byte)
            }
        }

        let addressLength = socklen_t(MemoryLayout.size(ofValue: address))
        try withUnsafePointer(to: &address) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                guard connect(descriptor, socketAddress, addressLength) >= 0 else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
            }
        }

        let message = "speech:\(speech)"
        try message.utf8CString.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            guard write(descriptor, baseAddress, strlen(baseAddress)) >= 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }
        logger.log("direct socket speech event sent")
    }
    
    public override func cancelSpeechRequest() {
        logger.log("cancelSpeechRequest")
        self.request = nil
    }
    
    public override var speechVoices: [AVSpeechSynthesisProviderVoice] {
        get {
            defer {
                logger.log("speechVoices")
            }
            return [
            AVSpeechSynthesisProviderVoice(name: "MacOSATDriverServerExtensionVoice", identifier: Self.voiceIdentifier, primaryLanguages: ["en-US"], supportedLanguages: ["en-US"])
            ]
        }
        set { }
    }
    
}
