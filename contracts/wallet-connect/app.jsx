import React, { useEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ConnectKitButton, ConnectKitProvider, getDefaultConfig } from 'connectkit';
import { createConfig, http, WagmiProvider, useAccount, useSwitchChain } from 'wagmi';
import { sepolia } from 'wagmi/chains';

import './style.css';

const runtime = window.__TANIIN_WALLET_CONFIG__ || {};
const queryClient = new QueryClient();
const config = createConfig(
  getDefaultConfig({
    appName: 'Taniin',
    appDescription: 'Connect your wallet to play Taniin',
    appUrl: window.location.origin,
    walletConnectProjectId: runtime.projectId || 'missing-project-id',
    chains: [sepolia],
    transports: { [sepolia.id]: http() },
  }),
);

function callbackUrl(address, chainId) {
  const destination = new URL(runtime.returnUrl || '/', window.location.origin);
  destination.searchParams.set('address', address);
  destination.searchParams.set('chainId', String(chainId));
  return destination.toString();
}

function WalletConnect() {
  const { address, chainId, isConnected } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  const [status, setStatus] = useState('Choose a wallet to continue.');
  const returning = useRef(false);

  useEffect(() => {
    if (!isConnected || !address || returning.current) return;
    returning.current = true;

    async function returnToTaniin() {
      let activeChainId = chainId;
      if (activeChainId !== sepolia.id) {
        setStatus('Switching wallet to Sepolia...');
        try {
          const chain = await switchChainAsync({ chainId: sepolia.id });
          activeChainId = chain.id;
        } catch (error) {
          returning.current = false;
          setStatus(error?.shortMessage || error?.message || 'Switch to Sepolia to continue.');
          return;
        }
      }
      setStatus('Wallet connected. Returning to Taniin...');
      window.location.replace(callbackUrl(address, activeChainId));
    }

    returnToTaniin();
  }, [address, chainId, isConnected, switchChainAsync]);

  return (
    <main>
      <section className="brand">
        <div className="mark">T</div>
        <p className="eyebrow">Taniin Play to Earn</p>
        <h1>Bring your wallet to the farm.</h1>
        <p className="intro">Connect securely to sync your Sepolia assets and continue playing.</p>
        <div className="network"><span /> Ethereum Sepolia</div>
      </section>
      <section className="connect-card">
        <p className="step">Wallet access</p>
        <h2>Connect to Taniin</h2>
        <p className="copy">Select your wallet in the ConnectKit dialog. Taniin never asks for your seed phrase.</p>
        <ConnectKitButton.Custom>
          {({ show, isConnecting }) => (
            <button type="button" onClick={show} disabled={isConnecting}>
              {isConnecting ? 'Connecting...' : isConnected ? 'Connected' : 'Choose wallet'}
            </button>
          )}
        </ConnectKitButton.Custom>
        {!runtime.projectId && (
          <p className="notice">Browser wallets are available. QR and mobile wallets require the WalletConnect Project ID on deployment.</p>
        )}
        <p className="status" aria-live="polite">{status}</p>
        <a href={runtime.cancelUrl || '/'}>Back to game</a>
      </section>
    </main>
  );
}

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ConnectKitProvider mode="dark" customTheme={{ '--ck-accent-color': '#f6c945', '--ck-accent-text-color': '#17271d' }}>
          <WalletConnect />
        </ConnectKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
);
