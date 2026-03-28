import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { baseSepolia } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'Atlas Protocol',
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID || '75628b0ef3dfd5cf95da9d669c0edda7',
  chains: [baseSepolia],
  ssr: true,
});
