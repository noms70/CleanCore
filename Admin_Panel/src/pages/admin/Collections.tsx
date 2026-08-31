import { useState, useEffect, useMemo } from "react";
import { collection, onSnapshot, query, orderBy } from "firebase/firestore";
import { db } from "@/firebase";
import { PackageCheck, User, MapPin, Recycle, Gauge } from "lucide-react";

interface PickupLog {
  logId: string;
  workerId: string;
  routeId: string;
  binId: string;
  area: string;
  wasteType: string;
  fillLevelAtPickup: number;
  binLat: number;
  binLng: number;
  completedAt: { seconds: number } | null;
}

function formatTimestamp(ts: { seconds: number } | null): string {
  if (!ts) return "—";
  return new Date(ts.seconds * 1000).toLocaleString("de-DE", {
    day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

const PAGE_SIZE = 20;

export default function Collections() {
  const [logs, setLogs]               = useState<PickupLog[]>([]);
  const [workerNames, setWorkerNames] = useState<Record<string, string>>({});
  const [binIds, setBinIds]           = useState<Set<string>>(new Set());
  const [binsLoaded, setBinsLoaded]   = useState(false);
  const [usersLoaded, setUsersLoaded] = useState(false);
  const [loading, setLoading]         = useState(true);
  const [workerFilter, setWorkerFilter] = useState("");
  const [currentPage, setCurrentPage]   = useState(1);

  // Live: pickup logs
  useEffect(() => {
    const q = query(collection(db, "pickupLogs"), orderBy("completedAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      setLogs(
        snap.docs.map((d) => {
          const r = d.data();
          return {
            logId:             d.id,
            workerId:          r.workerId ?? "",
            routeId:           r.routeId ?? "",
            binId:             r.binId ?? "",
            area:              r.area ?? "—",
            wasteType:         r.wasteType ?? "—",
            fillLevelAtPickup: r.fillLevelAtPickup ?? 0,
            binLat:            r.binLat ?? 0,
            binLng:            r.binLng ?? 0,
            completedAt:       r.completedAt ?? null,
          } as PickupLog;
        })
      );
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, []);

  // Live: all users (for name resolution)
  useEffect(() => {
    const unsub = onSnapshot(collection(db, "users"), (snap) => {
      const names: Record<string, string> = {};
      snap.docs.forEach(d => {
        const r = d.data();
        names[d.id] = `${r.firstName || ""} ${r.lastName || ""}`.trim() || (r.name as string) || "Unknown";
      });
      setWorkerNames(names);
      setUsersLoaded(true);
    }, () => setUsersLoaded(true));
    return () => unsub();
  }, []);

  // Live: bins collection — used to filter out orphaned log entries
  useEffect(() => {
    const unsub = onSnapshot(collection(db, "bins"), (snap) => {
      setBinIds(new Set(snap.docs.map(d => d.id)));
      setBinsLoaded(true);
    }, () => setBinsLoaded(true));
    return () => unsub();
  }, []);

  // Filter: only show logs whose bin AND worker still exist in Firebase
  const validLogs = useMemo(() => {
    if (!binsLoaded || !usersLoaded) return logs;
    return logs.filter(
      l => l.binId && binIds.has(l.binId) && l.workerId && workerNames[l.workerId] !== undefined
    );
  }, [logs, binIds, workerNames, binsLoaded, usersLoaded]);

  const workers = useMemo(
    () => Array.from(new Set(validLogs.map(l => l.workerId).filter(Boolean))),
    [validLogs]
  );

  const filtered = useMemo(
    () => workerFilter ? validLogs.filter(l => l.workerId === workerFilter) : validLogs,
    [validLogs, workerFilter]
  );

  const handleFilterChange = (v: string) => { setWorkerFilter(v); setCurrentPage(1); };

  // Reset filter if selected worker is no longer valid
  useEffect(() => {
    if (workerFilter && !workers.includes(workerFilter)) setWorkerFilter("");
  }, [workers, workerFilter]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const paginated  = filtered.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);

  const totalPickups = filtered.length;
  const avgFill      = filtered.length
    ? Math.round(filtered.reduce((s, l) => s + l.fillLevelAtPickup, 0) / filtered.length)
    : 0;
  const areas      = new Set(filtered.map(l => l.area).filter(a => a !== "—")).size;
  const wasteTypes = new Set(filtered.map(l => l.wasteType).filter(w => w !== "—")).size;

  const isReady = !loading && binsLoaded && usersLoaded;

  return (
    <div className="p-6 space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h2 className="text-2xl font-bold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
            Collection Logs
          </h2>
          <p className="text-sm text-muted-foreground mt-0.5">
            Every bin pickup recorded in real time — use this for worker performance and route auditing.
          </p>
        </div>

        <select
          value={workerFilter}
          onChange={(e) => handleFilterChange(e.target.value)}
          className="border border-border/50 bg-card px-3 py-2 rounded-lg text-sm text-foreground focus:border-accent transition-all"
        >
          <option value="">All Workers</option>
          {workers.map((w) => (
            <option key={w} value={w}>{workerNames[w] ?? w}</option>
          ))}
        </select>
      </div>

      {/* KPI strip */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { icon: PackageCheck, label: "Total Pickups",      value: totalPickups,  color: "text-success" },
          { icon: Gauge,        label: "Avg Fill at Pickup", value: `${avgFill}%`, color: "text-warning" },
          { icon: MapPin,       label: "Districts Served",   value: areas,         color: "text-primary" },
          { icon: Recycle,      label: "Waste Streams",      value: wasteTypes,    color: "text-accent"  },
        ].map(({ icon: Icon, label, value, color }) => (
          <div
            key={label}
            className="rounded-xl border border-accent/20 bg-gradient-to-br from-card to-card/50 p-4 shadow-lg shadow-accent/5"
          >
            <div className="flex items-center gap-2 mb-1">
              <Icon className={`h-4 w-4 ${color}`} />
              <span className="text-xs text-muted-foreground">{label}</span>
            </div>
            <p className={`text-2xl font-bold ${color}`}>{value}</p>
          </div>
        ))}
      </div>

      {/* Table */}
      <div className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 shadow-xl shadow-accent/10 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-border/50">
            <thead className="bg-gradient-to-r from-accent/15 via-primary/10 to-accent/15">
              <tr>
                {["Worker", "Bin ID", "District", "Waste Type", "Fill at Pickup", "Route", "Time"].map((h) => (
                  <th
                    key={h}
                    className="px-4 py-4 text-left text-xs font-semibold text-foreground uppercase tracking-wider"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-border/50">
              {!isReady ? (
                <tr>
                  <td colSpan={7} className="px-6 py-10 text-center text-sm text-muted-foreground">
                    Loading collection logs…
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-10 text-center text-sm text-muted-foreground">
                    <div className="flex flex-col items-center gap-2">
                      <PackageCheck className="h-10 w-10 opacity-20" />
                      <span>No pickups recorded yet. Complete a collection stop to see logs here.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                paginated.map((log, i) => {
                  const fill = log.fillLevelAtPickup;
                  const fillColor =
                    fill >= 90 ? "bg-destructive/20 text-destructive border-destructive/30" :
                    fill >= 70 ? "bg-warning/20 text-warning border-warning/30" :
                                 "bg-success/20 text-success border-success/30";

                  return (
                    <tr
                      key={log.logId}
                      className="hover:bg-gradient-to-r hover:from-primary/5 hover:to-accent/5 transition-all duration-200"
                      style={{ animationDelay: `${i * 30}ms` }}
                    >
                      <td className="px-4 py-3 text-sm text-foreground">
                        <span className="inline-flex items-center gap-1">
                          <User className="h-3 w-3 text-muted-foreground shrink-0" />
                          {workerNames[log.workerId] ?? "—"}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-xs font-mono text-muted-foreground max-w-[120px] truncate" title={log.binId}>
                        {log.binId ? log.binId.slice(0, 12) + "…" : "—"}
                      </td>
                      <td className="px-4 py-3 text-sm">
                        {log.area !== "—" ? (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-info/10 text-info border border-info/30">
                            {log.area}
                          </span>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-sm">
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-accent/20 text-accent border border-accent/40">
                          {log.wasteType}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${fillColor}`}>
                          {fill}%
                        </span>
                      </td>
                      <td className="px-4 py-3 text-xs font-mono text-muted-foreground max-w-[120px] truncate" title={log.routeId}>
                        {log.routeId ? log.routeId.slice(0, 12) + "…" : "—"}
                      </td>
                      <td className="px-4 py-3 text-xs text-muted-foreground whitespace-nowrap">
                        {formatTimestamp(log.completedAt)}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-4 text-sm text-muted-foreground">
          <span>
            Showing {(currentPage - 1) * PAGE_SIZE + 1}–{Math.min(currentPage * PAGE_SIZE, filtered.length)} of {filtered.length} logs
          </span>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
              disabled={currentPage === 1}
              className="px-3 py-1 rounded-lg border border-border/50 bg-card hover:bg-muted/40 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              ← Prev
            </button>
            <span className="px-2 font-medium text-foreground">{currentPage} / {totalPages}</span>
            <button
              onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
              disabled={currentPage === totalPages}
              className="px-3 py-1 rounded-lg border border-border/50 bg-card hover:bg-muted/40 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              Next →
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
