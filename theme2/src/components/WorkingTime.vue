<template>
  <main class="wt-wrapper">
    <header class="wt-header">
      <div class="wt-title-group">
        <p class="wt-eyebrow">Utilisateur ID: {{ currentUserId }}</p>
        <h1>{{ isEditMode ? 'Modifier' : 'Cr&eacute;er' }} un <em>cr&eacute;neau</em></h1>
      </div>
      <div class="wt-actions">
        <RouterLink :to="`/workingTimes/${currentUserId}`" class="btn-wt btn-outline">
          <span>&larr; Retour &agrave; la liste</span>
        </RouterLink>
      </div>
    </header>

    <!-- Feedback Alerts -->
    <div v-if="error" class="wt-alert wt-alert-error">
      <span>Erreur : {{ error }}</span>
      <button class="btn-link" @click="error = ''">Fermer</button>
    </div>

    <div v-if="successMessage" class="wt-alert wt-alert-success">
      <span>{{ successMessage }}</span>
      <button class="btn-link" @click="successMessage = ''">Fermer</button>
    </div>

    <!-- Form Card -->
    <section class="wt-form-card">
      <form @submit.prevent="handleSubmit">
        <div class="wt-form-grid">
          <div class="wt-field">
            <label for="wt-start">Date &amp; Heure de d&eacute;but</label>
            <input 
              id="wt-start" 
              v-model="start" 
              type="datetime-local" 
              required
            />
          </div>

          <div class="wt-field">
            <label for="wt-end">Date &amp; Heure de fin</label>
            <input 
              id="wt-end" 
              v-model="end" 
              type="datetime-local" 
              required
            />
          </div>
        </div>

        <!-- Calculated Duration Live Preview -->
        <div v-if="start && end" class="wt-preview-box">
          Dur&eacute;e calcul&eacute;e du cr&eacute;neau : <strong>{{ calculatedDuration }}</strong> 
          <span style="font-size: 11px; margin-left: 8px; color: #71807a;">
            (Format API : {{ apiStartFormatted }} &rarr; {{ apiEndFormatted }})
          </span>
        </div>

        <!-- Action Buttons -->
        <div class="wt-actions" style="margin-top: 24px; justify-content: flex-end;">
          <!-- Creation Mode -->
          <button 
            v-if="!isEditMode" 
            type="button" 
            class="btn-wt btn-primary" 
            :disabled="saving || !start || !end" 
            @click="createWorkingTime"
          >
            <span>{{ saving ? 'Cr&eacute;ation en cours...' : 'Cr&eacute;er le temps de travail' }}</span>
          </button>

          <!-- Edit Mode -->
          <template v-else>
            <button 
              type="button" 
              class="btn-wt btn-primary" 
              :disabled="saving || !start || !end" 
              @click="updateWorkingTime"
            >
              <span>{{ saving ? 'Enregistrement...' : 'Mettre &agrave; jour' }}</span>
            </button>
            <button 
              type="button" 
              class="btn-wt btn-danger" 
              :disabled="saving" 
              @click="deleteWorkingTime"
            >
              <span>Supprimer</span>
            </button>
          </template>
        </div>
      </form>
    </section>
  </main>
</template>

<script>
import "./WorkingTime.css";
// Route working-time requests through the shared authenticated API helper.
import { apiFetch } from "../services/auth";

export default {
  name: "WorkingTime",

  props: {
    userId: {
      type: [Number, String],
      default: null
    },
    workingTimeId: {
      type: [Number, String],
      default: null
    },
    workingTimeData: {
      type: Object,
      default: null
    }
  },

  data() {
    return {
      start: "",
      end: "",
      saving: false,
      loading: false,
      error: "",
      successMessage: ""
    };
  },

  computed: {
    currentUserId() {
      if (this.userId) return this.userId;
      return this.$route.params.userid || this.$route.params.userID || 1;
    },

    currentWorkingTimeId() {
      if (this.workingTimeId) return this.workingTimeId;
      return this.$route.params.workingtimeid || this.$route.params.id || null;
    },

    isEditMode() {
      return !!this.currentWorkingTimeId;
    },

    apiStartFormatted() {
      return this.formatInputToApi(this.start);
    },

    apiEndFormatted() {
      return this.formatInputToApi(this.end);
    },

    calculatedDuration() {
      if (!this.start || !this.end) return '-';
      const startDate = new Date(this.start);
      const endDate = new Date(this.end);
      const diffMs = endDate - startDate;
      if (isNaN(diffMs) || diffMs < 0) return 'Invalide (la fin doit ?tre apr?s le d?but)';
      const mins = Math.floor(diffMs / 60000);
      const hrs = Math.floor(mins / 60);
      const remMins = mins % 60;
      return `${hrs}h ${remMins > 0 ? remMins + 'm' : '00m'}`;
    }
  },

  watch: {
    workingTimeData: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.start = this.formatApiToInput(newVal.start);
          this.end = this.formatApiToInput(newVal.end);
        }
      }
    },
    '$route.params': {
      immediate: true,
      handler() {
        this.fetchExistingWorkingTime();
      }
    }
  },

  mounted() {
    this.fetchExistingWorkingTime();
  },

  methods: {
    formatApiToInput(dateStr) {
      if (!dateStr) return "";
      const isoStr = dateStr.replace(' ', 'T');
      const d = new Date(isoStr);
      if (isNaN(d.getTime())) return "";
      const pad = (n) => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    },

    formatInputToApi(inputVal) {
      if (!inputVal) return "";
      const d = new Date(inputVal);
      if (isNaN(d.getTime())) return inputVal;
      const pad = (n) => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    },

    async fetchExistingWorkingTime() {
      if (!this.isEditMode) return;
      if (this.workingTimeData && this.workingTimeData.start) return;

      this.loading = true;
      this.error = "";

      try {
        const response = await apiFetch(`/api/workingtime/${this.currentUserId}/${this.currentWorkingTimeId}`);
        if (!response.ok) {
          const fallbackResp = await apiFetch(`/api/workingtime/${this.currentUserId}`);
          if (!fallbackResp.ok) throw new Error("Impossible de r?cup?rer les d?tails du cr?neau.");
          const result = await fallbackResp.json();
          const items = result.data || result || [];
          const match = items.find(item => String(item.id) === String(this.currentWorkingTimeId));
          if (match) {
            this.start = this.formatApiToInput(match.start);
            this.end = this.formatApiToInput(match.end);
            return;
          }
          throw new Error("Cr?neau introuvable.");
        }

        const data = await response.json();
        const wt = data.data || data;
        if (wt) {
          this.start = this.formatApiToInput(wt.start);
          this.end = this.formatApiToInput(wt.end);
        }
      } catch (err) {
        console.error(err);
        this.error = err.message || "Erreur lors du chargement des donn?es.";
      } finally {
        this.loading = false;
      }
    },

    handleSubmit() {
      if (this.isEditMode) {
        this.updateWorkingTime();
      } else {
        this.createWorkingTime();
      }
    },

    async createWorkingTime() {
      if (!this.start || !this.end) {
        this.error = "Veuillez renseigner la date de d?but et de fin.";
        return;
      }

      this.saving = true;
      this.error = "";
      this.successMessage = "";

      try {
        const payload = {
          workingtime: {
            start: this.formatInputToApi(this.start),
            end: this.formatInputToApi(this.end)
          }
        };

        const response = await apiFetch(`/api/workingtime/${this.currentUserId}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        if (!response.ok) {
          const errData = await response.json().catch(() => ({}));
          const detail = errData.errors?.user_id ? "L'utilisateur sp?cifi? n'existe pas en base de donn?es." : `Code Erreur: ${response.status}`;
          throw new Error(`?chec de la cr?ation (${detail})`);
        }

        this.successMessage = "Temps de travail cr?? avec succ?s !";
        setTimeout(() => {
          this.$router.push(`/workingTimes/${this.currentUserId}`);
        }, 800);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Erreur lors de la cr?ation du temps de travail.";
      } finally {
        this.saving = false;
      }
    },

    async updateWorkingTime() {
      if (!this.currentWorkingTimeId) return;
      if (!this.start || !this.end) {
        this.error = "Veuillez renseigner la date de d?but et de fin.";
        return;
      }

      this.saving = true;
      this.error = "";
      this.successMessage = "";

      try {
        const payload = {
          workingtime: {
            start: this.formatInputToApi(this.start),
            end: this.formatInputToApi(this.end)
          }
        };

        const response = await apiFetch(`/api/workingtime/${this.currentWorkingTimeId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        if (!response.ok) {
          throw new Error(`?chec de la modification (Status: ${response.status})`);
        }

        this.successMessage = "Temps de travail mis ? jour avec succ?s !";
        setTimeout(() => {
          this.$router.push(`/workingTimes/${this.currentUserId}`);
        }, 800);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Erreur lors de la mise ? jour.";
      } finally {
        this.saving = false;
      }
    },

    async deleteWorkingTime() {
      if (!this.currentWorkingTimeId) return;
      if (!confirm("?tes-vous s?r de vouloir supprimer ce temps de travail ?")) return;

      this.saving = true;
      this.error = "";

      try {
        const response = await apiFetch(`/api/workingtime/${this.currentWorkingTimeId}`, {
          method: 'DELETE'
        });

        if (!response.ok) {
          throw new Error(`?chec de la suppression (Status: ${response.status})`);
        }

        this.successMessage = "Temps de travail supprim?.";
        setTimeout(() => {
          this.$router.push(`/workingTimes/${this.currentUserId}`);
        }, 800);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Erreur lors de la suppression.";
      } finally {
        this.saving = false;
      }
    }
  }
};
</script>
