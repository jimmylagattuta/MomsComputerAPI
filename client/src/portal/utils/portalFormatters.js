export function getDisplayName(user) {
  const fullName = `${user.first_name || ""} ${user.last_name || ""}`.trim();
  return fullName || user.preferred_name || user.email || "Unnamed User";
}

export function getInitials(user) {
  const first =
    user.first_name?.[0] || user.preferred_name?.[0] || user.email?.[0] || "U";

  const last = user.last_name?.[0] || "";

  return `${first}${last}`.toUpperCase();
}

export function normalizeStatus(status) {
  return String(status || "").toLowerCase() === "active" ? "Active" : "Inactive";
}

export function formatCreatedAt(createdAt) {
  if (!createdAt) return "—";

  try {
    return new Date(createdAt).toLocaleDateString("en-US", {
      month: "short",
      year: "numeric",
    });
  } catch (_err) {
    return "—";
  }
}

export function formatDate(value) {
  if (!value) return "—";

  try {
    return new Date(value).toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  } catch (_err) {
    return "—";
  }
}

export function formatDateTime(value) {
  if (!value) return "—";

  try {
    return new Date(value).toLocaleString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch (_err) {
    return "—";
  }
}

export function formatMoneyFromCents(cents) {
  const safeCents = Number.isFinite(Number(cents)) ? Number(cents) : 0;

  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(safeCents / 100);
}

export function formatNumber(value) {
  const safeValue = Number.isFinite(Number(value)) ? Number(value) : 0;

  return new Intl.NumberFormat("en-US").format(safeValue);
}