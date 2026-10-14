// Sign-out entry point for the UI: warns before leaving unsent offline actions.

import { authState, logout } from "./auth";
import { outbox } from "../data/outbox";
import { confirmDialog } from "../platform/native";

// Returns true when the user was signed out.
export async function signOutWithConfirmation(router) {
  const userId = authState.user?.id;
  const unsent = (await outbox.list()).filter((item) => String(item.userId) === String(userId)).length;

  if (unsent > 0) {
    const what = unsent === 1 ? "1 action is" : `${unsent} actions are`;
    const confirmed = await confirmDialog(
      `${what} not synchronised yet. They stay on this phone and will be sent the next time you sign in. Sign out anyway?`,
      { title: "Unsent actions", confirmLabel: "Sign out", cancelLabel: "Stay signed in" }
    );
    if (!confirmed) return false;
  }

  await logout();
  await router.push({ name: "Login" });
  return true;
}
