import { watch } from "vue";
import { createRouter, createWebHistory, createWebHashHistory } from "vue-router";
import ChartManager from "../components/ChartManager.vue";
import WorkingTimes from "../components/WorkingTimes.vue";
import WorkingTime from "../components/WorkingTime.vue";
import ClockManager from "../components/ClockManager.vue";
import User from "../components/User.vue";
import LoginView from "../views/LoginView.vue";
import DashboardView from "../views/DashboardView.vue";
import ForgotPasswordView from "../views/ForgotPasswordView.vue";
import ResetPasswordView from "../views/ResetPasswordView.vue";
import AdminView from "../views/AdminView.vue";
import AdminTeamsView from "../views/AdminTeamsView.vue";
import AcceptInviteView from "../views/AcceptInviteView.vue";
import MyTimeView from "../views/MyTimeView.vue";
import MyTeamView from "../views/MyTeamView.vue";
import ProfileView from "../views/ProfileView.vue";
import NotFoundView from "../views/NotFoundView.vue";
import MyHoursView from "../views/MyHoursView.vue";
import { authState, initializeAuth } from "../services/auth";
import { isMobileApp } from "../utils/platform";

// Mobile build: hash URLs, and no dashboards or charts.
const isCordova = isMobileApp;

// Home is the dashboard on the web; the mobile app opens on the user's own time instead.
const homeRoute = isCordova
  ? { path: "/", name: "Home", redirect: { name: "MyTime" } }
  : { path: "/", name: "Home", component: DashboardView, meta: { requiresAuth: true } };

// Dashboards (charts and averages) exist on the web only.
const webOnlyRoutes = [
  {
    path: "/my-hours",
    name: "MyHours",
    component: MyHoursView,
    meta: { requiresAuth: true }
  },
  {
    path: "/chartManager/:userid",
    name: "ChartManager",
    component: ChartManager,
    meta: { requiresAuth: true }
  }
];

const SUPERVISOR_ROLES = ["administrator", "hr_payroll", "manager"];

const router = createRouter({
  // No server inside the app to rewrite URLs: hash mode always reloads index.html.
  history: isCordova ? createWebHashHistory() : createWebHistory(),

  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition;
    }

    if (to.hash) {
      return {
        el: to.hash,
        behavior: "smooth"
      };
    }

    return false;
  },

  routes: [
    homeRoute,
    {
      path: '/login',
      name: 'Login',
      component: LoginView,
      meta: { guestOnly: true }
    },
    {
      path: '/register',
      redirect: '/login'
    },
    {
      path: '/forgot-password',
      name: 'ForgotPassword',
      component: ForgotPasswordView,
      meta: { guestOnly: true }
    },
    {
      path: '/reset-password',
      name: 'ResetPassword',
      component: ResetPasswordView,
      meta: { guestOnly: true }
    },
    {
      path: '/accept-invite',
      name: 'AcceptInvite',
      component: AcceptInviteView,
      meta: { guestOnly: true }
    },
    {
      path: '/my-time',
      name: 'MyTime',
      component: MyTimeView,
      meta: { requiresAuth: true }
    },
    {
      path: '/my-team',
      name: 'MyTeam',
      component: MyTeamView,
      meta: { requiresAuth: true }
    },
    {
      path: '/profile',
      name: 'Profile',
      component: ProfileView,
      meta: { requiresAuth: true }
    },
    {
      path: '/admin',
      name: 'Admin',
      component: AdminView,
      meta: { requiresAuth: true, requiresRole: ['administrator'] }
    },
    {
      path: '/admin/teams',
      name: 'AdminTeams',
      component: AdminTeamsView,
      meta: { requiresAuth: true, requiresRole: SUPERVISOR_ROLES }
    },
    {
      // Employees use My time, My team and Profile instead.
      path: '/directory',
      name: 'Directory',
      component: User,
      meta: { requiresAuth: true, requiresRole: SUPERVISOR_ROLES }
    },
    {
      path: '/workingTimes/:userID',
      alias: ['/workingTimes/:userid', '/working-times/:userid', '/working-times/:userID'],
      name: 'WorkingTimes',
      component: WorkingTimes,
      props: true,
      meta: { requiresAuth: true }
    },
    {
      path: '/workingTime/:userid/:workingtimeid',
      name: 'WorkingTimeEdit',
      component: WorkingTime,
      props: true,
      meta: { requiresAuth: true }
    },
    {
      path: '/workingTime/:userid',
      name: 'WorkingTimeCreate',
      component: WorkingTime,
      props: true,
      meta: { requiresAuth: true }
    },
    {
      path: '/clock/:userid',
      alias: ['/clock/:userID'],
      name: 'ClockManager',
      component: ClockManager,
      props: true,
      meta: { requiresAuth: true }
    },
    ...(isCordova ? [] : webOnlyRoutes),
    {
      path: '/:pathMatch(.*)*',
      name: 'NotFound',
      component: NotFoundView
    }
  ]
});

// Restore the HttpOnly-cookie session and enforce authentication before navigation.
router.beforeEach(async (to) => {
  if (!authState.initialized) await initializeAuth();

  if (to.meta.requiresAuth && !authState.user) return { name: "Login" };
  if (to.meta.guestOnly && authState.user) return { name: "Home" };

  // Role gate for admin-only routes.
  if (to.meta.requiresRole && authState.user) {
    const allowed = to.meta.requiresRole;
    const role = authState.user.role;
    if (!allowed.includes(role)) return { name: "Home" };
  }

  return true;
});

// A session can end in the background (refresh refused during a sync, account
// deleted): leave the protected page instead of showing failing requests.
watch(
  () => authState.user,
  (user) => {
    if (!user && authState.initialized && router.currentRoute.value.meta.requiresAuth) {
      router.push({ name: "Login" });
    }
  }
);

export default router;