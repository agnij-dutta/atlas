import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { baseSepolia } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'Atlas Protocol',
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID || 'atlas-dev',
  chains: [baseSepolia],
  ssr: true,
});
