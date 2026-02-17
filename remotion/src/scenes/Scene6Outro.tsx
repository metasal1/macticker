import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { colors, font, gradients } from "../styles";

export const Scene6Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const fade = interpolate(frame, [0, 2 * fps], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: gradients.midnight, color: colors.white, fontFamily: font }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "radial-gradient(circle at 70% 20%, rgba(36, 0, 255, 0.4), transparent 55%)",
        }}
      />
      <div style={{ position: "absolute", top: 200, left: 120, opacity: fade }}>
        <Img src={staticFile("brand/logo-name.png")} style={{ width: 320, height: 320 }} />
      </div>

      <div style={{ position: "absolute", top: 260, right: 140, textAlign: "right", opacity: fade }}>
        <div style={{ fontSize: 54, fontWeight: 700 }}>Ready to launch?</div>
        <div style={{ marginTop: 12, fontSize: 22, color: colors.gray }}>
          Motion kits for events, launches, and community stories.
        </div>
        <div style={{ marginTop: 28, fontSize: 20, color: colors.mint }}>solanaanz.org</div>
      </div>
    </AbsoluteFill>
  );
};
