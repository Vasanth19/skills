import { Config } from "@remotion/cli/config";

// 9:16 portrait background b-roll. H.264 MP4 by default.
Config.setVideoImageFormat("jpeg");
// concurrency=1: verified in-container (shared-cpu-1x). Auto-detect crashed
// (resolveConcurrency) and >1 risks OOM under the tight per-VM memory.
Config.setConcurrency(1);

// swiftshader = pure software GL — VERIFIED rendering on /usr/bin/chromium in the
// Fly container. "angle" timed out connecting to the browser headless (needs a
// GPU/SwiftANGLE path not available). Do NOT switch back to angle without re-testing.
Config.setChromiumOpenGlRenderer("swiftshader");
Config.setChromiumDisableWebSecurity(false);
