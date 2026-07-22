import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

import { getData } from './src/data';
import { GlobalConfig } from './src/entities';
import { globalConfig as configData } from './data/';

const globalConfig = getData<GlobalConfig>(configData);
const docsPath = process.env.LLMS_DOCS_SOURCE_PATH || 'docs';
const config: Config = {
  ...globalConfig.site,
  trailingSlash: true,
  favicon: 'img/favicon.ico',
  onBrokenLinks: 'warn',
  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn'
    }
  },
  themes: ['@docusaurus/theme-mermaid'],
  i18n: {
    defaultLocale: 'en',
    locales: ['en']
  },
  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          path: docsPath,
          id: 'default',
          routeBasePath: 'docs'
        },
        theme: {
          customCss: './static/themes/default.css'
        }
      } satisfies Preset.Options
    ]
  ],
  themeConfig: {
    ...globalConfig.theme,
    image: 'img/docusaurus-social-card.jpg',
    navbar: {
      ...globalConfig?.theme?.navbar,
      hideOnScroll: false,
      items: [
        {
          type: 'doc',
          docId: 'getting-started/quickstart',
          position: 'left',
          label: 'Docs'
        },
        {
          type: 'custom-VersionDisplay',
          position: 'right'
        },
        {
          type: 'custom-ThemeSwitcher',
          position: 'right'
        },
        {
          type: 'custom-TextSizeSwitcher',
          position: 'right'
        },
        {
          type: 'custom-ReaderMode',
          position: 'right'
        },
        {
          type: 'custom-Admin',
          position: 'right'
        }
      ]
    },
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: false
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula
    }
  } satisfies Preset.ThemeConfig
};

export default config;
