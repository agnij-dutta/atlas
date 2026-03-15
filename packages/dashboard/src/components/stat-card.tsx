import { cn } from '@/lib/utils';

interface StatCardProps {
  title: string;
  value: string;
  description?: string;
  className?: string;
}

export function StatCard({
  title,
  value,
  description,
  className,
}: StatCardProps) {
  return (
    <div
      className={cn(
        'border border-white/[0.06] bg-black p-5',
        'transition-colors duration-200',
        'hover:border-white/[0.12]',
        className,
      )}
    >
      <div className="text-[8px] text-white/20 tracking-[0.2em] uppercase mb-3">
        {title}
      </div>
      <div className="text-2xl font-bold tracking-wider text-white/90">
        {value}
      </div>
      {description && (
        <p className="text-[9px] text-white/20 tracking-wider mt-1.5">{description}</p>
      )}
    </div>
  );
}
