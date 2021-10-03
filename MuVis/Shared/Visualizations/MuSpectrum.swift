/// MuSpectrum.swift
/// MuVis
///
/// This view renders a visualization of the muSpectrum (using a mean-square amplitude scale) of the music. I have coined the name muSpectrum for the
/// exponentially-resampled version of the spectrum to more closely represent the notes of the musical scale.
///
/// In the lower plot, the horizontal axis is exponential frequency - from the note C1 (about 33 Hz) on the left to the note B6 (about 1,976 Hz) on the right.
/// The vertical axis shows (in red) the mean-square amplitude of the instantaneous muSpectrum of the audio being played. The red peaks are spectral lines
/// depicting the harmonics of the musical notes being played - and cover six octaves. The blue curve is a smoothed average of the red curve (computed by the
/// findMean function within the SpectralEnhancer class). The blue curve typically represents percussive effects which smear spectral energy over a broad range.
///
/// In the upper plot, the green curve is simply the red curve after subtracting the blue curve. This green curve would be a good starting point for analyzing the
/// harmonic structure of an ensemble of notes being played to facilitate automated note detection.
///
/// Created by Keith Bromley on 20 Nov 2020.

import SwiftUI


struct MuSpectrum: View {

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
            
            let devGain:  CGFloat = 0.1        // devGain  is the optimum gain  value suggested by the developer
            let gain  = devGain  * settings.userGain
            var amp:  CGFloat = 0.0             // amp = amplitude + (slope * bin)
            var magY: CGFloat = 0.0             // used as a preliminary part of the "y" value
            
            var meanMuSpectrum: [Float]     = [Float](repeating: 0.0, count: totalPointCount)
            var enhancedMuSpectrum: [Float] = [Float](repeating: 0.0, count: totalPointCount)
            
// ---------------------------------------------------------------------------------------------------------------------
            // First, render the muSpectrum in red in the lower half pane:
            Path { path in
                
                path.move( to: CGPoint( x: CGFloat(0.0), y: height ) )
                
                for point in 0 ..< sixOctPointCount {
                    upRamp =  CGFloat(point) / CGFloat(sixOctPointCount)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to sixOctPointCount
                    x = upRamp * width
                    amp = gain + settings.userSlope * CGFloat(point)
                    magY = CGFloat(audioManager.muSpectrum[point]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
                    y = height - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(lineWidth: 2.0)
            .foregroundColor(.init(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0))  // foreground color = red
            .background((settings.selectedColorScheme == .light) ? Color.white : Color.black)    // Toggle between black and white background color.
            
// ---------------------------------------------------------------------------------------------------------------------
            // Second, render the mean of the muSpectrum in blue:
            Path { path in
            
                meanMuSpectrum = spectralEnhancer.findMean(inputArray: audioManager.muSpectrum)
                            
                path.move( to: CGPoint( x: CGFloat(0.0), y: height - CGFloat(meanMuSpectrum[0]) * height * gain ) )
                
                for point in 1 ..< sixOctPointCount {
                    upRamp =  CGFloat(point) / CGFloat(sixOctPointCount)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to sixOctPointCount
                    x = upRamp * width
                    amp = gain + settings.userSlope * CGFloat(point)
                    magY = CGFloat(meanMuSpectrum[point]) * halfHeight * amp
                    magY = min(max(0.0, magY), height)
                    y = height - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(lineWidth: 2.0)
            .foregroundColor(.init(red: 0.0, green: 0.0, blue: 1.0, opacity: 1.0))  // foreground color = blue


// ---------------------------------------------------------------------------------------------------------------------
            // Third, render the enhanced muSpectrum in green in the upper half pane:
            // The enhancedMuSpectrum is just the muSpectrum with the meanMuSpectrum subtracted from it.
            Path { path in
                
                enhancedMuSpectrum = spectralEnhancer.enhance(inputArray: audioManager.muSpectrum)
                
                path.move( to: CGPoint( x: CGFloat(0.0), y: halfHeight - CGFloat(enhancedMuSpectrum[0]) * height * gain ) )

                for point in 0 ..< sixOctPointCount {
                    upRamp =  CGFloat(point) / CGFloat(sixOctPointCount)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to sixOctPointCount
                    x = upRamp * width

                    amp = gain + settings.userSlope * CGFloat(point)
                    magY = CGFloat(enhancedMuSpectrum[point]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
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
            
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of MuSpectrum struct


struct MuSpectrum_Previews: PreviewProvider {
    static var previews: some View {
        MuSpectrum()
    }
}
