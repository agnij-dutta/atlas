import { cn } from '@/lib/utils';
import { cva, type VariantProps } from 'class-variance-authority';
import type { HTMLAttributes } from 'react';

const badgeVariants = cva(
  'inline-flex items-center font-mono text-[9px] tracking-[0.15em] uppercase transition-colors duration-200',
  {
    variants: {
      variant: {
        default: 'border border-white/20 text-white/60 px-2 py-0.5',
        highlight: 'border border-white/40 text-white/80 px-2 py-0.5',
        success: 'border border-white/20 text-emerald-400/70 px-2 py-0.5',
        warning: 'border border-white/20 text-amber-400/70 px-2 py-0.5',
        destructive: 'border border-white/20 text-red-400/70 px-2 py-0.5',
        secondary: 'border border-white/10 text-white/40 px-2 py-0.5',
        outline: 'border border-white/20 text-white/60 px-2 py-0.5',
      },
    },
    defaultVariants: { variant: 'default' },
  },
);

export interface BadgeProps extends HTMLAttributes<HTMLDivElement>, VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}
