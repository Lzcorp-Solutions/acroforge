import { defineConfig } from 'vitepress'
import versionData from './generated/version.json'

const footerMessage = [
  `<span>AcroForge v${versionData.version} — MIT License</span>`,
  `<span>© 2026–present Maxwell Nana Forson</span>`,
  `<a href="https://rubygems.org/gems/acroforge" target="_blank" rel="noreferrer">rubygems.org/gems/acroforge</a>`
].join('')

export default defineConfig({
  title: 'AcroForge',
  description: 'A Ruby toolkit for working with PDF AcroForms, especially the broken ones.',
  base: '/acroforge/',
  cleanUrls: true,
  lastUpdated: true,

  themeConfig: {
    nav: [
      { text: 'Guide', link: '/quick-start' },
      { text: 'CLI', link: '/cli' },
      { text: 'API', link: '/api' },
      { text: 'GitHub', link: 'https://github.com/Lzcorp-Solutions/acroforge' }
    ],

    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Introduction', link: '/introduction' },
          { text: 'Installation', link: '/installation' },
          { text: 'Quick Start', link: '/quick-start' }
        ]
      },
      {
        text: 'Reference',
        items: [
          { text: 'CLI', link: '/cli' },
          { text: 'Library API', link: '/api' },
          { text: 'File Formats', link: '/formats' }
        ]
      },
      {
        text: 'Concepts',
        items: [
          { text: 'Relabeling Workflow', link: '/relabeling' }
        ]
      }
    ],

    search: {
      provider: 'local'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/Lzcorp-Solutions/acroforge' }
    ],

    footer: {
      message: footerMessage
    }
  }
})
