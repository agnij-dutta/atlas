'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { CONTRACTS, WORKFLOW_REGISTRY_ABI } from '@/lib/contracts';

const STEP_TYPES = ['Contract Call', 'Token Transfer', 'Condition Check', 'Delay'] as const;

interface StepConfig {
  type: number;
  target: string;
  callData: string;
  value: string;
  delay: string;
}

const emptyStep = (): StepConfig => ({
  type: 0,
  target: '',
  callData: '0x',
  value: '0',
  delay: '0',
});

export default function NewWorkflowPage() {
  const { isConnected } = useAccount();
  const [steps, setSteps] = useState<StepConfig[]>([emptyStep()]);
  const [rewardPerStep, setRewardPerStep] = useState('0.001');

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const addStep = () => setSteps([...steps, emptyStep()]);
  const removeStep = (index: number) => setSteps(steps.filter((_, i) => i !== index));

  const updateStep = (index: number, field: keyof StepConfig, value: string | number) => {
    const updated = [...steps];
    (updated[index] as any)[field] = value;
    setSteps(updated);
  };

  const totalCost = parseEther(rewardPerStep || '0') * BigInt(steps.length);

  const handleSubmit = () => {
    const formattedSteps = steps.map((s) => ({
      stepType: s.type,
      target: (s.target || '0x0000000000000000000000000000000000000000') as `0x${string}`,
      callData: (s.callData || '0x') as `0x${string}`,
      value: parseEther(s.value || '0'),
      delay: BigInt(s.delay || '0'),
      conditionData: '0x' as `0x${string}`,
    }));

    writeContract({
      address: CONTRACTS.workflowRegistry,
      abi: WORKFLOW_REGISTRY_ABI,
      functionName: 'createWorkflow',
      args: [formattedSteps, parseEther(rewardPerStep)],
      value: totalCost,
    });
  };

  if (!isConnected) {
    return (
      <div className="text-center py-20">
        <h2 className="text-2xl font-bold mb-2">Connect Your Wallet</h2>
        <p className="text-muted-foreground">Connect to create workflows.</p>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Create Workflow</h1>
        <p className="text-muted-foreground mt-1">Define steps and deploy your workflow on-chain.</p>
      </div>

      {/* Reward config */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Reward Configuration</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="text-sm font-medium text-muted-foreground">Reward Per Step (ETH)</label>
            <input
              type="text"
              value={rewardPerStep}
              onChange={(e) => setRewardPerStep(e.target.value)}
              className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
              placeholder="0.001"
            />
          </div>
          <div className="text-sm text-muted-foreground">
            Total cost: {(Number(totalCost) / 1e18).toFixed(4)} ETH ({steps.length} steps)
          </div>
        </CardContent>
      </Card>

      {/* Steps */}
      <div className="space-y-4">
        {steps.map((step, index) => (
          <Card key={index}>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <div className="flex items-center gap-2">
                <Badge variant="outline">Step {index + 1}</Badge>
                <select
                  value={step.type}
                  onChange={(e) => updateStep(index, 'type', Number(e.target.value))}
                  className="rounded-md border bg-background px-2 py-1 text-sm"
                >
                  {STEP_TYPES.map((label, i) => (
                    <option key={i} value={i}>{label}</option>
                  ))}
                </select>
              </div>
              {steps.length > 1 && (
                <Button variant="ghost" size="sm" onClick={() => removeStep(index)}>
                  Remove
                </Button>
              )}
            </CardHeader>
            <CardContent className="space-y-3">
              {(step.type === 0 || step.type === 1) && (
                <div>
                  <label className="text-xs text-muted-foreground">Target Address</label>
                  <input
                    type="text"
                    value={step.target}
                    onChange={(e) => updateStep(index, 'target', e.target.value)}
                    className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm font-mono"
                    placeholder="0x..."
                  />
                </div>
              )}
              {step.type === 0 && (
                <div>
                  <label className="text-xs text-muted-foreground">Call Data</label>
                  <input
                    type="text"
                    value={step.callData}
                    onChange={(e) => updateStep(index, 'callData', e.target.value)}
                    className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm font-mono"
                    placeholder="0x..."
                  />
                </div>
              )}
              {(step.type === 0 || step.type === 1) && (
                <div>
                  <label className="text-xs text-muted-foreground">Value (ETH)</label>
                  <input
                    type="text"
                    value={step.value}
                    onChange={(e) => updateStep(index, 'value', e.target.value)}
                    className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                    placeholder="0"
                  />
                </div>
              )}
              {step.type === 3 && (
                <div>
                  <label className="text-xs text-muted-foreground">Delay (seconds)</label>
                  <input
                    type="text"
                    value={step.delay}
                    onChange={(e) => updateStep(index, 'delay', e.target.value)}
                    className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                    placeholder="3600"
                  />
                </div>
              )}
            </CardContent>
          </Card>
        ))}
      </div>

      <Button variant="outline" onClick={addStep} className="w-full">
        + Add Step
      </Button>

      <Button onClick={handleSubmit} disabled={isPending || isConfirming} className="w-full" size="lg">
        {isPending ? 'Confirm in wallet...' : isConfirming ? 'Deploying...' : 'Deploy Workflow'}
      </Button>

      {isSuccess && (
        <div className="rounded-lg border border-green-600 bg-green-600/10 p-4 text-sm text-green-400">
          Workflow created successfully! View it on the Workflows page.
        </div>
      )}
    </div>
  );
}
