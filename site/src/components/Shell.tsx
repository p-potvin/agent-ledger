import React from 'react';
import { Nav } from './Nav';

interface ShellProps {
  children: React.ReactNode;
}

export function Shell({ children }: ShellProps) {
  return (
    <div className="vw-console-shell min-h-screen w-full flex flex-col font-sans">
      <Nav />
      <main className="max-w-[1140px] mx-auto w-full px-4 pb-20 pt-6 flex-1">
        {children}
      </main>
    </div>
  );
}
