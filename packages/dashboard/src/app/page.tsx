'use client';

import Link from 'next/link';
import HeroAscii from '@/components/ui/hero-ascii-one';

/* ------------------------------------------------------------------ */
/*  Landing Page — Atlas Protocol                                       */
/* ------------------------------------------------------------------ */

export default function LandingPage() {
  return (
    <main className="relative min-h-screen overflow-hidden bg-black text-white font-mono">
      {/* Global dot pattern across entire page */}
      <div
        className="fixed inset-0 z-0 pointer-events-none"
        style={{
          backgroundImage: 'radial-gradient(circle, rgba(255,255,255,0.12) 1px, transparent 1px)',
          backgroundSize: '28px 28px',
        }}
        aria-hidden="true"
      />

      {/* ================================================================ */}
      {/*  HERO                                                            */}
      {/* ================================================================ */}
      <section className="relative min-h-screen overflow-hidden">
        {/* ASCII Animation Background — desktop */}
        <div className="absolute inset-0 w-full h-full hidden lg:block z-[1]">
          <HeroAscii />
        </div>

        {/* ---- Top Header Bar ---- */}
        <header className="fixed top-0 left-0 right-0 z-50 border-b border-white/[0.1] bg-black/70 backdrop-blur-md">
          <div className="max-w-[1400px] mx-auto px-5 lg:px-10 py-4 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-white text-lg lg:text-xl font-bold tracking-[0.3em]">
                ATLAS
              </span>
              <span className="h-4 w-px bg-white/25" />
              <span className="text-white/40 text-[9px] tracking-[0.25em]">
                PROTOCOL
              </span>
            </div>

            <nav className="hidden md:flex items-center gap-8 text-[11px] text-white/50 tracking-[0.18em]">
              <a href="#features" className="hover:text-white transition-colors duration-200">
                FEATURES
              </a>
              <a href="#process" className="hover:text-white transition-colors duration-200">
                PROCESS
              </a>
              <a href="#sdk" className="hover:text-white transition-colors duration-200">
                SDK
              </a>
            </nav>

            <Link
              href="/workflows"
              className="group relative px-5 py-2 border border-white/40 text-[10px] tracking-[0.2em] text-white hover:bg-white hover:text-black transition-all duration-200"
            >
              <span className="absolute -top-px -left-px w-2 h-2 border-t border-l border-white/50 opacity-0 group-hover:opacity-100 transition-opacity" />
              <span className="absolute -bottom-px -right-px w-2 h-2 border-b border-r border-white/50 opacity-0 group-hover:opacity-100 transition-opacity" />
              LAUNCH APP
            </Link>
          </div>
        </header>

        {/* ---- Corner Frames ---- */}
        <div className="absolute top-0 left-0 w-10 h-10 lg:w-14 lg:h-14 border-t-[1.5px] border-l-[1.5px] border-white/20 z-20 pointer-events-none" />
        <div className="absolute top-0 right-0 w-10 h-10 lg:w-14 lg:h-14 border-t-[1.5px] border-r-[1.5px] border-white/20 z-20 pointer-events-none" />
        <div className="absolute bottom-[5vh] left-0 w-10 h-10 lg:w-14 lg:h-14 border-b-[1.5px] border-l-[1.5px] border-white/20 z-20 pointer-events-none" />
        <div className="absolute bottom-[5vh] right-0 w-10 h-10 lg:w-14 lg:h-14 border-b-[1.5px] border-r-[1.5px] border-white/20 z-20 pointer-events-none" />

        {/* ---- Hero Content ---- */}
        <div className="relative z-10 flex min-h-screen items-center justify-end pt-16 lg:pt-0">
          <div className="w-full lg:w-[50%] px-6 lg:px-14 lg:pr-[7%]">
            <div className="max-w-xl lg:ml-auto">
              {/* Top rule */}
              <div className="flex items-center gap-2 mb-5 opacity-50">
                <div className="w-10 h-px bg-white" />
                <span className="text-[10px] tracking-wider">&#8734;</span>
                <div className="flex-1 h-px" style={{
                  backgroundImage: 'repeating-linear-gradient(90deg, white 0px, white 2px, transparent 2px, transparent 6px)',
                  backgroundSize: '6px 1px',
                }} />
              </div>

              {/* Headline */}
              <h1 className="text-5xl sm:text-6xl lg:text-[5.5rem] xl:text-[6.5rem] font-bold leading-[0.95] tracking-[0.12em]">
                <span className="block text-white">AUTOMATE</span>
                <span className="block text-white/70">THE CHAIN</span>
              </h1>

              {/* Dot separator */}
              <div className="hidden lg:flex gap-[3px] my-6 opacity-30">
                {Array.from({ length: 48 }).map((_, i) => (
                  <div key={i} className="w-[3px] h-[3px] rounded-full bg-white" />
                ))}
              </div>

              {/* Description */}
              <p className="mt-5 lg:mt-0 text-[12px] lg:text-[14px] text-white/50 leading-[1.9] max-w-md">
                On-chain workflow state machines executed by a decentralized
                network. Define. Deploy. Done.
              </p>

              {/* CTA */}
              <div className="flex flex-col sm:flex-row gap-3 mt-9">
                <Link
                  href="/workflows"
                  className="group relative inline-flex items-center justify-center px-8 py-3.5 border border-white text-[11px] tracking-[0.2em] text-white hover:bg-white hover:text-black transition-all duration-200"
                >
                  <span className="absolute -top-1 -left-1 w-2.5 h-2.5 border-t border-l border-white opacity-0 group-hover:opacity-100 transition-opacity" />
                  <span className="absolute -bottom-1 -right-1 w-2.5 h-2.5 border-b border-r border-white opacity-0 group-hover:opacity-100 transition-opacity" />
                  LAUNCH APP
                </Link>
                <a
                  href="#sdk"
                  className="inline-flex items-center justify-center px-8 py-3.5 border border-white/25 text-[11px] tracking-[0.2em] text-white/50 hover:border-white/50 hover:text-white/80 transition-all duration-200"
                >
                  VIEW SDK &rarr;
                </a>
              </div>

              {/* Bottom rule */}
              <div className="hidden lg:flex items-center gap-2 mt-12 opacity-30">
                <span className="text-[9px]">&#8734;</span>
                <div className="flex-1 h-px bg-white/60" />
                <span className="text-[9px] tracking-[0.3em]">ATLAS.PROTOCOL</span>
              </div>
            </div>
          </div>
        </div>

        {/* ---- Bottom Status Bar ---- */}
        <div className="absolute left-0 right-0 z-20 border-t border-white/[0.1] bg-black/70 backdrop-blur-sm" style={{ bottom: '5vh' }}>
          <div className="max-w-[1400px] mx-auto px-5 lg:px-10 py-2.5 flex items-center justify-between">
            <div className="flex items-center gap-4 text-[9px] text-white/30 tracking-wider">
              <span className="flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400/80 animate-pulse" />
                SYSTEM.ACTIVE
              </span>
              <AudioBars />
              <span>V0.1.0</span>
            </div>
            <div className="flex items-center gap-4 text-[9px] text-white/30 tracking-wider">
              <span className="hidden lg:inline">BASE SEPOLIA</span>
              <PulseDots />
              <span className="hidden lg:inline">FRAME: &#8734;</span>
            </div>
          </div>
        </div>
      </section>

      {/* ================================================================ */}
      {/*  STATS                                                           */}
      {/* ================================================================ */}
      <section className="relative z-10 border-y border-white/[0.08]">
        <div className="max-w-[1400px] mx-auto grid grid-cols-2 lg:grid-cols-4">
          {[
            { label: 'WORKFLOWS.CREATED', value: '1,247' },
            { label: 'STEPS.EXECUTED', value: '8,432' },
            { label: 'EXECUTORS.ACTIVE', value: '23' },
            { label: 'REWARDS.DISTRIBUTED', value: '12.4 ETH' },
          ].map((stat, i) => (
            <div
              key={stat.label}
              className={`px-6 lg:px-10 py-8 ${i < 3 ? 'border-r border-white/[0.06]' : ''}`}
            >
              <div className="text-[9px] text-white/25 tracking-[0.2em] mb-2">
                {stat.label}
              </div>
              <div className="text-2xl lg:text-3xl font-bold tracking-wider text-white">
                {stat.value}
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ================================================================ */}
      {/*  FEATURES                                                        */}
      {/* ================================================================ */}
      <section id="features" className="relative z-10 py-28 lg:py-36">
        <div className="max-w-[1400px] mx-auto px-5 lg:px-10">
          <SectionLabel text="CAPABILITIES" />

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-px bg-white/[0.06] mt-16">
            {[
              { tag: 'CORE', title: 'ON-CHAIN STATE MACHINES', desc: 'Workflows stored fully on-chain. Every step, every transition, every state change \u2014 verifiable and immutable.' },
              { tag: 'NETWORK', title: 'DECENTRALIZED EXECUTION', desc: 'No single point of failure. A permissionless executor network advances your workflows with MEV-resistant selection.' },
              { tag: 'BUILD', title: 'COMPOSABLE STEPS', desc: 'Chain contract calls, token transfers, time delays, and condition checks. Complex automation from simple primitives.' },
              { tag: 'INFRA', title: 'UUPS UPGRADEABLE', desc: 'Protocol evolves without breaking state. Upgrade logic while preserving all active workflows and balances.' },
              { tag: 'ECON', title: 'REWARD INCENTIVES', desc: 'Executors are paid per step from deposited rewards. Economics ensure reliable, timely execution every time.' },
              { tag: 'DEV', title: 'BUILDER SDK', desc: 'Fluent TypeScript SDK with type-safe workflow construction. From definition to deployment in 5 lines of code.' },
            ].map((f) => (
              <div key={f.title} className="bg-black p-8 lg:p-10 group hover:bg-white/[0.02] transition-colors duration-300">
                <div className="flex items-center gap-2 mb-5">
                  <div className="w-1.5 h-1.5 bg-white/40" />
                  <span className="text-[9px] text-white/35 tracking-[0.25em]">{f.tag}</span>
                </div>
                <h3 className="text-sm font-bold tracking-[0.12em] text-white mb-3 group-hover:text-white transition-colors duration-300">
                  {f.title}
                </h3>
                <p className="text-[11px] text-white/35 leading-[1.9]">{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ================================================================ */}
      {/*  PROCESS                                                         */}
      {/* ================================================================ */}
      <section id="process" className="relative z-10 border-t border-white/[0.06] py-28 lg:py-36">
        <div className="max-w-[900px] mx-auto px-5 lg:px-10">
          <SectionLabel text="PROCESS" />

          <div className="mt-16">
            {[
              { n: '01', title: 'DEFINE', desc: 'Use the SDK or dashboard to define workflow steps and trigger conditions.', active: false },
              { n: '02', title: 'DEPLOY', desc: 'Submit your workflow on-chain with a reward deposit for executor incentives.', active: false },
              { n: '03', title: 'EXECUTE', desc: 'Decentralized executors pick up and advance steps when conditions are met. Deterministic selection, zero coordination.', active: true },
              { n: '04', title: 'COMPLETE', desc: 'Workflow reaches terminal state. Rewards distributed. State is final.', active: false },
            ].map((item) => (
              <div
                key={item.n}
                className="flex gap-7 lg:gap-12 py-9 border-b border-white/[0.06] group"
              >
                <span className={`flex-shrink-0 text-3xl lg:text-5xl font-bold ${item.active ? 'text-white' : 'text-white/[0.08] group-hover:text-white/20'} transition-colors`}>
                  {item.n}
                </span>
                <div className="pt-1">
                  <div className="flex items-center gap-3">
                    <h3 className={`text-sm font-bold tracking-[0.15em] ${item.active ? 'text-white' : 'text-white/80'}`}>
                      {item.title}
                    </h3>
                    {item.active && (
                      <span className="flex items-center gap-1.5">
                        <span className="relative flex h-2 w-2">
                          <span className="animate-ping absolute h-full w-full rounded-full bg-white opacity-60" />
                          <span className="relative rounded-full h-2 w-2 bg-white" />
                        </span>
                        <span className="text-[9px] text-white/60 tracking-[0.2em]">ACTIVE</span>
                      </span>
                    )}
                  </div>
                  <p className="mt-2 text-[12px] text-white/35 leading-[1.9] max-w-lg">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ================================================================ */}
      {/*  SDK CODE                                                        */}
      {/* ================================================================ */}
      <section id="sdk" className="relative z-10 border-t border-white/[0.06] py-28 lg:py-36">
        <div className="max-w-[780px] mx-auto px-5 lg:px-10">
          <SectionLabel text="DEVELOPER SDK" />

          <div className="mt-16 border border-white/[0.08]">
            <div className="flex items-center justify-between px-5 py-3 border-b border-white/[0.08]">
              <div className="flex items-center gap-3">
                <div className="flex gap-1.5">
                  <span className="w-2.5 h-2.5 bg-white/[0.08]" />
                  <span className="w-2.5 h-2.5 bg-white/[0.08]" />
                  <span className="w-2.5 h-2.5 bg-white/[0.08]" />
                </div>
                <span className="text-[10px] text-white/25 tracking-[0.15em] ml-1">atlas-sdk.ts</span>
              </div>
              <span className="text-[9px] text-white/20 tracking-[0.2em]">TYPESCRIPT</span>
            </div>

            <pre className="px-6 py-7 text-[11px] lg:text-[12px] leading-[2.1] overflow-x-auto text-white/70">
              <code>{`const workflow = new WorkflowBuilder()
  .name('Weekly DCA')
  .rewardPerStep(parseEther('0.001'))
  .addContractCall({ target: ROUTER, callData: swapData })
  .addDelay(7 * 24 * 3600)
  .build();

const { workflowId } = await atlas.createWorkflow(workflow);`}</code>
            </pre>
          </div>

          <div className="mt-3 flex items-center justify-between text-[9px] text-white/20 tracking-wider">
            <span>@atlas-protocol/sdk v0.1.0</span>
            <span>npm install @atlas-protocol/sdk</span>
          </div>
        </div>
      </section>

      {/* ================================================================ */}
      {/*  CTA                                                             */}
      {/* ================================================================ */}
      <section className="relative z-10 border-t border-white/[0.06] py-28 lg:py-36">
        <div className="max-w-[700px] mx-auto px-5 lg:px-10 text-center">
          {/* Decorative top rule */}
          <div className="flex items-center justify-center gap-3 mb-10 opacity-25">
            <div className="w-16 h-px bg-white" />
            <span className="text-[10px] tracking-wider">&#8734;</span>
            <div className="w-16 h-px bg-white" />
          </div>

          <h2 className="text-3xl lg:text-5xl font-bold tracking-[0.12em] leading-[1.1]">
            READY TO
            <br />
            <span className="text-white/60">AUTOMATE?</span>
          </h2>

          <p className="mt-6 text-[12px] text-white/35 leading-[1.9] max-w-md mx-auto">
            Deploy your first on-chain workflow in minutes.
            No infrastructure. No single point of failure. Just code.
          </p>

          <div className="flex flex-col sm:flex-row gap-3 justify-center mt-10">
            <Link
              href="/workflows/new"
              className="group relative inline-flex items-center justify-center px-10 py-4 border-2 border-white text-[11px] font-bold tracking-[0.25em] text-white hover:bg-white hover:text-black transition-all duration-200"
            >
              <span className="absolute -top-1.5 -left-1.5 w-3 h-3 border-t-2 border-l-2 border-white opacity-0 group-hover:opacity-100 transition-opacity" />
              <span className="absolute -bottom-1.5 -right-1.5 w-3 h-3 border-b-2 border-r-2 border-white opacity-0 group-hover:opacity-100 transition-opacity" />
              CREATE WORKFLOW
            </Link>
            <a
              href="#"
              className="inline-flex items-center justify-center px-10 py-4 border border-white/25 text-[11px] text-white/45 tracking-[0.2em] hover:border-white/50 hover:text-white/80 transition-all duration-200"
            >
              READ DOCS &rarr;
            </a>
          </div>

          {/* Decorative bottom rule */}
          <div className="flex items-center justify-center gap-3 mt-14 opacity-15">
            <div className="flex-1 max-w-[100px] h-px bg-white" />
            <span className="text-[8px] tracking-[0.3em]">ATLAS.PROTOCOL</span>
            <div className="flex-1 max-w-[100px] h-px bg-white" />
          </div>
        </div>
      </section>

      {/* ================================================================ */}
      {/*  FOOTER                                                          */}
      {/* ================================================================ */}
      <footer className="relative z-20 border-t border-white/[0.08]">
        {/* Main footer */}
        <div className="max-w-[1400px] mx-auto px-5 lg:px-10 py-12 lg:py-16">
          <div className="flex flex-col lg:flex-row items-start justify-between gap-10">
            {/* Left — branding */}
            <div>
              <div className="flex items-center gap-2.5 mb-4">
                <span className="text-base font-bold tracking-[0.3em] text-white">ATLAS</span>
                <span className="h-3.5 w-px bg-white/20" />
                <span className="text-[8px] tracking-[0.2em] text-white/30">PROTOCOL</span>
              </div>
              <p className="text-[11px] text-white/25 leading-[1.8] max-w-xs">
                Decentralized on-chain workflow orchestration.
                Trustless. Composable. Unstoppable.
              </p>
            </div>

            {/* Right — links */}
            <div className="flex gap-16">
              <div>
                <div className="text-[9px] text-white/40 tracking-[0.25em] mb-4">PROTOCOL</div>
                <div className="flex flex-col gap-2.5">
                  <a href="#features" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">Features</a>
                  <a href="#process" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">Process</a>
                  <a href="#sdk" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">SDK</a>
                </div>
              </div>
              <div>
                <div className="text-[9px] text-white/40 tracking-[0.25em] mb-4">COMMUNITY</div>
                <div className="flex flex-col gap-2.5">
                  <a href="#" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">GitHub</a>
                  <a href="#" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">Discord</a>
                  <a href="#" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">Twitter</a>
                </div>
              </div>
              <div>
                <div className="text-[9px] text-white/40 tracking-[0.25em] mb-4">RESOURCES</div>
                <div className="flex flex-col gap-2.5">
                  <a href="#" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">Docs</a>
                  <a href="#" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">Audit</a>
                  <a href="#" className="text-[11px] text-white/25 hover:text-white/60 transition-colors">Blog</a>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="border-t border-white/[0.06]">
          <div className="max-w-[1400px] mx-auto px-5 lg:px-10 py-3 flex items-center justify-between">
            <div className="flex items-center gap-4 text-[8px] text-white/20 tracking-wider">
              <span className="flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400/70 animate-pulse" />
                ONLINE
              </span>
              <AudioBars />
              <span>V0.1.0</span>
            </div>
            <div className="flex items-center gap-4 text-[8px] text-white/20 tracking-wider">
              <span>BASE SEPOLIA</span>
              <PulseDots />
              <span>&#169; 2025</span>
            </div>
          </div>
        </div>
      </footer>
    </main>
  );
}

/* ------------------------------------------------------------------ */
/*  Helpers                                                             */
/* ------------------------------------------------------------------ */

function SectionLabel({ text }: { text: string }) {
  return (
    <div className="flex items-center gap-3">
      <div className="w-10 h-px bg-white/40" />
      <span className="text-[10px] text-white/40 tracking-[0.3em]">{text}</span>
      <div className="flex-1 h-px bg-white/[0.08]" />
    </div>
  );
}

function AudioBars() {
  return (
    <div className="hidden lg:flex items-end gap-[2px] h-3">
      {[5, 10, 7, 12, 4, 9, 6, 11].map((h, i) => (
        <div key={i} className="w-[2px] bg-white/20" style={{ height: `${h}px` }} />
      ))}
    </div>
  );
}

function PulseDots() {
  return (
    <div className="flex gap-1">
      <div className="w-1 h-1 bg-white/40 animate-pulse" />
      <div className="w-1 h-1 bg-white/25 animate-pulse" style={{ animationDelay: '200ms' }} />
      <div className="w-1 h-1 bg-white/15 animate-pulse" style={{ animationDelay: '400ms' }} />
    </div>
  );
}
