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
import { collection, onSnapshot, query, where } from "firebase/firestore";
import { db } from "@/firebase";

interface WorkerData {
  name: string;
  collections: number;
}

export function WorkerPerformanceChart() {
  const [data, setData] = useState<WorkerData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const workerNames = new Map<string, string>();
    const workerCounts = new Map<string, number>();

    const buildData = () => {
      const result = Array.from(workerCounts.entries())
        .map(([wid, count]) => ({
          name: workerNames.get(wid) ?? wid.slice(0, 8) + "…",
          collections: count,
        }))
        .sort((a, b) => b.collections - a.collections)
        .slice(0, 5);
      setData(result);
      setLoading(false);
    };

    const unsubUsers = onSnapshot(
      query(collection(db, "users"), where("role", "==", "worker")),
      (snap) => {
        workerNames.clear();
        snap.docs.forEach((d) => {
          const raw = d.data();
          const firstName = raw.firstName || "";
          const lastName = raw.lastName || "";
          const lastInitial = lastName ? lastName[0] + "." : "";
          workerNames.set(d.id, `${firstName} ${lastInitial}`.trim() || "Worker");
        });
        buildData();
      }
    );

    const unsubLogs = onSnapshot(
      collection(db, "pickupLogs"),
      (snap) => {
        workerCounts.clear();
        snap.docs.forEach((d) => {
          const wid = d.data().workerId;
          if (!wid) return;
          workerCounts.set(wid, (workerCounts.get(wid) ?? 0) + 1);
        });
        buildData();
      },
      () => setLoading(false)
    );

    return () => {
      unsubUsers();
      unsubLogs();
    };
  }, []);

  return (
    <div
      className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10"
      style={{ animationDelay: "400ms" }}
    >
      <div className="mb-6">
        <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent">
          Top Workers
        </h3>
        <p className="text-sm text-muted-foreground">Collections by worker (live)</p>
      </div>

      {loading ? (
        <div className="h-[250px] flex items-center justify-center text-muted-foreground text-sm">
          Loading...
        </div>
      ) : data.length === 0 ? (
        <div className="h-[250px] flex items-center justify-center text-muted-foreground text-sm">
          No worker data available
        </div>
      ) : (
        <div className="h-[250px]">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data} layout="vertical">
              <CartesianGrid
                strokeDasharray="3 3"
                stroke="hsl(222 30% 25%)"
                horizontal={false}
              />
              <XAxis
                type="number"
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 12 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
                allowDecimals={false}
              />
              <YAxis
                type="category"
                dataKey="name"
                stroke="hsl(215 20% 65%)"
                tick={{ fill: "hsl(215 20% 65%)", fontSize: 12 }}
                axisLine={{ stroke: "hsl(222 30% 25%)" }}
                width={80}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(245, 40%, 12%)",
                  border: "1px solid hsl(190, 50%, 40%)",
                  borderRadius: "12px",
                  color: "hsl(240, 10%, 95%)",
                  boxShadow: "0 8px 32px rgba(34, 211, 238, 0.3)",
                }}
                formatter={(value: number) => [value, "Collections"]}
              />
              <Bar
                dataKey="collections"
                fill="url(#barGradient)"
                radius={[0, 4, 4, 0]}
              />
              <defs>
                <linearGradient id="barGradient" x1="0" y1="0" x2="1" y2="0">
                  <stop offset="0%" stopColor="hsl(190, 95%, 55%)" />
                  <stop offset="100%" stopColor="hsl(262, 83%, 65%)" />
                </linearGradient>
              </defs>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}
