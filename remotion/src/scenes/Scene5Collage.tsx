import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { colors, font, shadows } from "../styles";

export const Scene5Collage: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const drift = interpolate(frame, [0, 8 * fps], [20, -20], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: colors.white, color: colors.black, fontFamily: font }}>
      <div style={{ position: "absolute", top: 110, left: 120, fontSize: 56, fontWeight: 700 }}>
        Collage & Lifestyle
      </div>
      <div style={{ position: "absolute", top: 185, left: 120, fontSize: 22, color: "#4B4F5A" }}>
        Mix photography, merch, and brand marks with dynamic layering.
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 100,
          left: 120,
          display: "flex",
          gap: 40,
          alignItems: "flex-end",
        }}
      >
        <div style={{ width: 360, height: 460, background: colors.black, borderRadius: 26, boxShadow: shadows.soft }}>
          <Img
            src={staticFile("brand/anzsol-tshirt.png")}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              borderRadius: 26,
              transform: `translateY(${drift}px)`
            }}
          />
        </div>
        <div style={{ width: 360, height: 460, position: "relative" }}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: colors.blue,
              borderRadius: 28,
              transform: "rotate(-4deg)",
              boxShadow: shadows.soft,
            }}
          />
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: colors.red,
              borderRadius: 28,
              transform: "rotate(4deg)",
              opacity: 0.85,
            }}
          />
          <div
            style={{
              position: "absolute",
              inset: 16,
              background: colors.white,
              borderRadius: 22,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              boxShadow: shadows.tight,
            }}
          >
            <Img src={staticFile("brand/logo-name.png")} style={{ width: 240, height: 240, objectFit: "contain" }} />
          </div>
        </div>
      </div>

      <div style={{ position: "absolute", right: 140, bottom: 140, textAlign: "right" }}>
        <div style={{ fontSize: 28, fontWeight: 600 }}>Merch Drops</div>
        <div style={{ fontSize: 18, color: "#4B4F5A", marginTop: 8 }}>Posters, product teasers, and social kits.</div>
      </div>
    </AbsoluteFill>
  );
};
