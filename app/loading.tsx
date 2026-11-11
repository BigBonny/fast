export default function Loading() {
  return (
    <div
      role="status"
      aria-label="Chargement"
      className="min-h-screen bg-background"
    >
      <div className="max-w-screen-xl mx-auto px-4 md:px-8 pt-8 space-y-10">
        <div className="space-y-3">
          <div className="h-8 w-1/2 max-w-xs rounded-full skeleton-shimmer" />
          <div className="h-4 w-2/3 max-w-sm rounded-full skeleton-shimmer" />
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {[1, 2, 3].map((i) => (
            <div key={i} className="rounded-2xl border border-border overflow-hidden">
              <div className="aspect-video skeleton-shimmer" />
              <div className="p-4 space-y-2.5">
                <div className="h-4 w-2/3 rounded-full skeleton-shimmer" />
                <div className="h-3 w-1/3 rounded-full skeleton-shimmer" />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
