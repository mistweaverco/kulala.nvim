import type { SidebarsConfig } from '@docusaurus/plugin-content-docs';

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
        'getting-started/keymaps',
        'getting-started/default-keymaps',
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
        "usage/basic-usage",
        'usage/http-file-spec',
        "usage/using-variables",
        "usage/request-variables",
        "usage/cookies",
        "usage/using-environment-variables",
        "usage/dotenv-and-http-client.env.json-support",
        "usage/magic-variables",
        "usage/authentication",
        "usage/import-and-run-http",
        "usage/shared-blocks",
        "usage/reading-file-data",
        "usage/filter-response",
        "usage/redirect-the-response",
        "usage/sending-form-data",
        "usage/dynamically-setting-environment-variables-based-on-headers",
        "usage/dynamically-setting-environment-variables-based-on-response-json",
        "usage/automatic-response-formatting",
        "usage/testing-and-reporting",
        "usage/graphql",
        "usage/grpc",
        "usage/websockets",
        "usage/streaming-and-transfer-chunked",
        "usage/custom-curl-flags",
        "usage/public-methods",
        "usage/import-export",
        "usage/api",
        "usage/cli-ci",
        'usage/demos',
        'usage/recipes'
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
        "scripts/lua-scripts",
        "scripts/client-reference",
        "scripts/request-reference",
        "scripts/response-reference",
      ],
    },
  ],
};

export default sidebars;
