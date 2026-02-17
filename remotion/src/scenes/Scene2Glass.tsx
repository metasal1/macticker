import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { colors, font, gradients, shadows } from "../styles";

const Card: React.FC<{ label: string; src: string; delay: number }> = ({ label, src, delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame: frame - delay, fps, config: { damping: 18, stiffness: 120 } });

  return (
    <div
      style={{
        width: 340,
        height: 240,
        borderRadius: 28,
        padding: 26,
        background: "rgba(255, 255, 255, 0.08)",
        border: "1px solid rgba(255, 255, 255, 0.18)",
        backdropFilter: "blur(18px)",
        boxShadow: shadows.tight,
        transform: `translateY(${(1 - enter) * 30}px)`
      }}
    >
      <Img src={staticFile(src)} style={{ width: "100%", height: 96, objectFit: "contain" }} />
      <div style={{ marginTop: 20, fontSize: 22, color: colors.white, fontWeight: 600 }}>{label}</div>
      <div style={{ marginTop: 6, fontSize: 16, color: colors.gray }}>
        Branded lower-third, titles, and overlays.
      </div>
    </div>
  );
};

export const Scene2Glass: React.FC = () => {
  const frame = useCurrentFrame();
  const glow = interpolate(frame, [0, 310], [0.6, 1]);

  return (
    <AbsoluteFill style={{ background: gradients.blueRed, fontFamily: font, color: colors.white }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "radial-gradient(circle at 20% 30%, rgba(255,255,255,0.3), transparent 60%)",
          opacity: glow,
        }}
      />
      <div style={{ position: "absolute", top: 90, left: 120, fontSize: 58, fontWeight: 700 }}>
        Glass UI
      </div>
      <div style={{ position: "absolute", top: 165, left: 120, fontSize: 22, color: "rgba(255,255,255,0.78)" }}>
        Sleek overlays with layered depth and brand clarity.
      </div>

      <div
        style={{
          position: "absolute",
          top: 260,
          left: 120,
          right: 120,
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gap: 28,
        }}
      >
        <Card label="LinkedIn" src="brand/linkedin.png" delay={0} />
        <Card label="Luma" src="brand/luma.png" delay={10} />
        <Card label="Brand Stack" src="brand/logo-name.png" delay={20} />
      </div>
    </AbsoluteFill>
  );
};
