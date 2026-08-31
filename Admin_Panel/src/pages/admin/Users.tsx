import { useState, useEffect } from "react";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { db } from "@/firebase";
import {
  collection,
  onSnapshot,
  addDoc,
  serverTimestamp,
  query,
  where,
  doc,
  deleteDoc,
  updateDoc,
} from "firebase/firestore";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Search,
  Plus,
  Shield,
  Users,
  UserCheck,
  Clock,
  Mail,
  Phone,
  ChevronLeft,
  ChevronRight,
  Trash2,
  Eye,
  EyeOff,
  Pencil,
  KeyRound,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { toast } from "sonner";

const WASTE_TYPES = ["Bio", "Paper", "Plastic", "Glass", "Metal", "Mixed"];

const BACKEND = import.meta.env.VITE_BACKEND_URL ?? "";

interface AppUser {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: "admin" | "manager" | "worker";
  status: "active" | "inactive";
  isOnline: boolean;
  collections: number;
  routes: number;
  lastActive: string;
  assignedArea?: string;
  assignedWasteType?: string;
}

export default function UsersPage() {
  const [users, setUsers] = useState<AppUser[]>([]);
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<AppUser | null>(null);
  const [deleting, setDeleting] = useState(false);

  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");

  const [currentPage, setCurrentPage] = useState(1);
  const ITEMS_PER_PAGE = 10;

  const [pickupCounts, setPickupCounts] = useState<Record<string, number>>({});
  const [routeCounts, setRouteCounts] = useState<Record<string, number>>({});

  const [isEditDialogOpen, setIsEditDialogOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<AppUser | null>(null);
  const [editSaving, setEditSaving] = useState(false);
  const [showEditPassword, setShowEditPassword] = useState(false);
  const [pendingResetRequestId, setPendingResetRequestId] = useState<string | null>(null);
  const [resetRequests, setResetRequests] = useState<{ id: string; email: string }[]>([]);

  const [editFormData, setEditFormData] = useState({
    firstName: "",
    lastName: "",
    phone: "",
    role: "worker",
    assignedArea: "",
    assignedWasteType: "",
    password: "",
  });

  const [formData, setFormData] = useState({
    firstName: "",
    lastName: "",
    email: "",
    password: "",
    phone: "",
    role: "worker",
    assignedArea: "",
    assignedWasteType: "",
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleRoleChange = (value: string) => {
    setFormData({ ...formData, role: value });
  };

  const resetForm = () => {
    setFormData({
      firstName: "",
      lastName: "",
      email: "",
      password: "",
      phone: "",
      role: "worker",
      assignedArea: "",
      assignedWasteType: "",
    });
    setShowPassword(false);
  };

  // Users listener
  useEffect(() => {
    const usersRef = collection(db, "users");
    const unsubscribe = onSnapshot(
      usersRef,
      (snapshot) => {
        const usersData: AppUser[] = snapshot.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            name:
              (
                (data.firstName || "") +
                " " +
                (data.lastName || "")
              ).trim() || "Unknown",
            email: data.email || "",
            phone: data.phoneNumber || data.phone || "",
            role: (data.role as AppUser["role"]) || "worker",
            status: (data.status as AppUser["status"]) || "inactive",
            isOnline: data.isOnline === true,
            collections: data.collections || 0,
            routes: data.routes || 0,
            lastActive:
              data.lastActiveAt?.toDate?.()?.toLocaleString() ||
              data.createdAt?.toDate?.()?.toLocaleString() ||
              "N/A",
            assignedArea: data.assignedArea || "",
            assignedWasteType: data.assignedWasteType || "",
          };
        });
        setUsers(usersData);
      },
      (error) => {
        toast.error("Failed to load users: " + error.message);
      }
    );
    return () => unsubscribe();
  }, []);

  // pickupLogs listener → count per workerId
  useEffect(() => {
    const unsub = onSnapshot(collection(db, "pickupLogs"), (snap) => {
      const counts: Record<string, number> = {};
      snap.docs.forEach((d) => {
        const wid = d.data().workerId as string | undefined;
        if (wid) counts[wid] = (counts[wid] ?? 0) + 1;
      });
      setPickupCounts(counts);
    });
    return () => unsub();
  }, []);

  // routes listener → count completed per workerId
  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, "routes"), where("status", "==", "completed")),
      (snap) => {
        const counts: Record<string, number> = {};
        snap.docs.forEach((d) => {
          const wid = (d.data().workerId ?? d.data().driverId ?? "") as string;
          if (wid) counts[wid] = (counts[wid] ?? 0) + 1;
        });
        setRouteCounts(counts);
      }
    );
    return () => unsub();
  }, []);

  // Password-reset request listener
  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, "passwordResetRequests"), where("status", "==", "pending")),
      (snap) => {
        setResetRequests(
          snap.docs.map((d) => ({ id: d.id, email: d.data().email as string }))
        );
      },
      () => {}
    );
    return () => unsub();
  }, []);

  const handleOpenEdit = (user: AppUser, resetRequestId?: string) => {
    setEditTarget(user);
    setEditFormData({
      firstName: user.name.split(" ")[0] ?? "",
      lastName: user.name.split(" ").slice(1).join(" ") ?? "",
      phone: user.phone,
      role: user.role,
      assignedArea: user.assignedArea ?? "",
      assignedWasteType: user.assignedWasteType ?? "",
      password: "",
    });
    setShowEditPassword(false);
    setPendingResetRequestId(resetRequestId ?? null);
    setIsEditDialogOpen(true);
  };

  const handleUpdateUser = async () => {
    if (!editTarget) return;
    if (editFormData.password && editFormData.password.length < 6) {
      toast.error("Password must be at least 6 characters");
      return;
    }
    if (editFormData.role === "worker" && editFormData.assignedArea.trim()) {
      const areaNorm = editFormData.assignedArea.trim().toLowerCase();
      const conflict = users.find(
        (u) =>
          u.id !== editTarget.id &&
          u.role === "worker" &&
          u.assignedArea?.trim().toLowerCase() === areaNorm
      );
      if (conflict) {
        toast.error(`"${editFormData.assignedArea.trim()}" is already assigned to ${conflict.name}.`);
        return;
      }
    }
    setEditSaving(true);
    try {
      const body: Record<string, string> = {
        first_name: editFormData.firstName.trim(),
        last_name: editFormData.lastName.trim(),
        phone: editFormData.phone.trim(),
        role: editFormData.role,
        assigned_area: editFormData.role === "worker" ? editFormData.assignedArea.trim() : "",
        assigned_waste_type: editFormData.role === "worker" ? editFormData.assignedWasteType : "",
      };
      if (editFormData.password) body.password = editFormData.password;
      const res = await fetch(`${BACKEND}/admin/update-user/${editTarget.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "ngrok-skip-browser-warning": "true" },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        let detail = `HTTP ${res.status}`;
        try { const e = await res.json(); detail = e.detail ?? e.message ?? detail; } catch { /* */ }
        throw new Error(detail);
      }
      if (pendingResetRequestId) {
        await updateDoc(doc(db, "passwordResetRequests", pendingResetRequestId), { status: "resolved" });
      }
      toast.success("User updated");
      writeActivity("Updated user", editTarget);
      setIsEditDialogOpen(false);
      setEditTarget(null);
      setPendingResetRequestId(null);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to update user");
    } finally {
      setEditSaving(false);
    }
  };

  const writeActivity = async (action: string, target?: AppUser) => {
    try {
      await addDoc(collection(db, "activityLogs"), {
        message:
          action + (target ? ` — ${target.name} (${target.email})` : ""),
        type: "info",
        userName: "Admin",
        createdAt: serverTimestamp(),
      });
    } catch {
      // Non-fatal; primary mutation already succeeded
    }
  };

  const handleDeleteUser = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      // Try backend first (deletes from Auth + Firestore)
      const res = await fetch(`${BACKEND}/admin/delete-user/${deleteTarget.id}`, {
        method: "DELETE",
        headers: { "ngrok-skip-browser-warning": "true" },
      }).catch(() => null);
      if (!res || !res.ok) {
        // Fallback: remove Firestore document only
        await deleteDoc(doc(db, "users", deleteTarget.id));
      }
      toast.success(`${deleteTarget.name} deleted`);
      writeActivity("Deleted user", deleteTarget);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to delete user");
    } finally {
      setDeleting(false);
      setDeleteTarget(null);
    }
  };

  const handleAddUser = async () => {
    const email = formData.email.trim().toLowerCase();
    const password = formData.password;

    if (!formData.firstName.trim() || !email) {
      toast.error("First name and email are required");
      return;
    }
    if (!email.endsWith("@gmail.com")) {
      toast.error("Email must be a @gmail.com address (app login only accepts Gmail)");
      return;
    }
    if (!password || password.length < 6) {
      toast.error("Password must be at least 6 characters");
      return;
    }
    if (formData.role === "worker") {
      if (!formData.assignedArea.trim()) {
        toast.error("Worker must have an assigned area");
        return;
      }
      if (!formData.assignedWasteType.trim()) {
        toast.error("Worker must have an assigned waste type");
        return;
      }
      const areaNorm = formData.assignedArea.trim().toLowerCase();
      const conflict = users.find(
        (u) =>
          u.role === "worker" &&
          u.assignedArea?.trim().toLowerCase() === areaNorm
      );
      if (conflict) {
        toast.error(
          `"${formData.assignedArea.trim()}" is already assigned to ${conflict.name}. Each area can only have one worker.`
        );
        return;
      }
    }

    setSaving(true);
    try {
      const res = await fetch(`${BACKEND}/admin/create-user`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "ngrok-skip-browser-warning": "true" },
        body: JSON.stringify({
          email,
          password,
          first_name: formData.firstName.trim(),
          last_name: formData.lastName.trim(),
          phone: formData.phone.trim(),
          role: formData.role,
          assigned_area: formData.role === "worker" ? formData.assignedArea.trim() : "",
          assigned_waste_type: formData.role === "worker" ? formData.assignedWasteType : "",
        }),
      });
      if (!res.ok) {
        let detail = `HTTP ${res.status}`;
        try {
          const errBody = await res.json();
          detail = errBody.detail ?? errBody.message ?? JSON.stringify(errBody);
        } catch { /* non-JSON body — keep status code */ }
        throw new Error(detail);
      }
      toast.success("User created (Auth + Firestore)");
      writeActivity("Created new user", {
        ...formData,
        name: formData.firstName + " " + formData.lastName,
      } as unknown as AppUser);
      setIsAddDialogOpen(false);
      resetForm();
    } catch (error) {
      const msg =
        error instanceof Error ? error.message : "Failed to add user";
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  };

  const filteredUsers = users.filter((u) => {
    const q = search.trim().toLowerCase();
    const matchSearch =
      q === "" ||
      u.name.toLowerCase().includes(q) ||
      u.email.toLowerCase().includes(q) ||
      u.phone.toLowerCase().includes(q);
    const matchRole = roleFilter === "all" || u.role === roleFilter;
    const matchStatus = statusFilter === "all" || u.status === statusFilter;
    return matchSearch && matchRole && matchStatus;
  });

  // Reset to page 1 whenever filters change
  useEffect(() => { setCurrentPage(1); }, [search, roleFilter, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / ITEMS_PER_PAGE));
  const safePage = Math.min(currentPage, totalPages);
  const paginatedUsers = filteredUsers.slice((safePage - 1) * ITEMS_PER_PAGE, safePage * ITEMS_PER_PAGE);

  const totalUsers = users.length;
  const activeWorkers = users.filter(
    (u) => u.role === "worker" && u.isOnline
  ).length;
  const totalWorkers = users.filter((u) => u.role === "worker").length;
  const admins = users.filter((u) => u.role === "admin").length;

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-card/10 to-background">
      <AdminHeader
        title="Manage Users"
        subtitle="Manage workers and administrators"
      />

      <div className="p-6 space-y-6">
        {/* Stats */}
        <div className="grid gap-4 md:grid-cols-4">
          <Card className="bg-card border-border">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <Users className="h-4 w-4" />
                Total Users
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-foreground">{totalUsers}</p>
            </CardContent>
          </Card>
          <Card className="bg-card border-border">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <UserCheck className="h-4 w-4 text-success" />
                Active Workers
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-success">{activeWorkers}</p>
            </CardContent>
          </Card>
          <Card className="bg-card border-border">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <Users className="h-4 w-4 text-primary" />
                Total Workers
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-foreground">{totalWorkers}</p>
            </CardContent>
          </Card>
          <Card className="bg-card border-border">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <Shield className="h-4 w-4 text-warning" />
                Admins
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-foreground">{admins}</p>
            </CardContent>
          </Card>
        </div>

        {/* Tabs */}
        <Tabs defaultValue="users" className="space-y-6">
          <TabsList className="bg-muted/50 border border-border">
            <TabsTrigger
              value="users"
              className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground"
            >
              <Users className="h-4 w-4 mr-2" />
              User Directory
            </TabsTrigger>
            <TabsTrigger
              value="roles"
              className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground"
            >
              <Shield className="h-4 w-4 mr-2" />
              Role Management
            </TabsTrigger>
          </TabsList>

          {/* Users Tab */}
          <TabsContent value="users" className="space-y-4">
            {/* Password-reset request banner */}
            {resetRequests.length > 0 && (
              <div className="rounded-lg border border-warning/40 bg-warning/10 p-3 space-y-2">
                <p className="text-sm font-semibold text-warning flex items-center gap-2">
                  <KeyRound className="h-4 w-4" />
                  Password reset requests ({resetRequests.length})
                </p>
                {resetRequests.map((req) => {
                  const worker = users.find(
                    (u) => u.email.toLowerCase() === req.email.toLowerCase()
                  );
                  return (
                    <div key={req.id} className="flex items-center justify-between text-sm">
                      <span className="text-foreground">{req.email}</span>
                      {worker ? (
                        <Button
                          size="sm"
                          variant="outline"
                          className="h-7 text-xs border-warning/40 text-warning hover:bg-warning/10"
                          onClick={() => handleOpenEdit(worker, req.id)}
                        >
                          Reset Password
                        </Button>
                      ) : (
                        <span className="text-xs text-muted-foreground">User not found</span>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
            {/* Toolbar */}
            <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
              <div className="flex flex-1 items-center gap-4">
                <div className="relative flex-1 max-w-md">
                  <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                  <Input
                    placeholder="Search by name, email, or phone..."
                    className="pl-10 bg-muted/50 border-border"
                    autoComplete="off"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
                <Select value={roleFilter} onValueChange={setRoleFilter}>
                  <SelectTrigger className="w-40 bg-muted/50 border-border">
                    <SelectValue placeholder="Role" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Roles</SelectItem>
                    <SelectItem value="admin">Admin</SelectItem>
                    <SelectItem value="worker">Worker</SelectItem>
                  </SelectContent>
                </Select>
                <Select value={statusFilter} onValueChange={setStatusFilter}>
                  <SelectTrigger className="w-40 bg-muted/50 border-border">
                    <SelectValue placeholder="Status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Status</SelectItem>
                    <SelectItem value="active">Active</SelectItem>
                    <SelectItem value="inactive">Inactive</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <Dialog
                open={isAddDialogOpen}
                onOpenChange={(open) => {
                  setIsAddDialogOpen(open);
                  if (!open) resetForm();
                }}
              >
                <DialogTrigger asChild>
                  <Button
                    size="sm"
                    className="gradient-primary text-primary-foreground"
                    onClick={resetForm}
                  >
                    <Plus className="h-4 w-4 mr-2" />
                    Add User
                  </Button>
                </DialogTrigger>
                <DialogContent className="bg-card border-border sm:max-w-md overflow-y-auto max-h-[90vh]">
                  <DialogHeader>
                    <DialogTitle className="text-foreground">Add New User</DialogTitle>
                    <DialogDescription className="text-muted-foreground">
                      Create a new user account and assign a role
                    </DialogDescription>
                  </DialogHeader>
                  <div className="grid gap-3 py-2">
                    <div className="grid grid-cols-2 gap-3">
                      <div className="grid gap-1.5">
                        <Label className="text-foreground">First Name</Label>
                        <Input
                          name="firstName"
                          value={formData.firstName}
                          onChange={handleInputChange}
                          placeholder="First name"
                          className="bg-muted/50 border-border"
                        />
                      </div>
                      <div className="grid gap-1.5">
                        <Label className="text-foreground">Last Name</Label>
                        <Input
                          name="lastName"
                          value={formData.lastName}
                          onChange={handleInputChange}
                          placeholder="Last name"
                          className="bg-muted/50 border-border"
                        />
                      </div>
                    </div>
                    <div className="grid gap-1.5">
                      <Label className="text-foreground">Email</Label>
                      <Input
                        name="email"
                        type="email"
                        value={formData.email}
                        onChange={handleInputChange}
                        placeholder="Enter Gmail address"
                        className="bg-muted/50 border-border"
                      />
                    </div>
                    <div className="grid gap-1.5">
                      <Label className="text-foreground">Password</Label>
                      <div className="relative">
                        <Input
                          name="password"
                          type={showPassword ? "text" : "password"}
                          value={formData.password}
                          onChange={handleInputChange}
                          placeholder="Min 6 characters"
                          className="bg-muted/50 border-border pr-10"
                        />
                        <button
                          type="button"
                          onClick={() => setShowPassword((v) => !v)}
                          className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                          tabIndex={-1}
                        >
                          {showPassword ? (
                            <EyeOff className="h-4 w-4" />
                          ) : (
                            <Eye className="h-4 w-4" />
                          )}
                        </button>
                      </div>
                    </div>
                    <div className="grid gap-1.5">
                      <Label className="text-foreground">Phone</Label>
                      <Input
                        name="phone"
                        type="tel"
                        value={formData.phone}
                        onChange={handleInputChange}
                        placeholder="Enter phone number"
                        className="bg-muted/50 border-border"
                      />
                    </div>
                    <div className="grid gap-1.5">
                      <Label className="text-foreground">Role</Label>
                      <Select
                        value={formData.role}
                        onValueChange={handleRoleChange}
                      >
                        <SelectTrigger className="bg-muted/50 border-border">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="worker">Worker</SelectItem>
                          <SelectItem value="admin">Admin</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    {formData.role === "worker" && (
                      <>
                        <div className="grid gap-1.5">
                          <Label className="text-foreground">Assigned Area</Label>
                          <Input
                            name="assignedArea"
                            value={formData.assignedArea}
                            onChange={handleInputChange}
                            placeholder="e.g. Wah"
                            className="bg-muted/50 border-border"
                          />
                        </div>
                        <div className="grid gap-1.5">
                          <Label className="text-foreground">Waste Type</Label>
                          <Select
                            value={formData.assignedWasteType}
                            onValueChange={(v) => setFormData({ ...formData, assignedWasteType: v })}
                          >
                            <SelectTrigger className="bg-muted/50 border-border">
                              <SelectValue placeholder="Select waste type…" />
                            </SelectTrigger>
                            <SelectContent>
                              {WASTE_TYPES.map((w) => (
                                <SelectItem key={w} value={w}>{w}</SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                      </>
                    )}
                  </div>
                  <DialogFooter>
                    <Button
                      variant="outline"
                      onClick={() => setIsAddDialogOpen(false)}
                      disabled={saving}
                    >
                      Cancel
                    </Button>
                    <Button
                      className="gradient-primary text-primary-foreground"
                      onClick={handleAddUser}
                      disabled={saving}
                    >
                      {saving ? "Saving..." : "Create User"}
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            </div>

            {/* Users Table */}
            <div className="rounded-xl border border-border bg-card overflow-hidden">
              {filteredUsers.length === 0 ? (
                <div className="p-12 text-center text-muted-foreground">
                  {users.length === 0
                    ? "No users found. Click \"Add User\" to create one."
                    : "No users match the current filters."}
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow className="border-border hover:bg-transparent">
                      <TableHead className="text-muted-foreground">User</TableHead>
                      <TableHead className="text-muted-foreground">Contact</TableHead>
                      <TableHead className="text-muted-foreground">Role</TableHead>
                      <TableHead className="text-muted-foreground">Area / Waste</TableHead>
                      <TableHead className="text-muted-foreground">Status</TableHead>
                      <TableHead className="text-muted-foreground">Collections</TableHead>
                      <TableHead className="text-muted-foreground">Routes</TableHead>
                      <TableHead className="text-muted-foreground">Last Active</TableHead>
                      <TableHead className="text-muted-foreground text-right">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {paginatedUsers.map((user, index) => (
                      <TableRow
                        key={user.id}
                        className="border-border hover:bg-muted/30 animate-fade-in"
                        style={{ animationDelay: `${index * 50}ms` }}
                      >
                        <TableCell>
                          <div className="flex items-center gap-3">
                            <div
                              className={cn(
                                "flex h-10 w-10 items-center justify-center rounded-full text-sm font-medium",
                                user.role === "admin" &&
                                "bg-warning/10 text-warning",
                                user.role === "manager" &&
                                "bg-primary/10 text-primary",
                                user.role === "worker" &&
                                "bg-accent/10 text-accent"
                              )}
                            >
                              {user.name
                                .split(" ")
                                .map((n) => n[0])
                                .join("")
                                .slice(0, 2)
                                .toUpperCase()}
                            </div>
                            <div>
                              <p className="font-medium text-foreground">
                                {user.name}
                              </p>
                              <p className="text-xs text-muted-foreground font-mono">
                                {user.id.slice(0, 8)}
                              </p>
                            </div>
                          </div>
                        </TableCell>
                        <TableCell>
                          <div className="space-y-1">
                            <p className="text-sm text-foreground flex items-center gap-1">
                              <Mail className="h-3 w-3 text-muted-foreground" />
                              {user.email}
                            </p>
                            <p className="text-xs text-muted-foreground flex items-center gap-1">
                              <Phone className="h-3 w-3" />
                              {user.phone || "—"}
                            </p>
                          </div>
                        </TableCell>
                        <TableCell>
                          <Badge
                            className={cn(
                              "capitalize",
                              user.role === "admin" &&
                              "bg-warning/10 text-warning border-warning/30",
                              user.role === "manager" &&
                              "bg-primary/10 text-primary border-primary/30",
                              user.role === "worker" &&
                              "bg-accent/10 text-accent border-accent/30"
                            )}
                          >
                            <Shield className="h-3 w-3 mr-1" />
                            {user.role}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          {user.role === "worker" ? (
                            <div className="space-y-1">
                              {user.assignedArea ? (
                                <Badge className="bg-info/10 text-info border-info/30 text-xs">
                                  {user.assignedArea}
                                </Badge>
                              ) : (
                                <span className="text-xs text-muted-foreground">No area</span>
                              )}
                              {user.assignedWasteType ? (
                                <Badge className="bg-success/10 text-success border-success/30 text-xs ml-1">
                                  {user.assignedWasteType}
                                </Badge>
                              ) : null}
                            </div>
                          ) : (
                            <span className="text-muted-foreground">—</span>
                          )}
                        </TableCell>
                        <TableCell>
                          <Badge
                            className={cn(
                              "capitalize",
                              user.isOnline
                                ? "bg-success/10 text-success border-success/30"
                                : "bg-muted text-muted-foreground border-border"
                            )}
                          >
                            {user.isOnline ? "Online" : "Offline"}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-foreground">
                          {user.role === "worker" ? (pickupCounts[user.id] ?? 0) : "—"}
                        </TableCell>
                        <TableCell className="text-foreground">
                          {user.role === "worker" ? (routeCounts[user.id] ?? 0) : "—"}
                        </TableCell>
                        <TableCell className="text-muted-foreground">
                          <span className="flex items-center gap-1">
                            <Clock className="h-3 w-3" />
                            {user.lastActive}
                          </span>
                        </TableCell>
                        <TableCell className="text-right">
                          <div className="flex items-center justify-end gap-1">
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8 hover:bg-primary/10"
                              title="Edit user"
                              onClick={() => handleOpenEdit(user)}
                            >
                              <Pencil className="h-4 w-4 text-primary" />
                            </Button>
                            {/* Delete — only workers */}
                            {user.role === "worker" && (
                              <Button
                                variant="ghost"
                                size="icon"
                                className="h-8 w-8 hover:bg-destructive/10"
                                title="Delete worker"
                                onClick={() => setDeleteTarget(user)}
                              >
                                <Trash2 className="h-4 w-4 text-destructive" />
                              </Button>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
              {/* Pagination */}
              {filteredUsers.length > ITEMS_PER_PAGE && (
                <div className="flex items-center justify-between px-4 py-3 border-t border-border">
                  <p className="text-sm text-muted-foreground">
                    Showing {(safePage - 1) * ITEMS_PER_PAGE + 1}–{Math.min(safePage * ITEMS_PER_PAGE, filteredUsers.length)} of {filteredUsers.length} users
                  </p>
                  <div className="flex items-center gap-1">
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-8 w-8"
                      disabled={safePage === 1}
                      onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    >
                      <ChevronLeft className="h-4 w-4" />
                    </Button>
                    {Array.from({ length: totalPages }, (_, i) => i + 1)
                      .filter((p) => p === 1 || p === totalPages || Math.abs(p - safePage) <= 1)
                      .reduce<(number | "…")[]>((acc, p, i, arr) => {
                        if (i > 0 && p - (arr[i - 1] as number) > 1) acc.push("…");
                        acc.push(p);
                        return acc;
                      }, [])
                      .map((p, i) =>
                        p === "…" ? (
                          <span key={"ellipsis-" + i} className="px-2 text-muted-foreground text-sm">…</span>
                        ) : (
                          <Button
                            key={p}
                            variant={safePage === p ? "default" : "ghost"}
                            size="icon"
                            className="h-8 w-8 text-sm"
                            onClick={() => setCurrentPage(p as number)}
                          >
                            {p}
                          </Button>
                        )
                      )}
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-8 w-8"
                      disabled={safePage === totalPages}
                      onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                    >
                      <ChevronRight className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              )}
            </div>
          </TabsContent>

          {/* Roles Tab */}
          <TabsContent value="roles">
            <div className="grid gap-6 md:grid-cols-2">
              {[
                {
                  role: "Admin",
                  description:
                    "Full system access including user management, settings, and all reports",
                  count: admins,
                  color: "warning",
                  permissions: [
                    "All access",
                    "User management",
                    "System settings",
                    "Delete data",
                  ],
                },
                {
                  role: "Worker",
                  description:
                    "Mobile app access for route navigation and collection marking",
                  count: totalWorkers,
                  color: "accent",
                  permissions: [
                    "View assigned routes",
                    "Mark collections",
                    "Report anomalies",
                    "View own stats",
                  ],
                },
              ].map((role) => (
                <Card key={role.role} className="bg-card border-border">
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <Badge
                        className={cn(
                          "text-base py-1 px-3",
                          role.color === "warning" &&
                          "bg-warning/10 text-warning border-warning/30",
                          role.color === "accent" &&
                          "bg-accent/10 text-accent border-accent/30"
                        )}
                      >
                        <Shield className="h-4 w-4 mr-2" />
                        {role.role}
                      </Badge>
                      <span className="text-2xl font-bold text-foreground">
                        {role.count}
                      </span>
                    </div>
                    <p className="text-sm text-muted-foreground mt-2">
                      {role.description}
                    </p>
                  </CardHeader>
                  <CardContent>
                    <h4 className="text-sm font-medium text-foreground mb-3">
                      Permissions
                    </h4>
                    <ul className="space-y-2">
                      {role.permissions.map((perm) => (
                        <li
                          key={perm}
                          className="flex items-center gap-2 text-sm text-muted-foreground"
                        >
                          <div
                            className={cn(
                              "h-1.5 w-1.5 rounded-full",
                              role.color === "warning" && "bg-warning",
                              role.color === "accent" && "bg-accent"
                            )}
                          />
                          {perm}
                        </li>
                      ))}
                    </ul>
                  </CardContent>
                </Card>
              ))}
            </div>
          </TabsContent>
        </Tabs>
      </div>

      {/* Edit user dialog */}
      <Dialog open={isEditDialogOpen} onOpenChange={(open) => { if (!open) { setIsEditDialogOpen(false); setEditTarget(null); setPendingResetRequestId(null); } }}>
        <DialogContent className="bg-card border-border sm:max-w-md overflow-y-auto max-h-[90vh]">
          <DialogHeader>
            <DialogTitle className="text-foreground">
              {pendingResetRequestId ? "Reset Password" : "Edit User"}
            </DialogTitle>
            <DialogDescription className="text-muted-foreground">
              {pendingResetRequestId
                ? `Set a new password for ${editTarget?.name ?? editTarget?.email}`
                : `Update details for ${editTarget?.name}`}
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-3 py-2">
            {!pendingResetRequestId && (
              <>
                <div className="grid grid-cols-2 gap-3">
                  <div className="grid gap-1.5">
                    <Label className="text-foreground">First Name</Label>
                    <Input
                      value={editFormData.firstName}
                      onChange={(e) => setEditFormData({ ...editFormData, firstName: e.target.value })}
                      placeholder="First name"
                      className="bg-muted/50 border-border"
                    />
                  </div>
                  <div className="grid gap-1.5">
                    <Label className="text-foreground">Last Name</Label>
                    <Input
                      value={editFormData.lastName}
                      onChange={(e) => setEditFormData({ ...editFormData, lastName: e.target.value })}
                      placeholder="Last name"
                      className="bg-muted/50 border-border"
                    />
                  </div>
                </div>
                <div className="grid gap-1.5">
                  <Label className="text-foreground">Phone</Label>
                  <Input
                    value={editFormData.phone}
                    onChange={(e) => setEditFormData({ ...editFormData, phone: e.target.value })}
                    placeholder="Phone number"
                    className="bg-muted/50 border-border"
                  />
                </div>
                <div className="grid gap-1.5">
                  <Label className="text-foreground">Role</Label>
                  <Select
                    value={editFormData.role}
                    onValueChange={(v) => setEditFormData({ ...editFormData, role: v })}
                  >
                    <SelectTrigger className="bg-muted/50 border-border">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="worker">Worker</SelectItem>
                      <SelectItem value="admin">Admin</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                {editFormData.role === "worker" && (
                  <>
                    <div className="grid gap-1.5">
                      <Label className="text-foreground">Assigned Area</Label>
                      <Input
                        value={editFormData.assignedArea}
                        onChange={(e) => setEditFormData({ ...editFormData, assignedArea: e.target.value })}
                        placeholder="e.g. Wah"
                        className="bg-muted/50 border-border"
                      />
                    </div>
                    <div className="grid gap-1.5">
                      <Label className="text-foreground">Waste Type</Label>
                      <Select
                        value={editFormData.assignedWasteType}
                        onValueChange={(v) => setEditFormData({ ...editFormData, assignedWasteType: v })}
                      >
                        <SelectTrigger className="bg-muted/50 border-border">
                          <SelectValue placeholder="Select waste type…" />
                        </SelectTrigger>
                        <SelectContent>
                          {WASTE_TYPES.map((w) => (
                            <SelectItem key={w} value={w}>{w}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </>
                )}
              </>
            )}
            <div className="grid gap-1.5">
              <Label className="text-foreground">
                {pendingResetRequestId ? "New Password" : "New Password"}
              </Label>
              <div className="relative">
                <Input
                  type={showEditPassword ? "text" : "password"}
                  value={editFormData.password}
                  onChange={(e) => setEditFormData({ ...editFormData, password: e.target.value })}
                  placeholder={pendingResetRequestId ? "Min 6 characters" : "Leave blank to keep current"}
                  className="bg-muted/50 border-border pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowEditPassword((v) => !v)}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                  tabIndex={-1}
                >
                  {showEditPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsEditDialogOpen(false)} disabled={editSaving}>
              Cancel
            </Button>
            <Button
              className="gradient-primary text-primary-foreground"
              onClick={handleUpdateUser}
              disabled={editSaving}
            >
              {editSaving ? "Saving…" : "Save Changes"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirmation dialog */}
      <Dialog open={!!deleteTarget} onOpenChange={(open) => { if (!open) setDeleteTarget(null); }}>
        <DialogContent className="bg-card border-border">
          <DialogHeader>
            <DialogTitle className="text-foreground">Delete Worker</DialogTitle>
            <DialogDescription className="text-muted-foreground">
              Are you sure you want to delete{" "}
              <span className="font-medium text-foreground">{deleteTarget?.name}</span>?
              This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)} disabled={deleting}>
              Cancel
            </Button>
            <Button
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              onClick={handleDeleteUser}
              disabled={deleting}
            >
              {deleting ? "Deleting…" : "Delete"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
