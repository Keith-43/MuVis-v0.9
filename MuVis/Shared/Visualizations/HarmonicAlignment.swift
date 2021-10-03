/// HarmonicAlignment.swift
/// MuVis
///
/// The HarmonicAlignment visualization is an enhanced version of the OctaveAlignedSpectrum visualization - which renders a muSpectrum displaying the FFT
/// frequency bins of the live audio data on a two-dimensional Cartesian grid. Each row of this grid is a standard muSpectrum display covering one octave.
/// Each row is aligned one octave above the next-lower row to show the vertical alignment of octave-related frequencies in the music.
/// (Note that this requires compressing the frequency range by a factor of two for each octave.)
/// Hence the six rows of our displayed grid cover six octaves of musical frequency.
///
/// We have an audio sampling rate of 11,025 samples per second which means that the highest frequency we can observe is 11,025 / 2 = 5,512.5 Hz.
/// This implies that the highest musical note that we can reliably observe is E8 (freqE8 is about 5,274 Hz). If C1 is considered as note = 0 then E8 is note = 88.
/// Thus the muSpectrum (generated from the spectrum computed by the FFT) covers a total of 89 notes (just over 7 octaves).
///
/// The bottom 6 octaves (the 72 notes from 0 to 71) will be displayed as possible fundamentals of the notes in the music, and the remaining 89 - 72 = 17 notes
/// will be used only for harmonic information. The rendered grid (shown in the above picture) has 6 rows and 12 columns - containing 6 * 12 = 72 boxes.
/// Each box represents one note. In the bottom row (octave 0), the leftmost box represents note 0 (C1 is 33 Hz) and the rightmost box represents note 11 (B1 is 61 Hz).
/// In the top row (octave 5), the leftmost box represents note 60 (C6 is 1046 Hz) and the rightmost box represents note 71 (B6 is 1975 Hz).
///
/// But the novel feature of the HarmonicAlignment visualization is the rendering of the harmonics beneath each note. We are rendering 6 harmonics of each note.
/// We will start counting from 1 - meaning that harm=1 refers to the fundamental. If the fundamental is note C1, then:
///
///	harm=1  is  C1  fundamental
///	harm=2  is  C2  octave                                  harm=3  is  G2
///	harm=4  is  C3  two octaves         harm=5  is  E3      harm=6  is  G3
/// So, harmonicCount = 6 and  harm = 1, 2, 3, 4, 5, 6, 7.
/// The harmonic increment (harmIncrement) for our 6 rendered harmonics is 0, 12, 19, 24, 28, 31 notes.
///
/// The fundamental (harm=1) (the basic octave-aligned spectrum) is shown in red.  The first harmonic (harm=2) shows as orange; the second harmonic (harm=3) is yellow;
/// and the third harmonic harm=4) is green, and so on.  It is instructive to note the massive redundancy displayed here.  A fundamental note rendered as red in row 4
/// will also appear as orange in row 3 since it is the first harmonic of the note one-octave lower, and as orange in row 2 since it is the second harmonic of the note
/// two-octaves lower, and as yellow in row 1 since it is the fourth harmonic of the note three-octaves lower.
///
///In order to decrease the visual clutter (and to be more musically meaningfull), we multiply the value of the harmonics (harm = 2 through 6) by the value of the
///fundamental (harm = 1). So, if there is no meaningful amplitude for the fundamental, then its harmonics are not shown (or at least only with low amplitude).
///
/// We will render a total of 6 * 6 = 36 polygons - one for each harmonic of each octave.
///
/// totalPointCount = 89 * 8 = 712      // total number of points provided by the interpolator
/// sixOctPointCount = 72 * 8 = 576  // total number of points of the 72 possible fundamentals
///
/// Created by Keith Bromley on 20 Nov 2020.


import SwiftUI


struct HarmonicAlignment: View {

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GrayRectangles(columnCount: 12)
                HorizontalLines(rowCount: 6, offset: 0.0, color: Color(hue: 5.0/6.0, saturation: 1.0, brightness: 0.3) ) // lavendar hue matches highest harmonic
                VerticalLines(columnCount: 12)
                NoteNames(rowCount: 2, octavesPerRow: 1)
                LiveSpectra()
            }
        }
    }



    struct LiveSpectra: View {
        @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
        @EnvironmentObject var settings: Settings
        
        var body: some View {
            GeometryReader { geometry in
            
                /*
                This is a two-dimensional grid containing 6 row and 12 columns.
                Each of the 6 rows contains 1 octave or 12 notes or 12*12 = 144 points.
                Each of the 12 columns contains 6 octaves of that particular note.
                The entire grid renders 6 octaves or 6*12 = 72 notes or 6*144 = 864 points
                */

                let harmonicCount: Int = 6  // The total number of harmonics rendered.       0 <= harm < 6
                let width: CGFloat  = geometry.size.width
                let height: CGFloat = geometry.size.height
                let rowOffset: CGFloat = CGFloat(harmonicCount - 1) / CGFloat(harmonicCount * 3);  // rowOffset = 5 / 18
                
                var x: CGFloat = 0.0       // The drawing origin is in the upper left corner.
                var y: CGFloat = 0.0       // The drawing origin is in the upper left corner.
                var upRamp: CGFloat = 0.0

                let rowCount: Int = 6  // The FFT provides 7 octaves (plus 5 unrendered notes)
                let rowHeight: CGFloat = height / CGFloat(rowCount)
                
                let devGain:  CGFloat = 0.3     // devGain  is the optimum gain  value suggested by the developer
                let gain  = devGain  * settings.userGain
                var amp:   CGFloat = 0.0        // amp = amplitude + (slope * bin)
                var magY:  CGFloat = 0.0        // used as a preliminary part of the "y" value
                var CGrow: CGFloat = 0.0
                var totalPoints: Int = 0
                            
                let harmIncrement: [Int]  = [ 0, 12, 19, 24, 28, 31 ]      // The increment (in notes) for the six harmonics:
                //                           C1  C2  G2  C3  E3  G3
                
                // Render each of the six harmonics:
                ForEach( 0 ..< harmonicCount, id: \.self) { harm in		// harm = 0,1,2,3,4,5
                
                    let harmOffset: CGFloat = CGFloat(harm) / CGFloat(harmonicCount * 3) // harmOffset = 0,1/18,2/18,3/18,4/18,5/18
                    
                    // let harmAmp: CGFloat = 1.0 - harmOffset  // harmonic amplitude = 1, 17/18, 16/18, 15/18, 14/18, 13/18
                    var harmAmp: CGFloat = 0.0

                    let hueHarmOffset: Double = 1.0 / ( Double(harmonicCount) ) // hueHarmOffset = 1/6
                    let hueIndex: Double = Double(harm) * hueHarmOffset         // hueIndex = 0, 1/6, 2/6, 3/6, 4/6, 5/6

                        Path { path in
                        
                            for row in 0 ..< rowCount {
                                CGrow = CGFloat(row)
                        
                                path.move( to: CGPoint( x: 0.0, y: height - CGrow * rowHeight - rowHeight * (rowOffset - harmOffset) ) )

                                for point in 0 ..< pointsPerOctave {
                                    // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerOctave
                                    upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)
                                    x = upRamp * width
                                    
                                    // This gracefully reduces the harmonic spectra for weak fundamentals:
                                    harmAmp = (harm == 0) ? 1.0 : CGFloat(audioManager.muSpectrum[row * pointsPerOctave + point])
                                    
                                    amp = harmAmp * ( gain + settings.userSlope * CGFloat( row * pointsPerOctave + point ) )
                                    totalPoints = row * pointsPerOctave + pointsPerNote*harmIncrement[harm] + point
                                    if(totalPoints >= totalPointCount) { totalPoints = totalPointCount-1 }
                                     
                                    magY = CGFloat(audioManager.muSpectrum[totalPoints]) * rowHeight * harmAmp * amp
                                    if( totalPoints == totalPointCount-1 ) { magY = 0 }
                                    magY = min(max(0.0, magY), rowHeight * (1.0 - rowOffset + harmOffset))  // Limit over- and under-saturation.
                                    y = height - CGrow * rowHeight - rowHeight * (rowOffset - harmOffset) - magY
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                                
                                path.addLine( to: CGPoint( x: width, y: height - CGrow * rowHeight - rowHeight * (rowOffset - harmOffset) ) )
                                path.addLine( to: CGPoint( x: 0.0,   y: height - CGrow * rowHeight - rowHeight * (rowOffset - harmOffset) ) )
                                path.closeSubpath()
                            }
                        
                        }
                        .foregroundColor(Color(hue: hueIndex, saturation: 1.0, brightness: 1.0))
                        
                }  // end of ForEach(harm)

                
            }  // end of GeometryReader
        }  // end of var body: some View
    }  // end of LiveSpectra struct

}  // end of the HarmonicAlignment struct



/*
struct OctaveAlignedSpectrum_Previews: PreviewProvider {
    static var previews: some View {
        OctaveAlignedSpectrum()
    }
}
*/
