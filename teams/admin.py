from django.contrib import admin

from teams.models import Team, TeamMembership, ScheduleShare


class TeamMembershipInline(admin.TabularInline):
    model = TeamMembership
    extra = 1


class TeamAdmin(admin.ModelAdmin):
    list_display = ["name", "created_by"]
    list_filter = ["created_by"]
    inlines = [TeamMembershipInline]


class ScheduleShareAdmin(admin.ModelAdmin):
    list_display = ["schedule", "shared_with_user", "shared_with_team", "permission"]
    list_filter = ["permission"]


admin.site.register(Team, TeamAdmin)
admin.site.register(ScheduleShare, ScheduleShareAdmin)
