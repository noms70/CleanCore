// src/components/admin/UsersTable.tsx
import { useEffect, useState } from "react";
import { db } from "@/firebase";
import { collection, onSnapshot, query, orderBy } from "firebase/firestore";

interface User {
  id: string;
  name: string;
  email: string;
  role: string;
  status: string;
  lastLogin?: any;
}

const UsersTable = () => {
  const [users, setUsers] = useState<User[]>([]);

  useEffect(() => {
    const q = query(collection(db, "users"), orderBy("createdAt", "desc"));

    const unsubscribe = onSnapshot(q, snapshot => {
      const usersData: User[] = snapshot.docs.map(d => {
        const data = d.data();
        return {
          id: d.id,
          name: `${data.firstName || ""} ${data.lastName || ""}`.trim() || "Unknown",
          email: data.email || "",
          role: data.role || "user",
          status: data.status || "offline",
          lastLogin: data.createdAt?.toDate?.() || null
        };
      });
      setUsers(usersData);
    });

    return () => unsubscribe();
  }, []);

  return (
    <div className="rounded-xl border border-accent/30 bg-gradient-to-br from-card to-card/50 backdrop-blur-sm p-6 animate-fade-in shadow-xl shadow-accent/10">
      <h3 className="text-lg font-semibold bg-gradient-to-r from-accent to-primary bg-clip-text text-transparent mb-4">Users</h3>
      <div className="overflow-x-auto">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="border-b border-border/50 text-sm text-muted-foreground bg-gradient-to-r from-accent/15 via-primary/10 to-accent/15">
              <th className="py-3 px-4 font-semibold">Name</th>
              <th className="py-3 px-4 font-semibold">Email</th>
              <th className="py-3 px-4 font-semibold">Role</th>
              <th className="py-3 px-4 font-semibold">Status</th>
              <th className="py-3 px-4 font-semibold">Last Login</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user, index) => (
              <tr key={user.id} className="border-b border-border/50 hover:bg-gradient-to-r hover:from-accent/8 hover:to-primary/5 transition-all duration-200" style={{ animationDelay: `${index * 50}ms` }}>
                <td className="py-3 px-4 font-medium text-foreground">{user.name}</td>
                <td className="py-3 px-4 text-muted-foreground">{user.email}</td>
                <td className="py-3 px-4">
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-accent/20 text-accent border border-accent/40">
                    {user.role}
                  </span>
                </td>
                <td className="py-3 px-4">
                  <span
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                      user.status === "online" 
                        ? "bg-success/20 text-success border border-success/30" 
                        : "bg-muted text-muted-foreground border border-border/50"
                    }`}
                  >
                    {user.status}
                  </span>
                </td>
                <td className="py-3 px-4 text-sm text-muted-foreground">
                  {user.lastLogin
                    ? user.lastLogin.toLocaleString()
                    : "N/A"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default UsersTable;
