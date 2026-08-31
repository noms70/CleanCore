import { useState, useEffect } from "react";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Save } from "lucide-react";
import { db } from "@/firebase";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { useAuth } from "@/context/AuthContext";
import { toast } from "sonner";

export default function EditProfile() {
  const { currentUser } = useAuth();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const [form, setForm] = useState({
    firstName: "",
    lastName: "",
    phone: "",
    profilePicture: "",
  });

  const [readOnly, setReadOnly] = useState({
    email: "",
    role: "",
    status: "",
    uid: "",
  });

  useEffect(() => {
    if (!currentUser) return;
    getDoc(doc(db, "users", currentUser.uid))
      .then((snap) => {
        if (snap.exists()) {
          const d = snap.data();
          setForm({
            firstName: d.firstName ?? "",
            lastName: d.lastName ?? "",
            phone: d.phoneNumber ?? d.phone ?? "",
            profilePicture: d.profilePicture ?? "",
          });
          setReadOnly({
            email: d.email ?? currentUser.email ?? "",
            role: d.role ?? "admin",
            status: d.status ?? "active",
            uid: currentUser.uid,
          });
        } else {
          setReadOnly((r) => ({ ...r, email: currentUser.email ?? "", uid: currentUser.uid }));
        }
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [currentUser]);

  const handleSave = async () => {
    if (!currentUser) return;
    setSaving(true);
    try {
      await setDoc(
        doc(db, "users", currentUser.uid),
        {
          firstName: form.firstName.trim(),
          lastName: form.lastName.trim(),
          phoneNumber: form.phone.trim(),
          profilePicture: form.profilePicture.trim(),
        },
        { merge: true }
      );
      toast.success("Profile updated");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to update profile");
    } finally {
      setSaving(false);
    }
  };

  const initials =
    `${form.firstName.charAt(0)}${form.lastName.charAt(0)}`.toUpperCase() || "A";

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-card/10 to-background">
      <AdminHeader title="Edit Profile" subtitle="Update your account information" />

      <div className="p-6 max-w-2xl mx-auto space-y-6">
        {loading ? (
          <p className="text-muted-foreground text-center py-12">Loading profile…</p>
        ) : (
          <>
            {/* Avatar + summary */}
            <div className="flex items-center gap-6 p-6 rounded-xl border border-border bg-card">
              <div className="h-20 w-20 rounded-full bg-gradient-to-br from-primary to-accent flex items-center justify-center text-primary-foreground text-2xl font-bold shadow-lg overflow-hidden shrink-0">
                {form.profilePicture ? (
                  <img
                    src={form.profilePicture}
                    alt="avatar"
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <span>{initials}</span>
                )}
              </div>
              <div>
                <p className="font-semibold text-foreground text-lg">
                  {form.firstName || form.lastName
                    ? `${form.firstName} ${form.lastName}`.trim()
                    : "—"}
                </p>
                <p className="text-sm text-muted-foreground">{readOnly.email}</p>
                <span className="inline-block mt-1 px-2 py-0.5 rounded-full text-xs font-medium bg-warning/10 text-warning border border-warning/30 capitalize">
                  {readOnly.role}
                </span>
              </div>
            </div>

            {/* Editable fields */}
            <Card className="bg-card border-border">
              <CardHeader>
                <CardTitle className="text-foreground">Personal Information</CardTitle>
                <CardDescription className="text-muted-foreground">
                  Update your display name and contact details
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid gap-4 md:grid-cols-2">
                  <div className="space-y-2">
                    <Label className="text-foreground">First Name</Label>
                    <Input
                      value={form.firstName}
                      onChange={(e) => setForm({ ...form, firstName: e.target.value })}
                      placeholder="First name"
                      className="bg-muted/50 border-border"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label className="text-foreground">Last Name</Label>
                    <Input
                      value={form.lastName}
                      onChange={(e) => setForm({ ...form, lastName: e.target.value })}
                      placeholder="Last name"
                      className="bg-muted/50 border-border"
                    />
                  </div>
                </div>
                <div className="space-y-2">
                  <Label className="text-foreground">Phone Number</Label>
                  <Input
                    value={form.phone}
                    onChange={(e) => setForm({ ...form, phone: e.target.value })}
                    placeholder="+92 3XX XXXXXXX"
                    type="tel"
                    className="bg-muted/50 border-border"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="text-foreground">Profile Picture URL</Label>
                  <Input
                    value={form.profilePicture}
                    onChange={(e) => setForm({ ...form, profilePicture: e.target.value })}
                    placeholder="https://…"
                    className="bg-muted/50 border-border"
                  />
                  <p className="text-xs text-muted-foreground">
                    Enter a publicly accessible image URL. The preview above updates live.
                  </p>
                </div>
              </CardContent>
            </Card>

            {/* Read-only account details */}
            <Card className="bg-card border-border">
              <CardHeader>
                <CardTitle className="text-foreground">Account Details</CardTitle>
                <CardDescription className="text-muted-foreground">
                  Read-only information managed by the system
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid gap-4 md:grid-cols-2">
                  <div className="space-y-2">
                    <Label className="text-muted-foreground">Email</Label>
                    <Input
                      value={readOnly.email}
                      readOnly
                      className="bg-muted/30 border-border text-muted-foreground cursor-not-allowed"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label className="text-muted-foreground">Role</Label>
                    <Input
                      value={readOnly.role}
                      readOnly
                      className="bg-muted/30 border-border text-muted-foreground cursor-not-allowed capitalize"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label className="text-muted-foreground">Status</Label>
                    <Input
                      value={readOnly.status}
                      readOnly
                      className="bg-muted/30 border-border text-muted-foreground cursor-not-allowed capitalize"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label className="text-muted-foreground">User ID</Label>
                    <Input
                      value={readOnly.uid}
                      readOnly
                      className="bg-muted/30 border-border text-muted-foreground cursor-not-allowed font-mono text-xs"
                    />
                  </div>
                </div>
              </CardContent>
            </Card>

            <div className="flex justify-end">
              <Button
                className="gradient-primary text-primary-foreground"
                onClick={handleSave}
                disabled={saving}
              >
                <Save className="h-4 w-4 mr-2" />
                {saving ? "Saving…" : "Save Changes"}
              </Button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
