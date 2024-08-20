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
        'getting-started/configuration-options',
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
        "usage/api",
        "usage/authentication",
        "usage/automatic-response-formatting",
        "usage/dotenv-and-http-client.env.json-support",
        "usage/request-variables",
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
    {
      type: 'category',
      label: 'Scripts',
      link: {
        type: 'generated-index',
        title: 'Scripts',
        description: 'Learn about the scripting capabilities!',
        slug: 'scripts',
      },
      items: [
        "scripts/overview",
        "scripts/client-reference",
        "scripts/request-reference",
        "scripts/response-reference",
      ],
    },
  ],
};

export default sidebars;
