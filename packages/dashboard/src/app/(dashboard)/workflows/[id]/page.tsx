'use client';

import { useParams } from 'next/navigation';
import Link from 'next/link';
import { useReadContract, useWriteContract } from 'wagmi';
import { StatusBadge } from '@/components/status-badge';
import { CONTRACTS, WORKFLOW_REGISTRY_ABI } from '@/lib/contracts';
import { formatEth, shortenAddress, formatTimestamp } from '@/lib/utils';

const STEP_TYPE_LABELS = ['CONTRACT CALL', 'TOKEN TRANSFER', 'CONDITION CHECK', 'DELAY'];

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
    return (
      <div className="py-20 text-center">
        <span className="text-[11px] text-white/30 tracking-wider">LOADING WORKFLOW...</span>
      </div>
    );
  }

  const wf = workflow as any;

  return (
    <div className="max-w-3xl mx-auto space-y-8 pb-12">
      {/* ---- Back link ---- */}
      <Link href="/workflows" className="text-[9px] text-white/25 hover:text-white/50 transition-colors inline-flex items-center gap-1.5 tracking-[0.15em]">
        &larr; BACK TO WORKFLOWS
      </Link>

      {/* ---- Header ---- */}
      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <div className="w-8 h-px bg-white/30" />
            <span className="text-[8px] text-white/20 tracking-[0.25em]">WORKFLOW</span>
          </div>
          <h1 className="text-2xl font-bold tracking-[0.1em] text-white/90">
            WF-{String(id).padStart(4, '0')}
          </h1>
          <p className="text-[11px] text-white/30 mt-1.5 tracking-wider">
            OWNER: {shortenAddress(wf.owner)}
          </p>
        </div>
        <StatusBadge status={Number(wf.status)} />
      </div>

      {/* ---- Stats ---- */}
      <div className="border border-white/[0.06] bg-black">
        <div className="grid grid-cols-3 divide-x divide-white/[0.04]">
          <div className="p-5">
            <div className="text-[8px] text-white/20 tracking-[0.2em] mb-2">PROGRESS</div>
            <div className="text-xl font-bold text-white/90 tracking-wider">
              {Number(wf.currentStepIndex)}/{Number(wf.totalSteps)}
            </div>
          </div>
          <div className="p-5">
            <div className="text-[8px] text-white/20 tracking-[0.2em] mb-2">REWARD BALANCE</div>
            <div className="text-xl font-bold text-white/90 tracking-wider">{formatEth(wf.rewardBalance)}</div>
          </div>
          <div className="p-5">
            <div className="text-[8px] text-white/20 tracking-[0.2em] mb-2">REWARD/STEP</div>
            <div className="text-xl font-bold text-white/90 tracking-wider">{formatEth(wf.rewardPerStep)}</div>
          </div>
        </div>
      </div>

      {/* ---- Controls ---- */}
      {Number(wf.status) <= 2 && (
        <div className="flex gap-2">
          {Number(wf.status) === 1 && (
            <button
              onClick={() => pause({ address: CONTRACTS.workflowRegistry, abi: WORKFLOW_REGISTRY_ABI, functionName: 'pauseWorkflow', args: [workflowId] })}
              className="px-5 py-2 border border-white/20 text-[9px] tracking-[0.15em] text-white/50 hover:border-white/40 hover:text-white/80 transition-all duration-200"
            >
              PAUSE
            </button>
          )}
          {Number(wf.status) === 2 && (
            <button
              onClick={() => resume({ address: CONTRACTS.workflowRegistry, abi: WORKFLOW_REGISTRY_ABI, functionName: 'resumeWorkflow', args: [workflowId] })}
              className="px-5 py-2 border border-white/20 text-[9px] tracking-[0.15em] text-white/50 hover:border-white/40 hover:text-white/80 transition-all duration-200"
            >
              RESUME
            </button>
          )}
          <button
            onClick={() => cancel({ address: CONTRACTS.workflowRegistry, abi: WORKFLOW_REGISTRY_ABI, functionName: 'cancelWorkflow', args: [workflowId] })}
            className="px-5 py-2 border border-red-400/30 text-[9px] tracking-[0.15em] text-red-400/60 hover:bg-red-400/10 hover:text-red-400/80 transition-all duration-200"
          >
            CANCEL
          </button>
        </div>
      )}

      {/* ---- Step Timeline ---- */}
      <div className="border border-white/[0.06] bg-black">
        <div className="px-5 py-3 border-b border-white/[0.06]">
          <span className="text-[8px] text-white/20 tracking-[0.2em]">STEP TIMELINE</span>
        </div>
        <div className="p-5">
          <div className="space-y-0">
            {(steps as any[])?.map((step: any, index: number) => {
              const isDone = index < Number(wf.currentStepIndex);
              const isCurrent = index === Number(wf.currentStepIndex) && Number(wf.status) === 1;
              const isPending = !isDone && !isCurrent;

              return (
                <div key={index} className="flex items-start gap-4">
                  <div className="flex flex-col items-center">
                    {/* Step marker */}
                    <div className="text-[11px] font-mono text-white/60 py-1">
                      {isDone ? '[x]' : isCurrent ? '[>]' : '[ ]'}
                    </div>
                    {/* Connector */}
                    {index < (steps as any[]).length - 1 && (
                      <div className="w-px h-6 bg-white/[0.06]" />
                    )}
                  </div>
                  <div className="flex-1 pb-4 pt-0.5">
                    <div className="flex items-center gap-3">
                      <span className={`text-[11px] tracking-wider ${isDone ? 'text-white/50' : isCurrent ? 'text-white/90' : 'text-white/25'}`}>
                        {STEP_TYPE_LABELS[Number(step.stepType)]}
                      </span>
                      {isDone && (
                        <span className="text-[8px] text-emerald-400/60 tracking-[0.15em]">DONE</span>
                      )}
                      {isCurrent && (
                        <span className="flex items-center gap-1">
                          <span className="relative flex h-1.5 w-1.5">
                            <span className="animate-ping absolute h-full w-full rounded-full bg-white/60" />
                            <span className="relative rounded-full h-1.5 w-1.5 bg-white" />
                          </span>
                          <span className="text-[8px] text-white/60 tracking-[0.15em]">CURRENT</span>
                        </span>
                      )}
                    </div>
                    {step.target !== '0x0000000000000000000000000000000000000000' && (
                      <p className="text-[10px] text-white/20 mt-0.5 tracking-wider">{shortenAddress(step.target)}</p>
                    )}
                    {Number(step.delay) > 0 && (
                      <p className="text-[10px] text-white/20 mt-0.5 tracking-wider">DELAY: {Number(step.delay)}s</p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* ---- Timestamps ---- */}
      <div className="border border-white/[0.06] bg-black p-5 space-y-3">
        <div className="text-[8px] text-white/20 tracking-[0.2em] mb-3">TIMESTAMPS</div>
        <div className="flex justify-between text-[11px]">
          <span className="text-white/30 tracking-wider">CREATED</span>
          <span className="text-white/60">{formatTimestamp(wf.createdAt)}</span>
        </div>
        {wf.lastExecutedAt > 0n && (
          <div className="flex justify-between text-[11px]">
            <span className="text-white/30 tracking-wider">LAST EXECUTED</span>
            <span className="text-white/60">{formatTimestamp(wf.lastExecutedAt)}</span>
          </div>
        )}
      </div>
    </div>
  );
}
