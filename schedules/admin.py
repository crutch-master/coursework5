from django.contrib import admin

from schedules.models import Schedule, Event, RecurrenceRule, EventParticipant


class EventParticipantInline(admin.TabularInline):
    model = EventParticipant
    extra = 1


class EventAdmin(admin.ModelAdmin):
    list_display = ["title", "schedule", "start_datetime", "end_datetime", "creator"]
    list_filter = ["schedule", "creator"]
    search_fields = ["title", "description"]
    inlines = [EventParticipantInline]


class ScheduleAdmin(admin.ModelAdmin):
    list_display = ["name", "owner", "color"]
    list_filter = ["owner"]


admin.site.register(Schedule, ScheduleAdmin)
admin.site.register(Event, EventAdmin)
admin.site.register(RecurrenceRule)
admin.site.register(EventParticipant)
