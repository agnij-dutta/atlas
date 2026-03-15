'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { CONTRACTS, WORKFLOW_REGISTRY_ABI } from '@/lib/contracts';

const STEP_TYPES = ['CONTRACT CALL', 'TOKEN TRANSFER', 'CONDITION', 'DELAY'] as const;

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

const inputClasses =
  'w-full bg-transparent border-b border-white/10 px-0 py-2.5 text-[11px] text-white/80 placeholder:text-white/15 focus:border-white/30 focus:outline-none transition-colors duration-200 font-mono';

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
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="border border-white/[0.06] bg-black max-w-md w-full text-center p-14">
          <div className="text-[9px] text-white/20 tracking-[0.2em] mb-6">WALLET REQUIRED</div>
          <h2 className="text-lg font-bold tracking-[0.1em] text-white/90 mb-3">CONNECT WALLET</h2>
          <p className="text-[11px] text-white/30 leading-[1.8]">Connect to create workflows.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-10 pb-12">
      {/* ---- Header ---- */}
      <div>
        <Link href="/workflows" className="text-[9px] text-white/25 hover:text-white/50 transition-colors mb-4 inline-flex items-center gap-1.5 tracking-[0.15em]">
          &larr; BACK TO WORKFLOWS
        </Link>
        <div className="flex items-center gap-3 mb-2 mt-4">
          <div className="w-8 h-px bg-white/30" />
          <span className="text-[8px] text-white/20 tracking-[0.25em]">BUILDER</span>
        </div>
        <h1 className="text-2xl font-bold tracking-[0.1em] text-white/90">CREATE WORKFLOW</h1>
        <p className="text-[11px] text-white/30 mt-1.5 tracking-wider">
          Define your automation steps and deploy on-chain.
        </p>
      </div>

      {/* ---- Reward Configuration ---- */}
      <div className="border border-white/[0.06] bg-black p-6">
        <div className="text-[8px] text-white/20 tracking-[0.2em] uppercase mb-5">REWARD CONFIGURATION</div>

        <div className="space-y-5">
          <div>
            <label className="text-[8px] text-white/20 tracking-[0.2em] uppercase mb-2 block">
              REWARD PER STEP
            </label>
            <div className="relative">
              <input
                type="text"
                value={rewardPerStep}
                onChange={(e) => setRewardPerStep(e.target.value)}
                className={`${inputClasses} pr-14`}
                placeholder="0.001"
              />
              <span className="absolute right-0 top-1/2 -translate-y-1/2 text-[9px] text-white/20 tracking-wider">
                ETH
              </span>
            </div>
          </div>

          <div className="border-t border-white/[0.04] pt-4 flex items-center justify-between">
            <span className="text-[9px] text-white/30 tracking-wider">TOTAL COST</span>
            <span className="text-lg font-bold text-white/90 tracking-wider">
              {(Number(totalCost) / 1e18).toFixed(4)} ETH
            </span>
          </div>

          <p className="text-[9px] text-white/15 tracking-wider">
            {steps.length} step{steps.length !== 1 ? 's' : ''} x {rewardPerStep || '0'} ETH per step
          </p>
        </div>
      </div>

      {/* ---- Step Pipeline ---- */}
      <div>
        <div className="text-[8px] text-white/20 tracking-[0.2em] uppercase mb-5">
          WORKFLOW STEPS
        </div>

        <div className="relative">
          {/* Vertical connector line */}
          {steps.length > 1 && (
            <div
              className="absolute left-[11px] top-[40px] w-px bg-white/[0.06]"
              style={{ height: `calc(100% - 80px)` }}
            />
          )}

          <div className="space-y-4">
            {steps.map((step, index) => (
              <div key={index} className="relative flex gap-5">
                {/* Step number on the connector line */}
                <div className="flex-shrink-0 pt-5 z-10">
                  <div className="w-[22px] h-[22px] border border-white/20 bg-black flex items-center justify-center text-[9px] font-bold text-white/60">
                    {index + 1}
                  </div>
                </div>

                {/* Step card */}
                <div className="flex-1 border border-white/[0.06] bg-black p-5">
                  <div className="flex items-center justify-between mb-5">
                    <div className="flex items-center gap-3">
                      <span className="text-[8px] text-white/20 tracking-[0.2em]">STEP {index + 1}</span>

                      {/* Step type selector */}
                      <div className="flex border border-white/[0.06]">
                        {STEP_TYPES.map((label, i) => (
                          <button
                            key={i}
                            onClick={() => updateStep(index, 'type', i)}
                            className={`
                              px-2.5 py-1 text-[8px] tracking-[0.1em] transition-all duration-200
                              ${step.type === i
                                ? 'bg-white/[0.06] text-white/80'
                                : 'text-white/20 hover:text-white/40'
                              }
                            `}
                          >
                            {label}
                          </button>
                        ))}
                      </div>
                    </div>

                    {steps.length > 1 && (
                      <button
                        onClick={() => removeStep(index)}
                        className="text-white/15 hover:text-red-400/60 transition-colors duration-200 text-[9px] tracking-wider"
                      >
                        [REMOVE]
                      </button>
                    )}
                  </div>

                  <div className="space-y-4">
                    {(step.type === 0 || step.type === 1) && (
                      <div>
                        <label className="text-[8px] text-white/15 tracking-[0.2em] mb-1.5 block">
                          TARGET ADDRESS
                        </label>
                        <input
                          type="text"
                          value={step.target}
                          onChange={(e) => updateStep(index, 'target', e.target.value)}
                          className={inputClasses}
                          placeholder="0x..."
                        />
                      </div>
                    )}
                    {step.type === 0 && (
                      <div>
                        <label className="text-[8px] text-white/15 tracking-[0.2em] mb-1.5 block">
                          CALL DATA
                        </label>
                        <input
                          type="text"
                          value={step.callData}
                          onChange={(e) => updateStep(index, 'callData', e.target.value)}
                          className={inputClasses}
                          placeholder="0x..."
                        />
                      </div>
                    )}
                    {(step.type === 0 || step.type === 1) && (
                      <div>
                        <label className="text-[8px] text-white/15 tracking-[0.2em] mb-1.5 block">
                          VALUE (ETH)
                        </label>
                        <input
                          type="text"
                          value={step.value}
                          onChange={(e) => updateStep(index, 'value', e.target.value)}
                          className={inputClasses}
                          placeholder="0"
                        />
                      </div>
                    )}
                    {step.type === 3 && (
                      <div>
                        <label className="text-[8px] text-white/15 tracking-[0.2em] mb-1.5 block">
                          DELAY (SECONDS)
                        </label>
                        <input
                          type="text"
                          value={step.delay}
                          onChange={(e) => updateStep(index, 'delay', e.target.value)}
                          className={inputClasses}
                          placeholder="3600"
                        />
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Add Step Button */}
        <button
          onClick={addStep}
          className="w-full mt-4 py-3 border border-dashed border-white/[0.08] text-[9px] tracking-[0.15em] text-white/25 hover:text-white/50 hover:border-white/20 transition-all duration-200 flex items-center justify-center gap-2"
        >
          + ADD STEP
        </button>
      </div>

      {/* ---- Deploy Button ---- */}
      <button
        onClick={handleSubmit}
        disabled={isPending || isConfirming}
        className="group relative w-full py-4 border border-white/30 text-[11px] font-bold tracking-[0.2em] text-white bg-transparent hover:bg-white hover:text-black transition-all duration-200 disabled:opacity-30 disabled:pointer-events-none"
      >
        <span className="absolute -top-px -left-px w-3 h-3 border-t border-l border-white/50 opacity-0 group-hover:opacity-100 transition-opacity" />
        <span className="absolute -bottom-px -right-px w-3 h-3 border-b border-r border-white/50 opacity-0 group-hover:opacity-100 transition-opacity" />
        {isPending
          ? 'CONFIRM IN WALLET...'
          : isConfirming
            ? 'DEPLOYING ON-CHAIN...'
            : 'DEPLOY WORKFLOW'}
      </button>

      {/* ---- Success Message ---- */}
      {isSuccess && (
        <div className="border border-white/[0.06] bg-black p-5">
          <div className="flex items-center gap-2 mb-2">
            <span className="text-emerald-400/70 text-[9px] tracking-[0.15em]">[SUCCESS]</span>
          </div>
          <p className="text-[11px] text-white/50 leading-[1.8]">
            Workflow deployed on-chain.{' '}
            <Link href="/workflows" className="text-white/70 hover:text-white underline underline-offset-2 transition-colors">
              View all workflows
            </Link>
          </p>
        </div>
      )}
    </div>
  );
}
