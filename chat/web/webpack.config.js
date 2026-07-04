const path = require('path');

module.exports = {
  mode: 'production',
  entry: './wfc-wrapper.js',
  output: {
    path: path.resolve(__dirname, '.'),
    filename: 'wfc-sdk.js',
    library: {
      type: 'window',
      name: 'wfc',
      export: 'default',
    },
  },
  resolve: {
    modules: [
      path.resolve(__dirname, 'node_modules'),
      path.resolve(__dirname, '../../../vue-chat/node_modules'),
    ],
    alias: {
      '../av/engine/avenginekitproxy$': path.resolve(__dirname, 'avenginekit-stub.js'),
      '../ptt/client/pttClient$': path.resolve(__dirname, 'pttClient-stub.js'),
    },
    fallback: {
      path: false,
      fs: false,
      assert: false,
      util: false,
      os: false,
      crypto: false,
      buffer: require.resolve('buffer/'),
    },
  },
  plugins: [
    new (require('webpack').ProvidePlugin)({
      process: 'process/browser',
      Buffer: ['buffer', 'Buffer'],
    }),
    new (require('webpack').NormalModuleReplacementPlugin)(
      /avenginekitproxy\.js$/,
      path.resolve(__dirname, 'avenginekit-stub.js')
    ),
    new (require('webpack').NormalModuleReplacementPlugin)(
      /pttClient\.js$/,
      path.resolve(__dirname, 'pttClient-stub.js')
    ),
  ],
};
