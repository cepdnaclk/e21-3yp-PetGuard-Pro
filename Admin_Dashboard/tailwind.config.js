/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: '#00897B', // Teal primary color matching mobile app scaffold
        darkBg: '#0F172A',
        cardDark: '#1E293B',
      }
    },
  },
  plugins: [],
}
