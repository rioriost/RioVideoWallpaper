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
- Generates abstract wallpapers locally using renderer, seed, and parameter controls
- Keeps exported history revisions separate and protects referenced library assets

## Requirements

- macOS 26 or later

## Install

Install with Homebrew:

```sh
brew install --cask rioriost/cask/riovideowallpaper
```

## How to use

1. Launch `RioVideoWallpaper`.
2. On first launch, the generation editor opens; no existing video is required.
3. Select a renderer, adjust its parameters, then export and choose `Set as Wallpaper`.
4. To use a local video, open `Settings...` from the menu bar, select `General`, then `Choose Video...`.
5. Use `Video Generation` in Settings to create more wallpapers. The current UI uses direct controls, not natural-language prompts.
6. To quit, choose `Quit RioVideoWallpaper` from the menu bar.

## Notes

- Your selected video is remembered for the next launch.
- If your display configuration changes, the app reloads the video for the current screens.
- Mouse clicks pass through the wallpaper layer, so you can use your desktop normally.
- Videos are rendered through AVFoundation and are best used in hardware-accelerated formats such as H.264 or HEVC.
- Very high-resolution videos may be downscaled by the display but still cost extra decode power.
- A shared playback session pauses only when all displays using it are covered, or displays are sleeping. Window coverage is refreshed within roughly one second without requesting Accessibility access.
- Unavailable files do not erase saved display assignments. Reconnect their storage or select a replacement in Settings.
- History cleanup stops if project records cannot be read. Back up a damaged library before repairing those records; do not delete records merely to make cleanup proceed.
- Owned library assets use relocatable references. Keep the `Projects`, `Videos`, and `Thumbnails` folders together when moving the history location.

## Profiling

Use Xcode Instruments Time Profiler to confirm CPU usage. A healthy run should spend most time in AVFoundation/CoreMedia system threads with little self time in `RioVideoWallpaper`; compare one display versus multiple displays to verify the shared playback pipeline. If CPU time is already low, use Energy Log or GPU/Metal profiling before considering a custom renderer.

## Development

Run `make test` for unit and UI tests. Test builds use separate bundle identifiers, ad-hoc signing, and temporary UI libraries so they do not replace the installed app or its wallpaper history. Metal regression tests require a Metal-capable Mac. Use `make build` for the unsigned Release build.

## License

MIT