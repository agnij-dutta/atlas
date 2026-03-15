import { Badge } from '@/components/ui/badge';

const STATUS_MAP: Record<number, { label: string; variant: 'default' | 'success' | 'warning' | 'destructive' | 'secondary' }> = {
  0: { label: 'None', variant: 'secondary' },
  1: { label: 'Active', variant: 'default' },
  2: { label: 'Paused', variant: 'warning' },
  3: { label: 'Completed', variant: 'success' },
  4: { label: 'Failed', variant: 'destructive' },
};

export function StatusBadge({ status }: { status: number }) {
  const { label, variant } = STATUS_MAP[status] || STATUS_MAP[0];
  return <Badge variant={variant}>{label}</Badge>;
}
