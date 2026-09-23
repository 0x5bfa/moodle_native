import {
  Button,
  ContentUnavailableView,
  HStack,
  Host,
  Image,
  List,
  NavigationDestination,
  NavigationLink,
  NavigationStack,
  Spacer,
  SwipeActions,
  Text,
  Toolbar,
  VStack,
} from '@expo/ui/swift-ui';
import {
  background,
  buttonStyle,
  disabled,
  font,
  foregroundStyle,
  lineLimit,
  listRowSeparator,
  listStyle,
  navigationTitle,
  opacity,
  padding,
  shapes,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { makeMockAssignments } from '@/mock-data/assignments';
import {
  dueBucket,
  type DueBucket,
  type LmsAssignmentItem,
} from '@/models/lms-assignment-item';
import { accentColor } from '@/theme/colors';
import { useMemo, useState } from 'react';
import { PlatformColor, StyleSheet } from 'react-native';

type AssignmentFilter = 'all' | 'own';

const secondaryStyle = { type: 'hierarchical', style: 'secondary' } as const;

const strings = {
  en: {
    title: 'Assignments',
    all: 'All',
    own: 'My assignments',
    ownEmptyTitle: 'No assignments for you',
    ownEmptyDescription: 'Switch to All to see hidden assignments too.',
    emptyTitle: 'No assignments',
    emptyDescription: 'There are no assignments to show.',
    select: 'Select',
    cancel: 'Cancel',
    hide: 'Hide',
    hideSelected: 'Hide selected assignments',
    restore: 'Restore to my assignments',
    overdue: 'Overdue',
    undated: 'No due date',
  },
  ja: {
    title: '課題',
    all: '全て',
    own: '自分の課題',
    ownEmptyTitle: '自分の課題はありません',
    ownEmptyDescription: '全てに切り替えると非表示にした課題も確認できます。',
    emptyTitle: '課題はありません',
    emptyDescription: '表示できる課題はありません。',
    select: '選択',
    cancel: 'キャンセル',
    hide: '非表示',
    hideSelected: '選択した課題を非表示',
    restore: '自分の課題へ戻す',
    overdue: '期限切れ',
    undated: '期限未設定',
  },
} as const;

function orderedAssignments(assignments: LmsAssignmentItem[], now: Date): LmsAssignmentItem[] {
  const compareText = (lhs: string, rhs: string) => lhs.localeCompare(rhs);

  const sortBucket = (bucket: DueBucket) =>
    assignments
      .filter((assignment) => dueBucket(assignment, now) === bucket)
      .sort((lhs, rhs) => {
        if (bucket === 'overdue') {
          const lhsTime = lhs.dueDate?.getTime() ?? Number.NEGATIVE_INFINITY;
          const rhsTime = rhs.dueDate?.getTime() ?? Number.NEGATIVE_INFINITY;
          if (lhsTime !== rhsTime) return rhsTime - lhsTime;
        } else if (bucket === 'upcoming') {
          const lhsTime = lhs.dueDate?.getTime() ?? Number.POSITIVE_INFINITY;
          const rhsTime = rhs.dueDate?.getTime() ?? Number.POSITIVE_INFINITY;
          if (lhsTime !== rhsTime) return lhsTime - rhsTime;
        }

        const courseComparison = compareText(lhs.courseTitle, rhs.courseTitle);
        if (courseComparison !== 0) return courseComparison;

        if (bucket === 'undated') {
          const lhsUpdated = lhs.updatedAt?.getTime() ?? Number.NEGATIVE_INFINITY;
          const rhsUpdated = rhs.updatedAt?.getTime() ?? Number.NEGATIVE_INFINITY;
          if (lhsUpdated !== rhsUpdated) return rhsUpdated - lhsUpdated;
        }

        return compareText(lhs.title, rhs.title);
      });

  return [...sortBucket('overdue'), ...sortBucket('upcoming'), ...sortBucket('undated')];
}

function AssignmentRow({ assignment, now }: { assignment: LmsAssignmentItem; now: Date }) {
  const bucket = dueBucket(assignment, now);

  return (
    <VStack alignment="leading" spacing={10}>
      <HStack alignment="top" spacing={4}>
        <VStack alignment="leading">
          <Text modifiers={[font({ textStyle: 'headline' }), lineLimit(1)]}>{assignment.title}</Text>
          <Text modifiers={[font({ textStyle: 'body' }), lineLimit(1)]}>{assignment.courseTitle}</Text>
          {assignment.introPreview ? (
            <Text
              modifiers={[
                font({ textStyle: 'callout' }),
                foregroundStyle(secondaryStyle),
                lineLimit(2),
              ]}>
              {assignment.introPreview}
            </Text>
          ) : null}
        </VStack>

        <Spacer />

        {bucket === 'overdue' ? (
          <Text
            modifiers={[
              font({ textStyle: 'caption', weight: 'semibold' }),
              foregroundStyle(PlatformColor('systemRed')),
              padding({ horizontal: 10, vertical: 6 }),
              background('rgba(255, 59, 48, 0.12)', shapes.capsule()),
            ]}>
            {currentStrings().overdue}
          </Text>
        ) : bucket === 'undated' ? (
          <Text
            modifiers={[
              font({ textStyle: 'caption', weight: 'semibold' }),
              foregroundStyle(secondaryStyle),
              padding({ horizontal: 10, vertical: 6 }),
              background('rgba(142, 142, 147, 0.12)', shapes.capsule()),
            ]}>
            {currentStrings().undated}
          </Text>
        ) : (
          <Text
            date={assignment.dueDate}
            dateStyle="relative"
            modifiers={[font({ textStyle: 'callout' }), foregroundStyle(secondaryStyle)]}
          />
        )}
      </HStack>
    </VStack>
  );
}

function FilterControls({
  filter,
  onChange,
}: {
  filter: AssignmentFilter;
  onChange: (filter: AssignmentFilter) => void;
}) {
  const labels = currentStrings();

  return (
    <HStack spacing={8} modifiers={[listRowSeparator('hidden')]}>
      <FilterButton
        selected={filter === 'all'}
        systemName="tray.fill"
        label={labels.all}
        onPress={() => onChange('all')}
      />
      <FilterButton
        selected={filter === 'own'}
        systemName="checklist.checked"
        label={labels.own}
        onPress={() => onChange('own')}
      />
    </HStack>
  );
}

function FilterButton({
  selected,
  systemName,
  label,
  onPress,
}: {
  selected: boolean;
  systemName: 'tray.fill' | 'checklist.checked';
  label: string;
  onPress: () => void;
}) {
  return (
    <Button onPress={onPress} modifiers={[buttonStyle('plain')]}>
      <HStack
        spacing={8}
        modifiers={[
          font({ textStyle: 'callout', weight: 'medium' }),
          foregroundStyle(selected ? 'white' : secondaryStyle),
          padding({ horizontal: 14, vertical: 10 }),
          background(selected ? accentColor : PlatformColor('tertiarySystemFill'), shapes.capsule()),
        ]}>
        <Image systemName={systemName} />
        <Text>{label}</Text>
      </HStack>
    </Button>
  );
}

function SelectionRow({
  assignment,
  selected,
  hidden,
  now,
  onPress,
}: {
  assignment: LmsAssignmentItem;
  selected: boolean;
  hidden: boolean;
  now: Date;
  onPress: () => void;
}) {
  return (
    <Button
      onPress={onPress}
      modifiers={[buttonStyle('plain'), disabled(hidden), opacity(hidden ? 0.55 : 1)]}>
      <HStack alignment="top" spacing={12}>
        <Image
          systemName={selected ? 'checkmark.circle.fill' : 'circle'}
          modifiers={[
            font({ textStyle: 'title3' }),
            foregroundStyle(hidden ? secondaryStyle : selected ? accentColor : secondaryStyle),
            padding({ top: 6 }),
          ]}
        />
        <AssignmentRow assignment={assignment} now={now} />
      </HStack>
    </Button>
  );
}

function currentStrings() {
  return Intl.DateTimeFormat().resolvedOptions().locale.toLowerCase().startsWith('ja')
    ? strings.ja
    : strings.en;
}

export default function AssignmentsTabView() {
  const labels = currentStrings();
  const [assignments] = useState<LmsAssignmentItem[]>(() =>
    typeof __DEV__ !== 'undefined' && __DEV__ ? makeMockAssignments() : []
  );
  const [assignmentFilter, setAssignmentFilter] = useState<AssignmentFilter>('own');
  const [hiddenAssignmentIDs, setHiddenAssignmentIDs] = useState<Set<number>>(() => new Set());
  const [isSelectingAssignments, setIsSelectingAssignments] = useState(false);
  const [selectedAssignmentIDs, setSelectedAssignmentIDs] = useState<Set<number>>(() => new Set());
  const now = useMemo(() => new Date(), []);

  const allAssignments = useMemo(() => orderedAssignments(assignments, now), [assignments, now]);
  const visibleAssignments = useMemo(
    () => allAssignments.filter((assignment) => !hiddenAssignmentIDs.has(assignment.id)),
    [allAssignments, hiddenAssignmentIDs]
  );
  const displayedAssignments = assignmentFilter === 'own' ? visibleAssignments : allAssignments;
  const hasVisibleDisplayedAssignment = displayedAssignments.some(
    (assignment) => !hiddenAssignmentIDs.has(assignment.id)
  );
  const selectedVisibleAssignments = displayedAssignments.filter(
    (assignment) =>
      !hiddenAssignmentIDs.has(assignment.id) && selectedAssignmentIDs.has(assignment.id)
  );

  const changeFilter = (filter: AssignmentFilter) => {
    setAssignmentFilter(filter);
    setIsSelectingAssignments(false);
    setSelectedAssignmentIDs(new Set());
  };

  const hideAssignment = (assignment: LmsAssignmentItem) => {
    setHiddenAssignmentIDs((current) => new Set(current).add(assignment.id));
    setSelectedAssignmentIDs((current) => {
      const next = new Set(current);
      next.delete(assignment.id);
      return next;
    });
  };

  const restoreAssignment = (assignment: LmsAssignmentItem) => {
    setHiddenAssignmentIDs((current) => {
      const next = new Set(current);
      next.delete(assignment.id);
      return next;
    });
  };

  const toggleSelection = (assignment: LmsAssignmentItem) => {
    if (hiddenAssignmentIDs.has(assignment.id)) return;

    setSelectedAssignmentIDs((current) => {
      const next = new Set(current);
      if (next.has(assignment.id)) next.delete(assignment.id);
      else next.add(assignment.id);
      return next;
    });
  };

  const hideSelectedAssignments = () => {
    setHiddenAssignmentIDs((current) => {
      const next = new Set(current);
      selectedVisibleAssignments.forEach((assignment) => next.add(assignment.id));
      return next;
    });
    setSelectedAssignmentIDs(new Set());
    setIsSelectingAssignments(false);
  };

  return (
    <Host style={styles.host} useViewportSizeMeasurement seedColor={accentColor}>
      <NavigationStack>
        <Toolbar>
          {assignments.length === 0 ? (
            <ContentUnavailableView
              title={labels.emptyTitle}
              systemImage="checklist"
              description={labels.emptyDescription}
              modifiers={[navigationTitle(labels.title)]}
            />
          ) : (
            <List modifiers={[listStyle('plain'), navigationTitle(labels.title)]}>
              <FilterControls filter={assignmentFilter} onChange={changeFilter} />

              {displayedAssignments.length === 0 ? (
                <ContentUnavailableView
                  title={labels.ownEmptyTitle}
                  systemImage="checklist"
                  description={labels.ownEmptyDescription}
                  modifiers={[listRowSeparator('hidden')]}
                />
              ) : null}

              {displayedAssignments.map((assignment) => {
                const hidden = hiddenAssignmentIDs.has(assignment.id);

                if (isSelectingAssignments) {
                  return (
                    <SelectionRow
                      key={assignment.id}
                      assignment={assignment}
                      selected={selectedAssignmentIDs.has(assignment.id)}
                      hidden={hidden}
                      now={now}
                      onPress={() => toggleSelection(assignment)}
                    />
                  );
                }

                return (
                  <SwipeActions key={assignment.id}>
                    <NavigationLink value={`assignment-${assignment.id}`}>
                      <AssignmentRow assignment={assignment} now={now} />
                    </NavigationLink>
                    <SwipeActions.Actions
                      edge="trailing"
                      allowsFullSwipe={assignmentFilter === 'own'}>
                      {hidden ? (
                        <Button
                          label={labels.restore}
                          systemImage="eye"
                          onPress={() => restoreAssignment(assignment)}
                          modifiers={[tint(accentColor)]}
                        />
                      ) : (
                        <Button
                          label={labels.hide}
                          systemImage="eye.slash"
                          role={assignmentFilter === 'own' ? 'destructive' : 'default'}
                          onPress={() => hideAssignment(assignment)}
                          modifiers={assignmentFilter === 'all' ? [tint(PlatformColor('systemRed'))] : []}
                        />
                      )}
                    </SwipeActions.Actions>
                  </SwipeActions>
                );
              })}
            </List>
          )}

          {hasVisibleDisplayedAssignment ? (
            <Toolbar.Content>
              {isSelectingAssignments ? (
                <>
                  <Button
                    label={labels.cancel}
                    onPress={() => {
                      setIsSelectingAssignments(false);
                      setSelectedAssignmentIDs(new Set());
                    }}
                  />
                  <Button
                    onPress={hideSelectedAssignments}
                    modifiers={[
                      disabled(selectedVisibleAssignments.length === 0),
                      foregroundStyle(accentColor),
                    ]}>
                    <Image systemName="eye.slash" />
                  </Button>
                </>
              ) : (
                <Button
                  label={labels.select}
                  onPress={() => {
                    setIsSelectingAssignments(true);
                    setSelectedAssignmentIDs(new Set());
                  }}
                />
              )}
            </Toolbar.Content>
          ) : null}
        </Toolbar>

        {allAssignments.map((assignment) => (
          <NavigationDestination key={assignment.id} value={`assignment-${assignment.id}`}>
            <ContentUnavailableView
              title={assignment.title}
              systemImage="checklist"
              description={assignment.courseTitle}
              modifiers={[navigationTitle(assignment.title)]}
            />
          </NavigationDestination>
        ))}
      </NavigationStack>
    </Host>
  );
}

const styles = StyleSheet.create({
  host: {
    flex: 1,
  },
});
