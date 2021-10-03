#  MuVis - an Audio Visualizer app for Music
#  MuVis Release Notes
by Keith Bromley, San Diego, CA, USA &nbsp; &nbsp; kbromley@me.com


#### MuVis-v0.8  

It is the first public release of the MuVis music visualizer app (after a-year-and-a-half of development).  
It runs on macOS only. It was developed using Swift, SwiftUI, and Xcode.  
It plays song files from the user's computer - but not live audio from the microphone.  
The AudioManager class uses the AVAudioEngine API, but also has unused commented-out code using the AVCaptureSession API for potential microphone input.

  7 Aug 2021 - MuVis-v0.8 source code posted on GitHub (replaced on 20 Sep 2021) (See [here](https://github.com/Keith-43/MuVis-v0.8).)  
23 Aug 2021 - MuVis-v0.8 uploaded to the Apple Mac App Store (See [here](https://apps.apple.com/us/app/muvis-music-visualizer/id1582324352).)


#### MuVis-v0.9  

It runs on macOS, iOS, and iPadOS. It was developed using Swift, SwiftUI, and Xcode.  
It plays song files from the user's device, and also live audio from the device's microphone.  
In the AudioManager class , the code using the AVCaptureSession API was deleted.  
The AudioManager class uses the AVAudioEngine API for both song-file-playing and microphone-playing.  
Many minor code changes improved both the aesthetics and the performance.

3 Oct 2021 - MuVis v0.9 posted on GitHub (See [here](https://github.com/Keith-43/MuVis-v0.9).)
