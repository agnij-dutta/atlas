'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useAccount, useReadContract } from 'wagmi';
import { StatusBadge } from '@/components/status-badge';
import { CONTRACTS, WORKFLOW_REGISTRY_ABI } from '@/lib/contracts';

const FILTERS = ['All', 'Active', 'Paused', 'Completed', 'Failed'] as const;
const FILTER_STATUS_MAP: Record<string, number | null> = {
  All: null,
  Active: 1,
  Paused: 2,
  Completed: 3,
  Failed: 4,
};

/* ---------- mock workflows for visual richness ---------- */
const MOCK_WORKFLOWS = [
  { id: 1, status: 1, currentStep: 2, totalSteps: 5, rewardPerStep: '0.0010', created: '2026-03-14' },
  { id: 2, status: 3, currentStep: 4, totalSteps: 4, rewardPerStep: '0.0025', created: '2026-03-12' },
  { id: 3, status: 2, currentStep: 1, totalSteps: 3, rewardPerStep: '0.0050', created: '2026-03-10' },
  { id: 4, status: 4, currentStep: 3, totalSteps: 6, rewardPerStep: '0.0015', created: '2026-03-09' },
  { id: 5, status: 1, currentStep: 0, totalSteps: 2, rewardPerStep: '0.0100', created: '2026-03-08' },
];

export default function WorkflowsPage() {
  const { address, isConnected } = useAccount();
  const [activeFilter, setActiveFilter] = useState<string>('All');

  const { data: workflowCount } = useReadContract({
    address: CONTRACTS.workflowRegistry,
    abi: WORKFLOW_REGISTRY_ABI,
    functionName: 'workflowCount',
  });

  const filteredWorkflows = MOCK_WORKFLOWS.filter((wf) => {
    const statusFilter = FILTER_STATUS_MAP[activeFilter];
    return statusFilter === null || wf.status === statusFilter;
  });

  if (!isConnected) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="border border-white/[0.06] bg-black max-w-md w-full text-center p-14">
          <div className="text-[9px] text-white/20 tracking-[0.2em] mb-6">WALLET REQUIRED</div>
          <h2 className="text-lg font-bold tracking-[0.1em] text-white/90 mb-3">CONNECT WALLET</h2>
          <p className="text-[11px] text-white/30 leading-[1.8]">
            Connect your wallet to view and manage your automated workflows.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* ---- Header ---- */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <div className="w-8 h-px bg-white/30" />
            <span className="text-[8px] text-white/20 tracking-[0.25em]">DASHBOARD</span>
          </div>
          <h1 className="text-2xl font-bold tracking-[0.1em] text-white/90">MY WORKFLOWS</h1>
          <p className="text-[11px] text-white/30 mt-1.5 tracking-wider">
            {workflowCount !== undefined
              ? `${Number(workflowCount)} workflow${Number(workflowCount) !== 1 ? 's' : ''} deployed on-chain`
              : 'Loading workflow count...'}
          </p>
        </div>
        <Link
          href="/workflows/new"
          className="group relative inline-flex items-center justify-center px-6 py-2.5 border border-white/30 text-[10px] tracking-[0.2em] text-white hover:bg-white hover:text-black transition-all duration-200"
        >
          <span className="absolute -top-px -left-px w-2 h-2 border-t border-l border-white/50 opacity-0 group-hover:opacity-100 transition-opacity" />
          <span className="absolute -bottom-px -right-px w-2 h-2 border-b border-r border-white/50 opacity-0 group-hover:opacity-100 transition-opacity" />
          + CREATE WORKFLOW
        </Link>
      </div>

      {/* ---- Filter Tabs ---- */}
      <div className="flex flex-wrap gap-1">
        {FILTERS.map((filter) => (
          <button
            key={filter}
            onClick={() => setActiveFilter(filter)}
            className={`
              px-3 py-1.5 text-[9px] tracking-[0.15em] uppercase transition-all duration-200 border
              ${activeFilter === filter
                ? 'border-white/30 text-white/90'
                : 'border-transparent text-white/25 hover:text-white/50'
              }
            `}
          >
            {filter}
          </button>
        ))}
      </div>

      {/* ---- Workflow Table ---- */}
      {filteredWorkflows.length === 0 ? (
        <div className="border border-white/[0.06] bg-black text-center py-16 px-8">
          <div className="text-[9px] text-white/15 tracking-[0.2em] mb-4">NO RESULTS</div>
          <h3 className="text-[13px] font-bold tracking-[0.1em] text-white/60 mb-2">NO WORKFLOWS FOUND</h3>
          <p className="text-[11px] text-white/25 mb-6">
            Create your first automated workflow to get started.
          </p>
          <Link
            href="/workflows/new"
            className="inline-flex items-center justify-center px-6 py-2.5 border border-white/30 text-[10px] tracking-[0.2em] text-white hover:bg-white hover:text-black transition-all duration-200"
          >
            CREATE WORKFLOW
          </Link>
        </div>
      ) : (
        <div className="border border-white/[0.06]">
          {/* Table header */}
          <div className="grid grid-cols-[1fr_1fr_0.8fr_0.8fr_1fr] gap-4 px-5 py-3 border-b border-white/[0.06] text-[8px] text-white/20 tracking-[0.2em] uppercase">
            <span>ID</span>
            <span>STATUS</span>
            <span>PROGRESS</span>
            <span>REWARD</span>
            <span>CREATED</span>
          </div>

          {/* Table rows */}
          {filteredWorkflows.map((wf) => (
            <Link key={wf.id} href={`/workflows/${wf.id}`} className="block">
              <div className="grid grid-cols-[1fr_1fr_0.8fr_0.8fr_1fr] gap-4 px-5 py-4 border-b border-white/[0.03] hover:bg-white/[0.02] transition-colors duration-150 items-center">
                <span className="text-[11px] text-white/70">
                  WF-{String(wf.id).padStart(4, '0')}
                </span>
                <StatusBadge status={wf.status} />
                <span className="text-[11px] text-white/50">
                  {wf.currentStep}/{wf.totalSteps}
                </span>
                <span className="text-[11px] text-white/40">
                  {wf.rewardPerStep} ETH
                </span>
                <span className="text-[11px] text-white/25">
                  {wf.created}
                </span>
              </div>
            </Link>
          ))}
        </div>
      )}

      {/* ---- Info note ---- */}
      <p className="text-[9px] text-white/15 text-center tracking-wider pt-4">
        DEPLOY CONTRACTS AND CONNECT TO BASE SEPOLIA TO VIEW LIVE WORKFLOWS
      </p>
    </div>
  );
}
