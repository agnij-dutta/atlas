import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { StatCard } from '@/components/stat-card';

export default function ExecutorsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Executor Network</h1>
        <p className="text-muted-foreground mt-1">View the status of the executor network.</p>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard title="Active Executors" value="—" description="Currently online" />
        <StatCard title="Success Rate" value="—" description="Last 24 hours" />
        <StatCard title="Avg Gas Cost" value="—" description="Per execution" />
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Registered Executors</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Deploy contracts and register executors to see network status.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
