import { AbsoluteFill, Sequence, useCurrentFrame, interpolate } from 'remotion';
import { loadFont as loadBangers } from '@remotion/google-fonts/Bangers';
import { loadFont as loadPoppins } from '@remotion/google-fonts/Poppins';
import { loadFont as loadMono } from '@remotion/google-fonts/IBMPlexMono';

import { TerminalScene } from './scenes/TerminalScene';
import { MenuBarScene } from './scenes/MenuBarScene';
import { PopupScene } from './scenes/PopupScene';
import { StatementScene } from './scenes/StatementScene';
import { EndCard } from './scenes/EndCard';
import { beats, sec, color } from './theme';

// Same three families the website uses. Loaded at module scope so every frame
// renders with them already resolved — a late-loading font would cause the
// first frames of a render to fall back and flicker.
//
// Weights and subsets are pinned to exactly what the scenes use. Left
// unrestricted this pulled ~70 font files per frame render, which Remotion
// warns about and which dominated iteration time.
loadBangers('normal', { weights: ['400'], subsets: ['latin'] });
loadPoppins('normal', { weights: ['400', '600', '700'], subsets: ['latin'] });
loadMono('normal', { weights: ['400', '600'], subsets: ['latin'] });

/**
 * A short dip to black between scenes.
 *
 * Cutting straight from the dark terminal to the bright desktop was harsh
 * enough to read as a glitch; 4 frames of black turns it into a deliberate
 * edit. Only used where the background luminance actually jumps.
 */
const Dip: React.FC<{ atSecond: number }> = ({ atSecond }) => {
  const frame = useCurrentFrame();
  const at = sec(atSecond);
  const opacity = interpolate(frame, [at - 4, at, at + 4], [0, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  if (opacity <= 0) return null;
  return <AbsoluteFill style={{ backgroundColor: '#000', opacity, zIndex: 50 }} />;
};

export const LaunchVideo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: color.bg }}>
      <Sequence from={sec(beats.terminal.from)} durationInFrames={sec(beats.terminal.duration)}>
        <TerminalScene />
      </Sequence>

      <Sequence from={sec(beats.menubar.from)} durationInFrames={sec(beats.menubar.duration)}>
        <MenuBarScene />
      </Sequence>

      <Sequence from={sec(beats.popup.from)} durationInFrames={sec(beats.popup.duration)}>
        <PopupScene />
      </Sequence>

      <Sequence from={sec(beats.statement.from)} durationInFrames={sec(beats.statement.duration)}>
        <StatementScene />
      </Sequence>

      <Sequence from={sec(beats.end.from)} durationInFrames={sec(beats.end.duration)}>
        <EndCard />
      </Sequence>

      {/* dark -> light, and amber -> dark: the two jarring luminance jumps */}
      <Dip atSecond={beats.menubar.from} />
      <Dip atSecond={beats.end.from} />
    </AbsoluteFill>
  );
};
