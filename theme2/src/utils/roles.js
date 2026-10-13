export const ROLE_LABELS = {
  employee: "Employee",
  manager: "Manager",
  hr_payroll: "HR / Payroll",
  administrator: "General manager"
};

// Human-readable label for an API role name ("hr_payroll" -> "HR / Payroll").
export function formatRole(name) {
  if (!name || name === "none") return "No role";
  return ROLE_LABELS[name] || name.replace(/_/g, " ");
}
