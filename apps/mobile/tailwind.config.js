/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset"), require("@thumbsup/tokens/nativewind-v4")],
  theme: { extend: {} },
  plugins: [],
};
