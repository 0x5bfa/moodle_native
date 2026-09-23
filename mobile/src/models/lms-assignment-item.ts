export type DueBucket = 'overdue' | 'upcoming' | 'undated';

export type LmsAssignmentItem = {
  id: number;
  courseTitle: string;
  title: string;
  introPreview?: string;
  dueDate?: Date;
  updatedAt?: Date;
};

export function dueBucket(assignment: LmsAssignmentItem, now: Date): DueBucket {
  if (!assignment.dueDate) {
    return 'undated';
  }

  return assignment.dueDate < now ? 'overdue' : 'upcoming';
}
