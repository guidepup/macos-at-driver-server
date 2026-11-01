//
//  MacOSATDriverServerExtensionAudioUnit.swift
//  MacOSATDriverServerExtension
//
//  Created by Z Goddard on 12/14/23.
//

// NOTE:- An Audio Unit Speech Extension (ausp) is rendered offline, so it is safe to use
// Swift in this case. It is not recommended to use Swift in other AU types.

import AVFoundation
import os

public class MacOSATDriverServerExtensionAudioUnit: AVSpeechSynthesisProviderAudioUnit
{
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

        self.request = speechRequest
        guard let utterance = AVSpeechUtterance(ssmlRepresentation: speechRequest.ssmlRepresentation) else {
            logger.error("could not parse speech request")
            return
        }
        
        if let proxy = messenger.remoteObjectProxy as? MacOSATDriverServerServiceProtocol {
            proxy.postSpeechEvent(speech: utterance.speechString)
        }
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
            AVSpeechSynthesisProviderVoice(name: "MacOSATDriverServerExtensionVoice", identifier: "MacOSATDriverServerExtension", primaryLanguages: ["en-US"], supportedLanguages: ["en-US"])
            ]
        }
        set { }
    }
    
}
