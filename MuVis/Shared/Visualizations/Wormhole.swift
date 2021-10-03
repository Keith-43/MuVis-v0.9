/// Wormhole.swift
/// MuVis
///
/// This "Wormhole" visualization renders the time-history of the music's spectrum across a sequence of circles.
///
/// The following activities are performed during each rendering cycle:
/// 1. The 6-octave muSpectrum is computed.  It extends from C1 at 33 Hz to B6 at 1976 Hz. The sixOctPointCount = 72*8=576
/// 2. These spectral values are written into a buffer memory using an incremented write pointer.
/// 3. The most recent 32 spectra are read from this buffer memory and rendered along the outermost 32 of 40 concentric circles.
///   (Again, for iPhones and iPads, the number 32 is reduced to 16.)
///   Each muSpectrum is rendered counter-clockwise starting at the nine o'clock position.
///
/// The reason for the peculiar arithmetic of this last activity is: With a frame rate of 10 fps, and a buffer memory storing the previous 40 spectra, the data is
/// 4 seconds old by the time it reaches the outermost (biggest and boldest) circle. The casual observer might not realize that the wiggles he is seeing are related to
/// the sound that he is hearing (since the sound is 4 seconds older than the boldest wiggle). It looks better if we store only the previous 32 spectra and render them
/// on the outermost 32 of the 40 circles. (The innermost 8 circles render a scaled-down version of the newest data rendered on circle number 9.)
///
/// Again, the colors change with time (in addition to changing with this circle's radius).
///
/// Created by Keith Bromley on 1 June 2021. (adapted from his previous java version in the Polaris app)



import SwiftUI


struct Wormhole: View {

    @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed to us from ContentView.
    @EnvironmentObject var settings: Settings
    
    var body: some View {
    
        GeometryReader { geometry in
        
            // The important ellipse parameters are:
            let width:  CGFloat = geometry.size.width
            let height: CGFloat = geometry.size.height
            let X0: CGFloat = 0.5 * width   // the origin of the ellipses
            let Y0: CGFloat = 0.5 * height  // the origin of the ellipses
            
            var startX: CGFloat = 0.0
            var startY: CGFloat = 0.0
            let endX: CGFloat = X0
            let endY: CGFloat = Y0
            
            let endRadius: CGFloat = 0.8 * sqrt(X0 * X0 + Y0 * Y0)      // stretches from center to almost the corner
            let startRadius: CGFloat = endRadius * 0.02                 // starting radius value
            let rangeRadius = endRadius - startRadius                   // range of the radius value
            
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var theta:  Double = 0.0    // The angle theta starts at the 9 o'clock position and proceeds counter-clockwise.
            
            let devGain:  CGFloat = 0.05        // devGain  is the optimum gain  value suggested by the developer
            let gain  = devGain  * settings.userGain    // userGain  multiplies devGain  by a slider value from 0.0 to 2.0
            var amp:   CGFloat = 0.0        // amplitude = gain + (slope * point)
            var mag:  CGFloat = 0.0         // used as a preliminary part of the audio amplitude value
            var magX: CGFloat = 0.0         // used as a preliminary part of the audio amplitude value
            var magY: CGFloat = 0.0         // used as a preliminary part of the audio amplitude value
                      
            // We divide the ellipse into 8 * 72 = 576 angular increment.
            let pointIncrement: Double = 1.0 / Double(sixOctPointCount)      // pointIncrement = 1 / 576
            
            let innermostEllipseCount: Int = 8
            let ellipseCount: Int = muSpecHistoryCount + innermostEllipseCount  // macOS: 32+8 = 40;  iOS: 16+8 = 24
            var hist: Int = 0
            var histOffset:   Int = 0
            let tempIndex0 = muSpecHistoryIndex * sixOctPointCount  // index to first element of the most-recent (hist=0) spectrum written
            var tempIndex1 : Int = 0
            var tempIndex2 : Int = 0
            var tempIndex3 : Int = 0
            let colorSize: Int = 50_000    // This determines the frequency of the color change over time.
            var hue:  Double = 0.0
            var hue1: Double = 0.0
            var hue2: Double = 0.0

// ---------------------------------------------------------------------------------------------------------------------
            // Rendering this line allows us to use Path{} to write the sampleHistory, and to set the background color.
            Path { path in
            
                // Store the first 72*8=576 points of the current muSpectrum[] array (containing 89*8=712 points)
                // in the muSpecHistory[] circular buffer at pointer = muSpecHistoryIndex * sixOctPointCount.
                // At this time instant, muSpecHistoryIndex * sixOctPointCount_sparse points to the most-recent point written
                // into the muSpecHistory buffer.
                muSpecHistoryIndex += 1  // This is the "index" for the sample that is about to be written into our circBuffer
                if (muSpecHistoryIndex >= muSpecHistoryCount) { muSpecHistoryIndex = 0 }
                // muSpecHistoryIndex will always be less than muSpecHistoryCount

                for point in 0 ..< sixOctPointCount {
                    muSpecHistory[tempIndex0 + point] = audioManager.muSpectrum[point]
                }

                path.move( to: CGPoint(x: 0.0, y: height) )     // This line just allows us to use the Path{} to write the muSpecHistory
                path.addLine(to: CGPoint(x: width, y: height) )
                
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
            .stroke(lineWidth: 0.0)
            .background((settings.selectedColorScheme == .light) ? Color.white : Color.black)    // Toggle between black and white background color.
            
            
// ---------------------------------------------------------------------------------------------------------------------
            ForEach( 0 ..< ellipseCount, id: \.self) { ellipseNum in        //  0 <= ellipseCount < 64


                // As ellipseNum goes from 0 to ellipseCount, ellipseRampUp goes from 0.0 to 1.0:
                let rampUp: CGFloat = CGFloat(ellipseNum) / CGFloat(ellipseCount)
                let rampUp2: CGFloat = rampUp * rampUp          // Deliberate non-linear radius.

                // As ellipseNum goes from 0 to ellipseCount, ellipseRampDown goes from 1.0 to 0.0:
                let rampDown: CGFloat = CGFloat(ellipseCount - ellipseNum) / CGFloat(ellipseCount)
                
                let radius: CGFloat = startRadius + (rampUp2 * rangeRadius) // non-linear radius
                
                Path { path in

                    // It is easier to visualize the graphics using ellipseNum & ellipseCount instead of hist & muSpecHistoryCount
                    hist = (ellipseNum <= innermostEllipseCount) ?  0 : ellipseNum - innermostEllipseCount
                    
                    if(settings.offsetX > 1.0) { settings.incrementX = -0.0006 }
                    else if(settings.offsetX < -1.0) { settings.incrementX = 0.0006 }
                    
                    if(settings.offsetY > 1.0) { settings.incrementY = -0.0002 }
                    else if(settings.offsetY < -1.0) { settings.incrementY = 0.0002 }
                    
                    settings.offsetX += settings.incrementX
                    settings.offsetY += settings.incrementY
                    
                    startX = X0 + settings.offsetX * (width  * 0.1)
                    startY = Y0 + settings.offsetY * (height * 0.1)
                    
                    x = rampDown * startX + rampUp * endX - radius
                    y = rampDown * startY + rampUp * endY
                    
                    path.move( to: CGPoint(x: x, y: y) )

                    // Now ensure that we read the correct spectral data from the muSpecHistory[] array:
                    histOffset = hist * sixOctPointCount
                    tempIndex1 = tempIndex0 - histOffset
                    tempIndex2 = (tempIndex1 >= 0) ? tempIndex1 : tempIndex1 + (muSpecHistoryCount*sixOctPointCount)

                    for point in 1 ..< sixOctPointCount {    // 72 * 8 = 576 = number of points per ellipse

                        theta = Double(point) * pointIncrement  // 0 <= theta < 1

                        // We needed to account for wrap-around at the muSpecHistory[] ends:
                        tempIndex3 = (tempIndex2 + point) % (muSpecHistoryCount * sixOctPointCount)

                        amp = gain + settings.userSlope * CGFloat(point)
                        mag = amp * CGFloat( muSpecHistory[tempIndex3] )
                        mag = min(max(0.0, mag), 1.0)   // Limit over- and under-saturation.
                        
                        magX = mag * rampUp2 * width  // The spectral peaks get bigger at the outer rings
                        magY = mag * rampUp2 * height // The spectral peaks get bigger at the outer rings
                        
                        x = (rampDown * startX + rampUp * endX) - (radius - magX) * CGFloat(cos(2.0 * Double.pi * theta))
                        y = (rampDown * startY + rampUp * endY) + (radius - magY) * CGFloat(sin(2.0 * Double.pi * theta))
                        
                        path.addLine(to: CGPoint(x: x,  y: y ) )
                    }
                    
                    x = rampDown * startX + rampUp * endX - radius
                    y = rampDown * startY + rampUp * endY
                    
                    
                    path.addLine( to: CGPoint(x: x, y: y) )

                    settings.colorIndex = (settings.colorIndex >= colorSize) ? 0 : settings.colorIndex + 1
                    hue1 = Double(settings.colorIndex) / Double(colorSize)          // 0.0 <= hue1 < 1.0
                    hue2 = Double(rampUp2)                                          // 0.0 <= hue2 < 1.0
                    
                    // Apple clips the hue value to 0.0 <= hue <= 1.0
                    hue = (hue1 + hue2).truncatingRemainder(dividingBy: 1.0)
                    
                }  // end of Path
                .stroke(lineWidth: 0.4 + (rampUp2 * 3.0))   // lineWidth goes from 0.1 to 3.1
                .foregroundColor(Color(hue: hue, saturation: 1.0, brightness: 1.0))
                
            }  // end of ForEach(ellipseNum)
                               
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of Wormhole struct



/*
struct Wormhole_Previews: PreviewProvider {
    static var previews: some View {
        Wormhole()
    }
}
*/
