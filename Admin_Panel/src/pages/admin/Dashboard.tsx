import { useState, useEffect } from "react";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { StatCard } from "@/components/admin/StatCard";
import { CollectionTrendsChart } from "@/components/admin/charts/CollectionTrendsChart";
import { WasteDistributionChart } from "@/components/admin/charts/WasteDistributionChart";
import { WorkerPerformanceChart } from "@/components/admin/charts/WorkerPerformanceChart";
import { PeakHoursChart } from "@/components/admin/charts/PeakHoursChart";
import { FillEfficiencyChart } from "@/components/admin/charts/FillEfficiencyChart";
import { AreaPerformanceChart } from "@/components/admin/charts/AreaPerformanceChart";
import { MapPreview } from "@/components/admin/MapPreview";
import { AnomalyFeed } from "@/components/admin/AnomalyFeed";
import { useBinLocationNames } from "@/hooks/useBinLocationNames";
import { db } from "@/firebase";
import {
  collection,
  onSnapshot,
  query,
  where,
  updateDoc,
  doc,
  Timestamp,
} from "firebase/firestore";
import { Link } from "react-router-dom";
import {
  Trash2,
  Users,
  Route,
  AlertTriangle,
  TrendingUp,
  CheckCircle,
  Gauge,
  Leaf,
  AlertCircle,
  Clock,
} from "lucide-react";

// ── Backend base URL ─────────────────────────────────────────────────────────
const BACKEND = import.meta.env.VITE_BACKEND_URL ?? "";

interface DashBin {
  id: string;
  sector: string;
  fill: number;
  status: string;
  lat: number | null;
  lng: number | null;
}

interface DashUser {
  id: string;
  name: string;
  role: string;
  isOnline: boolean;
}

export default function Dashboard() {
  // ── Firestore-driven stats (real-time) ────────────────────────────────────
  const [totalBins, setTotalBins] = useState<number | string>("—");
  const [activeWorkers, setActiveWorkers] = useState<number | string>("—");
  const [todayCollections, setTodayCollections] = useState<number | string>("—");
  const [activeRoutes, setActiveRoutes] = useState<number | string>("—");
  const [pendingAnomalies, setPendingAnomalies] = useState<number | string>("—");
  const [avgFillRate, setAvgFillRate] = useState<number | string>("—");
  const [openExceptions, setOpenExceptions] = useState<number | string>("—");
  const [activeShifts, setActiveShifts] = useState<number | string>("—");
  // Critical bins not yet attached to any active route. These will be picked up
  // by the next /optimize-route call from a matching worker; surfacing the count
  // here lets the admin see when a route generation is overdue.
  const [orphanCriticalBins, setOrphanCriticalBins] = useState<number | string>("—");
  const [abandonedAlerts, setAbandonedAlerts] = useState<Array<{ id: string; workerName: string; area: string; routeId: string }>>([]);
  const [recentExceptions, setRecentExceptions] = useState<Array<{
    exceptionId: string; workerName: string; area: string;
    exceptionType: string; createdAt: { seconds: number } | null;
  }>>([]);
  const [dashBins, setDashBins] = useState<DashBin[]>([]);
  const [dashUsers, setDashUsers] = useState<DashUser[]>([]);

  // ── Backend stats (polled every 30 s) ────────────────────────────────────
  const [totalFuelLitres, setTotalFuelLitres] = useState<number | string>("—");
  const [totalCarbonKg, setTotalCarbonKg] = useState<number | string>("—");

  useEffect(() => {
    let cancelled = false;

    async function fetchBackendStats() {
      try {
        const res = await fetch(`${BACKEND}/admin/stats`, {
          signal: AbortSignal.timeout(5000),
          headers: { "ngrok-skip-browser-warning": "true" },
        });
        if (!res.ok || cancelled) return;
        const json = await res.json();
        const s = json.stats ?? {};
        if (!cancelled) {
          setTotalFuelLitres(
            typeof s.totalFuelUsedLitres === "number" ? s.totalFuelUsedLitres : "—"
          );
          setTotalCarbonKg(
            typeof s.totalCarbonKg === "number" ? s.totalCarbonKg : "—"
          );
        }
      } catch {
        // Backend offline — silently skip; Firestore listeners keep other stats live
      }
    }

    fetchBackendStats();
    const interval = setInterval(fetchBackendStats, 30_000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);

  // ── Firestore listeners ───────────────────────────────────────────────────
  useEffect(() => {
    // Bins: total count + avg fill rate + orphan critical count.
    // Orphan = `status == "critical"` (per-area threshold) AND `isLocked == false`,
    // i.e. a critical bin not yet on any active route.
    const binUnsub = onSnapshot(collection(db, "bins"), (snap) => {
      const bins = snap.docs.map((d) => d.data());
      setTotalBins(bins.length);
      const avg =
        bins.length > 0
          ? Math.round(
              bins.reduce(
                (sum, b) => sum + (b.fillLevel ?? b.fill_level ?? b.currentLevel ?? 0),
                0
              ) / bins.length
            )
          : 0;
      setAvgFillRate(avg + "%");
      setOrphanCriticalBins(
        bins.filter(
          (b) => String(b.status ?? "").toLowerCase() === "critical" && b.isLocked !== true
        ).length
      );
    });

    // Users: count active workers
    const userUnsub = onSnapshot(collection(db, "users"), (snap) => {
      setActiveWorkers(
        snap.docs.filter((d) => {
          const data = d.data();
          return data.role === "worker" && data.isOnline === true;
        }).length
      );
    });

    // Today's collections
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const colUnsub = onSnapshot(
      query(
        collection(db, "pickupLogs"),
        where("completedAt", ">=", Timestamp.fromDate(startOfDay))
      ),
      (snap) => setTodayCollections(snap.size),
      () => setTodayCollections(0)
    );

    // Active routes (written by backend /optimize-route)
    const routeUnsub = onSnapshot(
      query(collection(db, "routes"), where("status", "==", "active")),
      (snap) => setActiveRoutes(snap.size),
      () => setActiveRoutes(0)
    );

    // Pending anomalies (written by backend /report-anomaly)
    const anomalyUnsub = onSnapshot(
      query(collection(db, "anomalies"), where("status", "==", "pending")),
      (snap) => setPendingAnomalies(snap.size),
      () => setPendingAnomalies(0)
    );

    // Open route exceptions (written by backend /skip-stop)
    const exceptionUnsub = onSnapshot(
      query(collection(db, "routeExceptions"), where("status", "==", "open")),
      (snap) => {
        setOpenExceptions(snap.size);
        setRecentExceptions(
          snap.docs.slice(0, 5).map((d) => {
            const r = d.data();
            return {
              exceptionId: d.id,
              workerName:  r.workerName ?? "—",
              area:        r.area ?? "—",
              exceptionType: r.exceptionType ?? "—",
              createdAt:   r.createdAt ?? null,
            };
          })
        );
      },
      () => { setOpenExceptions(0); setRecentExceptions([]); }
    );

    // Active shifts (written by backend /clock-in)
    const shiftUnsub = onSnapshot(
      query(collection(db, "shifts"), where("status", "==", "active")),
      (snap) => setActiveShifts(snap.size),
      () => setActiveShifts(0)
    );

    // Abandoned route alerts (written by backend /skip-stop when all stops skipped)
    const alertUnsub = onSnapshot(
      query(collection(db, "alerts"), where("status", "==", "unread"), where("type", "==", "route_abandoned")),
      (snap) => setAbandonedAlerts(snap.docs.map((d) => {
        const r = d.data();
        return { id: d.id, workerName: r.workerName ?? "Unknown", area: r.area ?? "—", routeId: r.routeId ?? "" };
      })),
      () => setAbandonedAlerts([])
    );

    // Dashboard compact tables
    const dashBinUnsub = onSnapshot(collection(db, "bins"), (snap) => {
      setDashBins(
        snap.docs.map((d) => {
          const r = d.data();
          const fill = r.fillLevel ?? r.fill_level ?? r.currentLevel ?? 0;
          const s = String(r.status ?? "").toLowerCase();
          const status = s === "full" || s === "critical" || fill >= 90
            ? "critical"
            : s === "partial" || s === "warning" || fill >= 70
            ? "warning"
            : "normal";
          return {
            id: d.id,
            sector: r.sector ?? r.area ?? "—",
            fill,
            status,
            lat: typeof r.lat === "number" ? r.lat : null,
            lng: typeof r.lng === "number" ? r.lng : null,
          };
        })
      );
    });

    const dashUserUnsub = onSnapshot(collection(db, "users"), (snap) => {
      setDashUsers(
        snap.docs
          .filter((d) => d.data().role !== "admin")
          .map((d) => {
            const r = d.data();
            return {
              id: d.id,
              name: `${r.firstName ?? ""} ${r.lastName ?? ""}`.trim() || "Unknown",
              role: r.role ?? "worker",
              isOnline: r.isOnline === true,
            };
          })
      );
    });

    return () => {
      binUnsub();
      userUnsub();
      colUnsub();
      routeUnsub();
      anomalyUnsub();
      exceptionUnsub();
      shiftUnsub();
      alertUnsub();
      dashBinUnsub();
      dashUserUnsub();
    };
  }, []);

  const binLocationNames = useBinLocationNames(dashBins);

  const fuelDisplay   = typeof totalFuelLitres === "number" ? totalFuelLitres + " L"  : totalFuelLitres;
  const carbonDisplay = typeof totalCarbonKg   === "number" ? totalCarbonKg   + " kg" : totalCarbonKg;
  
  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-accent/5 to-background relative overflow-hidden">
      <div
        className="absolute top-20 right-1/4 w-96 h-96 bg-accent/10 rounded-full blur-3xl animate-pulse"
        style={{ animationDuration: "4s" }}
      />
      <div
        className="absolute bottom-20 left-1/4 w-96 h-96 bg-primary/10 rounded-full blur-3xl animate-pulse"
        style={{ animationDuration: "6s", animationDelay: "2s" }}
      />

      <AdminHeader
        title="Dashboard"
        subtitle="Welcome back! Live data from Firestore and AI backend."
      />

      {/* Abandoned route alert banner — shown when a worker skipped all stops */}
      {abandonedAlerts.length > 0 && (
        <div className="mx-6 mt-4 rounded-xl border border-destructive/40 bg-destructive/10 px-5 py-4 flex items-start justify-between gap-4">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-destructive shrink-0 mt-0.5" />
            <div>
              <p className="text-sm font-semibold text-destructive">
                {abandonedAlerts.length} route{abandonedAlerts.length > 1 ? "s" : ""} abandoned — all stops skipped
              </p>
              <p className="text-xs text-muted-foreground mt-0.5">
                {abandonedAlerts.map((a) => `${a.workerName} (${a.area})`).join(" · ")}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2 shrink-0">
            <Link to="/admin/exceptions" className="text-xs text-primary hover:underline">View Exceptions →</Link>
            <button
              className="text-xs text-muted-foreground hover:text-foreground"
              onClick={() => abandonedAlerts.forEach((a) =>
                updateDoc(doc(db, "alerts", a.id), { status: "dismissed" })
              )}
            >
              Dismiss
            </button>
          </div>
        </div>
      )}

      <div className="p-6 space-y-6">
        {/* Stats Grid — 7 cards: 4 columns on xl gives a clean 4+3 layout */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          <StatCard
            title="Total Bins"
            value={totalBins}
            change="Live from Firestore"
            changeType="positive"
            icon={Trash2}
            iconColor="text-primary"
            delay={0}
          />
          <StatCard
            title="Active Workers"
            value={activeWorkers}
            change="Currently logged in"
            changeType="positive"
            icon={Users}
            iconColor="text-accent"
            delay={50}
          />
          <StatCard
            title="Today Collections"
            value={todayCollections}
            change="Completed today"
            changeType="positive"
            icon={CheckCircle}
            iconColor="text-success"
            delay={100}
          />
          <StatCard
            title="Active Routes"
            value={activeRoutes}
            change="Status: active"
            changeType="neutral"
            icon={Route}
            iconColor="text-info"
            delay={150}
          />
          <StatCard
            title="Pending Anomalies"
            value={pendingAnomalies}
            change="Awaiting resolution"
            changeType="negative"
            icon={AlertTriangle}
            iconColor="text-warning"
            delay={200}
          />
          <StatCard
            title="Avg Fill Rate"
            value={avgFillRate}
            change="Avg across all bins"
            changeType="neutral"
            icon={TrendingUp}
            iconColor="text-primary"
            delay={250}
          />
          <StatCard
            title="Fuel Tracked"
            value={fuelDisplay}
            change="Completed routes total"
            changeType="neutral"
            icon={Gauge}
            iconColor="text-warning"
            delay={300}
          />
          <StatCard
            title="CO₂ Footprint"
            value={carbonDisplay}
            change="0.95 kg/km — completed routes"
            changeType="negative"
            icon={Leaf}
            iconColor="text-success"
            delay={350}
          />
          <StatCard
            title="Open Exceptions"
            value={openExceptions}
            change="Awaiting admin review"
            changeType="negative"
            icon={AlertCircle}
            iconColor="text-warning"
            delay={400}
          />
          <StatCard
            title="Active Shifts"
            value={activeShifts}
            change="Workers currently on shift"
            changeType="positive"
            icon={Clock}
            iconColor="text-success"
            delay={450}
          />
          <StatCard
            title="Urgent Bins Waiting"
            value={orphanCriticalBins}
            change="Critical bins not yet on a route"
            changeType={
              typeof orphanCriticalBins === "number" && orphanCriticalBins > 0
                ? "negative"
                : "neutral"
            }
            icon={AlertTriangle}
            iconColor="text-destructive"
            delay={500}
          />
        </div>

        {/* Charts Row */}
        <div className="grid gap-6 lg:grid-cols-3">
          <div className="lg:col-span-2">
            <CollectionTrendsChart />
          </div>
          <WasteDistributionChart />
        </div>

        {/* Advanced Analytics Row */}
        <div className="grid gap-6 lg:grid-cols-3">
          <PeakHoursChart />
          <FillEfficiencyChart />
          <AreaPerformanceChart />
        </div>

        {/* Map — full width */}
        <MapPreview />

        {/* Worker Performance */}
        <WorkerPerformanceChart />

        {/* Compact Bins + Users tables */}
        <div className="grid gap-6 lg:grid-cols-2">
          {/* Bins — District, Fill Level, Status */}
          <div className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm shadow-xl shadow-accent/10 overflow-hidden animate-fade-in" style={{ animationDelay: "800ms" }}>
            <div className="px-5 py-4 bg-gradient-to-r from-accent/15 via-primary/10 to-accent/15 flex items-center justify-between">
              <h3 className="text-sm font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent uppercase tracking-wider">Bins</h3>
              <span className="text-xs text-muted-foreground">{dashBins.length} total</span>
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-border/50">
                <thead>
                  <tr className="text-xs text-muted-foreground">
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">District</th>
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Fill Level</th>
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/50">
                  {dashBins.length === 0 ? (
                    <tr><td colSpan={3} className="px-4 py-6 text-center text-sm text-muted-foreground">No bins found</td></tr>
                  ) : dashBins.slice(0, 8).map((bin) => (
                    <tr key={bin.id} className="hover:bg-primary/5 transition-colors">
                      <td className="px-4 py-3 text-sm text-foreground">
                        {bin.sector !== "—" ? (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-info/10 text-info border border-info/30">{bin.sector}</span>
                        ) : <span className="text-muted-foreground">—</span>}
                        {binLocationNames[bin.id] && (
                          <p className="text-xs text-muted-foreground truncate mt-1 max-w-[120px]">{binLocationNames[bin.id]}</p>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <div className="w-16 h-1.5 bg-muted rounded-full overflow-hidden">
                            <div className={`h-full rounded-full ${bin.fill >= 90 ? "bg-destructive" : bin.fill >= 70 ? "bg-warning" : "bg-success"}`} style={{ width: `${bin.fill}%` }} />
                          </div>
                          <span className="text-xs text-foreground font-medium">{bin.fill}%</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                          bin.status === "critical" ? "bg-destructive/20 text-destructive border border-destructive/30" :
                          bin.status === "warning"  ? "bg-warning/20 text-warning border border-warning/30" :
                                                     "bg-success/20 text-success border border-success/30"
                        }`}>{bin.status}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Users — Name, Role, Status */}
          <div className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm shadow-xl shadow-accent/10 overflow-hidden animate-fade-in" style={{ animationDelay: "850ms" }}>
            <div className="px-5 py-4 bg-gradient-to-r from-accent/15 via-primary/10 to-accent/15 flex items-center justify-between">
              <h3 className="text-sm font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent uppercase tracking-wider">Users</h3>
              <span className="text-xs text-muted-foreground">{dashUsers.length} total</span>
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-border/50">
                <thead>
                  <tr className="text-xs text-muted-foreground">
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Name</th>
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Role</th>
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/50">
                  {dashUsers.length === 0 ? (
                    <tr><td colSpan={3} className="px-4 py-6 text-center text-sm text-muted-foreground">No users found</td></tr>
                  ) : dashUsers.slice(0, 8).map((user) => (
                    <tr key={user.id} className="hover:bg-primary/5 transition-colors">
                      <td className="px-4 py-3 text-sm font-medium text-foreground">{user.name}</td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                          user.role === "admin"   ? "bg-warning/20 text-warning border border-warning/30" :
                          user.role === "manager" ? "bg-primary/20 text-primary border border-primary/30" :
                                                   "bg-accent/20 text-accent border border-accent/40"
                        }`}>{user.role}</span>
                      </td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                          user.isOnline
                            ? "bg-success/20 text-success border border-success/30"
                            : "bg-muted text-muted-foreground border border-border/50"
                        }`}>{user.isOnline ? "Online" : "Offline"}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {/* Recent Open Exceptions preview */}
        <div className="rounded-xl border border-warning/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm shadow-xl shadow-warning/10 overflow-hidden animate-fade-in" style={{ animationDelay: "900ms" }}>
          <div className="px-5 py-4 bg-gradient-to-r from-warning/15 via-warning/5 to-warning/15 flex items-center justify-between">
            <h3 className="text-sm font-semibold text-warning uppercase tracking-wider flex items-center gap-2">
              <AlertCircle className="w-4 h-4" /> Open Exceptions
            </h3>
            <Link to="/admin/exceptions" className="text-xs text-primary hover:underline">View All →</Link>
          </div>
          {recentExceptions.length === 0 ? (
            <p className="px-5 py-6 text-sm text-muted-foreground text-center">No open exceptions</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-border/50">
                <thead>
                  <tr className="text-xs text-muted-foreground">
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Time</th>
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Worker</th>
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Area</th>
                    <th className="px-4 py-2 text-left font-semibold uppercase tracking-wider">Type</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/50">
                  {recentExceptions.map((ex) => (
                    <tr key={ex.exceptionId} className="hover:bg-warning/5 transition-colors">
                      <td className="px-4 py-3 text-xs text-muted-foreground">
                        {ex.createdAt ? new Date(ex.createdAt.seconds * 1000).toLocaleString("en-GB", { day:"2-digit", month:"2-digit", hour:"2-digit", minute:"2-digit" }) : "—"}
                      </td>
                      <td className="px-4 py-3 text-sm font-medium text-foreground">{ex.workerName}</td>
                      <td className="px-4 py-3 text-sm text-muted-foreground">{ex.area}</td>
                      <td className="px-4 py-3">
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-warning/20 text-warning border border-warning/30">
                          {ex.exceptionType.replace(/_/g, " ")}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Anomaly Feed — real-time Firestore listener on 'anomalies' collection */}
        <AnomalyFeed />
      </div>
    </div>
  );
}
