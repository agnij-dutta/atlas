'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { StatCard } from '@/components/stat-card';

export default function AnalyticsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Analytics</h1>
        <p className="text-muted-foreground mt-1">Protocol performance metrics.</p>
      </div>

      <div className="grid gap-4 md:grid-cols-4">
        <StatCard title="Total Workflows" value="—" />
        <StatCard title="Completed" value="—" />
        <StatCard title="Total Rewards Paid" value="—" />
        <StatCard title="Avg Steps/Workflow" value="—" />
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader><CardTitle className="text-lg">Executions Over Time</CardTitle></CardHeader>
          <CardContent className="h-64 flex items-center justify-center">
            <p className="text-sm text-muted-foreground">Chart will populate with subgraph data.</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle className="text-lg">Gas Costs</CardTitle></CardHeader>
          <CardContent className="h-64 flex items-center justify-center">
            <p className="text-sm text-muted-foreground">Chart will populate with subgraph data.</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
