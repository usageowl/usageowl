import { Config } from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);

// The video is mostly flat colour and large type, which H.264 compresses very
// well. CRF 18 keeps the amber gradients free of banding while still landing
// comfortably under the file-size limits X and Product Hunt impose.
Config.setCrf(18);
