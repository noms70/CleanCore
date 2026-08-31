import { useState, useEffect, useMemo } from "react";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
import { db } from "@/firebase";
import {
  collection,
  onSnapshot,
  query,
  where,
  orderBy,
  limit,
  deleteDoc,
  doc,
} from "firebase/firestore";
import { Clock, Users, Timer, PackageCheck, CalendarClock, Plus, Trash2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { getAuth } from "firebase/auth";

const BACKEND = import.meta.env.VITE_BACKEND_URL ?? "";

interface ShiftSchedule {
  scheduleId:       string;
  workerId:         string;
  workerName:       string;
  assignedArea:     string;
  scheduledDate:    string;
  startTime:        string;
  endTime:          string;
  note:             string;
  status:           string;
}

interface Shift {
  shiftId:              string;
  workerId:             string;
  workerName:           string;
  assignedArea:         string;
  assignedWasteType:    string;
  clockInTime:          { seconds: number } | null;
  clockOutTime:         { seconds: number } | null;
  totalDurationMinutes: number | null;
  routesCompleted:      number;
  collectionsCompleted: number;
  status:               string;
}

function fmt(ts: { seconds: number } | null): string {
  if (!ts) return "—";
  return new Date(ts.seconds * 1000).toLocaleString("en-GB", {
    day: "2-digit", month: "2-digit",
    hour: "2-digit", minute: "2-digit",
  });
}

function fmtDuration(mins: number | null, clockIn: { seconds: number } | null, status: string): string {
  if (status === "active" && clockIn) {
    const elapsed = Math.floor((Date.now() / 1000 - clockIn.seconds) / 60);
    const h = Math.floor(elapsed / 60), m = elapsed % 60;
    return `${h}h ${m}m (active)`;
  }
  if (mins == null) return "—";
  return `${Math.floor(mins / 60)}h ${mins % 60}m`;
}

export default function Shifts() {
  const { toast } = useToast();
  const today = new Date().toISOString().slice(0, 10);
  const [selectedDate, setSelectedDate] = useState(today);
  const [allShiftsRaw, setAllShiftsRaw] = useState<Shift[]>([]);
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);

  // Schedule tab state
  const [schedules, setSchedules]         = useState<ShiftSchedule[]>([]);
  const [workers, setWorkers]             = useState<Array<{ id: string; name: string; area: string }>>([]);
  const [schedWorker, setSchedWorker]     = useState("");
  const [schedDate, setSchedDate]         = useState(today);
  const [schedStart, setSchedStart]       = useState("08:00");
  const [schedEnd, setSchedEnd]           = useState("16:00");
  const [schedNote, setSchedNote]         = useState("");
  const [scheduling, setScheduling]       = useState(false);
  const [deletingId, setDeletingId]       = useState<string | null>(null);

  // Tick every 60s to refresh "active" elapsed times
  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), 60_000);
    return () => clearInterval(id);
  }, []);

  // Load workers for schedule form
  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, "users"), where("role", "==", "worker")),
      (snap) => setWorkers(snap.docs.map((d) => {
        const r = d.data();
        return {
          id:   d.id,
          name: `${r.firstName ?? ""} ${r.lastName ?? ""}`.trim() || "Unknown",
          area: r.assignedArea ?? "",
        };
      }))
    );
    return () => unsub();
  }, []);

  // Live: upcoming shift schedules
  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, "shiftSchedules"), orderBy("scheduledDate", "desc")),
      (snap) => setSchedules(snap.docs.map((d) => {
        const r = d.data();
        return {
          scheduleId:    d.id,
          workerId:      r.workerId      ?? "",
          workerName:    r.workerName    ?? "—",
          assignedArea:  r.assignedArea  ?? "—",
          scheduledDate: r.scheduledDate ?? "—",
          startTime:     r.startTime     ?? "—",
          endTime:       r.endTime       ?? "—",
          note:          r.note          ?? "",
          status:        r.status        ?? "scheduled",
        };
      }))
    );
    return () => unsub();
  }, []);

  async function handleScheduleShift() {
    if (!schedWorker) { toast({ title: "Select a worker", variant: "destructive" }); return; }
    setScheduling(true);
    try {
      const auth  = getAuth();
      const res   = await fetch(`${BACKEND}/admin/schedule-shift`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "ngrok-skip-browser-warning": "true" },
        body: JSON.stringify({
          worker_id:      schedWorker,
          scheduled_date: schedDate,
          start_time:     schedStart,
          end_time:       schedEnd,
          note:           schedNote,
          created_by:     auth.currentUser?.email ?? "admin",
        }),
      });
      const json = await res.json();
      if (res.ok && json.success) {
        toast({ title: "Shift scheduled — worker notified" });
        setSchedNote("");
      } else {
        toast({ title: json.detail ?? "Failed to schedule", variant: "destructive" });
      }
    } catch {
      toast({ title: "Network error", variant: "destructive" });
    } finally {
      setScheduling(false);
    }
  }

  async function handleDeleteSchedule(id: string) {
    setDeletingId(id);
    try {
      await deleteDoc(doc(db, "shiftSchedules", id));
      toast({ title: "Schedule deleted" });
    } catch {
      toast({ title: "Failed to delete", variant: "destructive" });
    } finally {
      setDeletingId(null);
    }
  }

  // Single listener for ALL shifts — no Firestore range queries, no composite index needed.
  // 200-doc limit is plenty for an FYP; all filtering done client-side.
  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, "shifts"), orderBy("clockInTime", "desc"), limit(200)),
      (snap) => {
        setAllShiftsRaw(snap.docs.map((d) => {
          const r = d.data();
          return {
            shiftId:              d.id,
            workerId:             r.workerId             ?? "",
            workerName:           r.workerName           ?? "—",
            assignedArea:         r.assignedArea         ?? "—",
            assignedWasteType:    r.assignedWasteType    ?? "—",
            clockInTime:          r.clockInTime          ?? null,
            clockOutTime:         r.clockOutTime         ?? null,
            totalDurationMinutes: r.totalDurationMinutes ?? null,
            routesCompleted:      r.routesCompleted      ?? 0,
            collectionsCompleted: r.collectionsCompleted ?? 0,
            status:               (r.status as string)   ?? "",
          } as Shift;
        }));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  // Active shifts — always show regardless of selected date
  const activeShifts = useMemo(
    () => allShiftsRaw.filter((s) => s.status === "active"),
    [allShiftsRaw]
  );

  // Completed shifts for the selected date — filter client-side, no Firestore range needed
  const historicalShifts = useMemo(() => {
    const dayStartSec = new Date(selectedDate + "T00:00:00Z").getTime() / 1000;
    const dayEndSec   = new Date(selectedDate + "T23:59:59Z").getTime() / 1000;
    return allShiftsRaw.filter((s) => {
      if (s.status !== "completed") return false;
      const ts = s.clockInTime?.seconds ?? 0;
      return ts >= dayStartSec && ts <= dayEndSec;
    });
  }, [allShiftsRaw, selectedDate]);

  const allShifts = useMemo(
    // Include active shifts only when viewing today
    () => selectedDate === today
      ? [...activeShifts, ...historicalShifts]
      : historicalShifts,
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [activeShifts, historicalShifts, selectedDate, today, tick]
  );

  // KPI stats
  const totalToday    = allShifts.length;
  const completedOnly = historicalShifts;
  const avgDuration   = completedOnly.length > 0
    ? Math.round(completedOnly.reduce((s, sh) => s + (sh.totalDurationMinutes ?? 0), 0) / completedOnly.length)
    : 0;
  const totalColls    = allShifts.reduce((s, sh) => s + sh.collectionsCompleted, 0);

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-accent/5 to-background">
      <AdminHeader title="Shifts" subtitle="Worker shift tracking and scheduling." />

      <div className="p-6 space-y-6">
        <Tabs defaultValue="tracking">
          <TabsList>
            <TabsTrigger value="tracking"><Clock className="w-4 h-4 mr-2" />Active / History</TabsTrigger>
            <TabsTrigger value="schedule"><CalendarClock className="w-4 h-4 mr-2" />Schedule</TabsTrigger>
          </TabsList>

          {/* ── Tab 1: Clock-in / History ── */}
          <TabsContent value="tracking" className="space-y-6 mt-4">
            {/* Date picker */}
            <div className="flex items-center gap-3">
              <label className="text-sm font-medium text-muted-foreground">Date:</label>
              <Input type="date" value={selectedDate} max={today}
                onChange={(e) => setSelectedDate(e.target.value)} className="w-44" />
              {selectedDate !== today && (
                <Button variant="outline" size="sm" onClick={() => setSelectedDate(today)}>Today</Button>
              )}
            </div>

            {/* KPI strip */}
            <div className="grid gap-4 md:grid-cols-4">
              <Card>
                <CardHeader className="pb-2"><CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2"><Clock className="w-4 h-4 text-success" />Active Now</CardTitle></CardHeader>
                <CardContent><p className="text-3xl font-bold text-success">{activeShifts.length}</p></CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-2"><CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2"><Users className="w-4 h-4 text-primary" />Total Shifts</CardTitle></CardHeader>
                <CardContent><p className="text-3xl font-bold text-foreground">{totalToday}</p></CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-2"><CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2"><Timer className="w-4 h-4 text-accent" />Avg Duration</CardTitle></CardHeader>
                <CardContent><p className="text-3xl font-bold text-foreground">{Math.floor(avgDuration / 60)}h {avgDuration % 60}m</p></CardContent>
              </Card>
              <Card>
                <CardHeader className="pb-2"><CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2"><PackageCheck className="w-4 h-4 text-warning" />Collections</CardTitle></CardHeader>
                <CardContent><p className="text-3xl font-bold text-foreground">{totalColls}</p></CardContent>
              </Card>
            </div>

            {/* Shifts table */}
            <Card>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Worker</TableHead>
                      <TableHead>Area</TableHead>
                      <TableHead>Waste Type</TableHead>
                      <TableHead>Clock In</TableHead>
                      <TableHead>Clock Out</TableHead>
                      <TableHead>Duration</TableHead>
                      <TableHead>Routes</TableHead>
                      <TableHead>Collections</TableHead>
                      <TableHead>Status</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {loading ? (
                      <TableRow><TableCell colSpan={9} className="text-center py-8 text-muted-foreground">Loading…</TableCell></TableRow>
                    ) : allShifts.length === 0 ? (
                      <TableRow><TableCell colSpan={9} className="text-center py-8 text-muted-foreground">No shifts for this date</TableCell></TableRow>
                    ) : allShifts.map((sh) => (
                      <TableRow key={sh.shiftId}>
                        <TableCell className="font-medium">{sh.workerName}</TableCell>
                        <TableCell>{sh.assignedArea}</TableCell>
                        <TableCell className="text-muted-foreground">{sh.assignedWasteType}</TableCell>
                        <TableCell className="text-sm">{fmt(sh.clockInTime)}</TableCell>
                        <TableCell className="text-sm">{fmt(sh.clockOutTime)}</TableCell>
                        <TableCell className="text-sm whitespace-nowrap">{fmtDuration(sh.totalDurationMinutes, sh.clockInTime, sh.status)}</TableCell>
                        <TableCell>{sh.routesCompleted}</TableCell>
                        <TableCell>{sh.collectionsCompleted}</TableCell>
                        <TableCell>
                          {sh.status === "active"
                            ? <Badge className="bg-success/20 text-success border-success/30 animate-pulse"><Clock className="w-3 h-3 mr-1 inline" />Active</Badge>
                            : <Badge variant="outline" className="text-muted-foreground">Completed</Badge>
                          }
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </Card>
          </TabsContent>

          {/* ── Tab 2: Schedule ── */}
          <TabsContent value="schedule" className="space-y-6 mt-4">
            {/* Create schedule form */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Plus className="w-4 h-4 text-primary" /> Schedule a Shift
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid gap-4 md:grid-cols-3 lg:grid-cols-6">
                  <div className="lg:col-span-2 space-y-1">
                    <Label>Worker</Label>
                    <Select value={schedWorker} onValueChange={setSchedWorker}>
                      <SelectTrigger><SelectValue placeholder="Select worker" /></SelectTrigger>
                      <SelectContent>
                        {workers.map((w) => (
                          <SelectItem key={w.id} value={w.id}>{w.name} — {w.area}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-1">
                    <Label>Date</Label>
                    <Input type="date" value={schedDate} onChange={(e) => setSchedDate(e.target.value)} />
                  </div>
                  <div className="space-y-1">
                    <Label>Start Time</Label>
                    <Input type="time" value={schedStart} onChange={(e) => setSchedStart(e.target.value)} />
                  </div>
                  <div className="space-y-1">
                    <Label>End Time</Label>
                    <Input type="time" value={schedEnd} onChange={(e) => setSchedEnd(e.target.value)} />
                  </div>
                  <div className="space-y-1">
                    <Label>Note (optional)</Label>
                    <Input placeholder="e.g. Morning round" value={schedNote}
                      onChange={(e) => setSchedNote(e.target.value)} />
                  </div>
                </div>
                <Button className="mt-4" disabled={!schedWorker || scheduling} onClick={handleScheduleShift}>
                  {scheduling ? "Scheduling…" : <><Plus className="w-4 h-4 mr-2" />Schedule & Notify Worker</>}
                </Button>
              </CardContent>
            </Card>

            {/* Scheduled shifts table */}
            <Card>
              <CardHeader>
                <CardTitle className="text-sm font-medium text-muted-foreground">Upcoming & Recent Schedules</CardTitle>
              </CardHeader>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Date</TableHead>
                      <TableHead>Worker</TableHead>
                      <TableHead>Area</TableHead>
                      <TableHead>Start</TableHead>
                      <TableHead>End</TableHead>
                      <TableHead>Note</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead></TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {schedules.length === 0 ? (
                      <TableRow><TableCell colSpan={8} className="text-center py-8 text-muted-foreground">No schedules yet</TableCell></TableRow>
                    ) : schedules.map((s) => (
                      <TableRow key={s.scheduleId}>
                        <TableCell className="font-mono text-sm">{s.scheduledDate}</TableCell>
                        <TableCell className="font-medium">{s.workerName}</TableCell>
                        <TableCell>{s.assignedArea}</TableCell>
                        <TableCell>{s.startTime}</TableCell>
                        <TableCell>{s.endTime}</TableCell>
                        <TableCell className="text-muted-foreground text-xs">{s.note || "—"}</TableCell>
                        <TableCell>
                          <Badge variant="outline" className={
                            s.status === "completed" ? "text-success border-success/30" :
                            s.status === "missed"    ? "text-destructive border-destructive/30" :
                                                       "text-primary border-primary/30"
                          }>{s.status}</Badge>
                        </TableCell>
                        <TableCell>
                          <Button size="sm" variant="ghost"
                            disabled={deletingId === s.scheduleId}
                            onClick={() => handleDeleteSchedule(s.scheduleId)}
                            className="text-destructive hover:text-destructive hover:bg-destructive/10">
                            <Trash2 className="w-4 h-4" />
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}
