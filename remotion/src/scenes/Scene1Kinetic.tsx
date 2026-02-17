import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { colors, font, gradients, shadows } from "../styles";

export const Scene1Kinetic: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleEnter = spring({ frame, fps, config: { damping: 16, stiffness: 140 } });
  const subtitleEnter = spring({ frame: frame - 18, fps, config: { damping: 18, stiffness: 120 } });

  const orbit = interpolate(frame, [0, 300], [0, Math.PI * 2]);
  const blobOffset = 120 + Math.sin(orbit) * 80;

  return (
    <AbsoluteFill style={{ background: gradients.midnight, color: colors.white, fontFamily: font }}>
      <div
        style={{
          position: "absolute",
          width: 540,
          height: 540,
          borderRadius: 999,
          background: gradients.mintViolet,
          filter: "blur(2px)",
          opacity: 0.55,
          transform: `translate(${120 + blobOffset}px, ${-80 + Math.cos(orbit) * 40}px)`,
        }}
      />
      <div
        style={{
          position: "absolute",
          right: -120,
          bottom: -140,
          width: 620,
          height: 620,
          borderRadius: 999,
          background: gradients.blueRed,
          opacity: 0.4,
          filter: "blur(8px)",
          transform: `translate(${Math.sin(orbit) * 30}px, ${Math.cos(orbit) * 30}px)`,
        }}
      />

      <div
        style={{
          position: "absolute",
          top: 110,
          left: 120,
          display: "flex",
          alignItems: "center",
          gap: 16,
        }}
      >
        <Img
          src={staticFile("brand/logo.png")}
          style={{ width: 56, height: 56, borderRadius: 12, boxShadow: shadows.soft }}
        />
        <div style={{ fontSize: 22, letterSpacing: 2, textTransform: "uppercase", color: colors.gray }}>
          Solana ANZ Motion
        </div>
      </div>

      <div style={{ position: "absolute", top: 260, left: 120, maxWidth: 900 }}>
        <div
          style={{
            fontSize: 96,
            fontWeight: 700,
            lineHeight: 0.96,
            transform: `translateY(${(1 - titleEnter) * 30}px)`,
            opacity: titleEnter,
          }}
        >
          Motion Graphics
        </div>
        <div
          style={{
            marginTop: 24,
            fontSize: 36,
            fontWeight: 500,
            color: colors.gray,
            transform: `translateY(${(1 - subtitleEnter) * 30}px)`,
            opacity: subtitleEnter,
          }}
        >
          Six distinct styles. One coherent brand story.
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 100,
          left: 120,
          display: "flex",
          alignItems: "center",
          gap: 12,
          fontSize: 20,
          color: colors.gray,
        }}
      >
        <div style={{ width: 14, height: 14, borderRadius: 99, background: colors.mint }} />
        <span>Built for events, launches, and community moments.</span>
      </div>
    </AbsoluteFill>
  );
};
