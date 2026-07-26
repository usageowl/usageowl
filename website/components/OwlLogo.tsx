export default function OwlLogo({
  className = '',
  amber = true,
}: {
  className?: string;
  amber?: boolean;
}) {
  const ink = amber ? '#F0B429' : 'currentColor';
  return (
    <svg viewBox="0 0 64 64" fill="none" className={className} aria-hidden="true">
      <path d="M15 9 L26 19 L15 21 Z" fill={ink} />
      <path d="M49 9 L38 19 L49 21 Z" fill={ink} />
      <circle cx="32" cy="36" r="21" stroke={ink} strokeWidth="3.5" fill="#0B0B0D" />
      <circle cx="24" cy="33" r="7" fill={ink} />
      <circle cx="40" cy="33" r="7" fill={ink} />
      <circle cx="24" cy="33" r="2.8" fill="#08080A" />
      <circle cx="40" cy="33" r="2.8" fill="#08080A" />
      <path d="M32 41 L28.5 46.5 L35.5 46.5 Z" fill={ink} />
    </svg>
  );
}
