import { useState, useEffect, useMemo } from "react";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
import { db } from "@/firebase";
import { collection, onSnapshot, query, orderBy } from "firebase/firestore";
import { AlertCircle, CheckCircle, ArrowUpCircle, Lock, Construction, AlertTriangle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { getAuth } from "firebase/auth";

const BACKEND = import.meta.env.VITE_BACKEND_URL ?? "";
const PAGE_SIZE = 20;

interface RouteException {
  exceptionId: string;
  routeId:     string;
  binId:       string;
  workerId:    string;
  workerName:  string;
  exceptionType: string;
  exceptionNote: string;
  area:        string;
  status:      string;
  resolvedBy:  string | null;
  resolvedAt:  { seconds: number } | null;
  createdAt:   { seconds: number } | null;
}

function fmt(ts: { seconds: number } | null): string {
  if (!ts) return "—";
  return new Date(ts.seconds * 1000).toLocaleString("en-GB", {
    day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

function typeLabel(t: string) {
  return t.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function typeIcon(t: string) {
  if (t === "bin_inaccessible")   return <Lock className="w-3 h-3 inline mr-1" />;
  if (t === "bin_damaged")        return <Construction className="w-3 h-3 inline mr-1" />;
  if (t === "hazardous_material") return <AlertTriangle className="w-3 h-3 inline mr-1" />;
  return null;
}

export default function Exceptions() {
  const { toast } = useToast();
  const [exceptions, setExceptions] = useState<RouteException[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState("all");
  const [typeFilter, setTypeFilter] = useState("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [resolving, setResolving] = useState<string | null>(null);

  useEffect(() => {
    const q = query(collection(db, "routeExceptions"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      setExceptions(
        snap.docs.map((d) => {
          const r = d.data();
          return {
            exceptionId:   d.id,
            routeId:       r.routeId       ?? "",
            binId:         r.binId         ?? "",
            workerId:      r.workerId      ?? "",
            workerName:    r.workerName    ?? "—",
            exceptionType: r.exceptionType ?? "—",
            exceptionNote: r.exceptionNote ?? "",
            area:          r.area          ?? "—",
            status:        r.status        ?? "open",
            resolvedBy:    r.resolvedBy    ?? null,
            resolvedAt:    r.resolvedAt    ?? null,
            createdAt:     r.createdAt     ?? null,
          };
        })
      );
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, []);

  const filtered = useMemo(() => {
    return exceptions.filter((e) => {
      if (statusFilter !== "all" && e.status !== statusFilter) return false;
      if (typeFilter   !== "all" && e.exceptionType !== typeFilter) return false;
      return true;
    });
  }, [exceptions, statusFilter, typeFilter]);

  const totalPages  = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const paginated   = filtered.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);

  // KPI stats
  const openCount      = exceptions.filter((e) => e.status === "open").length;
  const today          = new Date(); today.setHours(0,0,0,0);
  const resolvedToday  = exceptions.filter((e) =>
    e.status === "resolved" && e.resolvedAt &&
    new Date(e.resolvedAt.seconds * 1000) >= today
  ).length;
  const typeCounts     = exceptions.reduce<Record<string, number>>((acc, e) => {
    acc[e.exceptionType] = (acc[e.exceptionType] ?? 0) + 1;
    return acc;
  }, {});
  const mostCommon     = Object.entries(typeCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "—";

  async function patchException(id: string, newStatus: "resolved" | "escalated") {
    setResolving(id);
    try {
      const auth  = getAuth();
      const admin = auth.currentUser?.email ?? "admin";
      const res   = await fetch(`${BACKEND}/admin/exceptions/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "ngrok-skip-browser-warning": "true" },
        body: JSON.stringify({ status: newStatus, resolved_by: admin }),
      });
      if (res.ok) {
        toast({ title: newStatus === "resolved" ? "Exception resolved" : "Exception escalated" });
      } else {
        toast({ title: "Action failed", variant: "destructive" });
      }
    } catch {
      toast({ title: "Network error", variant: "destructive" });
    } finally {
      setResolving(null);
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-accent/5 to-background">
      <AdminHeader title="Exceptions" subtitle="Route exceptions logged by drivers — resolve or escalate." />

      <div className="p-6 space-y-6">
        {/* KPI strip */}
        <div className="grid gap-4 md:grid-cols-3">
          <Card>
            <CardHeader className="pb-2"><CardTitle className="text-sm font-medium text-muted-foreground">Open Exceptions</CardTitle></CardHeader>
            <CardContent><p className="text-3xl font-bold text-warning">{openCount}</p></CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2"><CardTitle className="text-sm font-medium text-muted-foreground">Resolved Today</CardTitle></CardHeader>
            <CardContent><p className="text-3xl font-bold text-success">{resolvedToday}</p></CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2"><CardTitle className="text-sm font-medium text-muted-foreground">Most Common Type</CardTitle></CardHeader>
            <CardContent><p className="text-xl font-bold text-foreground">{typeLabel(mostCommon)}</p></CardContent>
          </Card>
        </div>

        {/* Filter bar */}
        <div className="flex flex-wrap gap-3 items-center">
          <Select value={statusFilter} onValueChange={(v) => { setStatusFilter(v); setCurrentPage(1); }}>
            <SelectTrigger className="w-36"><SelectValue placeholder="Status" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Statuses</SelectItem>
              <SelectItem value="open">Open</SelectItem>
              <SelectItem value="resolved">Resolved</SelectItem>
              <SelectItem value="escalated">Escalated</SelectItem>
            </SelectContent>
          </Select>
          <Select value={typeFilter} onValueChange={(v) => { setTypeFilter(v); setCurrentPage(1); }}>
            <SelectTrigger className="w-48"><SelectValue placeholder="Exception Type" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Types</SelectItem>
              <SelectItem value="bin_inaccessible">Bin Inaccessible</SelectItem>
              <SelectItem value="bin_damaged">Bin Damaged</SelectItem>
              <SelectItem value="hazardous_material">Hazardous Material</SelectItem>
            </SelectContent>
          </Select>
          <span className="text-sm text-muted-foreground ml-auto">{filtered.length} records</span>
        </div>

        {/* Table */}
        <Card>
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date / Time</TableHead>
                  <TableHead>Worker</TableHead>
                  <TableHead>Bin ID</TableHead>
                  <TableHead>Area</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Note</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {loading ? (
                  <TableRow><TableCell colSpan={8} className="text-center py-8 text-muted-foreground">Loading…</TableCell></TableRow>
                ) : paginated.length === 0 ? (
                  <TableRow><TableCell colSpan={8} className="text-center py-8 text-muted-foreground">No exceptions found</TableCell></TableRow>
                ) : paginated.map((ex) => (
                  <TableRow key={ex.exceptionId} className={ex.status !== "open" ? "opacity-60" : ""}>
                    <TableCell className="text-xs text-muted-foreground whitespace-nowrap">{fmt(ex.createdAt)}</TableCell>
                    <TableCell className="font-medium">{ex.workerName}</TableCell>
                    <TableCell className="text-xs font-mono text-muted-foreground">{ex.binId.slice(0, 16)}</TableCell>
                    <TableCell>{ex.area}</TableCell>
                    <TableCell>
                      <Badge variant="outline" className="bg-warning/10 text-warning border-warning/30 whitespace-nowrap">
                        {typeIcon(ex.exceptionType)}{typeLabel(ex.exceptionType)}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground max-w-[140px] truncate">{ex.exceptionNote || "—"}</TableCell>
                    <TableCell>
                      {ex.status === "open"      && <Badge className="bg-destructive/20 text-destructive border-destructive/30">Open</Badge>}
                      {ex.status === "resolved"  && <Badge className="bg-success/20 text-success border-success/30"><CheckCircle className="w-3 h-3 mr-1 inline" />Resolved</Badge>}
                      {ex.status === "escalated" && <Badge className="bg-warning/20 text-warning border-warning/30"><ArrowUpCircle className="w-3 h-3 mr-1 inline" />Escalated</Badge>}
                    </TableCell>
                    <TableCell className="text-right">
                      {ex.status === "open" && (
                        <div className="flex gap-2 justify-end">
                          <Button size="sm" variant="outline"
                            disabled={resolving === ex.exceptionId}
                            onClick={() => patchException(ex.exceptionId, "resolved")}
                            className="text-success border-success/40 hover:bg-success/10">
                            <CheckCircle className="w-3 h-3 mr-1" /> Resolve
                          </Button>
                          <Button size="sm" variant="outline"
                            disabled={resolving === ex.exceptionId}
                            onClick={() => patchException(ex.exceptionId, "escalated")}
                            className="text-warning border-warning/40 hover:bg-warning/10">
                            <ArrowUpCircle className="w-3 h-3 mr-1" /> Escalate
                          </Button>
                        </div>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          {totalPages > 1 && (
            <div className="flex items-center justify-between px-4 py-3 border-t border-border/50">
              <span className="text-xs text-muted-foreground">Page {currentPage} of {totalPages}</span>
              <div className="flex gap-2">
                <Button size="sm" variant="outline" disabled={currentPage === 1} onClick={() => setCurrentPage((p) => p - 1)}>Prev</Button>
                <Button size="sm" variant="outline" disabled={currentPage === totalPages} onClick={() => setCurrentPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
