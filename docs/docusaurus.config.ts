import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Kulala.nvim',
  tagline: 'A minimal 🤏 HTTP-client 🐼 interface 🖥️ for Neovim ❤️.',
  favicon: 'img/favicon.png',

  url: 'https://kulala.mwco.app',
  baseUrl: '/',

  organizationName: 'mistweaverco',
  projectName: 'kulala.nvim',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  plugins: [require.resolve('docusaurus-lunr-search')],

  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl:
            'https://github.com/mistweaverco/kulala.nvim/blob/main/docs',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/kulala-social-card.png',
    docs: {
      sidebar: {
        autoCollapseCategories: true,
      },
    },
    navbar: {
      title: 'Kulala.nvim',
      logo: {
        alt: 'Kulala.nvim Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          position: 'left',
          label: 'Usage',
          to: '/docs/usage',
        },
        {
          position: 'left',
          label: 'Scripts',
          to: '/docs/scripts/overview',
        },
        {
          href: 'https://github.com/mistweaverco/kulala.nvim',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Install',
              to: '/docs/getting-started/install',
            },
            {
              label: 'Usage',
              to: '/docs/usage',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Discord',
              href: 'https://discord.gg/QyVQmfY4Rt',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/mistweaverco/kulala.nvim',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} mistweaver.co.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['lua', 'http', 'json'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
