'use client';

import Link from 'next/link';
import { useAccount, useReadContract } from 'wagmi';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { StatusBadge } from '@/components/status-badge';
import { Button } from '@/components/ui/button';
import { CONTRACTS, WORKFLOW_REGISTRY_ABI } from '@/lib/contracts';
import { formatEth, shortenAddress } from '@/lib/utils';

export default function WorkflowsPage() {
  const { address, isConnected } = useAccount();

  const { data: workflowCount } = useReadContract({
    address: CONTRACTS.workflowRegistry,
    abi: WORKFLOW_REGISTRY_ABI,
    functionName: 'workflowCount',
  });

  if (!isConnected) {
    return (
      <div className="text-center py-20">
        <h2 className="text-2xl font-bold mb-2">Connect Your Wallet</h2>
        <p className="text-muted-foreground">Connect your wallet to view your workflows.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Workflows</h1>
          <p className="text-muted-foreground mt-1">
            {workflowCount ? `${workflowCount} total workflows` : 'Loading...'}
          </p>
        </div>
        <Link href="/workflows/new">
          <Button>Create Workflow</Button>
        </Link>
      </div>

      <div className="grid gap-4">
        {workflowCount === 0n && (
          <Card>
            <CardContent className="py-10 text-center">
              <p className="text-muted-foreground">No workflows yet. Create your first one!</p>
            </CardContent>
          </Card>
        )}
        {/* Workflow cards will be populated from contract reads */}
        <p className="text-sm text-muted-foreground">
          Deploy contracts and connect to Base Sepolia to view workflows.
        </p>
      </div>
    </div>
  );
}
