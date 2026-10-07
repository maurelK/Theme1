<template>
  <div class="password-field">
    <label :for="inputId">{{ label }}</label>
    <input
      :id="inputId"
      :value="modelValue"
      type="password"
      :autocomplete="autocomplete"
      :placeholder="placeholder"
      :minlength="rules.minLength"
      required
      @input="$emit('update:modelValue', $event.target.value)"
    >

    <div v-if="modelValue" class="password-meter" :data-strength="strength.level">
      <div class="password-meter-track">
        <span class="password-meter-fill" :style="{ width: strength.percent + '%' }"></span>
      </div>
      <span class="password-meter-label">{{ strength.label }}</span>
    </div>

    <ul v-if="modelValue" class="password-rules">
      <li :class="{ met: checks.length }">
        <span class="rule-dot" aria-hidden="true"></span>
        At least {{ rules.minLength }} characters
      </li>
      <li :class="{ met: checks.lowercase }">
        <span class="rule-dot" aria-hidden="true"></span>
        A lowercase letter
      </li>
      <li :class="{ met: checks.uppercase }">
        <span class="rule-dot" aria-hidden="true"></span>
        An uppercase letter
      </li>
      <li :class="{ met: checks.digit }">
        <span class="rule-dot" aria-hidden="true"></span>
        A number
      </li>
      <li :class="{ met: checks.symbol }">
        <span class="rule-dot" aria-hidden="true"></span>
        A symbol (e.g. ! ? @ #)
      </li>
      <li :class="{ met: checks.notCommon }">
        <span class="rule-dot" aria-hidden="true"></span>
        Not a commonly used password
      </li>
    </ul>
  </div>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  modelValue: { type: String, default: "" },
  label: { type: String, default: "Password" },
  inputId: { type: String, default: "password-field" },
  autocomplete: { type: String, default: "new-password" },
  placeholder: { type: String, default: "" }
});

defineEmits(["update:modelValue"]);

// Rules must mirror the backend User.password_rules / validate_password_strength.
const rules = {
  minLength: 10,
  maxLength: 72
};

// Small blocklist matching the backend's list, case-insensitive.
const BLOCKLIST = new Set([
  "password", "password1", "password123", "passw0rd", "12345678", "123456789", "1234567890",
  "qwerty", "qwerty123", "abc123", "letmein", "welcome", "admin", "administrator",
  "iloveyou", "monkey", "dragon", "sunshine", "princess", "football", "baseball",
  "changeme", "changeme123", "passw0rd!", "p@ssw0rd", "p@ssword"
]);

const checks = computed(() => {
  const value = props.modelValue || "";
  return {
    length: value.length >= rules.minLength && value.length <= rules.maxLength,
    lowercase: /[a-z]/.test(value),
    uppercase: /[A-Z]/.test(value),
    digit: /[0-9]/.test(value),
    symbol: /[^A-Za-z0-9]/.test(value),
    notCommon: value.length > 0 && !BLOCKLIST.has(value.toLowerCase())
  };
});

const strength = computed(() => {
  const value = props.modelValue || "";
  if (!value) return { level: "empty", label: "", percent: 0 };

  const c = checks.value;
  let score = 0;

  if (c.length) score += 2;
  if (c.lowercase) score += 1;
  if (c.uppercase) score += 1;
  if (c.digit) score += 1;
  if (c.symbol) score += 1;

  // Length is king: a very long password is inherently strong.
  if (value.length >= 16) score += 2;
  else if (value.length >= 14) score += 1;

  // Common passwords are always weak, regardless of other checks.
  if (!c.notCommon) score = 0;

  // Map 0..8 to a label and percentage.
  if (score <= 2) return { level: "weak", label: "Weak", percent: 25 };
  if (score <= 4) return { level: "fair", label: "Fair", percent: 50 };
  if (score <= 6) return { level: "good", label: "Good", percent: 75 };
  return { level: "strong", label: "Strong", percent: 100 };
});
</script>

<style scoped>
.password-field {
  display: grid;
  gap: 9px;
}

.password-meter {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 4px;
}

.password-meter-track {
  flex: 1;
  height: 4px;
  background: #d4d6cc;
  overflow: hidden;
}

.password-meter-fill {
  display: block;
  height: 100%;
  transition: width .25s, background .25s;
}

.password-meter-label {
  min-width: 52px;
  color: #71807a;
  font: 10px "DM Mono", monospace;
  letter-spacing: .08em;
  text-transform: uppercase;
  text-align: right;
}

.password-meter[data-strength="weak"]   .password-meter-fill { background: #c25a4c; }
.password-meter[data-strength="fair"]   .password-meter-fill { background: #cfa457; }
.password-meter[data-strength="good"]   .password-meter-fill { background: #7ba87e; }
.password-meter[data-strength="strong"] .password-meter-fill { background: #287c78; }

.password-meter[data-strength="weak"]   .password-meter-label { color: #c25a4c; }
.password-meter[data-strength="fair"]   .password-meter-label { color: #b18a3a; }
.password-meter[data-strength="good"]   .password-meter-label { color: #527653; }
.password-meter[data-strength="strong"] .password-meter-label { color: #287c78; }

.password-rules {
  list-style: none;
  margin: 4px 0 0;
  padding: 0;
  display: grid;
  gap: 4px;
}

.password-rules li {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #9aa39c;
  font: 11px "Manrope", sans-serif;
  transition: color .15s;
}

.password-rules li.met {
  color: #527653;
}

.rule-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #c4c9bf;
  flex-shrink: 0;
  transition: background .15s;
}

.password-rules li.met .rule-dot {
  background: #76a66e;
}
</style>