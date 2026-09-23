import type { LmsAssignmentItem } from '@/models/lms-assignment-item';

export function makeMockAssignments(now = new Date()): LmsAssignmentItem[] {
  return [
    {
      id: 1,
      courseTitle: 'ソフトウェア工学',
      title: '第1回課題',
      dueDate: new Date(now.getTime() - 3 * 60 * 60 * 1000),
      updatedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
    },
    {
      id: 2,
      courseTitle: 'ソフトウェア工学',
      title: '第2回課題',
      dueDate: new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000),
      updatedAt: now,
    },
    {
      id: 3,
      courseTitle: 'ソフトウェア工学',
      title: 'レポート',
      updatedAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
    },
  ];
}
