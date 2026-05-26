// Synthetic fixture for BC-10730 — decoy unrelated page proving absence of
// any UI consumer for the search-logs dashboard route. The vslice greps every
// .tsx under the fixture for the dashboard route path; zero matches is the
// operator-consumable absence signal.

export default function SearchPage() {
  return <div>Search (no dashboard consumer)</div>;
}
