import { Navbar } from '@/components/navbar';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="relative min-h-screen flex flex-col bg-black font-mono">
      {/* Dot grid background */}
      <div className="fixed inset-0 -z-30 dot-grid opacity-40" aria-hidden="true" />
      <div className="noise-overlay" aria-hidden="true" />

      <div className="relative z-10 flex flex-col flex-1">
        <Navbar />
        <main className="flex-1 max-w-[1200px] w-full mx-auto px-5 lg:px-10 py-8">{children}</main>
      </div>
    </div>
  );
}
