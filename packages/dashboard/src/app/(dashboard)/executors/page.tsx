import { StatCard } from '@/components/stat-card';

const MOCK_EXECUTORS = [
  { address: '0x742d...35Cc', executions: 142, successRate: '98.6%', lastActive: '2 min ago', stake: '1.5 ETH' },
  { address: '0x8ba1...9F2e', executions: 89, successRate: '97.2%', lastActive: '5 min ago', stake: '1.0 ETH' },
  { address: '0x3c44...93F8', executions: 67, successRate: '99.1%', lastActive: '12 min ago', stake: '2.0 ETH' },
  { address: '0xf39F...2266', executions: 45, successRate: '95.5%', lastActive: '1 hr ago', stake: '0.5 ETH' },
  { address: '0x9965...1aB4', executions: 23, successRate: '100%', lastActive: '3 hr ago', stake: '0.8 ETH' },
];

export default function ExecutorsPage() {
  return (
    <div className="space-y-8">
      {/* ---- Header ---- */}
      <div>
        <div className="flex items-center gap-3 mb-2">
          <div className="w-8 h-px bg-white/30" />
          <span className="text-[8px] text-white/20 tracking-[0.25em]">NETWORK</span>
        </div>
        <h1 className="text-2xl font-bold tracking-[0.1em] text-white/90">EXECUTOR NETWORK</h1>
        <p className="text-[11px] text-white/30 mt-1.5 tracking-wider">
          View the status of the decentralized executor network.
        </p>
      </div>

      {/* ---- Stats ---- */}
      <div className="grid gap-px bg-white/[0.04] md:grid-cols-3">
        <StatCard title="ACTIVE EXECUTORS" value="5" description="Currently online" />
        <StatCard title="SUCCESS RATE" value="98.1%" description="Last 24 hours" />
        <StatCard title="AVG GAS COST" value="0.0012 ETH" description="Per execution" />
      </div>

      {/* ---- Executor Table ---- */}
      <div className="border border-white/[0.06]">
        <div className="px-5 py-3 border-b border-white/[0.06]">
          <span className="text-[8px] text-white/20 tracking-[0.2em]">REGISTERED EXECUTORS</span>
        </div>

        {/* Table header */}
        <div className="grid grid-cols-[1.2fr_0.8fr_0.8fr_0.8fr_0.8fr] gap-4 px-5 py-3 border-b border-white/[0.06] text-[8px] text-white/20 tracking-[0.2em] uppercase">
          <span>ADDRESS</span>
          <span>EXECUTIONS</span>
          <span>SUCCESS</span>
          <span>STAKE</span>
          <span>LAST ACTIVE</span>
        </div>

        {/* Table rows */}
        {MOCK_EXECUTORS.map((executor) => (
          <div
            key={executor.address}
            className="grid grid-cols-[1.2fr_0.8fr_0.8fr_0.8fr_0.8fr] gap-4 px-5 py-4 border-b border-white/[0.03] hover:bg-white/[0.02] transition-colors duration-150 items-center"
          >
            <span className="text-[11px] text-white/70">{executor.address}</span>
            <span className="text-[11px] text-white/50">{executor.executions}</span>
            <span className="text-[11px] text-emerald-400/70">{executor.successRate}</span>
            <span className="text-[11px] text-white/40">{executor.stake}</span>
            <span className="text-[11px] text-white/25">{executor.lastActive}</span>
          </div>
        ))}
      </div>

      {/* ---- Info note ---- */}
      <p className="text-[9px] text-white/15 text-center tracking-wider pt-2">
        DEPLOY CONTRACTS AND REGISTER EXECUTORS TO SEE LIVE NETWORK STATUS
      </p>
    </div>
  );
}
