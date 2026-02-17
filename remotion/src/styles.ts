import { loadFont } from "@remotion/google-fonts/SpaceGrotesk";

const { fontFamily } = loadFont();

export const font = fontFamily;

export const colors = {
  blue: "#2400FF",
  red: "#FF0000",
  black: "#0A0A0C",
  white: "#F7F7F7",
  mint: "#14F195",
  violet: "#7B61FF",
  slate: "#111318",
  gray: "#9EA3AE",
};

export const gradients = {
  blueRed: `linear-gradient(135deg, ${colors.blue} 0%, ${colors.red} 100%)`,
  midnight: `radial-gradient(circle at 20% 20%, #1E2140 0%, #0A0A0C 55%, #050508 100%)`,
  mintViolet: `linear-gradient(120deg, ${colors.mint} 0%, ${colors.violet} 50%, ${colors.blue} 100%)`,
};

export const shadows = {
  soft: "0 24px 60px rgba(0, 0, 0, 0.35)",
  tight: "0 12px 30px rgba(0, 0, 0, 0.4)",
};
