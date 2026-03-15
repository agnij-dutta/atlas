'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { cn } from '@/lib/utils';

const navItems = [
  { href: '/workflows', label: 'WORKFLOWS' },
  { href: '/workflows/new', label: 'CREATE' },
  { href: '/executors', label: 'EXECUTORS' },
  { href: '/analytics', label: 'ANALYTICS' },
];

export function Navbar() {
  const pathname = usePathname();

  return (
    <nav className="sticky top-0 z-50 bg-black/90 backdrop-blur-sm border-b border-white/[0.08]">
      <div className="max-w-[1200px] mx-auto px-5 lg:px-10 flex items-center justify-between h-14">
        {/* Logo */}
        <div className="flex items-center gap-6 lg:gap-8">
          <Link href="/" className="flex items-center gap-2.5">
            <span className="text-base font-bold tracking-[0.3em] text-white">
              ATLAS
            </span>
            <span className="h-3.5 w-px bg-white/20" />
            <span className="text-[8px] tracking-[0.2em] text-white/30">
              PROTOCOL
            </span>
          </Link>

          {/* Nav */}
          <div className="hidden md:flex items-center gap-0.5">
            {navItems.map((item) => {
              const isActive = pathname === item.href;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    'relative px-3.5 py-2 text-[10px] tracking-[0.15em] transition-colors duration-200',
                    isActive
                      ? 'text-white'
                      : 'text-white/40 hover:text-white/70',
                  )}
                >
                  {item.label}
                  {isActive && (
                    <span className="absolute bottom-1 left-3.5 right-3.5 h-px bg-white/80" />
                  )}
                </Link>
              );
            })}
          </div>
        </div>

        {/* Connect */}
        <ConnectButton.Custom>
          {({ account, chain, openConnectModal, openAccountModal, openChainModal, mounted }) => {
            const connected = mounted && account && chain;
            return (
              <div
                {...(!mounted && {
                  'aria-hidden': true,
                  style: { opacity: 0, pointerEvents: 'none' as const, userSelect: 'none' as const },
                })}
              >
                {!connected ? (
                  <button
                    onClick={openConnectModal}
                    className="group relative px-5 py-2 border border-white/30 text-[10px] tracking-[0.2em] text-white hover:bg-white hover:text-black transition-all duration-200 font-mono"
                  >
                    <span className="absolute -top-px -left-px w-1.5 h-1.5 border-t border-l border-white/40 opacity-0 group-hover:opacity-100 transition-opacity" />
                    <span className="absolute -bottom-px -right-px w-1.5 h-1.5 border-b border-r border-white/40 opacity-0 group-hover:opacity-100 transition-opacity" />
                    CONNECT
                  </button>
                ) : (
                  <div className="flex items-center gap-2">
                    <button
                      onClick={openChainModal}
                      className="px-3 py-1.5 border border-white/10 text-[9px] tracking-[0.1em] text-white/50 hover:border-white/20 hover:text-white/70 transition-all duration-200 font-mono"
                    >
                      {chain.name?.toUpperCase() || 'CHAIN'}
                    </button>
                    <button
                      onClick={openAccountModal}
                      className="px-3 py-1.5 border border-white/15 text-[9px] tracking-[0.1em] text-white/60 hover:border-white/30 hover:text-white transition-all duration-200 font-mono"
                    >
                      {account.displayName}
                    </button>
                  </div>
                )}
              </div>
            );
          }}
        </ConnectButton.Custom>
      </div>
    </nav>
  );
}
