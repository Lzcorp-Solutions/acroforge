import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'AcroForge',
  description: 'A Ruby toolkit for working with PDF AcroForms — especially the broken ones.',
  base: '/acroforge/',
  cleanUrls: true,
  lastUpdated: true,

  themeConfig: {
    nav: [
      { text: 'Guide', link: '/quick-start' },
      { text: 'CLI', link: '/cli' },
      { text: 'API', link: '/api' },
      { text: 'GitHub', link: 'https://github.com/youruser/acroforge' }
    ],

    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Introduction', link: '/' },
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
      { icon: 'github', link: 'https://github.com/youruser/acroforge' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'AcroForge v0.1.0'
    }
  }
})
