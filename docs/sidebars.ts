import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  defaultSidebar: [
    {
      type: 'category',
      label: 'Getting Started',
      link: {
        type: 'generated-index',
        title: 'Getting Started',
        description: 'Learn how to install and setup kulala.nvim!',
        slug: 'getting-started',
      },
      items: [
        'getting-started/install',
        'getting-started/requirements',
        'getting-started/setup-options',
      ],
    },
    {
      type: 'category',
      label: 'Usage',
      link: {
        type: 'generated-index',
        title: 'Usage',
        description: 'Learn about the most important kulala.nvim features!',
        slug: 'usage',
      },
      items: [
        "usage/public-methods",
        "usage/authentication",
        "usage/automatic-response-formatting",
        "usage/dotenv-and-http-client.env.json-support",
        "usage/dynamically-setting-environment-variables-based-on-response-json",
        "usage/dynamically-setting-environment-variables-based-on-headers",
        "usage/file-to-variable",
        "usage/graphql",
        "usage/magic-variables",
        "usage/sending-form-data",
        "usage/using-environment-variables",
        "usage/using-variables",
        'usage/http-file-spec',
      ],
    },
  ],
};

export default sidebars;
