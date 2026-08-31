import { useState } from "react";
import { NavLink, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  Trash2,
  FileText,
  Users,
  Settings,
  PackageCheck,
  MapPinned,
  ChevronLeft,
  ChevronRight,
  AlertCircle,
  Clock,
} from "lucide-react";
import { cn } from "@/lib/utils";

const menuItems = [
  { title: "Dashboard",       icon: LayoutDashboard, path: "/admin" },
  { title: "Manage Bins",     icon: Trash2,          path: "/admin/bins" },
  { title: "View Reports",    icon: FileText,         path: "/admin/reports" },
  { title: "Manage Users",    icon: Users,            path: "/admin/users" },
  { title: "Collections",     icon: PackageCheck,     path: "/admin/collections" },
  { title: "Routes",          icon: MapPinned,        path: "/admin/routes" },
  { title: "Exceptions",      icon: AlertCircle,      path: "/admin/exceptions" },
  { title: "Shifts",          icon: Clock,            path: "/admin/shifts" },
  { title: "Settings",        icon: Settings,         path: "/admin/settings" },
];

export function AdminSidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const location  = useLocation();
  return (
    <aside
      className={cn(
        "fixed left-0 top-0 z-40 h-screen flex flex-col bg-sidebar border-r border-sidebar-border transition-all duration-300 ease-in-out",
        collapsed ? "w-20" : "w-64"
      )}
    >
      {/* ── Logo ────────────────────────────────────────────── */}
      <div className="flex h-20 shrink-0 items-center justify-between px-4 border-b border-sidebar-border bg-gradient-to-r from-primary/20 via-accent/10 to-transparent">
        <div className={cn("flex items-center gap-3", collapsed && "justify-center w-full")}>
          <div
            className={cn(
              "shrink-0 overflow-hidden",
              collapsed ? "h-9 w-9" : "h-12 w-12"
            )}
          >
            <img src={`${import.meta.env.BASE_URL}logo.png`} alt="Clean Core" className="w-full h-full object-contain" />
          </div>
          {!collapsed && (
            <div className="animate-fade-in overflow-hidden">
              <h1 className="text-lg font-bold bg-gradient-to-r from-accent via-primary to-accent bg-clip-text text-transparent whitespace-nowrap">
                Clean Core
              </h1>
              <p className="text-xs text-muted-foreground">Admin Panel</p>
            </div>
          )}
        </div>
      </div>

      {/* ── Navigation ──────────────────────────────────────── */}
      <nav className="flex-1 overflow-y-auto px-3 py-5 space-y-1">
        {menuItems.map((item, index) => {
          const isActive =
            item.path === "/admin"
              ? location.pathname === "/admin"
              : location.pathname.startsWith(item.path);

          return (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === "/admin"}
              className={cn(
                "flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 group relative overflow-hidden",
                isActive
                  ? "bg-gradient-to-r from-primary/25 to-accent/15 text-primary border border-primary/35 shadow-lg shadow-primary/20"
                  : "text-muted-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground hover:shadow-md hover:shadow-primary/10",
                collapsed && "justify-center px-3"
              )}
              style={{ animationDelay: `${index * 50}ms` }}
            >
              {/* Active glow orb */}
              {isActive && (
                <span className="absolute inset-0 bg-gradient-to-r from-primary/10 to-accent/5 rounded-xl" />
              )}
              <item.icon
                className={cn(
                  "h-5 w-5 shrink-0 transition-transform duration-200 relative z-10",
                  isActive
                    ? "text-primary drop-shadow-[0_0_8px_rgba(11,191,201,0.7)]"
                    : "group-hover:scale-110"
                )}
              />
              {!collapsed && (
                <span className="font-medium animate-fade-in relative z-10 truncate">
                  {item.title}
                </span>
              )}
            </NavLink>
          );
        })}
      </nav>

      {/* ── Collapse toggle ─────────────────────────────────── */}
      <button
        onClick={() => setCollapsed(!collapsed)}
        className="absolute -right-3 top-24 flex h-6 w-6 items-center justify-center rounded-full bg-gradient-to-br from-primary to-accent text-primary-foreground shadow-xl shadow-primary/50 hover:scale-110 hover:shadow-2xl hover:shadow-primary/60 transition-all z-50"
      >
        {collapsed ? (
          <ChevronRight className="h-3.5 w-3.5" />
        ) : (
          <ChevronLeft className="h-3.5 w-3.5" />
        )}
      </button>

    </aside>
  );
}
