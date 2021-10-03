/// Harmonograph.swift
/// MuVis
///
/// I have long sought to develop a music-visualization scheme that readily displays the harmonic relationship of the frequencies being played. My inspiration comes
/// from Lissajous figures generated by applying sinusoidal waveforms to the vertical and horizontal inputs of an oscilloscope. Inputs of the same frequency generate
/// elliptical curves (including circles and lines). Inputs of different frequencies, where one is an integer multiple of the other, generate "twisted" ellipses.
/// A frequency ratio of 3:1 produces a "twisted ellipse" with 3 major lobes. A frequency ratio of 5:4 produces a curve with 5 horizontal lobes and 4 vertical lobes.
/// Such audio visualizations are both aesthetically pleasing and highly informative.
///
/// Over the past several years, I have implemented many many such visualizations and applied them to analyzing music. Unfortunately, most suffered from being
/// overly complex, overly dynamic, and uninformative. In my humble opinion, this Harmonograph visualization strikes the right balance between simplicity (i.e., the
/// ability to appreciate the symmetry of harmonic relationships) and dynamics that respond promptly to the music.
///
/// The wikipedia article at https://en.wikipedia.org/wiki/Harmonograph describes a double pendulum apparatus, called a Harmonograph, that creates
/// Lissajous figures from mixing two sinusoidal waves of different frequencies and phases. This Harmonograph visualization uses just the two loudest spectrum
/// peaks to produce the Lissajous figure. That is, the loudest peak generates a sine wave of its frequency to drive the horizontal axis of our visual oscilloscope,
/// and the second-loudest peak generates a sine wave of its frequency to drive the vertical axis.
///
/// For a pleasing effect, the Harmonograph Lissajous figure is rendered on top of a simplified TriOctSpectrum visualization.
///
/// Created by Keith Bromley on 29/ Nov 2020.

import SwiftUI


struct Harmonograph: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Harmonograph_DoubleSpectrum()
                LissajousFigure()
            }
        }
    }
}



struct Harmonograph_DoubleSpectrum : View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        GeometryReader { geometry in
        
            let width  : CGFloat = geometry.size.width
            let height : CGFloat = geometry.size.height
            let halfHeight : CGFloat = height * 0.5
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp : CGFloat = 0.0
            let devGain:  CGFloat = 0.3     // devGain  is the optimum gain  value suggested by the developer
            let gain = devGain * settings.userGain
            var amp:  CGFloat = 0.0     // amp = amplitude + (slope * bin)
            var magY: CGFloat = 0.0     // used as a preliminary part of the "y" value
            var backgroundColor: Color = Color.black
            let octavesPerRow : Int = 3
            let pointsPerRow : Int = pointsPerNote * notesPerOctave * octavesPerRow  //  12 * 12 * 3 = 432
            
// ---------------------------------------------------------------------------------------------------------------------
            // Before rendering any live data, let's paint the underlying graphics layer with a time-varying color:
            
            let colorSize: Int = 500    // This determines the frequency of the color change over time.
            var hue:  Double = 0.0
            
            Path { path in
                path.move   ( to: CGPoint( x: 0.0,  y: 0.0   ) )        // top left
                path.addLine( to: CGPoint( x: width,y: 0.0   ) )        // top right
                path.addLine( to: CGPoint( x: width,y: height) )        // bottom right
                path.addLine( to: CGPoint( x: 0.0,  y: height) )        // bottom left
                path.addLine( to: CGPoint( x: 0.0,  y: 0.0   ) )        // top left
                path.closeSubpath()
                
                settings.colorIndex = (settings.colorIndex >= colorSize) ? 0 : settings.colorIndex + 1
                hue = Double(settings.colorIndex) / Double(colorSize)          // 0.0 <= hue < 1.0
            }
            .foregroundColor(Color(hue: hue, saturation: 1.0, brightness: 0.9))  // Deliberately slightly dim to serve as background

// ---------------------------------------------------------------------------------------------------------------------
            // Render a black/white blob over the lower half-pane but exposing the spectrum of the lower three octaves:
            Path { path in
            
                path.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
                path.addLine( to: CGPoint( x: width, y: height))        // right bottom
                path.addLine( to: CGPoint( x: 0.0,   y: height))        // left bottom
                path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
                
                for point in 1 ..< pointsPerRow {
                    upRamp =  CGFloat(point) / CGFloat(pointsPerRow)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerRow
                    x = upRamp * width
                    
                    amp = gain + settings.userSlope * CGFloat(point)
                    magY = CGFloat(audioManager.muSpectrum[point]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight + magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine( to: CGPoint( x: width, y: halfHeight ) )
                path.closeSubpath()
                backgroundColor = (settings.selectedColorScheme == .dark) ? Color.black : Color.white
            }
            .foregroundColor(backgroundColor)  // Toggle between black and white background color.
        
// ---------------------------------------------------------------------------------------------------------------------
            // Render a black/white blob over the upper half-pane but exposing the spectrum of the upper three octaves:
            Path { path in
                path.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
                path.addLine( to: CGPoint( x: width, y: 0.0))           // right top
                path.addLine( to: CGPoint( x: 0.0,   y: 0.0))           // left top
                path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
                
                for point in 1 ..< pointsPerRow {
                    upRamp =  CGFloat(point) / CGFloat(pointsPerRow)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerRow
                    x = upRamp * width
                    
                    amp = gain + settings.userSlope * CGFloat(pointsPerRow + point)
                    magY = CGFloat(audioManager.muSpectrum[pointsPerRow + point]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine( to: CGPoint( x: width, y: halfHeight ) )
                path.closeSubpath()
                backgroundColor = (settings.selectedColorScheme == .dark) ? Color.black : Color.white
            }
            .foregroundColor(backgroundColor)  // Toggle between black and white background color.
            
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of DoubleSpectrum struct

// ---------------------------------------------------------------------------------------------------------------------
// Render the Lissajous figures.  This allows us to use Path{} to perform some computations.
struct LissajousFigure : View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    var spectralEnhancer = SpectralEnhancer()
    
    var body: some View {
        GeometryReader { geometry in
        
            let width  : CGFloat = geometry.size.width
            let height : CGFloat = geometry.size.height
            let halfWidth : CGFloat  = width * 0.5
            let halfHeight : CGFloat = height * 0.5
            let dataLength: Int = 160                   // Looks aesthetically pleasing
    
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            let threshold: Float = 0.02
            let binFreqWidth: Double = (audioManager.sampleRate / 2.0 ) / Double(binCount)  // (11,025/2) / 2,048 = 2.69165 Hz
            
            let devGain:  CGFloat = 0.3     // devGain  is the optimum gain  value suggested by the developer
            let gain = devGain * settings.userGain    // userGain multiplies devGain by a slider value from 0.0 to 2.0
            
            let startBin: Int =  12     // bin12  frequency =   32 Hz
            let midBin:   Int =  95     // bin95  frequency =  254 Hz
            let endBin:   Int = 755     // bin755 frequency = 2033 Hz
            
            var peaks: [Bool] = [Bool](repeating: false, count: binCount/2)
            var lowerPeakCount: Int = 0
            var upperPeakCount: Int = 0
            
            var period: Double = 1.0
            var angle: Double = 0.0
            var peakAmplitude: Double = 0.0
            
            var maxPeakAmplitude_L1: Double = 0.0    // loudest peak amplitude in lower 3 octaves
            var maxPeakAmplitude_L2: Double = 0.0    // next-loudest peak amplitude in lower 3 octaves
            var maxPeakAmplitude_U1: Double = 0.0    // loudest peak amplitude in upper 3 octaves
            var maxPeakAmplitude_U2: Double = 0.0    // next-loudest peak amplitude in upper 3 octaves
            var maxPeakBin_L1: Int = 0          // loudest peak binNum in lower 3 octaves
            var maxPeakBin_L2: Int = 0          // next-loudest peak binNum in lower 3 octaves
            var maxPeakBin_U1: Int = 0          // loudest peak binNum in upper 3 octaves
            var maxPeakBin_U2: Int = 0          // next-loudest peak binNum in upper 3 octaves
            var maxPeakFrequency_L1: Double = 0.0   // loudest peak frequency in lower 3 octaves
            var maxPeakFrequency_L2: Double = 0.0   // next-loudest peak frequency in lower 3 octaves
            var maxPeakFrequency_U1: Double = 0.0   // loudest peak frequency in upper 3 octaves
            var maxPeakFrequency_U2: Double = 0.0   // next-loudest peak frequency in upper 3 octaves

            var horWaveform: [CGFloat] = [CGFloat](repeating: 0.0, count: dataLength)   // horizontal waveform
            var verWaveform: [CGFloat] = [CGFloat](repeating: 0.0, count: dataLength)   // vertical waveform
                        
            
            Path { path in

                // Use pickPeaks() to identify the spectrum values above a threshold and > the 3 peaks on either side:
                peaks = spectralEnhancer.pickPeaks(inputArray: audioManager.halfSpectrum, peakThreshold: threshold)
                
// --------------------------------------------------------------------------------------------------------------------
                // In the lower 3 octaves, find the loudest peak and the next-loudest peak:
                lowerPeakCount = 0
                maxPeakAmplitude_L1 = 0.0
                for binNum in startBin ..< midBin {
                    if (peaks[binNum]) {
                        lowerPeakCount  += 1
                        peakAmplitude = Double( audioManager.halfSpectrum[binNum] )
                        if(peakAmplitude > maxPeakAmplitude_L1) {maxPeakAmplitude_L1 = peakAmplitude; maxPeakBin_L1 = binNum}
                    }
                }
                maxPeakFrequency_L1 = Double(maxPeakBin_L1) * binFreqWidth
                // After this loop, we've found lowerPeakCount, maxPeakBin_L1, maxPeakFrequency_L1, and maxPeakAmplitude_L1.


                // Now perform the same operation again to get the next-loudest peak in the lower 3 octaves:
                maxPeakAmplitude_L2 = 0.0
                for binNum in startBin ..< midBin {
                    if (peaks[binNum]) {
                        if(binNum == maxPeakBin_L1) { continue }  // Ignore the maxPeakBin_L1 that we have just found
                        peakAmplitude = Double( audioManager.halfSpectrum[binNum] )
                        if(peakAmplitude > maxPeakAmplitude_L2) {maxPeakAmplitude_L2 = peakAmplitude; maxPeakBin_L2 = binNum}
                    }
                }
                maxPeakFrequency_L2 = Double(maxPeakBin_L2) * binFreqWidth
                // After this loop, we've found maxPeakBin_L2, maxPeakFrequency_L2, and maxPeakAmplitude_L2.

                
// --------------------------------------------------------------------------------------------------------------------
                // In the upper 3 octaves, find the loudest peak and the next-loudest peak:
                upperPeakCount = 0
                maxPeakAmplitude_U1 = 0.0           // amplitude of the loudest peak
                for binNum in midBin ..< endBin {
                    if (peaks[binNum]) {
                        upperPeakCount += 1
                        peakAmplitude = Double( audioManager.halfSpectrum[binNum] )
                        if(peakAmplitude > maxPeakAmplitude_U1) {maxPeakAmplitude_U1 = peakAmplitude; maxPeakBin_U1 = binNum}
                    }
                }
                maxPeakFrequency_U1 = Double(maxPeakBin_U1) * binFreqWidth
                // After this loop, we've found upperPeakCount, maxPeakBin_U1, maxPeakFrequency_U1, and maxPeakAmplitude_U1.
                    
                // Now perform the same operation again to get the next-loudest peak in the upper 3 octaves:
                maxPeakAmplitude_U2 = 0.0           // amplitude of the next-loudest peak
                for binNum in startBin ..< midBin {
                    if (peaks[binNum]) {
                        if(binNum == maxPeakBin_U1) { continue }  // Ignore the maxPeakBin_U1 that we have just found
                        peakAmplitude = Double( audioManager.halfSpectrum[binNum] )
                        if(peakAmplitude > maxPeakAmplitude_U2) {maxPeakAmplitude_U2 = peakAmplitude; maxPeakBin_U2 = binNum}
                    }
                }
                maxPeakFrequency_U2 = Double(maxPeakBin_U2) * binFreqWidth
                // After this loop, we've found maxPeakBin_U2, maxPeakFrequency_U2, and maxPeakAmplitude_U2.
                  
// ------------------------------------------------------------------------------------------------------------
                // Now generate a sinusoidal waveform for these peaks:
                
                if(lowerPeakCount > 0 && upperPeakCount > 0)    // There is at least one peak in each of the lower and upper 3 octaves.
                {
                    period = audioManager.sampleRate / maxPeakFrequency_L1
                    for i in 0 ..< dataLength {
                        angle = settings.oldHorAngle + ( 2.0 * Double.pi * Double(i) / period )
                        horWaveform[i] = CGFloat(maxPeakAmplitude_L1) * CGFloat( sin(angle) )
                    }
                    settings.oldHorAngle = angle  // persistent:   Maintains phase of horWaveform across frames

                    period = audioManager.sampleRate / maxPeakFrequency_U1
                    for i in 0 ..< dataLength {
                        angle = settings.oldVerAngle + ( 2.0 * Double.pi * Double(i) / period )
                        verWaveform[i] = CGFloat(maxPeakAmplitude_U1) * CGFloat( sin(angle) )
                    }
                    settings.oldVerAngle = angle  // persistent:   Maintains phase of verWaveform across frames
                }


                else if(lowerPeakCount < 1 && upperPeakCount > 1)    // No peak in lower 3 octaves, so we must use 2 peaks from upper 3 octaves.
                {
                    period = audioManager.sampleRate / maxPeakFrequency_U1
                    for i in 0 ..< dataLength {
                        angle = settings.oldHorAngle + ( 2.0 * Double.pi * Double(i) / period )
                        horWaveform[i] = CGFloat(maxPeakAmplitude_U1) * CGFloat( sin(angle) )
                    }
                    settings.oldHorAngle = angle  // persistent:   Maintains phase of horWaveform across frames

                    period = audioManager.sampleRate / maxPeakFrequency_U2
                    for i in 0 ..< dataLength {
                        angle = settings.oldVerAngle + ( 2.0 * Double.pi * Double(i) / period )
                        verWaveform[i] = CGFloat(maxPeakAmplitude_U2) * CGFloat( sin(angle) )
                    }
                    settings.oldVerAngle = angle  // persistent:   Maintains phase of verWaveform across frames
                }

                else if(lowerPeakCount > 1 && upperPeakCount < 1)    // No peak in upper 3 octaves, so we must use 2 peaks from lower 3 octaves.
                {
                    period = audioManager.sampleRate / maxPeakFrequency_L1
                    for i in 0 ..< dataLength {
                        angle = settings.oldHorAngle + ( 2.0 * Double.pi * Double(i) / period )
                        horWaveform[i] = CGFloat(maxPeakAmplitude_L1) * CGFloat( sin(angle) )
                    }
                    settings.oldHorAngle = angle  // persistent:   Maintains phase of horWaveform across frames

                    period = audioManager.sampleRate / maxPeakFrequency_L2
                    for i in 0 ..< dataLength {
                        angle = settings.oldVerAngle + ( 2.0 * Double.pi * Double(i) / period )
                        verWaveform[i] = CGFloat(maxPeakAmplitude_L2) * CGFloat( sin(angle) )
                    }
                    settings.oldVerAngle = angle  // persistent:   Maintains phase of verWaveform across frames
                }

                // Finally, generate the Lissajous figure from these horizonatal and vertical waveforms:
                x = halfWidth  + (halfWidth  * gain * horWaveform[0]) // x coordinate of the zeroth sample
                y = halfHeight - (halfHeight * gain * verWaveform[0]) // y coordinate of the zeroth sample
                path.move( to: CGPoint( x: x, y: y ) )

                for sampleNum in 0 ..< dataLength {
                    x = halfWidth  + (halfWidth  * gain * horWaveform[sampleNum])
                    y = halfHeight - (halfHeight * gain * verWaveform[sampleNum])
                    x = min(max(0, x), width);
                    y = min(max(0, y), height);
                    path.addLine( to: CGPoint( x: x, y: y ) )
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

            }  // end of Path{}
            .stroke(lineWidth: 4.0)
            .foregroundColor(.init(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0))  // foreground color = red
            
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of EnhancedSpectrum struct



/*
struct TriOctSpectrumVis_Previews: PreviewProvider {
    static var previews: some View {
        TriOctSpectrumVis()
    }
}
*/
