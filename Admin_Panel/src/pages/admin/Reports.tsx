import { useState, useEffect, useMemo } from "react";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Download,
  AlertTriangle,
  TrendingUp,
  Eye,
  CheckCircle,
  Clock,
  Printer,
} from "lucide-react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { cn } from "@/lib/utils";
import { db } from "@/firebase";
import {
  collection,
  onSnapshot,
  query,
  orderBy,
  limit,
  Timestamp,
  doc,
  updateDoc,
} from "firebase/firestore";
import { toast } from "sonner";
import { useBinLocationNames } from "@/hooks/useBinLocationNames";

interface Anomaly {
  id: string;
  docId: string;
  bin: string;
  type: string;
  workerId: string;   // raw reportedBy UID from Firestore
  workerFallback: string; // pre-stored name/label if no UID
  sector: string;
  date: string;
  createdAtMs: number;  // raw timestamp for sorting
  status: "pending" | "resolved" | "investigating";
  priority: "high" | "medium" | "low";
}

type AnomalySortKey = "date_desc" | "date_asc" | "priority_desc" | "priority_asc";

const PRIORITY_RANK: Record<string, number> = { high: 3, medium: 2, low: 1 };

interface WorkerPerf {
  worker: string;
  collections: number;
  routes: number;
  efficiency: number;
  area: string;
}

function resolveReporter(
  workerId: string,
  fallback: string,
  map: Map<string, string>
): { name: string; unknown: boolean } {
  if (!workerId && !fallback) return { name: "N/A", unknown: false };
  if (workerId && map.has(workerId)) return { name: map.get(workerId)!, unknown: false };
  if (fallback) return { name: fallback, unknown: false };
  // UID present but not found in users collection
  return { name: `Unknown Worker`, unknown: true };
}

function escapeCsv(v: unknown): string {
  const s = v === null || v === undefined ? "" : String(v);
  return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

function toCsv(headers: string[], rows: (string | number)[][]): string {
  return [
    headers.map(escapeCsv).join(","),
    ...rows.map((r) => r.map(escapeCsv).join(",")),
  ].join("\n");
}

function downloadFile(filename: string, content: string, mime: string) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export default function Reports() {
  const [sectorFilter, setSectorFilter] = useState<string>("all");
  const [anomalySort, setAnomalySort] = useState<AnomalySortKey>("date_desc");

  const [anomalies, setAnomalies] = useState<Anomaly[]>([]);
  const [performanceData, setPerformanceData] = useState<WorkerPerf[]>([]);
  const [workerNamesMap, setWorkerNamesMap] = useState<Map<string, string>>(new Map());
  const [binCoords, setBinCoords] = useState<Record<string, { lat: number | null; lng: number | null }>>({});

  // Anomalies listener
  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, "anomalies"), orderBy("createdAt", "desc"), limit(50)),
      (snap) => {
        const data: Anomaly[] = snap.docs.map((d) => {
          const raw = d.data();
          const ts = raw.createdAt?.toDate?.();
          const reportedBy = (raw.reportedBy ?? "") as string;
          const fallbackName = (raw.workerName ?? raw.worker ?? "") as string;
          return {
            id: d.id.slice(0, 8).toUpperCase(),
            docId: d.id,
            bin: raw.binId ?? raw.bin ?? "N/A",
            type: raw.type ?? raw.anomalyType ?? "Unknown",
            workerId: reportedBy,
            workerFallback: fallbackName,
            sector: raw.sector ?? raw.sectorId ?? "N/A",
            date: ts ? ts.toLocaleString() : "N/A",
            createdAtMs: ts ? ts.getTime() : 0,
            status: raw.status ?? "pending",
            priority: raw.priority ?? "medium",
          };
        });
        setAnomalies(data);
      },
      () => setAnomalies([])
    );
    return () => unsub();
  }, []);

  // Bin coordinates — needed so anomaly rows can be reverse-geocoded to a
  // readable location name (the anomaly doc only stores binId).
  useEffect(() => {
    const unsub = onSnapshot(collection(db, "bins"), (snap) => {
      const next: Record<string, { lat: number | null; lng: number | null }> = {};
      snap.docs.forEach((d) => {
        const raw = d.data() as Record<string, unknown>;
        let lat: number | null = null;
        let lng: number | null = null;
        if (raw.location && typeof raw.location === "object") {
          const loc = raw.location as Record<string, unknown>;
          lat = (loc._lat ?? loc.latitude) as number | null ?? null;
          lng = (loc._long ?? loc.longitude) as number | null ?? null;
        }
        if (raw.lat !== undefined && raw.lng !== undefined) {
          lat = Number(raw.lat);
          lng = Number(raw.lng);
        }
        if (lat === 0 && lng === 0) { lat = null; lng = null; }
        next[d.id] = { lat, lng };
      });
      setBinCoords(next);
    });
    return () => unsub();
  }, []);

  // Worker performance — 3 real-time listeners: pickupLogs, routes, users(workers only)
  useEffect(() => {
    const pickupCounts  = new Map<string, number>();
    const completedRoutes = new Map<string, number>(); // workerId → completed routes
    const assignedRoutes  = new Map<string, number>(); // workerId → total assigned routes
    const workerNames   = new Map<string, string>();
    const workerAreas   = new Map<string, string>();

    function rebuild() {
      // Only IDs known from the users collection (role=worker) appear in the chart
      const ids = Array.from(workerNames.keys());

      const workers: WorkerPerf[] = ids
        .map((id) => {
          const assigned  = assignedRoutes.get(id) ?? 0;
          const completed = completedRoutes.get(id) ?? 0;
          const efficiency = assigned > 0 ? Math.round((completed / assigned) * 100) : 0;
          return {
            worker:      workerNames.get(id) ?? id.slice(0, 12),
            collections: pickupCounts.get(id) ?? 0,
            routes:      completed,
            efficiency,
            area:        workerAreas.get(id) ?? "",
          };
        })
        .sort((a, b) => b.collections - a.collections)
        .slice(0, 10);

      setPerformanceData(workers);
    }

    const unsubPickup = onSnapshot(collection(db, "pickupLogs"), (snap) => {
      pickupCounts.clear();
      snap.docs.forEach((d) => {
        const wid = d.data().workerId as string | undefined;
        if (wid) pickupCounts.set(wid, (pickupCounts.get(wid) ?? 0) + 1);
      });
      rebuild();
    });

    const unsubRoutes = onSnapshot(collection(db, "routes"), (snap) => {
      completedRoutes.clear();
      assignedRoutes.clear();
      snap.docs.forEach((d) => {
        const r = d.data();
        const wid = (r.workerId ?? r.driverId ?? "") as string;
        if (!wid) return;
        // Count every route assigned to this worker
        assignedRoutes.set(wid, (assignedRoutes.get(wid) ?? 0) + 1);
        // Count completed routes (status=completed or all stops done)
        const cs = r.completedStops ?? 0;
        const ts = r.totalStops ?? 0;
        const isDone = r.status === "completed" || (ts > 0 && cs >= ts);
        if (isDone) completedRoutes.set(wid, (completedRoutes.get(wid) ?? 0) + 1);
      });
      rebuild();
    });

    const unsubWorkers = onSnapshot(collection(db, "users"), (snap) => {
      workerNames.clear();
      workerAreas.clear();
      snap.docs.forEach((d) => {
        const raw = d.data();
        // Skip non-workers so admins never appear in performance charts
        if (raw.role !== "worker") return;
        const name = ((raw.firstName || "") + " " + (raw.lastName || "")).trim()
          || (raw.name as string)
          || "Unknown";
        workerNames.set(d.id, name);
        workerAreas.set(d.id, (raw.assignedArea ?? "") as string);
      });
      setWorkerNamesMap(new Map(workerNames));
      rebuild();
    });

    return () => {
      unsubPickup();
      unsubRoutes();
      unsubWorkers();
    };
  }, []);

  // Reverse-geocode the bins referenced by anomalies so the table can show a
  // readable location name instead of the raw binId.
  const anomalyBinList = useMemo(
    () =>
      Array.from(new Set(anomalies.map((a) => a.bin).filter((id) => id && id !== "N/A"))).map(
        (id) => ({ id, lat: binCoords[id]?.lat ?? null, lng: binCoords[id]?.lng ?? null }),
      ),
    [anomalies, binCoords],
  );
  const binLocationNames = useBinLocationNames(anomalyBinList);

  // Derive available sectors from anomalies
  const availableSectors = useMemo(
    () => Array.from(new Set(anomalies.map((a) => a.sector).filter((s) => s !== "N/A" && s.trim() !== ""))),
    [anomalies]
  );

  const filteredAnomalies = useMemo(() => {
    const rows = anomalies.filter(
      (a) => sectorFilter === "all" || a.sector === sectorFilter
    );
    const sorted = [...rows];
    sorted.sort((a, b) => {
      switch (anomalySort) {
        case "date_asc":
          return a.createdAtMs - b.createdAtMs;
        case "priority_desc":
          return (PRIORITY_RANK[b.priority] ?? 0) - (PRIORITY_RANK[a.priority] ?? 0);
        case "priority_asc":
          return (PRIORITY_RANK[a.priority] ?? 0) - (PRIORITY_RANK[b.priority] ?? 0);
        case "date_desc":
        default:
          return b.createdAtMs - a.createdAtMs;
      }
    });
    return sorted;
  }, [anomalies, sectorFilter, anomalySort]);

  // Apply sector filter to performance data as well (matches worker's assigned area)
  const filteredPerformanceData = sectorFilter === "all"
    ? performanceData
    : performanceData.filter(
        (w) => w.area === sectorFilter || w.area.toLowerCase().includes(sectorFilter.toLowerCase())
      );

  const anomalyStats = {
    pending: filteredAnomalies.filter((a) => a.status === "pending").length,
  };

  const handleUpdateAnomalyStatus = async (docId: string, newStatus: "pending" | "resolved" | "investigating") => {
    try {
      await updateDoc(doc(db, "anomalies", docId), {
        status: newStatus,
        updatedAt: Timestamp.now(),
      });
      toast.success(`Anomaly marked as ${newStatus}`);
    } catch (error) {
      console.error("Error updating anomaly:", error);
      toast.error("Failed to update anomaly status");
    }
  };

  const handleExportCsv = () => {
    const stamp = new Date().toISOString().slice(0, 10);
    const sections: string[] = [];

    sections.push(`CleanCore Report`);
    sections.push(`Generated: ${new Date().toLocaleString()}`);
    sections.push(
      `Sector filter: ${sectorFilter === "all" ? "All sectors" : sectorFilter}`
    );
    sections.push("");

    sections.push("Anomalies");
    sections.push(
      toCsv(
        ["ID", "Bin", "Type", "Reported By", "Sector", "Date", "Priority", "Status"],
        filteredAnomalies.map((a) => [
          a.id, a.bin, a.type,
          resolveReporter(a.workerId, a.workerFallback, workerNamesMap).name,
          a.sector, a.date, a.priority, a.status,
        ])
      )
    );
    sections.push("");

    sections.push("Worker Performance");
    sections.push(
      toCsv(
        ["Worker", "Collections", "Routes", "Efficiency %"],
        filteredPerformanceData.map((w) => [w.worker, w.collections, w.routes, w.efficiency])
      )
    );

    downloadFile(
      `cleancore-report-${stamp}.csv`,
      sections.join("\n"),
      "text/csv;charset=utf-8;"
    );
    toast.success("Report exported as CSV");
  };

  const handleExportPdf = () => {
    const html = `<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<title>CleanCore Report</title>
<style>
  body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; padding: 32px; color: #111; }
  h1 { margin-bottom: 4px; }
  .meta { color: #666; font-size: 12px; margin-bottom: 24px; }
  h2 { margin-top: 28px; border-bottom: 1px solid #ddd; padding-bottom: 4px; font-size: 16px; }
  table { width: 100%; border-collapse: collapse; margin-top: 8px; font-size: 13px; }
  th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid #eee; }
  th { background: #f5f5f5; }
  .stats { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin-bottom: 16px; }
  .stat { border: 1px solid #ddd; border-radius: 6px; padding: 12px; }
  .stat .label { font-size: 11px; color: #666; text-transform: uppercase; }
  .stat .value { font-size: 22px; font-weight: 700; }
  @media print { body { padding: 16px; } }
</style>
</head>
<body>
  <h1>CleanCore Report</h1>
  <div class="meta">
    Sector: ${sectorFilter === "all" ? "All sectors" : sectorFilter} &middot;
    Generated ${new Date().toLocaleString()}
  </div>

  <div class="stats">
    <div class="stat"><div class="label">Pending Anomalies</div><div class="value">${anomalyStats.pending}</div></div>
    <div class="stat"><div class="label">Total Workers Tracked</div><div class="value">${filteredPerformanceData.length}</div></div>
  </div>

  <h2>Recent Anomalies</h2>
  <table>
    <thead><tr><th>ID</th><th>Bin</th><th>Type</th><th>Reported By</th><th>Priority</th><th>Status</th><th>Date</th></tr></thead>
    <tbody>
      ${filteredAnomalies
        .slice(0, 25)
        .map(
          (a) =>
            `<tr><td>${a.id}</td><td>${a.bin}</td><td>${a.type}</td><td>${resolveReporter(a.workerId, a.workerFallback, workerNamesMap).name}</td><td>${a.priority}</td><td>${a.status}</td><td>${a.date}</td></tr>`
        )
        .join("")}
    </tbody>
  </table>

  <h2>Worker Performance</h2>
  <table>
    <thead><tr><th>Worker</th><th>Collections</th><th>Routes</th><th>Efficiency</th></tr></thead>
    <tbody>
      ${filteredPerformanceData
        .map(
          (w) =>
            `<tr><td>${w.worker}</td><td>${w.collections}</td><td>${w.routes}</td><td>${w.efficiency || 0}%</td></tr>`
        )
        .join("")}
    </tbody>
  </table>

  <script>window.onload = () => { setTimeout(() => window.print(), 250); };</script>
</body>
</html>`;

    const win = window.open("", "_blank");
    if (!win) {
      toast.error("Pop-up blocked. Please allow pop-ups to export PDF.");
      return;
    }
    win.document.open();
    win.document.write(html);
    win.document.close();
    toast.success("Report opened — use the print dialog to save as PDF");
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-card/10 to-background">
      <AdminHeader
        title="View Reports"
        subtitle="Analytics and insights for waste management operations"
      />

      <div className="p-6 space-y-6">
        {/* Filters */}
        <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div className="flex items-center gap-4">
            <Select value={sectorFilter} onValueChange={setSectorFilter}>
              <SelectTrigger className="w-40 bg-muted/50 border-border">
                <SelectValue placeholder="Sector" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Sectors</SelectItem>
                {availableSectors.map((s) => (
                  <SelectItem key={s} value={s}>
                    Sector {s}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select value={anomalySort} onValueChange={(v) => setAnomalySort(v as AnomalySortKey)}>
              <SelectTrigger className="w-52 bg-muted/50 border-border">
                <SelectValue placeholder="Sort anomalies" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="date_desc">Newest first</SelectItem>
                <SelectItem value="date_asc">Oldest first</SelectItem>
                <SelectItem value="priority_desc">Priority: High → Low</SelectItem>
                <SelectItem value="priority_asc">Priority: Low → High</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              className="border-border"
              onClick={handleExportPdf}
            >
              <Printer className="h-4 w-4 mr-2" />
              Export PDF
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="border-border"
              onClick={handleExportCsv}
            >
              <Download className="h-4 w-4 mr-2" />
              Export CSV
            </Button>
          </div>
        </div>

        {/* Tabs */}
        <Tabs defaultValue="anomaly" className="space-y-6">
          <TabsList className="bg-muted/50 border border-border">
            <TabsTrigger
              value="anomaly"
              className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground"
            >
              <AlertTriangle className="h-4 w-4 mr-2" />
              Anomaly Reports
            </TabsTrigger>
            <TabsTrigger
              value="performance"
              className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground"
            >
              <TrendingUp className="h-4 w-4 mr-2" />
              Performance Analytics
            </TabsTrigger>
          </TabsList>

          {/* Anomaly Reports */}
          <TabsContent value="anomaly" className="space-y-6">
            <div className="grid gap-4 md:grid-cols-1 max-w-xs">
              <Card className="bg-card border-border">
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm text-muted-foreground">
                    Pending Anomalies
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-3xl font-bold text-warning">
                    {anomalyStats.pending}
                  </p>
                  <p className="text-sm text-muted-foreground">
                    Awaiting action
                  </p>
                </CardContent>
              </Card>
            </div>

            <Card className="bg-card border-border">
              <CardHeader>
                <CardTitle className="text-foreground">
                  Recent Anomalies
                </CardTitle>
              </CardHeader>
              <CardContent>
                {filteredAnomalies.length === 0 ? (
                  <p className="text-sm text-muted-foreground text-center py-8">
                    No anomalies found
                  </p>
                ) : (
                  <Table>
                    <TableHeader>
                      <TableRow className="border-border hover:bg-transparent">
                        <TableHead className="text-muted-foreground">ID</TableHead>
                        <TableHead className="text-muted-foreground">Bin</TableHead>
                        <TableHead className="text-muted-foreground">Type</TableHead>
                        <TableHead className="text-muted-foreground">
                          Reported By
                        </TableHead>
                        <TableHead className="text-muted-foreground">Date</TableHead>
                        <TableHead className="text-muted-foreground">
                          Priority
                        </TableHead>
                        <TableHead className="text-muted-foreground">
                          Status
                        </TableHead>
                        <TableHead className="text-muted-foreground text-right">
                          Actions
                        </TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredAnomalies.map((anomaly) => (
                        <TableRow
                          key={anomaly.id}
                          className="border-border hover:bg-muted/30"
                        >
                          <TableCell className="font-medium text-foreground">
                            {anomaly.id}
                          </TableCell>
                          <TableCell className="text-foreground">
                            {binLocationNames[anomaly.bin] ?? (
                              <span className="font-mono text-xs text-muted-foreground" title={anomaly.bin}>
                                {anomaly.bin.length > 14 ? anomaly.bin.slice(0, 14) + "…" : anomaly.bin}
                              </span>
                            )}
                          </TableCell>
                          <TableCell className="text-foreground">
                            {anomaly.type}
                          </TableCell>
                          <TableCell className="text-foreground">
                            {(() => {
                              const { name, unknown } = resolveReporter(
                                anomaly.workerId,
                                anomaly.workerFallback,
                                workerNamesMap
                              );
                              return unknown ? (
                                <span className="flex items-center gap-1.5 text-warning">
                                  <AlertTriangle className="h-3.5 w-3.5 shrink-0" />
                                  {name}
                                </span>
                              ) : name;
                            })()}
                          </TableCell>
                          <TableCell className="text-muted-foreground">
                            {anomaly.date}
                          </TableCell>
                          <TableCell>
                            <Badge
                              className={cn(
                                anomaly.priority === "high" &&
                                  "bg-destructive/10 text-destructive border-destructive/30",
                                anomaly.priority === "medium" &&
                                  "bg-warning/10 text-warning border-warning/30",
                                anomaly.priority === "low" &&
                                  "bg-info/10 text-info border-info/30"
                              )}
                            >
                              {anomaly.priority}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            <Badge
                              className={cn(
                                "capitalize",
                                anomaly.status === "pending" &&
                                  "bg-warning/10 text-warning border-warning/30",
                                anomaly.status === "resolved" &&
                                  "bg-success/10 text-success border-success/30",
                                anomaly.status === "investigating" &&
                                  "bg-info/10 text-info border-info/30"
                              )}
                            >
                              <span className="flex items-center gap-1">
                                {anomaly.status === "pending" && (
                                  <Clock className="h-3 w-3" />
                                )}
                                {anomaly.status === "resolved" && (
                                  <CheckCircle className="h-3 w-3" />
                                )}
                                {anomaly.status === "investigating" && (
                                  <Eye className="h-3 w-3" />
                                )}
                                {anomaly.status}
                              </span>
                            </Badge>
                          </TableCell>
                          <TableCell className="text-right">
                            {anomaly.status !== "resolved" && (
                              <div className="flex items-center justify-end gap-2">
                                {anomaly.status === "pending" && (
                                  <Button
                                    variant="outline"
                                    size="sm"
                                    className="h-7 text-xs border-info/30 text-info hover:bg-info/10"
                                    onClick={() => handleUpdateAnomalyStatus(anomaly.docId, "investigating")}
                                  >
                                    Investigate
                                  </Button>
                                )}
                                <Button
                                  variant="outline"
                                  size="sm"
                                  className="h-7 text-xs border-success/30 text-success hover:bg-success/10"
                                  onClick={() => handleUpdateAnomalyStatus(anomaly.docId, "resolved")}
                                >
                                  Resolve
                                </Button>
                              </div>
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* Performance Analytics */}
          <TabsContent value="performance" className="space-y-6">
            <div className="grid gap-6 lg:grid-cols-2">
              <Card className="bg-card border-border">
                <CardHeader>
                  <CardTitle className="text-foreground">
                    Worker Performance (Collections)
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="h-[300px]">
                    {filteredPerformanceData.length === 0 ? (
                      <div className="h-full flex items-center justify-center text-muted-foreground text-sm">
                        No worker data available
                      </div>
                    ) : (
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={filteredPerformanceData}>
                          <CartesianGrid
                            strokeDasharray="3 3"
                            stroke="hsl(222 30% 25%)"
                          />
                          <XAxis
                            dataKey="worker"
                            stroke="hsl(215 20% 65%)"
                            tick={{ fill: "hsl(215 20% 65%)", fontSize: 11 }}
                          />
                          <YAxis
                            stroke="hsl(215 20% 65%)"
                            tick={{ fill: "hsl(215 20% 65%)", fontSize: 12 }}
                          />
                          <Tooltip
                            contentStyle={{
                              backgroundColor: "hsl(222 47% 14%)",
                              border: "1px solid hsl(222 30% 25%)",
                              borderRadius: "8px",
                              color: "hsl(180 100% 95%)",
                            }}
                          />
                          <Bar
                            dataKey="collections"
                            fill="hsl(180 100% 50%)"
                            radius={[4, 4, 0, 0]}
                          />
                        </BarChart>
                      </ResponsiveContainer>
                    )}
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-card border-border">
                <CardHeader>
                  <CardTitle className="text-foreground">
                    Routes Completed by Worker
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="h-[300px]">
                    {filteredPerformanceData.length === 0 ? (
                      <div className="h-full flex items-center justify-center text-muted-foreground text-sm">
                        No worker data available
                      </div>
                    ) : (
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={filteredPerformanceData} layout="vertical">
                          <CartesianGrid
                            strokeDasharray="3 3"
                            stroke="hsl(222 30% 25%)"
                            horizontal={false}
                          />
                          <XAxis
                            type="number"
                            stroke="hsl(215 20% 65%)"
                            tick={{ fill: "hsl(215 20% 65%)", fontSize: 12 }}
                          />
                          <YAxis
                            type="category"
                            dataKey="worker"
                            stroke="hsl(215 20% 65%)"
                            tick={{ fill: "hsl(215 20% 65%)", fontSize: 11 }}
                            width={90}
                          />
                          <Tooltip
                            contentStyle={{
                              backgroundColor: "hsl(222 47% 14%)",
                              border: "1px solid hsl(222 30% 25%)",
                              borderRadius: "8px",
                              color: "hsl(180 100% 95%)",
                            }}
                          />
                          <Bar
                            dataKey="routes"
                            fill="hsl(168 76% 42%)"
                            radius={[0, 4, 4, 0]}
                          />
                        </BarChart>
                      </ResponsiveContainer>
                    )}
                  </div>
                </CardContent>
              </Card>
            </div>

            <Card className="bg-card border-border">
              <CardHeader>
                <CardTitle className="text-foreground">
                  Detailed Worker Analytics
                </CardTitle>
              </CardHeader>
              <CardContent>
                {filteredPerformanceData.length === 0 ? (
                  <p className="text-sm text-muted-foreground text-center py-8">
                    No worker data found in Firestore
                  </p>
                ) : (
                  <Table>
                    <TableHeader>
                      <TableRow className="border-border hover:bg-transparent">
                        <TableHead className="text-muted-foreground">Worker</TableHead>
                        <TableHead className="text-muted-foreground">Collections</TableHead>
                        <TableHead className="text-muted-foreground">Routes</TableHead>
                        <TableHead className="text-muted-foreground">Efficiency</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredPerformanceData.map((worker) => (
                        <TableRow
                          key={worker.worker}
                          className="border-border hover:bg-muted/30"
                        >
                          <TableCell className="font-medium text-foreground">
                            {worker.worker}
                          </TableCell>
                          <TableCell className="text-foreground">
                            {worker.collections}
                          </TableCell>
                          <TableCell className="text-foreground">
                            {worker.routes}
                          </TableCell>
                          <TableCell>
                            <span
                              className={cn(
                                "font-medium",
                                worker.efficiency >= 95 && "text-success",
                                worker.efficiency >= 80 &&
                                  worker.efficiency < 95 &&
                                  "text-warning",
                                worker.efficiency > 0 &&
                                  worker.efficiency < 80 &&
                                  "text-destructive",
                                worker.efficiency === 0 &&
                                  "text-muted-foreground"
                              )}
                            >
                              {worker.efficiency > 0
                                ? worker.efficiency + "%"
                                : "N/A"}
                            </span>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}
