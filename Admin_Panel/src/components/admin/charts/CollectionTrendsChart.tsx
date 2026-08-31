import { useEffect, useState } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { collection, onSnapshot, query, where, Timestamp } from "firebase/firestore";
import { db } from "@/firebase";

const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

interface DayData {
  day: string;
  collections: number;
}

export function CollectionTrendsChart() {
  const [data, setData] = useState<DayData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Build last-7-days skeleton (oldest first)
    const days: DayData[] = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      days.push({ day: DAY_NAMES[d.getDay()], collections: 0 });
    }

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
    sevenDaysAgo.setHours(0, 0, 0, 0);

    const q = query(
      collection(db, "pickupLogs"),
      where("completedAt", ">=", Timestamp.fromDate(sevenDaysAgo))
    );

    const unsub = onSnapshot(
      q,
      (snap) => {
        const counts: Record<string, number> = {};
        snap.docs.forEach((d) => {
          const raw = d.data();
          const date = raw.completedAt?.toDate?.();
          if (date) {
            const dayName = DAY_NAMES[date.getDay()];
            counts[dayName] = (counts[dayName] || 0) + 1;
          }
        });
        const updated = days.map((d) => ({
          ...d,
          collections: counts[d.day] || 0,
        }));
        setData(updated);
        setLoading(false);
      },
      () => {
        // collections collection may not exist — show all zeros
        setData(days);
        setLoading(false);
      }
    );

    return () => unsub();
  }, []);

  return (
    <div
      className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10"
      style={{ animationDelay: "200ms" }}
    >
      <div className="mb-6">
        <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
          Collection Trends
        </h3>
        <p className="text-sm text-muted-foreground">Weekly collections (live)</p>
      </div>

      {loading ? (
        <div className="h-[300px] flex items-center justify-center text-muted-foreground text-sm">
          Loading...
        </div>
      ) : (
        <div className="h-[300px]">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data}>
              <defs>
                <linearGradient id="colorCollections" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="hsl(190, 95%, 55%)" stopOpacity={0.5} />
                  <stop offset="95%" stopColor="hsl(190, 95%, 55%)" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(222 30% 25%)" />
              <XAxis
                dataKey="day"
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 12 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
              />
              <YAxis
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 12 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(222 47% 14%)",
                  border: "1px solid hsl(222 30% 25%)",
                  borderRadius: "8px",
                  color: "hsl(180 100% 95%)",
                }}
              />
              <Area
                type="monotone"
                dataKey="collections"
                stroke="hsl(180 100% 50%)"
                strokeWidth={2}
                fill="url(#colorCollections)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
      <div className="mt-4 flex items-center justify-center gap-6">
        <div className="flex items-center gap-2">
          <div className="h-3 w-3 rounded-full bg-primary" />
          <span className="text-sm text-muted-foreground">Collections</span>
        </div>
      </div>
    </div>
  );
}
