import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

// Apply saved theme before first paint to avoid flash
const saved = localStorage.getItem("theme");
if (saved === "light") {
  document.documentElement.classList.remove("dark");
  document.documentElement.classList.add("light");
} else {
  document.documentElement.classList.remove("light");
  document.documentElement.classList.add("dark");
}

createRoot(document.getElementById("root")!).render(<App />);
