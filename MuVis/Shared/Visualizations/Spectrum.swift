///  Spectrum.swift
///  MuVis
///
/// This view renders a visualization of the simple one-dimensional spectrum (using a mean-square amplitude scale) of the music. To be more accurate is renders a
/// halfSpectrum in that it renders only the first 1,024 of the 2,048 bins.
///
/// In the lower plot, the horizontal axis is linear frequency (from 0 Hz on the left to about 5512 / 2 = 2,756 Hz on the right). The vertical axis shows (in red) the
/// mean-square amplitude of the instantaneous spectrum of the audio being played. The red peaks are spectral lines depicting the harmonics of the musical notes
/// being played. The blue curve is a smoothed average of the red curve (computed by the findMean function within the SpectralEnhancer class).
/// The blue curve typically represents percussive effects which smear spectral energy over a broad range.
///
/// The upper plot (in green) is the same as the lower plot except the vertical scale is decibels (over an 80 dB range) instead of the mean-square amplitude.
/// This more closely represents what the human ear actually hears.
///
/// Created by Keith Bromley on 20 Nov 2020.

import SwiftUI


struct Spectrum: View {

    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    var spectralEnhancer = SpectralEnhancer()
    
    var body: some View {
    
        GeometryReader { geometry in

            let width: CGFloat  = geometry.size.width
            let height: CGFloat = geometry.size.height
            let halfHeight: CGFloat = height * 0.5

            var x: CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y: CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp: CGFloat = 0.0
            var spectrumRange: Int = 0
            var dB: Float = 0.0
            let dBmin: Float =  1.0 + 0.0125 * 20.0 * log10(0.001)
            var backgroundColor: Color = Color.black
            var amplitude: Float = 0.0
            
            let devGain:  CGFloat = 0.5         // devGain  is the optimum gain  value suggested by the developer
            let gain  = devGain * settings.userGain
            var amp:  CGFloat = 0.0             // amp = amplitude + (slope * bin)
            var magY: CGFloat = 0.0             // used as a preliminary part of the "y" value
            
            var meanSpectrum: [Float] = [Float](repeating: 0.0, count: binCount/2)  // the mean spectrum of the current frame of audio samples
            var dB_Spectrum:  [Float] = [Float](repeating: 0.0, count: binCount/2)  // the dB-scale spectrum
            
            
// ---------------------------------------------------------------------------------------------------------------------
            // First, render the rms amplitude spectrum in red in the lower half pane:
            // We will only render the first 1024 of the 2048 bins.  Thus, highest frequency is 11,025 / 4 = 2,756 Hz
            Path { path in
                
                path.move( to: CGPoint( x: CGFloat(0.0), y: height ) )
                
                spectrumRange = binCount/2  // This renders the lowest half of the full spectrum (0 <= bin < 2048/2)
                
                for bin in 0 ..< spectrumRange {
                    upRamp =  CGFloat(bin) / CGFloat(spectrumRange)   // upRamp goes from 0.0 to 1.0 as bin goes from 0 to spectrumRange
                    x = upRamp * width
                    amp = gain + settings.userSlope * CGFloat(bin)
                    magY = CGFloat(audioManager.halfSpectrum[bin]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
                    y = height - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                backgroundColor = (settings.selectedColorScheme == .dark) ? Color.black : Color.white
                
            }
            .stroke(lineWidth: 2.0)
            .foregroundColor(.init(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0))  // foreground color = red
            .background(backgroundColor)    // Toggle between black and white background color.
            
            
// ---------------------------------------------------------------------------------------------------------------------
            // Second, render the mean of the rms amplitude spectrum in blue:
            // We will only render the first 1024 of the 2048 bins.  Thus, highest frequency is 11,025 / 4 = 2,756 Hz
            Path { path in
            
                meanSpectrum = spectralEnhancer.findMean(inputArray: audioManager.halfSpectrum)
                            
                path.move( to: CGPoint( x: CGFloat(0.0), y: height - CGFloat(meanSpectrum[0]) * height * gain ) )
                spectrumRange = binCount/2  // This renders the lowest half of the full spectrum (0 <= bin < 2048/2)
                
                for bin in 1 ..< spectrumRange {
                    upRamp =  CGFloat(bin) / CGFloat(spectrumRange)   // upRamp goes from 0.0 to 1.0 as bin goes from 0 to spectrumRange
                    x = upRamp * width
                    amp = gain + settings.userSlope * CGFloat(bin)
                    magY = CGFloat(meanSpectrum[bin]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
                    y = height - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(lineWidth: 2.0)
            .foregroundColor(.init(red: 0.0, green: 0.0, blue: 1.0, opacity: 1.0))  // foreground color = blue


// ---------------------------------------------------------------------------------------------------------------------
            // Third, render the decibel-scale spectrum in green in the upper half pane:
            // We will only render the first 1024 of the 2048 bins.  Thus, highest frequency is 11,025 / 4 = 2,756 Hz
            Path { path in
                
                path.move( to: CGPoint( x: CGFloat(0.0), y: halfHeight ) )

                spectrumRange = binCount/2  // This renders the lowest half of the full spectrum (0 <= bin < 2048/2)

                for bin in 0 ..< spectrumRange {
                    upRamp =  CGFloat(bin) / CGFloat(spectrumRange)   // upRamp goes from 0.0 to 1.0 as bin goes from 0 to spectrumRange
                    x = upRamp * width

                    
                    // I must raise 10 to the power of -4 to get my lowest dB value (0.001) to 20*(-4) = 80 dB
                    amplitude = audioManager.halfSpectrum[bin]
                    if(amplitude < 0.001) { amplitude = 0.001 }
                    dB = 20.0 * log10(amplitude)    // As 0.001  < spectrum < 1 then  -80 < dB < 0
                    dB = 1.0 + 0.0125 * dB          // As 0.001  < spectrum < 1 then    0 < dB < 1
                    dB = dB - dBmin
                    dB = min(max(0.0, dB), 1.0)
                    dB_Spectrum[bin] = dB           // We use this array below in creating the mean spectrum
                    amp = (1.5 * gain) + (settings.userSlope * CGFloat(bin))
                    magY = CGFloat(dB) * halfHeight * amp
                    y = halfHeight - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                /*
                // Performance monitor:
                let timePassed: Double = -settings.date.timeIntervalSinceNow  // Find elapsed time since last timer reset.
                
                // Insert most-recent timeInterval into the array (over-writing the oldest timeInterval):
                settings.pointer = (settings.pointer  < 9) ? settings.pointer + 1 : 0
                settings.timePassedForLastTenFrames[settings.pointer] = timePassed
                
                var sum: Double = 0.0
                for i in 0 ..< 10 {
                    sum += settings.timePassedForLastTenFrames[i]
                }

                let period: Double = 0.1 * 1000.0 * sum     // period (in milliseconds)
                print("msPerFrame: \( lround( period) )")   // lround() rounds to nearest int and returns that Int.
                settings.date = NSDate()                    // Reset the timer to the current time.
                */
                
            }
            .stroke(lineWidth: 2.0)
            .foregroundColor(.init(red: 0.0, green: 1.0, blue: 0.0, opacity: 1.0))  // foreground color = green
            
            
// ---------------------------------------------------------------------------------------------------------------------
            // Fourth, render the mean of the decibel-scale spectrum in blue:
            // We will only render the first 1024 of the 2048 bins.  Thus, highest frequency is 11,025 / 4 = 2,756 Hz
            Path { path in
            
                meanSpectrum = spectralEnhancer.findMean(inputArray: dB_Spectrum)
                            
                path.move( to: CGPoint( x: CGFloat(0.0), y: halfHeight - CGFloat(meanSpectrum[0]) * halfHeight * gain ) )
                spectrumRange = binCount/2  // This renders the lowest half of the full spectrum (0 <= bin < 2048/2)
                
                for bin in 1 ..< spectrumRange {
                    upRamp =  CGFloat(bin) / CGFloat(spectrumRange)   // upRamp goes from 0.0 to 1.0 as bin goes from 0 to spectrumRange
                    x = upRamp * width
                    amp = gain + settings.userSlope * CGFloat(bin)
                    magY = CGFloat(meanSpectrum[bin]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(lineWidth: 2.0)
            .foregroundColor(.init(red: 0.0, green: 0.0, blue: 1.0, opacity: 1.0))  // foreground color = blue
            
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of Spectrum struct



struct Spectrum_Previews: PreviewProvider {
    static var previews: some View {
        Spectrum()
    }
}
