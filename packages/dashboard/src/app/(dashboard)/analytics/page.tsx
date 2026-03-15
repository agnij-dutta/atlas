'use client';

import { StatCard } from '@/components/stat-card';

const CHART_DATA = [
  { label: 'MON', value: 12 },
  { label: 'TUE', value: 28 },
  { label: 'WED', value: 19 },
  { label: 'THU', value: 35 },
  { label: 'FRI', value: 42 },
  { label: 'SAT', value: 15 },
  { label: 'SUN', value: 8 },
];

const LEADERBOARD = [
  { rank: 1, address: '0x742d...35Cc', executions: 142, rewards: '0.284 ETH' },
  { rank: 2, address: '0x8ba1...9F2e', executions: 89, rewards: '0.178 ETH' },
  { rank: 3, address: '0x3c44...93F8', executions: 67, rewards: '0.134 ETH' },
  { rank: 4, address: '0xf39F...2266', executions: 45, rewards: '0.090 ETH' },
  { rank: 5, address: '0x9965...1aB4', executions: 23, rewards: '0.046 ETH' },
];

function AsciiBarChart({ data }: { data: typeof CHART_DATA }) {
  const maxValue = Math.max(...data.map((d) => d.value));
  const maxBarHeight = 12; // rows

  const rows: string[] = [];
  for (let row = maxBarHeight; row >= 1; row--) {
    let line = '';
    for (let i = 0; i < data.length; i++) {
      const barHeight = Math.round((data[i].value / maxValue) * maxBarHeight);
      if (barHeight >= row) {
        line += '  ██  ';
      } else {
        line += '      ';
      }
    }
    rows.push(line);
  }

  const labels = data.map((d) => ` ${d.label} `).join('');
  const values = data.map((d) => String(d.value).padStart(4, ' ') + '  ').join('');

  return (
    <pre className="text-[10px] text-white/40 leading-[1.4] overflow-x-auto">
      {rows.map((row, i) => (
        <span key={i} className="block">{row}</span>
      ))}
      <span className="block text-white/10">{'------'.repeat(data.length)}</span>
      <span className="block text-white/20">{labels}</span>
      <span className="block text-white/30">{values}</span>
    </pre>
  );
}

export default function AnalyticsPage() {
  return (
    <div className="space-y-8">
      {/* ---- Header ---- */}
      <div>
        <div className="flex items-center gap-3 mb-2">
          <div className="w-8 h-px bg-white/30" />
          <span className="text-[8px] text-white/20 tracking-[0.25em]">METRICS</span>
        </div>
        <h1 className="text-2xl font-bold tracking-[0.1em] text-white/90">ANALYTICS</h1>
        <p className="text-[11px] text-white/30 mt-1.5 tracking-wider">
          Protocol performance metrics and executor leaderboard.
        </p>
      </div>

      {/* ---- Stats ---- */}
      <div className="grid gap-px bg-white/[0.04] grid-cols-2 md:grid-cols-4">
        <StatCard title="TOTAL WORKFLOWS" value="1,247" />
        <StatCard title="COMPLETED" value="892" />
        <StatCard title="TOTAL REWARDS PAID" value="12.4 ETH" />
        <StatCard title="AVG STEPS/WORKFLOW" value="4.2" />
      </div>

      {/* ---- Charts ---- */}
      <div className="grid gap-4 md:grid-cols-2">
        {/* Executions Chart */}
        <div className="border border-white/[0.06] bg-black">
          <div className="px-5 py-3 border-b border-white/[0.06]">
            <span className="text-[8px] text-white/20 tracking-[0.2em]">EXECUTIONS THIS WEEK</span>
          </div>
          <div className="p-5">
            <AsciiBarChart data={CHART_DATA} />
          </div>
        </div>

        {/* Gas Costs Chart */}
        <div className="border border-white/[0.06] bg-black">
          <div className="px-5 py-3 border-b border-white/[0.06]">
            <span className="text-[8px] text-white/20 tracking-[0.2em]">GAS COSTS (GWEI)</span>
          </div>
          <div className="p-5">
            <AsciiBarChart
              data={[
                { label: 'MON', value: 24 },
                { label: 'TUE', value: 18 },
                { label: 'WED', value: 31 },
                { label: 'THU', value: 22 },
                { label: 'FRI', value: 27 },
                { label: 'SAT', value: 14 },
                { label: 'SUN', value: 10 },
              ]}
            />
          </div>
        </div>
      </div>

      {/* ---- Leaderboard ---- */}
      <div className="border border-white/[0.06]">
        <div className="px-5 py-3 border-b border-white/[0.06]">
          <span className="text-[8px] text-white/20 tracking-[0.2em]">EXECUTOR LEADERBOARD</span>
        </div>

        {/* Table header */}
        <div className="grid grid-cols-[0.4fr_1.2fr_0.8fr_0.8fr] gap-4 px-5 py-3 border-b border-white/[0.06] text-[8px] text-white/20 tracking-[0.2em] uppercase">
          <span>RANK</span>
          <span>ADDRESS</span>
          <span>EXECUTIONS</span>
          <span>REWARDS</span>
        </div>

        {/* Table rows */}
        {LEADERBOARD.map((entry) => (
          <div
            key={entry.rank}
            className="grid grid-cols-[0.4fr_1.2fr_0.8fr_0.8fr] gap-4 px-5 py-4 border-b border-white/[0.03] hover:bg-white/[0.02] transition-colors duration-150 items-center"
          >
            <span className="text-[11px] text-white/30">#{entry.rank}</span>
            <span className="text-[11px] text-white/70">{entry.address}</span>
            <span className="text-[11px] text-white/50">{entry.executions}</span>
            <span className="text-[11px] text-white/40">{entry.rewards}</span>
          </div>
        ))}
      </div>

      {/* ---- Info note ---- */}
      <p className="text-[9px] text-white/15 text-center tracking-wider pt-2">
        DATA WILL POPULATE FROM SUBGRAPH WHEN CONTRACTS ARE DEPLOYED
      </p>
    </div>
  );
}
