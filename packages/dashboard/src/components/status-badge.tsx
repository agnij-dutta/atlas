import { cn } from '@/lib/utils';

interface StatusConfig {
  label: string;
  bracket: string;
  textColor: string;
  ping: boolean;
}

const STATUS_MAP: Record<number, StatusConfig> = {
  0: { label: 'NONE', bracket: '[NONE]', textColor: 'text-white/30', ping: false },
  1: { label: 'ACTIVE', bracket: '[ACTIVE]', textColor: 'text-emerald-400/70', ping: true },
  2: { label: 'PAUSED', bracket: '[PAUSED]', textColor: 'text-amber-400/70', ping: false },
  3: { label: 'COMPLETED', bracket: '[COMPLETED]', textColor: 'text-white/60', ping: false },
  4: { label: 'FAILED', bracket: '[FAILED]', textColor: 'text-red-400/70', ping: false },
};

export function StatusBadge({ status }: { status: number }) {
  const config = STATUS_MAP[status] || STATUS_MAP[0];

  return (
    <span className={cn('inline-flex items-center gap-1.5 font-mono text-[9px] tracking-[0.15em]', config.textColor)}>
      {config.ping && (
        <span className="relative flex h-1.5 w-1.5">
          <span className="animate-ping absolute h-full w-full rounded-full bg-emerald-400/60" />
          <span className="relative rounded-full h-1.5 w-1.5 bg-emerald-400/70" />
        </span>
      )}
      {config.bracket}
    </span>
  );
}
