import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { colors, font, gradients, shadows } from "../styles";

export const Scene4Depth: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const rotate = interpolate(frame, [0, 6 * fps], [-8, 6], { extrapolateRight: "clamp" });
  const lift = interpolate(frame, [0, 6 * fps], [40, 0], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: gradients.midnight, color: colors.white, fontFamily: font }}>
      <div style={{ position: "absolute", top: 100, left: 120, fontSize: 56, fontWeight: 700 }}>
        Depth & Dimension
      </div>
      <div style={{ position: "absolute", top: 175, left: 120, fontSize: 22, color: colors.gray }}>
        Poster-grade compositions with subtle 3D energy.
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 140,
          left: 120,
          width: 880,
          height: 420,
          transform: `skewY(-4deg) rotate(${rotate}deg) translateY(${lift}px)`,
        }}
      >
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 32,
              background: i === 2 ? gradients.blueRed : "rgba(255, 255, 255, 0.08)",
              border: "1px solid rgba(255,255,255,0.2)",
              transform: `translate(${i * 24}px, ${-i * 20}px)`,
              boxShadow: shadows.soft,
            }}
          />
        ))}
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <Img src={staticFile("brand/logo-square.png")} style={{ width: 220, height: 220 }} />
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          right: 140,
          bottom: 160,
          fontSize: 28,
          fontWeight: 600,
          textAlign: "right",
        }}
      >
        Event Backdrops
        <div style={{ fontSize: 18, color: colors.gray, marginTop: 8 }}>Stage visuals and hero reveals.</div>
      </div>
    </AbsoluteFill>
  );
};
