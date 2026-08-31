import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";
import { componentTagger } from "lovable-tagger";

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  base: mode === "production" ? "/" : "/admin/",
  server: {
    host: "::",
    port: 8080,
    proxy: {
      // Proxy backend API requests to FastAPI
      "^/admin/stats$": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
      "^/optimize-route$": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
      "^/report-anomaly$": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
      "^/update-worker-location$": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
      "^/admin/create-user$": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
      "^/admin/delete-user": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
      "^/admin/update-user": {
        target: "http://127.0.0.1:8000",
        changeOrigin: true,
      },
    },
  },
  plugins: [react(), mode === "development" && componentTagger()].filter(Boolean),
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
}));
