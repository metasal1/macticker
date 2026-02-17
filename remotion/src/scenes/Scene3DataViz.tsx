import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { colors, font } from "../styles";

const bars = [64, 110, 150, 190, 140, 210, 180];

export const Scene3DataViz: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const progress = interpolate(frame, [0, 3 * fps], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: colors.black, color: colors.white, fontFamily: font }}>
      <div style={{ position: "absolute", top: 100, left: 120, fontSize: 56, fontWeight: 700 }}>
        Data-Driven Motion
      </div>
      <div style={{ position: "absolute", top: 175, left: 120, fontSize: 22, color: colors.gray }}>
        Stats, metrics, and network activity visualized in seconds.
      </div>

      <div style={{ position: "absolute", bottom: 160, left: 120, right: 120, height: 320 }}>
        <div style={{ display: "flex", alignItems: "flex-end", gap: 24, height: "100%" }}>
          {bars.map((value, index) => {
            const barHeight = value * progress;
            return (
              <div
                key={index}
                style={{
                  width: 70,
                  height: barHeight,
                  background: index % 2 === 0 ? colors.blue : colors.mint,
                  borderRadius: 16,
                  transition: "none",
                }}
              />
            );
          })}
        </div>
      </div>

      <svg
        viewBox="0 0 800 200"
        width={900}
        height={220}
        style={{ position: "absolute", bottom: 380, left: 140 }}
      >
        <path
          d="M20 160 L140 120 L260 80 L380 100 L500 60 L620 90 L740 30"
          fill="none"
          stroke={colors.red}
          strokeWidth={6}
          strokeLinecap="round"
          strokeDasharray={800}
          strokeDashoffset={800 - 800 * progress}
        />
      </svg>
    </AbsoluteFill>
  );
};
