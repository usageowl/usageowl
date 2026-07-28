import { Composition } from 'remotion';
import { LaunchVideo } from './LaunchVideo';
import { FPS, TOTAL_SECONDS } from './theme';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="LaunchVideo"
      component={LaunchVideo}
      durationInFrames={FPS * TOTAL_SECONDS}
      fps={FPS}
      width={1920}
      height={1080}
    />
  );
};
