interface CleanCoreLogoProps {
  size?: number;
  className?: string;
}

/**
 * Crisp SVG reproduction of the Clean Core circular emblem.
 * Scales perfectly at any size — no blur from favicon upscaling.
 */
export function CleanCoreLogo({ size = 80, className = "" }: CleanCoreLogoProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      {/* Outer glow ring */}
      <circle cx="50" cy="50" r="48" stroke="url(#outerRing)" strokeWidth="1.5" opacity="0.6" />

      {/* Main background circle */}
      <circle cx="50" cy="50" r="44" fill="url(#bgGradient)" />

      {/* Inner teal ring */}
      <circle cx="50" cy="50" r="40" stroke="url(#innerRing)" strokeWidth="2.5" fill="none" />

      {/* Outer C arc (the larger ring arc) */}
      <path
        d="M 50 14
           A 36 36 0 1 0 79 68"
        stroke="url(#arcGradient)"
        strokeWidth="5"
        strokeLinecap="round"
        fill="none"
      />

      {/* Inner C arc (smaller, offset) */}
      <path
        d="M 50 24
           A 26 26 0 1 0 71.5 64"
        stroke="url(#arcGradient2)"
        strokeWidth="4"
        strokeLinecap="round"
        fill="none"
        opacity="0.75"
      />

      {/* Truck silhouette — body */}
      <rect x="29" y="51" width="26" height="14" rx="2" fill="url(#truckGradient)" />
      {/* Cab */}
      <path d="M55 58 L55 51 L65 51 L70 57 L70 65 L55 65 Z" fill="url(#truckGradient)" />
      {/* Windscreen */}
      <path d="M57 52.5 L57 57 L68 57 L64.5 52.5 Z" fill="hsl(228,55%,9%)" opacity="0.7" />
      {/* Wheels */}
      <circle cx="36" cy="65" r="4.5" fill="hsl(228,55%,9%)" />
      <circle cx="36" cy="65" r="2.5" fill="url(#wheelGradient)" />
      <circle cx="62" cy="65" r="4.5" fill="hsl(228,55%,9%)" />
      <circle cx="62" cy="65" r="2.5" fill="url(#wheelGradient)" />

      {/* Gradient definitions */}
      <defs>
        <radialGradient id="bgGradient" cx="50%" cy="35%" r="65%">
          <stop offset="0%"   stopColor="hsl(222,52%,18%)" />
          <stop offset="100%" stopColor="hsl(228,60%,10%)" />
        </radialGradient>

        <linearGradient id="outerRing" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%"   stopColor="hsl(181,100%,50%)" stopOpacity="0.8" />
          <stop offset="100%" stopColor="hsl(184,86%,42%)"  stopOpacity="0.2" />
        </linearGradient>

        <linearGradient id="innerRing" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%"   stopColor="hsl(181,100%,55%)" stopOpacity="0.9" />
          <stop offset="100%" stopColor="hsl(184,86%,42%)"  stopOpacity="0.3" />
        </linearGradient>

        <linearGradient id="arcGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%"   stopColor="hsl(181,100%,60%)" />
          <stop offset="100%" stopColor="hsl(184,86%,44%)" />
        </linearGradient>

        <linearGradient id="arcGradient2" x1="100%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%"   stopColor="hsl(181,100%,55%)" />
          <stop offset="100%" stopColor="hsl(190,80%,40%)" />
        </linearGradient>

        <linearGradient id="truckGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%"   stopColor="hsl(181,100%,58%)" />
          <stop offset="100%" stopColor="hsl(184,86%,44%)" />
        </linearGradient>

        <linearGradient id="wheelGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%"   stopColor="hsl(181,100%,55%)" />
          <stop offset="100%" stopColor="hsl(184,86%,42%)" />
        </linearGradient>
      </defs>
    </svg>
  );
}
