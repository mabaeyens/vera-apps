import { useEffect, useState } from "react";

interface RepoStatus {
  owner: string;
  repo: string;
  branch: string;
  aheadBy: number;
  syncing: boolean;
}

export function RepoStatusCard({ owner, repo }: { owner: string; repo: string }) {
  const [status, setStatus] = useState<RepoStatus | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      const response = await fetch(`/api/repos/${owner}/${repo}/status`);
      const data: RepoStatus = await response.json();
      if (!cancelled) setStatus(data);
    }

    load();
    const interval = setInterval(load, 15_000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [owner, repo]);

  if (!status) {
    return <div className="repo-card repo-card--loading">Loading…</div>;
  }

  return (
    <div className="repo-card">
      <header>
        <span className="repo-card__name">
          {status.owner}/{status.repo}
        </span>
        <span className="repo-card__branch">{status.branch}</span>
      </header>
      {status.aheadBy > 0 && (
        <p className="repo-card__ahead">{status.aheadBy} commits ahead of local</p>
      )}
      {status.syncing && <span className="repo-card__badge">Syncing…</span>}
    </div>
  );
}
