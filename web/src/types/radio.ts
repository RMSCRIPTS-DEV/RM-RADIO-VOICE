export type RadioTab = 'frequencies' | 'settings';

export type FavoriteFrequency = {
  id: string;
  channel: number;
  label: string;
  category?: string;
};

export type RadioMember = {
  id: string;
  name: string;
  tag?: string;
  talking?: boolean;
  self?: boolean;
};

export type ChatMessage = {
  id: string;
  author: string;
  message: string;
  timestamp: number;
  self?: boolean;
};

export type RadioProfile = {
  name: string;
  tag: string;
  avatar?: string;
};

export type RadioState = {
  onRadio: boolean;
  channel: number;
  volume: number;
  micClicks: boolean;
  muted?: boolean;
  deafened?: boolean;
  profile?: RadioProfile;
  members?: RadioMember[];
  /** Whether this player currently qualifies to be hidden from member lists (job or shadow_module item). */
  shadowEligible?: boolean;
  /** Whether shadow mode is actually active right now (eligible AND not opted out). */
  shadowEnabled?: boolean;
};
