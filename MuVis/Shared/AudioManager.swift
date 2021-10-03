/// AudioManager.swift
/// MuVis
///
/// The AudioManager class handles the playing, capture, and processing of audio data in real time.  It uses the AVAudioEngine API to create a chain of
/// audio-procesing nodes.  If the variable micEnabled is true then the chain processes audio data from the microphone.  The chain comprises the following
/// node architecture:
///
/// microphone  ------>   micMixer  ------>  mixer ------->  mixer2 ----------> main ------->   (to speakers)
///                 node                    node        |       node                     mixer
///                                     |                                    node
///                                     v
///                                 sampling tap
///
/// The micMixer node amplifies the audio signal from the device's microphone input.
/// The mixer node is used to convert the input audio stream to monophonic and to lower the sampling rate to 11025 sps.
/// The mixer2 node sets the volume to zero when using the microphone input (preventing audio feedback)
/// The mainMixerNode is implemented automatically by the AVAudioEngine and links to the audio output (speakers).
///
/// If the variable filePlayEnabled is true then the chain processes audio data from song files selected from the device's file structure.  The chain comprises the following
/// node architecture:
///
/// (file)  ---------->  player  ---------> mixer  --------->   delay  ------->  main  -------->  (to speakers)
///             node                    node        |           node                mixer
///                                 |                                   node
///                                 v
///                             sampling tap
///
/// The player node plays the audio stream from the desired music file.
/// The mixer node is used to convert the input audio stream to monophonic and to lower the sampling rate to 11025 sps.
/// The delay node is used to introduce a delay into the audio stream (after our sampling tap) to synchronize the audio output
/// with the on-screen rendered visualizations.  It compensates for the latency of the sampling process and graphics rendering.
///
/// The mainMixerNode is implemented automatically by the AVAudioEngine and links to the audio output (speakers).
///
/// Using a sampleRate of 11,025 sps, the AVAudioEngine's sampling tap delivers blockSampleCount = 1,102 samples every 0.1 seconds.
///
/// Declared functions:
///     func setupAudio()
///     func captureOutput()
///     func ReadData()
///
/// Created by Keith Bromley on 8/21/20.



import AVFoundation
import Accelerate

class AudioManager: ObservableObject {

    static let audioManager = AudioManager() // This singleton instantiates the AudioManager class and runs the setupAudio() func
                                             //Thread 1: "required condition is false: _engine->IsRunning()"
    let spectralEnhancer = SpectralEnhancer()  // This instatiates the SpectralEnhancer class

    init() { setupAudio() }

    var selectedSongURL = Bundle.main.url(forResource: "music", withExtension: "mp3")  // Play this song when MuVis app starts.
    let sampleRate: Double = 11025.0     // We will process the audio data at 11,025 samples per second.

    var engine: AVAudioEngine!

    var blockSampleCount: Int = 0  // will be set to the number of audio samples actually captured per block
    
    var circBuffer : [Float] = [Float] (repeating: 0.0, count: circBufferLength)  // Store the most recent 5,510 samples in circBuffer.
    
    // Declare an FFT setup object for fftLength values going forward (time domain -> frequency domain):
    let fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(fftLength), vDSP_DFT_Direction.FORWARD)
    
    // Setup the FFT output variables:
    var realIn  = [Float](repeating: 0.0, count: fftLength)
    var imagIn  = [Float](repeating: 0.0, count: fftLength)
    var realOut = [Float](repeating: 0.0, count: fftLength)
    var imagOut = [Float](repeating: 0.0, count: fftLength)
    
    // Calculate a Hann window function of length fftLength:
    var hannWindow = [Float](repeating: 0, count: fftLength)

    // Setup the rms amplitude FFT output:
    var amplitudes = [Float](repeating: 0.0, count: binCount)
    
    // Declare a scaling factor to normalize the amplitude[] array:
    var scalingFactor = Float(0.011)     // 1 / sqrt(8192) = 0.011
                  
    // Declare a dispatchSemaphore for syncronizing processing between frames:
    let dispatchSemaphore = DispatchSemaphore(value: 1)
    
    // Declare a reusable array to contain the current window of audio samples as we manipulate it:
    var sampleValues: [Float] = [Float] (repeating: 0.0, count: fftLength)
    // var sampleBuffer        = [Float](repeating: 0.0, count: fftLength) // fftLength = 4_096
    // var sampleBufferHann    = [Float](repeating: 0.0, count: fftLength) // with a Hanning window applied
    
    // Declare an array to contain the binValues of the current window of audio spectral data:
    var binBuffer = [Float](repeating: 0.0, count: binCount)    // binCount = 2_048
    
    // Prepare to enhance the spectrum to the muSpectrum:
    var outputIndices   = [Float] (repeating: 0.0, count: totalPointCount)  // totalPointCount = 89 * 8 = 712
    var pointBuffer     = [Float](repeating: 0.0, count: totalPointCount)   // totalPointCount = 89 * 8 = 712
    
    // Declare arrays of the final values (for this frame) that we will publish to the various visualizations:
    @Published var halfSpectrum = [Float](repeating: 0.0, count: binCount/2)        // lower half of the spectrum of the current frame of audio samples
    @Published var muSpectrum   = [Float](repeating: 0.0, count: totalPointCount)   // totalPointCount = 89 * 8 = 712
    
    
    
    // ----------------------------------------------------------------------------------------------------------------
    //  Setup and start our audio engine:
    func setupAudio(){
    
        // Create our player, mixer, and delay nodes.  (The mainMixerNode is created automatically.)
        engine = AVAudioEngine()            // Initialize our audio engine.
        let mic = engine.inputNode          // mic inputs audio from the default microphone   // This line causes low iPhone volume
        let micMixer = AVAudioMixerNode()   // micMixer converts the microphone input to compatible signal
        let player = AVAudioPlayerNode()    // player will read and play our song file
        let mixer = AVAudioMixerNode()      // mixer will convert channelCount to mono, and sampleRate to 11,025
        let mixer2 = AVAudioMixerNode()     // mixer2 sets volume to 0 when using microphone (preventing feedback)
        let delay = AVAudioUnitDelay()      // delay will add a 0.1 seconds delay to the audio output
        
        // Before connecting nodes we need to attach them to the engine:
        engine.attach(micMixer) // mic provides audio input from the microphone
        engine.attach(player)   // player will read and play our song file
        engine.attach(mixer)    // mixer will convert channelCount to mono, and sampleRate to 11,025
        engine.attach(mixer2)   // mixer2 sets volume to 0 when using microphone (preventing audio feedback)
        engine.attach(delay)    // delay will add a 0.1 seconds delay to the audio output
        
        do {
        
            // This is an inappropriate place to put the following 3 lines, but I couldn't find any better.
            #if os(iOS)
                muSpecHistoryCount = 16  // Throttle back the graphics load for iOS devices.
            #endif
            
            let micFormat = mic.inputFormat(forBus: 0)
        
            // Player nodes have a few ways to play music, the easiest way is from an AVAudioFile
            let audioFile = try AVAudioFile(forReading: selectedSongURL!)
            
            // Capture the AVAudioFormat of our player node (It should be that of the music file.)
            let playerOutputFormat = player.outputFormat(forBus: 0)
            print("playerOutputFormat = \(playerOutputFormat)")
            
            // Define a monophonic (1 ch) and 11025 sps AVAudioFormat for the desired output of our mixer node.
            let mixerOutputFormat =  AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
            // print("mixerOutputFormat = \(String(describing: mixerOutputFormat))")
            
            // Connect our nodes in the desired order:
            if(micEnabled) {
                engine.connect(mic,     to: micMixer, format: micFormat)        // Connect microphone to mixer
                engine.connect(micMixer, to: mixer, format: micFormat)          // Connect micMixer to mixer
                engine.connect(mixer,   to: mixer2, format: mixerOutputFormat) // Connect mixer to mixer2
                engine.connect(mixer2,   to: engine.mainMixerNode, format:mixerOutputFormat) // Connect mixer2 to mainMixerNode
                mixer2.volume = 0.0 // Zeroing mixer2.volume effectively shuts off the speakers when using the microphone (but not for FilePlay).
            }
            
            if(filePlayEnabled) {
                engine.connect(player,  to: mixer, format: playerOutputFormat)  // Connect player to mixer
                engine.connect(mixer,   to: delay, format: mixerOutputFormat)   // Connect mixer to delay
                engine.connect(delay,   to: engine.mainMixerNode, format:mixerOutputFormat) // Connect delay to mainMixerNode
            
                // Confirm that the format of the delay node output is what we expect.
                let delayOutputFormat = delay.outputFormat(forBus: 0)
                // print("delayOutputFormat = \(delayOutputFormat)")
            
                player.scheduleFile(audioFile, at: nil, completionHandler: nil)     // Play the file.
            }

        }   catch let error { print(error.localizedDescription) }
        
        // Install a tap on the mixerNode to get the buffer data to use for rendering visualizations:
        // Even though I request 1024 samples, the app consistently gives me 1102 samples every 0.1 seconds.
        mixer.installTap(onBus:0, bufferSize: 1102, format: nil) { (buffer, time) in
            self.captureOutput(buffer: buffer)
            // print("actual frameLength: \(buffer.frameLength)")  // 4410 for SR=44100; 2205 for SR=22050; 1102 for SR=11025
        }
    
        engine.prepare()        // Prepare and start our audio engine:
        do { try engine.start()
        } catch { print("Unable to start AVAudioEngine: \(error.localizedDescription)")
        }
    
        // Set the parameters for our delay node:
        delay.delayTime = 0.2   // The delay is specified in seconds. Default is 1. Valid range of values is 0 to 2 seconds.
        delay.feedback = 0.0    // Percentage of the output signal fed back. Default is 50%. Valid range of values is -100% to 100%.
        delay.lowPassCutoff = 5512  // The default value is 15000 Hz. The valid range of values is 10 Hz through (sampleRate/2).
        delay.wetDryMix = 100     // Blend is specified as a percentage. Default value is 100%. Valid range is 0% (all dry) through 100% (all wet).
        
        if(filePlayEnabled) {player.play()}   // Start playing the music.
    }



    // ----------------------------------------------------------------------------------------------------------------
    func captureOutput(buffer: AVAudioPCMBuffer){
        blockSampleCount = Int(buffer.frameLength)        // number of audio samples actually captured per block (typically 1102)
        var blockSampleValues: [Float] = [Float](repeating: 0.0, count: blockSampleCount)  // one block of audio sample values
        
        // Extract the most-recent block of audio samples from the AVAudioPCMBuffer created by the AVAudioEngine
        blockSampleValues  = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count:Int(buffer.frameLength)))
        
        // Write the most-recent block of audio samples into our circBuffer:
        for sample in 0 ..< blockSampleCount {
            // At this time instance, "index" points to the most recent sample written into our circBuffer.
            index += 1  // This is the "index" for the sample that is about to be written into our circBuffer.
            if (index >= circBufferLength) { index = 0 }      // index will always be less than circBufferLength
            circBuffer[index] = blockSampleValues[sample]
        }
        readData()
    }  // end of captureOutput func



    // ----------------------------------------------------------------------------------------------------------------
    // After the first 5 frames of audio data, the AudioManager has filled the circBuffer with the most-recent
    // 5 * 1102 = 5510 audio samples with "index" pointing to the most-recent sample.
    // Now we can read the data out of this circular buffer into the 4096-element sampleValues array.
    
    func readData() {
    
        // Fill the sampleValues array with the most recent fftLength audio values from the circBuffer:
        // At this time instance, "index" points to the most-recent sample written into the circBuffer.
        let tempIndex1 = (index - fftLength >= 0) ? index - fftLength : index - fftLength + circBufferLength
        
        for sample in 0 ..< fftLength {
            let tempIndex2 = (tempIndex1 + sample) % circBufferLength  // We needed to account for wrap-around at the circBuffer ends
            sampleValues[sample] = self.circBuffer[tempIndex2]
        }
        processData()   // This func is located in the AudioManager extension.
    }  // end of readData() func


    // ----------------------------------------------------------------------------------------------------------------
    // Now we can start processing and rendering this audio data:
    func processData() {
    
        dispatchSemaphore.wait()  // Wait until receiving a semaphore indicating that the processing of data from the previous frame is complete
        
        vDSP_hann_window(&hannWindow, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))

        // Fill the real input part (&realIn) with audio data from the AudioManager (multiplied by the Hann window):
        vDSP_vmul(sampleValues, 1, hannWindow, vDSP_Stride(1), &realIn, vDSP_Stride(1), vDSP_Length(fftLength))

        // Execute the FFT.  The results are now inside the realOut[] and imagOut[] arrays:
        vDSP_DFT_Execute(fftSetup!, &realIn, &imagIn, &realOut, &imagOut)
        
        // Package the FFT results inside a complex vector representation used in the vDSP framework:
        var complex = DSPSplitComplex(realp: &realOut, imagp: &imagOut)

        // Calculate the rms amplitude FFT results:
        vDSP_zvabs(&complex, vDSP_Stride(1), &amplitudes, vDSP_Stride(1),  vDSP_Length(binCount))

        // Normalize the rms amplitudes to be within the range 0.0 to 1.0:
        vDSP_vsmul(&amplitudes, 1, &scalingFactor, &binBuffer, 1, vDSP_Length(binCount))

        let binWidth: Float = ( Float(sampleRate) / 2.0 ) / Float(binCount)     //  (11,025/2) / 2,048 = 2.69165 Hz

        // Compute the pointBuffer[] (precursor to the muSpectrum[]):
        // This uses pointsPerNote = 8, so the pointBuffer has size totalPointCount = 89 * 8 = 712
        for point in 0 ..< totalPointCount {
            outputIndices[point] = (leftFreqC1 * pow(2.0, Float(point) / Float(notesPerOctave * pointsPerNote))) / binWidth
        }
        vDSP_vqint(binBuffer, &outputIndices, vDSP_Stride(1), &pointBuffer, vDSP_Stride(1), vDSP_Length(totalPointCount) , vDSP_Length(binCount))

        dispatchSemaphore.signal()  // Transmit a semaphore indicating that the processing of data from this frame is complete
        
        publishData()

    } // end of processData() func



    func publishData() {
        DispatchQueue.main.async { [self] in
            halfSpectrum = binBuffer            // This is wastefull copying of the binBuffer    to enable publishing it.
            muSpectrum   = pointBuffer          // This is wastefull copying of the pointBuffer  to enable publishing it.
        }
    }  // end of publishData func


}  // end of AudioManager class
