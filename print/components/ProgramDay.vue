<template>
  <v-row no-gutters>
    <v-col cols="12">
      <div v-if="showDailySummary" class="page_break">
        <h1>Daily summary of day {{ day.dayOffset }}</h1>
      </div>

      <div v-if="showActivities">
        <program-schedule-entry
          v-for="scheduleEntry in scheduleEntries"
          :key="scheduleEntry.id"
          :schedule-entry="scheduleEntry"
        />
      </div>
    </v-col>
  </v-row>
</template>

<script>
export default {
  props: {
    day: { type: Object, required: true },
    showDailySummary: { type: Boolean, required: true },
    showActivities: { type: Boolean, required: true },
  },
  async fetch() {
    this.scheduleEntries = (await this.day.scheduleEntries()._meta.load).items
  },
  data() {
    return {
      scheduleEntries: null,
    }
  },
  computed: {
    dayAsDate() {
      return this.day.dayOffset
    },
  },
}
</script>

<style lang="scss" scoped>
@media print {
  .page_break {
    page-break-after: always;
  }
}
</style>
