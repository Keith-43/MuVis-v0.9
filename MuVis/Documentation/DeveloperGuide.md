#  MuVis - an Audio Visualizer app for Music
#  MuVis Developer Guide
by Keith Bromley, San Diego, CA, USA &nbsp; &nbsp; kbromley@me.com

#### **Overview:**

The MuVis app runs on macOS, iOS, and iPadOS.  Upon opening, it plays a music song file stored internally, and renders a spectrum-like display.
The user can push the "Select Song" button in the bottom toolbar to open a pop-up file-picker pane allowing her to select a song file to play next.
With macOS, the user can select files from her Music folder.  But with iOS and iPadOS, the user is restricted to files within her Files folder.
Also, the user can push the "Prev Vis" and "Next Vis" buttons in the bottom toolbar to change the visualization rendered in the visualization pane.
(Alternatively, she can use the left-arrow and right-arrow buttons on her keyboard.)

This project uses the Swift programming language and the Xcode integrated development environment (IDE).
 I am a novice Xcode and Swift developer, so I recommend you NOT use my coding style as an example to follow.  (Also, I would appreciate any help from experienced-others who can improve my code, so feel free to contact me if you wish to contribute or collaborate.)

The main parts of the code are:  
1.  The MuVisApp.swift file simply serves as the starting point for the app.  It also contains several global constants and variables.  
2.  The ContentView.swift file handles the GUI (graphical user interface) of the app (mainly using SwiftUI).  
3.  The AudioManager.swift file handles the audio subsytem (using Apple's AVAudioEngine API).  
4   The Visualizations folder contains about twenty SwiftUI views each rendering a particular visualization.

#### **History:**

This project started life in August 2020 as an exact clone of the project "Metal Audio Visualizer" by Alex Barbulescu.
I am indebted to him for providing me with a valuable starting point in my early explorations.
You can read his tutorials on "Audio Visualization In Swift Using Metal & Accelerate" at

[Making Your First Circle Using Metal Shaders](https://www.medium.com/better-programming/making-your-first-circle-using-metal-shaders-1e5049ec8505)
   
[Audio Visualizations Using Metal, Part 1](https://www.medium.com/@barbulescualex/audio-visualization-in-swift-using-metal-accelerate-part-1-390965c095d7)
   
[Audio Visualizations Using Metal, Part 2](https://www.medium.com/@barbulescualex/audio-visualization-in-swift-using-metal-accelerate-part-2-7ec8df4def91)

and you can download his code at:

[Metal Circle](https://www.github.com/barbulescualex/MetalCircle)
   
[Metal Audio Visualizer](https://www.github.com/barbulescualex/MetalAudioVisualizer)

My app still uses a lot of his code in the AudioManager class - mainly some  AVAudioEngine and AVAudioPCMBuffer code
(from the AVFoundation framework) for audio play and capture, and some vDSP_DFT code (from the Accelerate framework) 
for FFT computations.

In Septermber 2020, I decided that the Metal framwork was not the right tool for the 2D drawing that I had in mind.
I switched to Quartz 2D (part of Core Graphics).

#### **The User Interface:**

The user-interface is based upon SwiftUI.  Unfortunately, Apple's SwiftUI API is currently an incomplete work-in-progress.  So, I expect
the user-interface to look more polished with each new SwiftUI release from Apple.  The document UserGuide.md provided in the Documentation folder provides a more-detailed desciption of the user-interface.

#### **The Audio Subsystem:**

Apple has several high-level APIs for handling audio functionality.  I have chosen to use the AVAudioEngine API because (1) the "Metal Audio
Visualizer" tutorial provided a complete working example app for me to copy as a starting point, (2) it allows acces to live audio data through
its "tap-on-bus" mechanism, and (3) it's use of AU processing nodes allows modularity and flexibility.  Unfortunately, it can only provided
these audio samples with a buffer update rate of 10 times per second.  This limits my screen update rate to 10 frames per second. Also, I use a 
delay node in the audio path (after sampling) to compensate for the latency introduced by the sampling, processing, and rendering processes.
 
The document AudioProcessing.md provided in the Documentation folder gives more detail on the AudioManager class.

#### **The Visualizations:**

The MuVis app currently contains about twenty visualizations - some are scientifically-based; some are music-theory based; and some are
simply aesthetically pleasing.  The document Visualizations.md provided in the Documentation folder describes each of them.

Writing the graphics code for these visualizations within the restrictions of ViewBuilder was a challenge.  I am anxiously awaiting the arrival of the Canvas graphics framework which should make the code cleaner - with the added benefit of GPU performance enhancement.
