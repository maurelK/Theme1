<template>
  <main class="wt-wrapper">
    <!-- Header Section -->
    <header class="wt-header">
      <div class="wt-title-group">
        <p class="wt-eyebrow">Utilisateur ID: {{ currentUserId }}</p>
        <h1>Working Times <em>History</em></h1>
      </div>
      <div class="wt-actions">
        <button class="btn-wt btn-outline" @click="getWorkingTimes" :disabled="loading">
          <span>Actualiser</span>
        </button>
        <button type="button" class="btn-wt btn-primary" @click="$emit('go-create-entry')">
          <span>+ Cr&eacute;er un cr&eacute;neau</span>
        </button>
      </div>
    </header>

    <!-- Date Range Filter Toolbar -->
    <section class="wt-toolbar" aria-label="Filtrer les temps de travail">
      <div class="wt-field">
        <label for="filter-start">Date de d&eacute;but</label>
        <input 
          id="filter-start" 
          v-model="startDateFilter" 
          type="datetime-local" 
          @change="getWorkingTimes"
        />
      </div>
      <div class="wt-field">
        <label for="filter-end">Date de fin</label>
        <input 
          id="filter-end" 
          v-model="endDateFilter" 
          type="datetime-local" 
          @change="getWorkingTimes"
        />
      </div>
      <div class="wt-toolbar-actions">
        <button 
          v-if="startDateFilter || endDateFilter" 
          class="btn-wt btn-secondary" 
          @click="clearFilters"
        >
          R&eacute;initialiser
        </button>
      </div>
    </section>

    <!-- Feedback Alerts -->
    <div v-if="error" class="wt-alert wt-alert-error">
      <span>Erreur : {{ error }}</span>
      <button class="btn-link" @click="error = ''">Fermer</button>
    </div>

    <div v-if="successMessage" class="wt-alert wt-alert-success">
      <span>{{ successMessage }}</span>
      <button class="btn-link" @click="successMessage = ''">Fermer</button>
    </div>

    <!-- Summary Stats -->
    <div v-if="!loading && workingTimes.length > 0" class="wt-stats">
      <div class="wt-stat-card">
        <div class="wt-stat-label">Total Cr&eacute;neaux</div>
        <div class="wt-stat-value">{{ workingTimes.length }}</div>
      </div>
      <div class="wt-stat-card">
        <div class="wt-stat-label">Temps Total</div>
        <div class="wt-stat-value">{{ totalHoursFormatted }}</div>
      </div>
      <div class="wt-stat-card">
        <div class="wt-stat-label">Moyenne / Cr&eacute;neau</div>
        <div class="wt-stat-value">{{ avgHoursFormatted }}</div>
      </div>
    </div>

    <!-- Working Times Table Card -->
    <section class="wt-table-card">
      <div v-if="loading" class="wt-empty-state">
        <p>Chargement des temps de travail...</p>
      </div>

      <div v-else-if="workingTimes.length === 0" class="wt-empty-state">
        <h3>Aucun temps de travail enregistr&eacute;</h3>
        <p>Aucun cr&eacute;neau ne correspond aux crit&egrave;res pour cet utilisateur.</p>
        <button type="button" class="btn-wt btn-primary" style="margin-top: 16px;" @click="$emit('go-create-entry')">
          Cr&eacute;er un premier cr&eacute;neau
        </button>
      </div>

      <table v-else class="wt-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>D&eacute;but (YYYY-MM-DD hh:mm:ss)</th>
            <th>Fin (YYYY-MM-DD hh:mm:ss)</th>
            <th>Dur&eacute;e</th>
            <th style="text-align: right;">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="wt in workingTimes" :key="wt.id">
            <td>
              <span class="wt-badge">#{{ wt.id }}</span>
            </td>
            <td>
              <span class="wt-time-code">{{ formatDate(wt.start) }}</span>
            </td>
            <td>
              <span class="wt-time-code">{{ formatDate(wt.end) }}</span>
            </td>
            <td>
              <strong>{{ getDuration(wt.start, wt.end) }}</strong>
            </td>
            <td>
              <div class="wt-table-actions">
                <RouterLink 
                  :to="`/workingTime/${currentUserId}/${wt.id}`" 
                  class="btn-wt btn-secondary" 
                  style="padding: 6px 12px; font-size: 11px;"
                >
                  &Eacute;diter
                </RouterLink>
                <button 
                  class="btn-wt btn-danger" 
                  style="padding: 6px 12px; font-size: 11px;"
                  @click="deleteWorkingTime(wt.id)"
                >
                  Supprimer
                </button>
                <button
                  class="btn-wt btn-secondary"
                  style="padding: 6px 12px; font-size: 11px;"
                  @click="requestCorrection(wt.id)"
                >
                  Demander une correction
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </main>
</template>

<script>
import "./WorkingTime.css";
// Route working-time list requests through the shared authenticated API helper.
import { apiFetch } from "../services/auth";

export default {
  name: "WorkingTimes",

  props: {
    userId: {
      type: [Number, String],
      default: null
    }
  },

  data() {
    return {
      workingTimes: [],
      loading: false,
      error: "",
      successMessage: "",
      startDateFilter: "",
      endDateFilter: ""
    };
  },

  computed: {
    currentUserId() {
      if (this.userId) return this.userId;
      return this.$route.params.userID || this.$route.params.userid || 1;
    },

    totalHoursFormatted() {
      let totalMinutes = 0;
      for (const wt of this.workingTimes) {
        const ms = new Date(wt.end.replace(' ', 'T')) - new Date(wt.start.replace(' ', 'T'));
        if (!isNaN(ms) && ms > 0) {
          totalMinutes += Math.floor(ms / 60000);
        }
      }
      const hrs = Math.floor(totalMinutes / 60);
      const mins = totalMinutes % 60;
      return `${hrs}h ${mins > 0 ? mins + 'm' : ''}`;
    },

    avgHoursFormatted() {
      if (this.workingTimes.length === 0) return '0h';
      let totalMinutes = 0;
      let validCount = 0;
      for (const wt of this.workingTimes) {
        const ms = new Date(wt.end.replace(' ', 'T')) - new Date(wt.start.replace(' ', 'T'));
        if (!isNaN(ms) && ms > 0) {
          totalMinutes += Math.floor(ms / 60000);
          validCount++;
        }
      }
      if (validCount === 0) return '0h';
      const avgMins = Math.round(totalMinutes / validCount);
      const hrs = Math.floor(avgMins / 60);
      const mins = avgMins % 60;
      return `${hrs}h ${mins > 0 ? mins + 'm' : ''}`;
    }
  },

  watch: {
    '$route.params.userID': {
      immediate: true,
      handler() {
        this.getWorkingTimes();
      }
    },
    '$route.params.userid': {
      handler() {
        this.getWorkingTimes();
      }
    }
  },

  mounted() {
    this.getWorkingTimes();
  },

  methods: {
    formatDate(dateStr) {
      if (!dateStr) return '';
      const formatted = dateStr.replace('T', ' ').substring(0, 19);
      if (formatted.length === 16) return formatted + ':00';
      return formatted;
    },

    formatInputToApi(inputVal) {
      if (!inputVal) return '';
      const d = new Date(inputVal);
      if (isNaN(d.getTime())) return inputVal;
      const pad = (n) => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    },

    getDuration(startStr, endStr) {
      if (!startStr || !endStr) return '-';
      const start = new Date(startStr.replace(' ', 'T'));
      const end = new Date(endStr.replace(' ', 'T'));
      const diffMs = end - start;
      if (isNaN(diffMs) || diffMs < 0) return '-';
      const mins = Math.floor(diffMs / 60000);
      const hrs = Math.floor(mins / 60);
      const remMins = mins % 60;
      return `${hrs}h ${remMins > 0 ? remMins + 'm' : '00m'}`;
    },

    async getWorkingTimes() {
      this.loading = true;
      this.error = "";

      try {
        let url = `/api/workingtime/${this.currentUserId}`;
        const params = new URLSearchParams();

        if (this.startDateFilter) {
          params.append("start", this.formatInputToApi(this.startDateFilter));
        }
        if (this.endDateFilter) {
          params.append("end", this.formatInputToApi(this.endDateFilter));
        }

        const queryString = params.toString();
        if (queryString) {
          url += `?${queryString}`;
        }

        const response = await apiFetch(url);
        if (!response.ok) {
          throw new Error(`Erreur lors de la r?cup?ration (Status: ${response.status})`);
        }

        const result = await response.json();
        this.workingTimes = result.data || result || [];
      } catch (err) {
        console.error(err);
        this.error = err.message || "Impossible de charger les temps de travail.";
      } finally {
        this.loading = false;
      }
    },

    async deleteWorkingTime(id) {
      if (!confirm("Voulez-vous vraiment supprimer ce temps de travail ?")) return;

      try {
        const response = await apiFetch(`/api/workingtime/${id}`, {
          method: 'DELETE'
        });

        if (!response.ok) {
          throw new Error(`?chec de la suppression (Status: ${response.status})`);
        }

        this.successMessage = "Cr?neau de travail supprim? avec succ?s.";
        this.workingTimes = this.workingTimes.filter(wt => wt.id !== id);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Erreur lors de la suppression du cr?neau.";
      }
    },

    // Submit an employee explanation without mutating the recorded time entry.
    async requestCorrection(id) {
      const reason = window.prompt("Pourquoi cette entrée doit-elle être corrigée ?");
      if (!reason || !reason.trim()) return;

      try {
        const response = await apiFetch(`/api/workingtime/${id}/correction-requests`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ reason: reason.trim() })
        });

        if (!response.ok) throw new Error("Impossible d'envoyer la demande de correction.");
        this.successMessage = "Demande de correction envoyée.";
      } catch (err) {
        this.error = err.message;
      }
    },

    clearFilters() {
      this.startDateFilter = "";
      this.endDateFilter = "";
      this.getWorkingTimes();
    }
  }
};
</script>
