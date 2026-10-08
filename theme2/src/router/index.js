import { createRouter, createWebHistory } from "vue-router";
import ChartManager from "../components/ChartManager.vue";
import WorkingTimes from "../components/WorkingTimes.vue";
import WorkingTime from "../components/WorkingTime.vue";
import ClockManager from "../components/ClockManager.vue";
import User from "../components/User.vue";
import LoginView from "../views/LoginView.vue";
import DashboardView from "../views/DashboardView.vue";
import ForgotPasswordView from "../views/ForgotPasswordView.vue";
import ResetPasswordView from "../views/ResetPasswordView.vue";
import AcceptInviteView from "../views/AcceptInviteView.vue";
import { authState, initializeAuth } from "../services/auth";

const router = createRouter({
  history: createWebHistory(),

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
    {
      path: '/',
      name: 'Home',
      component: DashboardView,
      meta: { requiresAuth: true }
    },
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
      path: '/directory',
      name: 'Directory',
      component: User,
      meta: { requiresAuth: true }
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
    {
      path: "/chartManager/:userid",
      name: "ChartManager",
      component: ChartManager,
      meta: { requiresAuth: true }
    }
  ]
});

// Restore the HttpOnly-cookie session and enforce authentication before navigation.
router.beforeEach(async (to) => {
  if (!authState.initialized) await initializeAuth();

  if (to.meta.requiresAuth && !authState.user) return { name: "Login" };
  if (to.meta.guestOnly && authState.user) return { name: "Home" };
  return true;
});

export default router;