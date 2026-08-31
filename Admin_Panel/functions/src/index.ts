import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

export const getUsers = functions.https.onCall(async (data, context) => {
    // Check authentication if needed (admin only)
    // if (!context.auth) return { error: "Unauthenticated" };

    try {
        const usersSnapshot = await admin.firestore().collection("users").orderBy("lastLogin", "desc").get();
        const users = usersSnapshot.docs.map(doc => {
            const d = doc.data();

            // Formatting similar to frontend to ensure consistency
            // Note: Dates in admin SDK are Firestore Timestamp objects usually
            let lastActiveStr = "Never";
            if (d.lastLogin) {
                // Simplified date handling for backend -> frontend transmission
                // We send the raw timestamp or ISO string and let frontend format it? 
                // Or format here. Let's send ISO string to be safe.
                const date = d.lastLogin.toDate ? d.lastLogin.toDate() : new Date(d.lastLogin);
                lastActiveStr = date.toISOString();
            }

            return {
                id: doc.id,
                firstName: d.firstName || "",
                lastName: d.lastName || "",
                name: `${d.firstName || ""} ${d.lastName || ""}`.trim() || d.name || "Unknown",
                email: d.email || "",
                phone: d.phoneNumber || d.phone || "",
                role: d.role || "worker",
                status: d.status || "active",
                collections: d.collections || 0,
                routes: d.routes || 0,
                lastActive: lastActiveStr
            };
        });

        return { users };
    } catch (error) {
        console.error("Error fetching users", error);
        throw new functions.https.HttpsError("internal", "Unable to fetch users");
    }
});
