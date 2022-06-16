import React, { useState, useEffect } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { farmdoa } from '../src/declarations/defi_dapp/index';

import { HashRouter } from 'react-router-dom';
import { EmojiProvider } from 'react-apple-emojis';
import emojiData from './styles/emojis.json';
import './styles/index.scss';

const container = document.getElementById('app');
const app = createRoot(container);


app.render(
  <HashRouter>
    <EmojiProvider data={emojiData}>
      <React.StrictMode>
        <ErrorBoundary>
          <App />
        </ErrorBoundary>
      </React.StrictMode>
    </EmojiProvider>
  </HashRouter>
);
