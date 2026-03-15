import { StatCard } from '@/components/stat-card';

export default function HomePage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Overview</h1>
        <p className="text-muted-foreground mt-2">Atlas Protocol — Decentralized Workflow Orchestrator</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard title="Total Workflows" value="—" description="Connect wallet to view" />
        <StatCard title="Active Workflows" value="—" description="Currently running" />
        <StatCard title="Total Executions" value="—" description="Steps executed" />
        <StatCard title="Active Executors" value="—" description="Network participants" />
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="rounded-lg border bg-card p-6">
          <h2 className="text-lg font-semibold mb-4">Recent Activity</h2>
          <p className="text-muted-foreground text-sm">No recent activity. Create your first workflow to get started.</p>
        </div>
        <div className="rounded-lg border bg-card p-6">
          <h2 className="text-lg font-semibold mb-4">Quick Actions</h2>
          <div className="space-y-2">
            <a href="/workflows/new" className="block p-3 rounded-md bg-primary/10 text-primary hover:bg-primary/20 transition-colors text-sm font-medium">
              Create New Workflow
            </a>
            <a href="/workflows" className="block p-3 rounded-md bg-secondary text-secondary-foreground hover:bg-secondary/80 transition-colors text-sm font-medium">
              View My Workflows
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
