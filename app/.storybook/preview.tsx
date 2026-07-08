import type { Preview } from '@storybook/nextjs-vite'
import '../src/app/globals.css'

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
       color: /(background|color)$/i,
       date: /Date$/i,
      },
    },

    backgrounds: {
      default: 'app',
      // '#f4f7fb' = globals.css --color-bg 토큰과 동일. Storybook backgrounds 애드온은 리터럴만 받아 토큰 참조 불가 — 토큰 변경 시 함께 갱신.
      values: [{ name: 'app', value: '#f4f7fb' }],
    },
  },
};

export default preview;