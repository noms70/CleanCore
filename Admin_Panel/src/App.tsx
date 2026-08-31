import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AdminLayout } from "@/components/admin/AdminLayout";
import { AuthProvider } from "@/context/AuthContext";
import { ProtectedRoute } from "@/components/ProtectedRoute";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import Dashboard from "@/pages/admin/Dashboard";
import Bins from "@/pages/admin/Bins";
import Reports from "@/pages/admin/Reports";
import Users from "@/pages/admin/Users";
import Settings from "@/pages/admin/Settings";
import Collections from "@/pages/admin/Collections";
import AdminRoutes from "@/pages/admin/Routes";
import EditProfile from "@/pages/admin/EditProfile";
import Exceptions from "@/pages/admin/Exceptions";
import Shifts from "@/pages/admin/Shifts";
import Login from "@/pages/Login";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <ErrorBoundary>
        <AuthProvider>
          <Routes>
            <Route path="/" element={<Navigate to="/admin" replace />} />
            <Route path="/login" element={<Login />} />
            <Route element={<ProtectedRoute />}>
              <Route path="/admin" element={<AdminLayout />}>
                <Route index element={<Dashboard />} />
                <Route path="bins" element={<Bins />} />
                <Route path="reports" element={<Reports />} />
                <Route path="users" element={<Users />} />
                <Route path="settings" element={<Settings />} />
                <Route path="collections" element={<Collections />} />
                <Route path="routes" element={<AdminRoutes />} />
                <Route path="profile" element={<EditProfile />} />
                <Route path="exceptions" element={<Exceptions />} />
                <Route path="shifts" element={<Shifts />} />
              </Route>
            </Route>
            <Route path="*" element={<NotFound />} />
          </Routes>
        </AuthProvider>
        </ErrorBoundary>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
