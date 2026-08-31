import { Navigate, Outlet } from "react-router-dom";
import { signOut } from "firebase/auth";
import { useAuth } from "@/context/AuthContext";
import { auth } from "@/firebase";

export function ProtectedRoute() {
  const { currentUser, isAdmin, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center bg-background">
        <div className="h-10 w-10 animate-spin rounded-full border-4 border-accent border-t-transparent" />
      </div>
    );
  }

  // Not logged in → redirect to login
  if (!currentUser) {
    return <Navigate to="/login" replace />;
  }

  // Logged in but NOT an admin → sign them out and redirect to login
  if (!isAdmin) {
    signOut(auth);
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
}
