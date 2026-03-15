'use client';

import { useParams } from 'next/navigation';
import { useReadContract, useWriteContract } from 'wagmi';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { StatusBadge } from '@/components/status-badge';
import { Badge } from '@/components/ui/badge';
import { CONTRACTS, WORKFLOW_REGISTRY_ABI } from '@/lib/contracts';
import { formatEth, shortenAddress, formatTimestamp } from '@/lib/utils';

const STEP_TYPE_LABELS = ['Contract Call', 'Token Transfer', 'Condition Check', 'Delay'];

export default function WorkflowDetailPage() {
  const { id } = useParams<{ id: string }>();
  const workflowId = BigInt(id || '0');

  const { data: workflow } = useReadContract({
    address: CONTRACTS.workflowRegistry,
    abi: WORKFLOW_REGISTRY_ABI,
    functionName: 'getWorkflow',
    args: [workflowId],
  });

  const { data: steps } = useReadContract({
    address: CONTRACTS.workflowRegistry,
    abi: WORKFLOW_REGISTRY_ABI,
    functionName: 'getSteps',
    args: [workflowId],
  });

  const { writeContract: pause } = useWriteContract();
  const { writeContract: resume } = useWriteContract();
  const { writeContract: cancel } = useWriteContract();

  if (!workflow) {
    return <p className="text-muted-foreground py-10 text-center">Loading workflow...</p>;
  }

  const wf = workflow as any;

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Workflow #{id}</h1>
          <p className="text-muted-foreground mt-1">Owner: {shortenAddress(wf.owner)}</p>
        </div>
        <StatusBadge status={Number(wf.status)} />
      </div>

      {/* Info */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground">Progress</div>
            <div className="text-2xl font-bold">{Number(wf.currentStepIndex)} / {Number(wf.totalSteps)}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground">Reward Balance</div>
            <div className="text-2xl font-bold">{formatEth(wf.rewardBalance)}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-sm text-muted-foreground">Reward Per Step</div>
            <div className="text-2xl font-bold">{formatEth(wf.rewardPerStep)}</div>
          </CardContent>
        </Card>
      </div>

      {/* Controls */}
      {Number(wf.status) <= 2 && (
        <div className="flex gap-2">
          {Number(wf.status) === 1 && (
            <Button variant="outline" onClick={() => pause({ address: CONTRACTS.workflowRegistry, abi: WORKFLOW_REGISTRY_ABI, functionName: 'pauseWorkflow', args: [workflowId] })}>
              Pause
            </Button>
          )}
          {Number(wf.status) === 2 && (
            <Button variant="outline" onClick={() => resume({ address: CONTRACTS.workflowRegistry, abi: WORKFLOW_REGISTRY_ABI, functionName: 'resumeWorkflow', args: [workflowId] })}>
              Resume
            </Button>
          )}
          <Button variant="destructive" onClick={() => cancel({ address: CONTRACTS.workflowRegistry, abi: WORKFLOW_REGISTRY_ABI, functionName: 'cancelWorkflow', args: [workflowId] })}>
            Cancel
          </Button>
        </div>
      )}

      {/* Step Timeline */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Steps</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {(steps as any[])?.map((step: any, index: number) => (
              <div key={index} className="flex items-start gap-4">
                <div className="flex flex-col items-center">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold ${
                    index < Number(wf.currentStepIndex)
                      ? 'bg-green-600 text-white'
                      : index === Number(wf.currentStepIndex)
                        ? 'bg-primary text-primary-foreground'
                        : 'bg-muted text-muted-foreground'
                  }`}>
                    {index + 1}
                  </div>
                  {index < (steps as any[]).length - 1 && (
                    <div className="w-0.5 h-8 bg-border mt-1" />
                  )}
                </div>
                <div className="flex-1 pb-4">
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-sm">{STEP_TYPE_LABELS[Number(step.stepType)]}</span>
                    {index < Number(wf.currentStepIndex) && <Badge variant="success">Done</Badge>}
                    {index === Number(wf.currentStepIndex) && Number(wf.status) === 1 && <Badge>Current</Badge>}
                  </div>
                  {step.target !== '0x0000000000000000000000000000000000000000' && (
                    <p className="text-xs text-muted-foreground mt-1 font-mono">{shortenAddress(step.target)}</p>
                  )}
                  {Number(step.delay) > 0 && (
                    <p className="text-xs text-muted-foreground mt-1">Delay: {Number(step.delay)}s</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Timestamps */}
      <Card>
        <CardContent className="pt-6 space-y-2 text-sm">
          <div className="flex justify-between">
            <span className="text-muted-foreground">Created</span>
            <span>{formatTimestamp(wf.createdAt)}</span>
          </div>
          {wf.lastExecutedAt > 0n && (
            <div className="flex justify-between">
              <span className="text-muted-foreground">Last Executed</span>
              <span>{formatTimestamp(wf.lastExecutedAt)}</span>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
