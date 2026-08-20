import type {
  ChatMessage,
  FavoriteFrequency,
  RadioMember,
  RadioProfile,
  RadioState,
} from '../types/radio';

export const mockProfile: RadioProfile = {
  name: 'L-01 | John Carter',
  tag: 'Member',
};

export const mockMembers: RadioMember[] = [
  {
    id: 'self',
    name: 'L-01 | John Carter',
    tag: 'Member',
    self: true,
    talking: false,
  },
  {
    id: '2',
    name: 'A-12 | Marcus Hale',
    tag: 'Joined',
    talking: true,
  },
  {
    id: '3',
    name: 'A-14 | Sofia Reyes',
    tag: 'Joined',
    talking: false,
  },
  {
    id: '4',
    name: 'B-21 | Daniel Brooks',
    tag: 'Joined',
    talking: false,
  },
  {
    id: '5',
    name: 'B-22 | Emily Nguyen',
    tag: 'Joined',
    talking: false,
  },
  {
    id: '6',
    name: 'C-05 | James Ortega',
    tag: 'Joined',
    talking: false,
  },
  {
    id: '7',
    name: 'C-09 | Hannah Price',
    tag: 'Joined',
    talking: false,
  },
  {
    id: '8',
    name: 'D-33 | Kevin Walsh',
    tag: 'Joined',
    talking: false,
  },
  {
    id: '9',
    name: 'D-34 | Laura Kim',
    tag: 'Joined',
    talking: false,
  },
  {
    id: '10',
    name: 'S-02 | Robert Blake',
    tag: 'Joined',
    talking: false,
  },
];

export const mockRadioState: RadioState = {
  onRadio: true,
  channel: 1,
  volume: 50,
  micClicks: true,
  muted: false,
  deafened: false,
  profile: mockProfile,
  members: mockMembers,
};

export const mockFavorites: FavoriteFrequency[] = [
  { id: '1', channel: 1, label: 'Dispatch', category: 'Police' },
  { id: '2', channel: 2, label: 'Patrol Alpha', category: 'Police' },
  { id: '3', channel: 3, label: 'Patrol Bravo', category: 'Police' },
  { id: '4', channel: 101, label: 'General', category: 'Private Freq Test' },
  { id: '5', channel: 420, label: 'Test Channel #1', category: 'Private Freq Test' },
  { id: '6', channel: 69.5, label: 'Tactical 1', category: 'Private Freq Test' },
];

export const mockChatMessages: ChatMessage[] = [
  {
    id: '1',
    author: 'L-01 | John Carter',
    message: 'Dispatch, unit L-01 on scene.',
    timestamp: Date.now() - 120000,
    self: true,
  },
  {
    id: '2',
    author: 'A-12 | Marcus Hale',
    message: 'Copy L-01, A-12 en route.',
    timestamp: Date.now() - 90000,
  },
  {
    id: '3',
    author: 'S-02 | Robert Blake',
    message: 'All units keep this channel clear.',
    timestamp: Date.now() - 45000,
  },
];
