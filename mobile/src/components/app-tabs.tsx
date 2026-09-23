import { NativeTabs } from 'expo-router/unstable-native-tabs';

export default function AppTabs() {
  return (
    <NativeTabs>
      <NativeTabs.Trigger name="index">
        <NativeTabs.Trigger.Label>Assignments</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          sf="checklist"
          md="assignment"
        />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="timetable">
        <NativeTabs.Trigger.Label>Timetable</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          sf="calendar"
          md="calendar_month"
        />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="notifications">
        <NativeTabs.Trigger.Label>Notifications</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          sf="bell"
          md="notifications"
        />
      </NativeTabs.Trigger>

      <NativeTabs.Trigger name="settings">
        <NativeTabs.Trigger.Label>Settings</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon
          sf="gearshape"
          md="settings"
        />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
