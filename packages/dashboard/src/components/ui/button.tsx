import { cn } from '@/lib/utils';
import { cva, type VariantProps } from 'class-variance-authority';
import { forwardRef, type ButtonHTMLAttributes } from 'react';

const buttonVariants = cva(
  [
    'group relative inline-flex items-center justify-center font-mono text-[10px] tracking-[0.15em] uppercase',
    'transition-all duration-200',
    'disabled:pointer-events-none disabled:opacity-30',
  ].join(' '),
  {
    variants: {
      variant: {
        default: [
          'border border-white/30 text-white bg-transparent',
          'hover:bg-white hover:text-black',
        ].join(' '),
        destructive: [
          'border border-red-400/30 text-red-400/60 bg-transparent',
          'hover:bg-red-400/10 hover:text-red-400/80',
        ].join(' '),
        outline: [
          'border border-white/20 text-white/60 bg-transparent',
          'hover:border-white/40 hover:text-white/80',
        ].join(' '),
        secondary: [
          'border border-white/10 text-white/40 bg-transparent',
          'hover:border-white/20 hover:text-white/60',
        ].join(' '),
        ghost: [
          'text-white/40 bg-transparent border border-transparent',
          'hover:text-white/70 hover:border-white/10',
        ].join(' '),
      },
      size: {
        default: 'h-10 px-5 py-2',
        sm: 'h-8 px-3 text-[9px]',
        lg: 'h-12 px-8 text-[11px]',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
);

export interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(buttonVariants({ variant, size }), className)}
        {...props}
      >
        {/* Corner accents on hover */}
        <span className="absolute -top-px -left-px w-2 h-2 border-t border-l border-white/50 opacity-0 group-hover:opacity-100 transition-opacity" />
        <span className="absolute -bottom-px -right-px w-2 h-2 border-b border-r border-white/50 opacity-0 group-hover:opacity-100 transition-opacity" />
        {children}
      </button>
    );
  },
);
Button.displayName = 'Button';
