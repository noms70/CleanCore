import { useEffect, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { collection, onSnapshot } from "firebase/firestore";
import { db } from "@/firebase";

interface HourData {
  hour: string;
  collections: number;
}

export function PeakHoursChart() {
  const [data, setData] = useState<HourData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, "pickupLogs"),
      (snap) => {
        const counts = new Array(24).fill(0);
        snap.docs.forEach((d) => {
          const ts = d.data().completedAt;
          if (!ts) return;
          const date = ts.toDate ? ts.toDate() : new Date(ts.seconds * 1000);
          counts[date.getHours()]++;
        });
        setData(
          counts.map((c, h) => ({
            hour: `${h.toString().padStart(2, "0")}:00`,
            collections: c,
          }))
        );
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const maxVal = Math.max(...data.map((d) => d.collections), 1);

  return (
    <div
      className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10"
      style={{ animationDelay: "250ms" }}
    >
      <div className="mb-6">
        <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
          Peak Collection Hours
        </h3>
        <p className="text-sm text-muted-foreground">Pickups by hour of day — last 30 days</p>
      </div>

      {loading ? (
        <div className="h-[240px] flex items-center justify-center text-muted-foreground text-sm">
          Loading…
        </div>
      ) : data.every((d) => d.collections === 0) ? (
        <div className="h-[240px] flex items-center justify-center text-muted-foreground text-sm">
          No data yet — complete pickups to see peak hours
        </div>
      ) : (
        <div className="h-[240px]">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} margin={{ top: 4, right: 4, left: -16, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(222 30% 25%)" vertical={false} />
              <XAxis
                dataKey="hour"
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 10 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
                interval={2}
              />
              <YAxis
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 11 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
                allowDecimals={false}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(222 47% 14%)",
                  border: "1px solid hsl(222 30% 25%)",
                  borderRadius: "8px",
                  color: "hsl(180 100% 95%)",
                }}
                formatter={(v: number) => [v, "Pickups"]}
              />
              <Bar dataKey="collections" radius={[4, 4, 0, 0]} fill="hsl(190, 95%, 55%)" />
              <defs>
                <linearGradient id="peakGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="hsl(190, 95%, 65%)" />
                  <stop offset="100%" stopColor="hsl(190, 70%, 40%)" />
                </linearGradient>
              </defs>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
      {!loading && !data.every((d) => d.collections === 0) && (
        <p className="mt-3 text-xs text-muted-foreground text-center">
          Peak hour:{" "}
          <span className="font-semibold text-accent">
            {data.reduce((a, b) => (a.collections >= b.collections ? a : b)).hour}
          </span>{" "}
          · {maxVal} pickup{maxVal !== 1 ? "s" : ""}
        </p>
      )}
    </div>
  );
}
