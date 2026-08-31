import { useMemo, useState, useEffect } from "react";
import { collection, onSnapshot, query, orderBy } from "firebase/firestore";
import { db } from "@/firebase";
import { Route, CheckCircle2, Truck, Leaf, ChevronDown, ChevronUp } from "lucide-react";

interface RouteStop {
  binId: string;
  lat: number;
  lng: number;
  fillLevel: number;
  wasteType: string;
  area: string;
  completed?: boolean;
}

interface RouteDoc {
  routeId: string;
  workerId: string;
  assignedArea: string;
  assignedWasteType: string;
  status: "active" | "completed";
  stops: RouteStop[];
  totalStops: number;
  completedStops: number;
  totalDistanceKm: number;
  estimatedFuel: number;
  carbonFootprintKg: number;
  createdAt: { seconds: number } | null;
  completedAt?: { seconds: number } | null;
}

function formatTs(ts: { seconds: number } | null | undefined): string {
  if (!ts) return "—";
  return new Date(ts.seconds * 1000).toLocaleString("en-PK", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

/** Derive area from route doc, falling back to first stop's area */
function resolveArea(route: RouteDoc): string {
  if (route.assignedArea) return route.assignedArea;
  const first = route.stops.find(s => s.area);
  return first?.area ?? "—";
}

/** Derive waste type from route doc, falling back to first stop's wasteType */
function resolveWasteType(route: RouteDoc): string {
  if (route.assignedWasteType) return route.assignedWasteType;
  const first = route.stops.find(s => s.wasteType);
  return first?.wasteType ?? "—";
}

export default function Routes() {
  const [routes, setRoutes]           = useState<RouteDoc[]>([]);
  const [loading, setLoading]         = useState(true);
  const [workerNames, setWorkerNames] = useState<Record<string, string>>({});
  const [usersLoaded, setUsersLoaded] = useState(false);
  const [statusFilter, setStatusFilter] = useState<"" | "active" | "completed">("");
  const [expanded, setExpanded]         = useState<Set<string>>(new Set());

  // Live: routes collection
  useEffect(() => {
    const q = query(collection(db, "routes"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setRoutes(
          snap.docs.map((d) => {
            const r = d.data();
            const cs = r.completedStops ?? 0;
            const ts = r.totalStops ?? 0;
            const status: "active" | "completed" = ts > 0 && cs >= ts ? "completed" : "active";
            return {
              routeId:           d.id,
              workerId:          r.workerId ?? r.driverId ?? "",
              assignedArea:      r.assignedArea ?? "",
              assignedWasteType: r.assignedWasteType ?? "",
              status,
              stops:             Array.isArray(r.stops) ? r.stops : [],
              totalStops:        ts,
              completedStops:    cs,
              totalDistanceKm:   r.totalDistanceKm ?? 0,
              estimatedFuel:     r.estimatedFuel ?? 0,
              carbonFootprintKg: r.carbonFootprintKg ?? 0,
              createdAt:         r.createdAt ?? null,
              completedAt:       r.completedAt ?? null,
            } as RouteDoc;
          })
        );
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  // Live: all users (no role filter — resolves any worker UID to a name)
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

  // Only show routes whose worker still exists in the users collection
  const filtered = useMemo(() => {
    let result = routes;
    if (usersLoaded) {
      result = result.filter(r => r.workerId && workerNames[r.workerId] !== undefined);
    }
    if (statusFilter) {
      result = result.filter(r => r.status === statusFilter);
    }
    return result;
  }, [routes, statusFilter, workerNames, usersLoaded]);

  const activeCount    = filtered.filter(r => r.status === "active").length;
  const completedCount = filtered.filter(r => r.status === "completed").length;
  const totalBins      = filtered.reduce((s, r) => s + r.completedStops, 0);
  const avgKm =
    filtered.length
      ? (filtered.reduce((s, r) => s + r.totalDistanceKm, 0) / filtered.length).toFixed(1)
      : "0";

  const toggleExpand = (id: string) =>
    setExpanded(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });

  const isReady = !loading && usersLoaded;

  return (
    <div className="p-6 space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h2 className="text-2xl font-bold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
            Route Management
          </h2>
          <p className="text-sm text-muted-foreground mt-0.5">
            Real-time view of all worker routes — active and completed.
          </p>
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as "" | "active" | "completed")}
          className="border border-border/50 bg-card px-3 py-2 rounded-lg text-sm text-foreground focus:border-accent transition-all"
        >
          <option value="">All Routes</option>
          <option value="active">Active Only</option>
          <option value="completed">Completed Only</option>
        </select>
      </div>

      {/* KPI strip */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { icon: Truck,        label: "Active Routes",     value: activeCount,    color: "text-warning" },
          { icon: CheckCircle2, label: "Completed Routes",  value: completedCount, color: "text-success" },
          { icon: Route,        label: "Bins Collected",    value: totalBins,      color: "text-primary" },
          { icon: Leaf,         label: "Avg Distance (km)", value: avgKm,          color: "text-accent"  },
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

      {/* Routes table */}
      <div className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 shadow-xl shadow-accent/10 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-border/50">
            <thead className="bg-gradient-to-r from-accent/15 via-primary/10 to-accent/15">
              <tr>
                {["Worker", "Area", "Waste Type", "Progress", "Distance", "CO₂ (kg)", "Status", "Started", ""].map((h) => (
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
                  <td colSpan={9} className="px-6 py-10 text-center text-sm text-muted-foreground">
                    Loading routes…
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={9} className="px-6 py-10 text-center text-sm text-muted-foreground">
                    <div className="flex flex-col items-center gap-2">
                      <Route className="h-10 w-10 opacity-20" />
                      <span>No routes yet. Workers generate routes from the mobile app.</span>
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.flatMap((route) => {
                  const pct = route.totalStops > 0
                    ? Math.round((route.completedStops / route.totalStops) * 100)
                    : 0;
                  const isExpanded   = expanded.has(route.routeId);
                  const workerName   = workerNames[route.workerId] ?? "—";
                  const area         = resolveArea(route);
                  const wasteType    = resolveWasteType(route);

                  return [
                    <tr
                      key={route.routeId}
                      className="hover:bg-gradient-to-r hover:from-primary/5 hover:to-accent/5 transition-all duration-200"
                    >
                      <td className="px-4 py-3 text-sm text-foreground font-medium">
                        {workerName}
                      </td>
                      <td className="px-4 py-3 text-sm">
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-info/10 text-info border border-info/30">
                          {area}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm">
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-accent/20 text-accent border border-accent/40">
                          {wasteType}
                        </span>
                      </td>
                      <td className="px-4 py-3 min-w-[140px]">
                        <div className="flex items-center gap-2">
                          <div className="flex-1 bg-border/40 rounded-full h-1.5">
                            <div
                              className="bg-gradient-to-r from-primary to-accent h-1.5 rounded-full transition-all"
                              style={{ width: `${pct}%` }}
                            />
                          </div>
                          <span className="text-xs text-muted-foreground whitespace-nowrap">
                            {route.completedStops}/{route.totalStops}
                          </span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-xs text-muted-foreground">
                        {route.totalDistanceKm} km
                      </td>
                      <td className="px-4 py-3 text-xs text-muted-foreground">
                        {route.carbonFootprintKg}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${
                            route.status === "active"
                              ? "bg-warning/20 text-warning border-warning/30"
                              : "bg-success/20 text-success border-success/30"
                          }`}
                        >
                          {route.status === "active" ? "● Active" : "✓ Done"}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-xs text-muted-foreground whitespace-nowrap">
                        {formatTs(route.createdAt)}
                      </td>
                      <td className="px-4 py-3">
                        <button
                          onClick={() => toggleExpand(route.routeId)}
                          className="text-muted-foreground hover:text-foreground transition-colors p-1 rounded"
                          title="Show stops"
                        >
                          {isExpanded ? (
                            <ChevronUp className="h-4 w-4" />
                          ) : (
                            <ChevronDown className="h-4 w-4" />
                          )}
                        </button>
                      </td>
                    </tr>,

                    isExpanded ? (
                      <tr key={`${route.routeId}-stops`}>
                        <td colSpan={9} className="px-6 pb-4 pt-0 bg-muted/10">
                          <div className="pt-3 space-y-1.5">
                            <p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-widest mb-2">
                              Stops ({route.stops.length})
                            </p>
                            {route.stops.length === 0 ? (
                              <p className="text-xs text-muted-foreground">No stops recorded.</p>
                            ) : (
                              route.stops.map((stop, i) => (
                                <div
                                  key={stop.binId}
                                  className={`flex items-center gap-3 py-1.5 px-3 rounded-lg text-xs ${
                                    stop.completed
                                      ? "bg-success/10 text-success"
                                      : "bg-card text-muted-foreground"
                                  }`}
                                >
                                  <span
                                    className={`w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold shrink-0 ${
                                      stop.completed
                                        ? "bg-success text-white"
                                        : "bg-border/60 text-foreground"
                                    }`}
                                  >
                                    {stop.completed ? "✓" : i + 1}
                                  </span>
                                  <span className="font-mono">{stop.binId}</span>
                                  <span className="text-muted-foreground">{stop.area || "—"}</span>
                                  <span className="text-muted-foreground">{stop.wasteType || "—"}</span>
                                  <span
                                    className={`ml-auto px-2 py-0.5 rounded-full border text-[10px] font-medium ${
                                      stop.fillLevel >= 90
                                        ? "bg-destructive/20 text-destructive border-destructive/30"
                                        : stop.fillLevel >= 70
                                        ? "bg-warning/20 text-warning border-warning/30"
                                        : "bg-success/20 text-success border-success/30"
                                    }`}
                                  >
                                    {stop.fillLevel}%
                                  </span>
                                </div>
                              ))
                            )}
                          </div>
                        </td>
                      </tr>
                    ) : null,
                  ].filter(Boolean);
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
