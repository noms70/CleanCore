import { useEffect, useState } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { collection, onSnapshot } from "firebase/firestore";
import { db } from "@/firebase";

interface DayData {
  date: string;
  avgFill: number;
}

export function FillEfficiencyChart() {
  const [data, setData] = useState<DayData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, "pickupLogs"),
      (snap) => {
        // Accumulate fill totals per calendar day
        const byDate = new Map<string, { sum: number; count: number; ts: number }>();
        snap.docs.forEach((d) => {
          const r = d.data();
          const ts = r.completedAt;
          if (!ts) return;
          const date: Date = ts.toDate ? ts.toDate() : new Date(ts.seconds * 1000);
          const key = date.toLocaleDateString("en-GB", {
            day: "2-digit",
            month: "2-digit",
          });
          const fill = r.fillLevelAtPickup ?? 0;
          const entry = byDate.get(key) ?? { sum: 0, count: 0, ts: date.getTime() };
          entry.sum += fill;
          entry.count++;
          byDate.set(key, entry);
        });

        // Sort chronologically and take last 14 days
        const sorted = Array.from(byDate.entries())
          .sort((a, b) => a[1].ts - b[1].ts)
          .slice(-14)
          .map(([date, { sum, count }]) => ({
            date,
            avgFill: Math.round(sum / count),
          }));

        setData(sorted);
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const avg = data.length
    ? Math.round(data.reduce((s, d) => s + d.avgFill, 0) / data.length)
    : 0;

  return (
    <div
      className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10"
      style={{ animationDelay: "350ms" }}
    >
      <div className="mb-4 flex items-start justify-between gap-2">
        <div>
          <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
            Fill Efficiency
          </h3>
          <p className="text-sm text-muted-foreground">
            Avg fill level at pickup — last 14 days
          </p>
        </div>
        {!loading && data.length > 0 && (
          <div className="text-right shrink-0">
            <p
              className={`text-xl font-bold ${
                avg >= 85 ? "text-destructive" : avg >= 70 ? "text-warning" : "text-success"
              }`}
            >
              {avg}%
            </p>
            <p className="text-xs text-muted-foreground">14-day avg</p>
          </div>
        )}
      </div>

      {loading ? (
        <div className="h-[220px] flex items-center justify-center text-muted-foreground text-sm">
          Loading…
        </div>
      ) : data.length === 0 ? (
        <div className="h-[220px] flex items-center justify-center text-muted-foreground text-sm">
          No data yet — complete pickups to see efficiency trend
        </div>
      ) : (
        <div className="h-[220px]">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 4, right: 4, left: -16, bottom: 0 }}>
              <defs>
                <linearGradient id="fillEffGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="hsl(262, 83%, 65%)" stopOpacity={0.4} />
                  <stop offset="95%" stopColor="hsl(262, 83%, 65%)" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(222 30% 25%)" />
              <XAxis
                dataKey="date"
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 11 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
              />
              <YAxis
                domain={[0, 100]}
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 11 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
                tickFormatter={(v) => `${v}%`}
              />
              <ReferenceLine
                y={70}
                stroke="hsl(38, 92%, 55%)"
                strokeDasharray="4 3"
                label={{ value: "70% threshold", fill: "hsl(38, 92%, 55%)", fontSize: 10, position: "insideTopRight" }}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(222 47% 14%)",
                  border: "1px solid hsl(222 30% 25%)",
                  borderRadius: "8px",
                  color: "hsl(180 100% 95%)",
                }}
                formatter={(v: number) => [`${v}%`, "Avg Fill at Pickup"]}
              />
              <Area
                type="monotone"
                dataKey="avgFill"
                stroke="hsl(262, 83%, 65%)"
                strokeWidth={2}
                fill="url(#fillEffGrad)"
                dot={{ r: 3, fill: "hsl(262, 83%, 65%)" }}
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
      {!loading && data.length > 0 && (
        <p className="mt-3 text-xs text-muted-foreground">
          Ideal range: <span className="text-warning font-medium">70–90%</span>. Below 70% = collecting too early; above 90% = collecting too late.
        </p>
      )}
    </div>
  );
}
