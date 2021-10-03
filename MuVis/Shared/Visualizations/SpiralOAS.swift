/// SpiralOAS.swift
/// MuVis
///
/// This visualization generates the same FFT spectral information as the OctaveAlignedSpectrum, but displays it along a spiral instead of as rows in a Cartesian grid.
/// Each 360-degree revolution of this spiral is a standard spectrum display covering one octave of frequency. Each revolution is scaled and aligned one octave
/// above the next-inner revolution to show the radial alignment of octave-related frequencies in the music.
///
/// The LinearOAS visualization had the nice property that all spectral bins were adjacent to their neighbors, but it was poor at identifying harmonic relationships.
/// The OctaveAlignedSpectrum and EllipticalOAS visualizations were much more helpful in showing harmonic spectral relationships and identifying musical notes,
/// but sacrificed the continuity between neighboring spectral bins.  (That is, as the audio frequency of a tone increased, it could disappear off of the right end
/// of one row and reappear at the left end of the next-higher row.)  This SpiralOAS visualization attempts to get the best of both worlds.
/// It has the same harmonic alignment properties of the EllipticalOAS visualization while having all spectral bins uniformly rendered contiguously along
/// one continuous line (namely, the spiral).  In other words, the graphic representation more closely resembles the physics of the sound being analyzed.
///
/// The parametric equations for a circle are
/// x = r sin (2 * PI * theta)
/// y = r cos (2 * PI * theta)
/// where r is the radius and, the angle theta (in radians) is measured clockwise from the vertical axis.
///
/// The spiral used in this visualization is called the "Spiral of Archimedes" (also known as the arithmetic spiral) named after the Greek mathematician Archimedes.
/// In polar coordinates (r, theta) it can be described by the equation
/// r = b * theta
/// where b controls the distance between successive turnings.
///
/// Straight lines radiating out from the origin pass through the spiral at constant intervals (although not at right angles).  We will use the variable name "radInc" for
/// this constant "radial increment".  The parametric equations for an Archimedean spiral are
/// x = b * theta * sin (2 * PI * theta)
/// y = b * theta * cos (2 * PI * theta)
/// where theta is the angle in radians (measured clockwise from the 12 o'clock position).  The counterclockwise spiral is made with positive values of theta,
/// and the clockwise spiral (used here) is made with the negative values of theta.
///
/// Since our rendering pane is rectangular, we will generalize this to be an elongated spiral in order to maximally fill the rendering pane.
/// The new parametric equations for the spiral are
/// x = A * theta * sin (2 * PI * theta)
/// y = B * theta * cos (2 * PI * theta)
/// where A and B are related to the major- and minor-radii respectively.  I do NOT claim mathematical correctness in these equations.  They appear to work nicely
/// for this visualization.  But anyone using this for scientific purposes should re-verify that these shortcuts work for their purposes.
///
/// The following "trick" makes the rendering of the spiral more understandable.  As theta goes from 0 to 1, the spiral makes a complete revolution.
/// As theta goes from 1 to 2, the spiral makes another complete revolution.  etc.  We want 0  theta to extend from 0.0 to 1.0 so we can evenly spread the bins
/// comprising one octave over one revolution.  We define a variable called "spiralIndex" whose integer part specifies the octave (turn number),
/// and whose fractional part specifies the angle around that turn.  Hence, the actual spiral parametric equations that we will use are:
/// x = X0 + ( radIncA * spiralIndex * sin(2.0 * PI * spiralIndex) );
/// y = Y0 + ( radIncB * spiralIndex * cos(2.0 * PI * spiralIndex) );
/// where X0, Y0 are the coordinates of the desired origin (e.g., the pane's center) and radIncA and redIncB are the constant radial intervals in the horizontal and
/// vertical directions.
///
/// A Google search uncovered the patent US5127056A (www.google.com/patents/US5127056) for a "Spiral Audio Spectrum Display System".
/// It was filed in 1990 by Allen Storaasli. It states that "Each octave span of the audio signal is displayed as a revolution of the spiral such that tones of different
/// octaves are aligned and harmonic relationships between predominant tones are graphically illustrated."
///
/// Created by Keith Bromley on 21 Feb 2021 (from his previous java version for the Polaris app).


import SwiftUI


struct SpiralOAS: View {

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LayoutBackground()
                LiveSpectra()
            }
        }
    }


    struct LayoutBackground: View {
        @EnvironmentObject var settings: Settings
        var body: some View {
            GeometryReader { geometry in
            
                let octaveCount: Int = 7  // The FFT provides 7 octaves (plus 5 unrendered notes)
                let width: CGFloat  = geometry.size.width   // The drawing origin is in the upper left corner.
                let height: CGFloat = geometry.size.height  // The drawing origin is in the upper left corner.
                let X0: CGFloat = width  / 2.0  // the origin of the ellipses
                let Y0: CGFloat = height / 2.0  // the origin of the ellipses
                let A0: CGFloat = width  / 2.0  // the horizontal radius of the largest ellipse
                let B0: CGFloat = height / 2.0  // the vertical   radius of the largest ellipse
                let radIncA: CGFloat = A0 / CGFloat(octaveCount) // gets 7 octaves in the pane.
                let radIncB: CGFloat = B0 / CGFloat(octaveCount) // gets 7 octaves in the pane.
                var theta:  Double = 0.0
                var theta1: Double = 0.0
                var theta2: Double = 0.0
                var spiralIndex:     Double = 0.0
                var spiralIndexOut:  Double = 0.0
                var spiralIndexOut1: Double = 0.0
                var spiralIndexOut2: Double = 0.0
                var spiralIndexIn:   Double = 0.0
                var spiralIndexIn1:  Double = 0.0
                var spiralIndexIn2:  Double = 0.0
                
                var x: CGFloat = 0.0
                var y: CGFloat = 0.0
                
                var xOut: [CGFloat] =  [CGFloat] (repeating: 0.0, count: notesPerOctave)
                var yOut: [CGFloat] =  [CGFloat] (repeating: 0.0, count: notesPerOctave)
                var xIn:  [CGFloat] =  [CGFloat] (repeating: 0.0, count: notesPerOctave)
                var yIn:  [CGFloat] =  [CGFloat] (repeating: 0.0, count: notesPerOctave)
                
                let accidentalLine: [Int] = [1, 3, 6, 8, 10]  // line value preceding notes C#, D#, F#, G#, and A#
                
                // Render the 5 gray hexagons corresponding to the 5 sharp/flat notes in each octave
                ForEach( 0 ..< accidentalLine.count, id: \.self) { line in  // line = 0,1,2,3,4   accidentalLine = 1, 3, 6, 8, 10

                    Path { path in
                        let note: Int = accidentalLine[line]        // note = 1, 3, 6, 8, 10
                    
                        // Calculate the x,y coordinates where the 5 radial accidentalLines meet the outer-most turn of the spiral:
                        theta = Double(note) / Double(notesPerOctave)       // 0 <= theta <= 1
                        spiralIndexOut = -( Double(octaveCount-1) + theta )    // 0 <= spiralIndex <= octaveCount
                        xOut[note] = X0 + (radIncA * CGFloat(spiralIndexOut) * CGFloat( sin(2.0 * Double.pi * spiralIndexOut))) // 0 <= note < 12
                        yOut[note] = Y0 + (radIncB * CGFloat(spiralIndexOut) * CGFloat( cos(2.0 * Double.pi * spiralIndexOut))) // 0 <= note < 12

                        // Calculate the x1,y1 coordinates where the 5 radial accidentalLines meet the inner-most turn of the spiral:
                        spiralIndexIn = -theta
                        xIn[note] = X0 + (radIncA * CGFloat(spiralIndexIn) * CGFloat( sin(2.0 * Double.pi * spiralIndexIn)))
                        yIn[note] = Y0 + (radIncB * CGFloat(spiralIndexIn) * CGFloat( cos(2.0 * Double.pi * spiralIndexIn)))

                        // Calculate the x,y coordinates where the 5 radial accidentalLines meet the outer-most turn of the spiral:
                        theta1 = Double(note+1) / Double(notesPerOctave)       // 0 <= theta <= 1
                        spiralIndexOut1 = -( Double(octaveCount-1) + theta1 )    // 0 <= spiralIndex <= octaveCount
                        xOut[note+1] = X0 + (radIncA * CGFloat(spiralIndexOut1) * CGFloat( sin(2.0 * Double.pi * spiralIndexOut1))) // 0 <= note < 12
                        yOut[note+1] = Y0 + (radIncB * CGFloat(spiralIndexOut1) * CGFloat( cos(2.0 * Double.pi * spiralIndexOut1))) // 0 <= note < 12
                        
                        // Calculate the x1,y1 coordinates where the 5 radial accidentalLines meet the inner-most turn of the spiral:
                        spiralIndexIn1 = -theta1
                        xIn[note+1] = X0 + (radIncA * CGFloat(spiralIndexIn1) * CGFloat( sin(2.0 * Double.pi * spiralIndexIn1)))
                        yIn[note+1] = Y0 + (radIncB * CGFloat(spiralIndexIn1) * CGFloat( cos(2.0 * Double.pi * spiralIndexIn1)))


                        // Now render the 5 gray rectangles:
                        // First, start a line along the hexagon side from the outer turn to the inner turn:
                        path.move(   to: CGPoint(x: xOut[note], y: yOut[note] ) )   // from the outer turn
                        path.addLine(to: CGPoint(x: xIn[note],  y: yIn[note]  ) )   // to the inner turn
                        
                        // Second, add a line to a point on the inner turn that is halfway between these two angles:
                        theta2 = ( theta + theta1 ) * 0.5
                        spiralIndexIn2 = -theta2
                        let xInHalf: CGFloat = X0 + (radIncA * CGFloat(spiralIndexIn2) * CGFloat( sin(2.0 * Double.pi * spiralIndexIn2)))
                        let yInHalf: CGFloat = Y0 + (radIncB * CGFloat(spiralIndexIn2) * CGFloat( cos(2.0 * Double.pi * spiralIndexIn2)))
                        path.addLine(to: CGPoint(x: xInHalf,  y: yInHalf  ) )       // along the inner turn
                        
                        // Third, add a line from this inner halfway point to the inner point of the far side of the accidental line:
                        path.addLine(to: CGPoint(x: xIn[note+1],  y: yIn[note+1]  ) )   // along the inner turn

                        // Fourth, do the subsequent hexagon side from the inner turn to the outer turn:
                        path.addLine(to: CGPoint(x: xOut[note+1],  y: yOut[note+1] ) )  // to the outer turn
                        
                        // Fifth, add a line to a point on the outside turn that is halfway between these two angles:
                        theta2 = ( theta + theta1 ) * 0.5
                        spiralIndexOut2 = -( Double(octaveCount-1) + theta2 )
                        let xOutHalf: CGFloat = X0 + (radIncA * CGFloat(spiralIndexOut2) * CGFloat( sin(2.0 * Double.pi * spiralIndexOut2)))
                        let yOutHalf: CGFloat = Y0 + (radIncB * CGFloat(spiralIndexOut2) * CGFloat( cos(2.0 * Double.pi * spiralIndexOut2)))
                        path.addLine(to: CGPoint(x: xOutHalf,  y: yOutHalf  ) )       // along the outer turn
                        
                        // Six,add a line from this outer halfway point to the starting point of the outer turn
                        path.addLine(to: CGPoint(x: xOut[note],  y: yOut[note] ) )  // to the outer turn
                        path.closeSubpath()
                    }
                    // .fill(Color.accidentalNoteColor)
                    .fill( (settings.selectedColorScheme == .light) ? Color.lightGray.opacity(0.25) : Color.black.opacity(0.25) )
                }  // end of ForEach(accidentalLine)
                

                // Layout the spiral path:
                Path { path in
                    path.move(   to: CGPoint(x: X0,  y: Y0  ) )   // start at the pane's center
                    
                    for oct in 0 ..< octaveCount {              // oct = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
                        for point in 0 ..< pointsPerOctave {
                            theta = Double(point) / Double(pointsPerOctave)     // 0 <= theta <= 1
                            spiralIndex = -( Double(oct) + theta )              // 0 <= spiralIndex <= octaveCount
                            x = X0 + (radIncA * CGFloat(spiralIndex) * CGFloat( sin(2.0 * Double.pi * spiralIndex )))
                            y = Y0 + (radIncB * CGFloat(spiralIndex) * CGFloat( cos(2.0 * Double.pi * spiralIndex )))
                            path.addLine(to: CGPoint(x: x,  y: y ) )
                        }
                    }
                    spiralIndex = -( Double(octaveCount - 1) + 1.0)     // continue the outermost turn to the 12 o'clock position
                    x = X0 + (radIncA * CGFloat(spiralIndex) * CGFloat( sin(2.0 * Double.pi * spiralIndex)))
                    y = Y0 + (radIncB * CGFloat(spiralIndex) * CGFloat( cos(2.0 * Double.pi * spiralIndex)))
                    path.addLine(to: CGPoint(x: x,  y: y ) )
                }
                .stroke(lineWidth: 1.0)
                .foregroundColor(.black)


                // Render the radial gridlines dividing the spiral into 12 increments:
                ForEach( 0 ..< notesPerOctave, id: \.self) { note in      //  0 <= note < 12
                
                    Path { path in
                        // Calculate the x,y coordinates where the 12 radial lines meet the outer-most turn of the spiral:
                        theta = Double(note) / Double(notesPerOctave)       // 0 <= theta <= 1
                        theta = min(max(0.0, theta), 1.0)                   // Limit over- and under-saturation.
                        spiralIndex = -( Double(octaveCount-1) + theta )    // 0 <= spiralIndex <= octaveCount
                        xOut[note] = X0 + (radIncA * CGFloat(spiralIndex) * CGFloat( sin(2.0 * Double.pi * spiralIndex))) // 0 <= note < 12
                        yOut[note] = Y0 + (radIncB * CGFloat(spiralIndex) * CGFloat( cos(2.0 * Double.pi * spiralIndex))) // 0 <= note < 12

                        // The 12 o'clock radial line goes to outermost spiral:
                        yOut[0] = Y0 + (radIncB * CGFloat(-8.0) * CGFloat( cos(2.0 * Double.pi * (-8.0) ) ) )

                        // Calculate the x1,y1 coordinates where the 12 radial lines meet the inner-most turn of the spiral:
                        spiralIndex = -theta
                        xIn[note] = X0 + (radIncA * CGFloat(spiralIndex) * CGFloat( sin(2.0 * Double.pi * spiralIndex)))
                        yIn[note] = Y0 + (radIncB * CGFloat(spiralIndex) * CGFloat( cos(2.0 * Double.pi * spiralIndex)))

                        // Render the radial gridlines dividing the spiral into 12 increments:
                        // Each line starts at the innermost turn of the spiral and ends at the outermost turn.
                        // Each center between consecutive radial lines represents the center frequency of a musical note.
                        // For this elongated spiral, the angles are only approximately geometrically correct.
                        path.move(   to: CGPoint(x: xOut[note], y: yOut[note] ) )   // from the outer-most turn
                        path.addLine(to: CGPoint(x: xIn[note],  y: yIn[note]  ) )   // to the inner-most turn
                    }
                    .stroke(lineWidth: 1.0)
                    .foregroundColor(.black)
                }  // end of ForEach(note)
                
            }  // end of GeometryReader
        }  // end of var body: some View
    }  // end of LayoutBackground struct
    
    

    struct LiveSpectra: View {
        @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed to us from ContentView.
        @EnvironmentObject var settings: Settings
        
        var body: some View {
            GeometryReader { geometry in
            
                let octaveCount: Int = 7  // The FFT provides 7 octaves (plus 5 unrendered notes)
                let width: CGFloat  = geometry.size.width   // The drawing origin is in the upper left corner.
                let height: CGFloat = geometry.size.height  // The drawing origin is in the upper left corner.
                let X0: CGFloat = width  / 2.0  // the origin of the ellipses
                let Y0: CGFloat = height / 2.0  // the origin of the ellipses
                let A0: CGFloat = width  / 2.0  // the horizontal radius of the largest ellipse
                let B0: CGFloat = height / 2.0  // the vertical   radius of the largest ellipse
                let radIncA: CGFloat = A0 / CGFloat(octaveCount) // gets 7 octaves in the pane.
                let radIncB: CGFloat = B0 / CGFloat(octaveCount) // gets 7 octaves in the pane.
                var theta: Double = 0.0
                var spiralIndex: Double = 0.0
                var x: CGFloat = 0.0
                var y: CGFloat = 0.0
                
                let devGain:  CGFloat = 0.3     // devGain  is the optimum gain  value suggested by the developer
                let gain  = devGain  * settings.userGain
                var amp:   CGFloat = 0.0        // amplitude = gain + (slope * point)
                var mag:   CGFloat = 0.0        // used as a preliminary part of the audio amplitude value
                var addedDataA: CGFloat = 0.0
                var addedDataB: CGFloat = 0.0
                
                Path { path in
                                    
                    // Initialize the start of the spiral at the 12 o'clock position at the outermost end of the spiral:
                    spiralIndex = -( Double(octaveCount-1) + 0.99999);  // 0 <= spiralIndex <= rowCount
                    x = X0 + (radIncA * CGFloat(spiralIndex) * CGFloat( sin(2.0 * Double.pi * spiralIndex)))
                    y = Y0 + (radIncB * CGFloat(spiralIndex) * CGFloat( cos(2.0 * Double.pi * spiralIndex)))
                    path.move(   to: CGPoint(x: x, y: y ) )   // from the outer turn
                    
                    // Render the "spiral baseline" from the outside inward:
                    for oct in (0 ..< octaveCount).reversed() {          // oct = 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
                        for point in (0 ..< pointsPerOctave).reversed() {
                            theta = Double(point) / Double(pointsPerOctave)     // 0 <= theta <= 1
                            spiralIndex = -( Double(oct) + theta)               // 0 <= spiralIndex <= octaveCount
                            x = X0 + (radIncA * CGFloat(spiralIndex) * CGFloat( sin(2.0 * Double.pi * spiralIndex)))
                            y = Y0 + (radIncB * CGFloat(spiralIndex) * CGFloat( cos(2.0 * Double.pi * spiralIndex)))
                            path.addLine(to: CGPoint(x: x,  y: y ) )
                        }
                    }

                    // Render the "spiral plus spectral data" from the inside outward:
                    for oct in 0 ..< octaveCount {          // oct = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
                        for point in 0 ..< pointsPerOctave {
                            theta = Double(point) / Double(pointsPerOctave)     // 0.0 < theta < 1.0
                            spiralIndex = -( Double(oct) + theta )              // 0 <= spiralIndex <= octaveCount
                            amp = gain + settings.userSlope * CGFloat( oct*pointsPerOctave + point )
                            mag = amp * CGFloat(audioManager.muSpectrum[oct*pointsPerOctave + point])
                            mag = min(max(0.0, mag), 1.0);  // Limit over- and under-saturation.
                            addedDataA = radIncA * mag
                            addedDataB = radIncB * mag
                            x = X0 + ((radIncA * CGFloat(spiralIndex)) - addedDataA) * CGFloat( sin(2.0 * Double.pi * spiralIndex))
                            y = Y0 + ((radIncB * CGFloat(spiralIndex)) - addedDataB) * CGFloat( cos(2.0 * Double.pi * spiralIndex))
                            path.addLine(to: CGPoint(x: x,  y: y ) )
                        }
                    }
                    // Now close the outer points of these two spirals and fill the resultant blob:
                    path.closeSubpath()

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

                }  // end of Path
                .foregroundColor(.init(red: 192.0/255.0, green: 57.0/255.0, blue: 43.0/255.0, opacity: 1.0))  // Pomegranate color
                
            }  // end of GeometryReader
        }  // end of var body: some View
    }  // end of LiveSpectra struct

}  // end of SpiralOAS struct



/*
struct SpiralOAS_Previews: PreviewProvider {
    static var previews: some View {
        SpiralOAS()
    }
}
*/
