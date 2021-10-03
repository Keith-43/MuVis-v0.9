/// HarmonicAlignment3.swift
/// MuVis
///
/// The HarmonicAlignment3 visualization depicts the same information as the HarmonicAlignment visualization but rendered in a slightly different form.
/// (This is purely for aesthetic effect - which you may find pleasing or annoying.) The muSpectrum for each of the six octaves (and for each of the six harmonics
/// within each octave) is rendered twice - one upward stretching muSpectrum and one downward stretching muSpectrum.
///
/// The OAS of the fundamental notes (in red) is rendered first. Then the OAS of the first harmonic notes (in yellow) are rendered over it.
/// Then the OAS of the second harmonic notes (in green) are rendered over it, and so on - until all 6 harmonics are depicted.
///
/// Again, we multiply the value of the harmonics (harm = 2 through 6) by the value of the fundamental (harm = 1). So, the harmonics are shown if-and-only-if there is
/// meaningful energy in the fundamental.
///
/// Created by Keith Bromley on 20 Nov 2020.


import SwiftUI


struct HarmonicAlignment3: View {

    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GrayRectangles(columnCount: 12)
                HorizontalLines(rowCount: 6, offset: 0.5, color: .black)
                VerticalLines(columnCount: 12)
                NoteNames(rowCount: 2, octavesPerRow: 1)
                LiveSpectra()
            }
        }
    }



    struct LiveSpectra: View {
        @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed from ContentView.
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
                
                var x: CGFloat = 0.0       // The drawing origin is in the upper left corner.
                var y: CGFloat = 0.0       // The drawing origin is in the upper left corner.
                var upRamp: CGFloat = 0.0

                let rowCount: Int = 6  // The FFT provides 7 octaves (plus 5 unrendered notes)
                let rowHeight: CGFloat = height / CGFloat(rowCount)
                let halfRowHeight: CGFloat = 0.5 * rowHeight
                
                let devGain:  CGFloat = 0.1     // devGain  is the optimum gain  value suggested by the developer
                let gain  = devGain  * settings.userGain
                var amp:   CGFloat = 0.0        // amp = amplitude + (slope * bin)
                var magY:  CGFloat = 0.0        // used as a preliminary part of the "y" value
                var CGrow: CGFloat = 0.0
                var totalPoints: Int = 0
                            
                let harmIncrement: [Int]  = [ 0, 12, 19, 24, 28, 31 ]      // The increment (in notes) for the six harmonics:
                //                           C1  C2  G2  C3  E3  G3
                
                // Render each of the seven harmonics:
                ForEach( 0 ..< harmonicCount, id: \.self) { harm in		// harm = 0,1,2,3,4,5
                
                    let harmOffset: CGFloat = CGFloat(harm) / CGFloat(harmonicCount * 3) // harmOffset = 0,1/18,2/18,3/18,4/18,5/18
                    var harmAmp: CGFloat = 1.0 - harmOffset  // harmonic amplitude = 1, 17/18, 16/18, 15/18, 14/18, 13/18

                    let hueHarmOffset: Double = 1.0 / ( Double(harmonicCount) ) // hueHarmOffset = 1/6
                    let hueIndex: Double = Double(harm) * hueHarmOffset         // hueIndex = 0, 1/6, 2/6, 3/6, 4/6, 5/6

                        Path { path in
                        
                            for row in 0 ..< rowCount {
                                CGrow = CGFloat(row)
                        
                                path.move( to: CGPoint( x: 0.0, y: height - CGrow * rowHeight - halfRowHeight ) )

                                for point in 0 ..< pointsPerOctave {
                                    // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerOctave
                                    upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)
                                    x = upRamp * width

                                    totalPoints = row * pointsPerOctave + point
                                    magY = CGFloat(audioManager.muSpectrum[totalPoints])
                                    
                                    harmAmp = (harm==0) ? 1.0 : magY;  // This gracefully reduces the harmonic spectra for weak fundamentals
                                    amp = harmAmp * ( gain + settings.userSlope * CGFloat( row * pointsPerOctave + point ) )
                                    
                                    totalPoints = row * pointsPerOctave + pointsPerNote*harmIncrement[harm] + point
                                    if(totalPoints >= totalPointCount) { totalPoints = totalPointCount-1 }
                                    magY = CGFloat(audioManager.muSpectrum[totalPoints]) * rowHeight * harmAmp * amp
                                    
                                    if( totalPoints == totalPointCount-1 ) { magY = 0 }
                                    magY = min(max(0.0, magY), rowHeight)  // Limit over- and under-saturation.
                                    y = height - CGrow * rowHeight - halfRowHeight - magY
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                                
                                path.addLine( to: CGPoint( x: width, y: height - CGrow * rowHeight - halfRowHeight ) )
                                
                                for point in (0 ..< pointsPerOctave).reversed() {
                                    upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)
                                    x = upRamp * width
                                    
                                    totalPoints = row * pointsPerOctave + point
                                    magY = CGFloat(audioManager.muSpectrum[totalPoints])
                                    
                                    harmAmp = (harm==0) ? 1.0 : magY;  // This gracefully reduces the harmonic spectra for weak fundamentals
                                    amp = harmAmp * ( gain + settings.userSlope * CGFloat( row * pointsPerOctave + point ) )
                                    
                                    totalPoints = row * pointsPerOctave + pointsPerNote*harmIncrement[harm] + point
                                    if(totalPoints >= totalPointCount) { totalPoints = totalPointCount-1 }
                                    magY = CGFloat(audioManager.muSpectrum[totalPoints]) * rowHeight * harmAmp * amp
                                    
                                    if( totalPoints == totalPointCount-1 ) { magY = 0 }
                                    magY = min(max(0.0, magY), rowHeight)  // Limit over- and under-saturation.
                                    y = height - CGrow * rowHeight - halfRowHeight + magY
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                                   
                                path.addLine( to: CGPoint( x: 0.0,   y: height - CGrow * rowHeight - halfRowHeight ) )
                                path.closeSubpath()
                            }
                        
                        }
                        .foregroundColor(Color(hue: hueIndex, saturation: 1.0, brightness: 1.0))
                        
                }  // end of ForEach(harm)

                
            }  // end of GeometryReader
        }  // end of var body: some View
    }  // end of LiveSpectra struct

}  // end of the HarmonicAlignment3 struct



/*
struct OctaveAlignedSpectrum_Previews: PreviewProvider {
    static var previews: some View {
        OctaveAlignedSpectrum()
    }
}
*/
