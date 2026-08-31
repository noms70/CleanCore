import { useLocation } from "react-router-dom";
import { useEffect } from "react";

const NotFound = () => {
  const location = useLocation();

  useEffect(() => {
    console.error("404 Error: User attempted to access non-existent route:", location.pathname);
  }, [location.pathname]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-background via-card/20 to-background relative overflow-hidden">
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-1/4 -left-48 w-96 h-96 bg-accent/25 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-1/4 -right-48 w-96 h-96 bg-primary/20 rounded-full blur-3xl animate-pulse" style={{ animationDelay: '1s' }} />
      </div>

      <div className="text-center relative z-10">
        <div className="flex justify-center mb-8">
          <div className="h-24 w-24 rounded-2xl bg-gradient-to-br from-accent via-primary to-primary flex items-center justify-center shadow-xl shadow-accent/40 p-4">
            <img src={`${import.meta.env.BASE_URL}favicon.ico`} alt="Clean Core Logo" className="h-full w-full object-contain" />
          </div>
        </div>
        <h1 className="mb-4 text-6xl font-bold bg-gradient-to-r from-accent via-primary to-accent bg-clip-text text-transparent drop-shadow-[0_0_15px_rgba(34,211,238,0.4)]">404</h1>
        <p className="mb-8 text-2xl text-foreground">Oops! Page not found</p>
        <p className="mb-8 text-muted-foreground max-w-md mx-auto">
          The page you're looking for doesn't exist or has been moved.
        </p>
        <a 
          href="/" 
          className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-accent via-primary to-accent text-card rounded-lg hover:shadow-2xl hover:shadow-accent/40 transition-all duration-300 font-semibold"
        >
          Return to Dashboard
        </a>
      </div>
    </div>
  );
};

export default NotFound;
