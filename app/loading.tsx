export default function Loading() {
  return (
    <div
      role="status"
      aria-label="Chargement"
      className="min-h-screen flex items-center justify-center bg-white dark:bg-gray-950"
    >
      <div className="w-8 h-8 border-2 border-teal-400 border-t-transparent rounded-full animate-spin" />
    </div>
  );
}
