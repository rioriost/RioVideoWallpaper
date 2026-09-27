# RioVideoWallpaper

RioVideoWallpaper is a lightweight macOS menu bar app that lets you play a video as your desktop wallpaper.

## Features

- Plays a video behind your desktop icons
- Works across multiple displays
- Shares one playback pipeline across displays to avoid duplicate decoding
- Loops the selected video automatically
- Lives in the menu bar for quick access
- Lets you change the video at any time
- Starts automatically when you log in
- Skips audible playback and pauses when the display sleeps or another app covers the screen
- Warns when the selected video may be inefficient for wallpaper playback

## Requirements

- macOS 15 or later

## Install

Install with Homebrew:

```sh
brew install --cask rioriost/cask/riovideowallpaper
```

## How to use

1. Launch `RioVideoWallpaper`.
2. When prompted, choose a video file from your Mac.
3. The selected video will start playing as your wallpaper.
4. To change the video later, click the menu bar icon and choose `Change Video...`.
5. To quit the app, click the menu bar icon and choose `Quit`.

## Notes

- Your selected video is remembered for the next launch.
- If your display configuration changes, the app reloads the video for the current screens.
- Mouse clicks pass through the wallpaper layer, so you can use your desktop normally.
- Videos are rendered through AVFoundation and are best used in hardware-accelerated formats such as H.264 or HEVC.
- Very high-resolution videos may be downscaled by the display but still cost extra decode power.

## Profiling

Use Xcode Instruments Time Profiler to confirm CPU usage. A healthy run should spend most time in AVFoundation/CoreMedia system threads with little self time in `RioVideoWallpaper`; compare one display versus multiple displays to verify the shared playback pipeline. If CPU time is already low, use Energy Log or GPU/Metal profiling before considering a custom renderer.

## Testing

Run the unit and UI tests on a Mac with Xcode and the Metal Toolchain installed:

```sh
make test
```

If Metal compilation reports a missing toolchain, install it with `xcodebuild -downloadComponent MetalToolchain`.
The test target uses local ad-hoc signing, so no development certificate is required. It suppresses the initial video picker, and UI tests that match labels launch the app in English regardless of the Mac's preferred language.

## License

MIT