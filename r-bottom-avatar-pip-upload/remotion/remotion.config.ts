import { Config } from "@remotion/cli/config";

// 9:16 portrait background b-roll. H.264 MP4 by default.
Config.setVideoImageFormat("jpeg");
Config.setConcurrency(2);

// Chromium flags that keep headless Debian / container renders happy.
// These are harmless locally (Chrome ignores unknown/duplicate flags) and
// are the ones that matter when running on /usr/bin/chromium in prod.
Config.setChromiumOpenGlRenderer("angle"); // swiftshader-backed ANGLE; software GL, no GPU needed
Config.setChromiumDisableWebSecurity(false);
