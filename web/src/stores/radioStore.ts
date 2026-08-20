import { create } from 'zustand';
import {
  mockChatMessages,
  mockFavorites,
  mockMembers,
  mockProfile,
  mockRadioState,
} from '../data/mockRadio';
import type {
  ChatMessage,
  FavoriteFrequency,
  RadioMember,
  RadioProfile,
  RadioState,
  RadioTab,
} from '../types/radio';
import { isEnvBrowser } from '../utils/misc';

const FAV_KEY = 'at-radio-favorites';
const CAT_KEY = 'at-radio-categories';
const CHAT_KEY = 'at-radio-chat';
const NAME_KEY = 'at-radio-display-name';
const MEMBER_LIST_KEY = 'at-radio-member-list';

function loadDisplayName(fallback: string): string {
  try {
    const raw = localStorage.getItem(NAME_KEY);
    if (raw?.trim()) return raw.trim();
  } catch {
    /* ignore */
  }
  return fallback;
}

function persistDisplayName(name: string) {
  try {
    localStorage.setItem(NAME_KEY, name);
  } catch {
    /* ignore */
  }
}

function loadMemberListSetting(): boolean {
  try {
    const raw = localStorage.getItem(MEMBER_LIST_KEY);
    if (raw === '0' || raw === 'false') return false;
  } catch {
    /* ignore */
  }
  return true;
}

function persistMemberListSetting(enabled: boolean) {
  try {
    localStorage.setItem(MEMBER_LIST_KEY, enabled ? '1' : '0');
  } catch {
    /* ignore */
  }
}
function loadFavorites(): FavoriteFrequency[] {
  try {
    const raw = localStorage.getItem(FAV_KEY);
    if (raw) return JSON.parse(raw) as FavoriteFrequency[];
  } catch {
    /* ignore */
  }
  return isEnvBrowser() ? mockFavorites : [];
}

function persistFavorites(favorites: FavoriteFrequency[]) {
  try {
    localStorage.setItem(FAV_KEY, JSON.stringify(favorites));
  } catch {
    /* ignore */
  }
}

function loadCategories(favorites: FavoriteFrequency[]): string[] {
  try {
    const raw = localStorage.getItem(CAT_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as string[];
      if (Array.isArray(parsed)) return normalizeCategories(parsed, favorites);
    }
  } catch {
    /* ignore */
  }

  if (isEnvBrowser()) {
    return normalizeCategories(['Police', 'Private Freq Test'], favorites);
  }

  return normalizeCategories([], favorites);
}

function persistCategories(categories: string[]) {
  try {
    localStorage.setItem(CAT_KEY, JSON.stringify(categories));
  } catch {
    /* ignore */
  }
}

function normalizeCategories(categories: string[], favorites: FavoriteFrequency[]) {
  const set = new Set<string>();
  for (const name of categories) {
    const trimmed = name.trim();
    if (trimmed) set.add(trimmed);
  }
  for (const fav of favorites) {
    if (fav.category?.trim()) set.add(fav.category.trim());
  }
  return Array.from(set);
}

function loadChat(): ChatMessage[] {
  if (!isEnvBrowser()) {
    try {
      const raw = localStorage.getItem(CHAT_KEY);
      if (raw) return JSON.parse(raw) as ChatMessage[];
    } catch {
      /* ignore */
    }
    return [];
  }
  return mockChatMessages;
}

function persistChat(messages: ChatMessage[]) {
  try {
    localStorage.setItem(CHAT_KEY, JSON.stringify(messages.slice(-80)));
  } catch {
    /* ignore */
  }
}

type RadioStore = RadioState & {
  activeTab: RadioTab;
  search: string;
  favorites: FavoriteFrequency[];
  categories: string[];
  messages: ChatMessage[];
  chatOpen: boolean;
  showJoinForm: boolean;
  showCategoryForm: boolean;
  joinCategory: string;
  profile: RadioProfile;
  members: RadioMember[];
  muted: boolean;
  deafened: boolean;
  showMemberList: boolean;
  setRadioState: (state: Partial<RadioState>) => void;
  setActiveTab: (tab: RadioTab) => void;
  setSearch: (search: string) => void;
  setChatOpen: (open: boolean) => void;
  setShowJoinForm: (open: boolean) => void;
  setShowCategoryForm: (open: boolean) => void;
  setJoinCategory: (category: string) => void;
  setMuted: (muted: boolean) => void;
  setDeafened: (deafened: boolean) => void;
  setShowMemberList: (enabled: boolean) => void;
  setProfileName: (name: string) => void;
  addCategory: (name: string) => boolean;
  renameCategory: (oldName: string, newName: string) => boolean;
  removeCategory: (name: string) => void;
  addFavorite: (channel: number, label?: string, category?: string) => void;
  upsertFavorite: (channel: number, label?: string, category?: string) => void;
  removeFavorite: (id: string) => void;
  addMessage: (message: Omit<ChatMessage, 'id' | 'timestamp'> & { timestamp?: number }) => void;
  setMessages: (messages: ChatMessage[]) => void;
  getFilteredFavorites: () => FavoriteFrequency[];
  getGroupedFavorites: () => { category: string; items: FavoriteFrequency[] }[];
};

const initialFavorites = loadFavorites();

const useRadioStore = create<RadioStore>((set, get) => ({
  ...(isEnvBrowser()
    ? mockRadioState
    : {
        onRadio: false,
        channel: 0,
        volume: 50,
        micClicks: true,
        shadowEligible: false,
        shadowEnabled: false,
      }),
  activeTab: 'frequencies',
  search: '',
  favorites: initialFavorites,
  categories: loadCategories(initialFavorites),
  messages: loadChat(),
  chatOpen: false,
  showJoinForm: false,
  showCategoryForm: false,
  joinCategory: loadCategories(initialFavorites)[0] || '',
  profile: {
    ...(isEnvBrowser() ? mockProfile : { name: 'Player', tag: 'Member' }),
    name: loadDisplayName(isEnvBrowser() ? mockProfile.name : 'Player'),
  },
  members: isEnvBrowser() ? mockMembers : [],
  muted: false,
  deafened: false,
  showMemberList: loadMemberListSetting(),

  setRadioState: (state) =>
    set((current) => {
      const customName = loadDisplayName('');
      return {
        ...state,
        profile: {
          tag: state.profile?.tag ?? current.profile.tag,
          avatar: state.profile?.avatar ?? current.profile.avatar,
          name:
            customName ||
            state.profile?.name ||
            current.profile.name,
        },
        members: state.members ?? current.members,
        muted: state.muted ?? current.muted,
        deafened: state.deafened ?? current.deafened,
      };
    }),

  setActiveTab: (activeTab) => set({ activeTab }),
  setSearch: (search) => set({ search }),
  setChatOpen: (chatOpen) => set({ chatOpen }),
  setShowJoinForm: (showJoinForm) => set({ showJoinForm }),
  setShowCategoryForm: (showCategoryForm) => set({ showCategoryForm }),
  setJoinCategory: (joinCategory) => set({ joinCategory }),
  setMuted: (muted) => set({ muted }),
  setDeafened: (deafened) => set({ deafened }),

  setShowMemberList: (showMemberList) => {
    persistMemberListSetting(showMemberList);
    set({ showMemberList });
  },

  setProfileName: (name) => {
    const trimmed = name.trim() || 'Player';
    persistDisplayName(trimmed);
    set((current) => ({
      profile: { ...current.profile, name: trimmed },
    }));
  },

  addCategory: (name) => {
    const trimmed = name.trim();
    if (!trimmed) return false;
    const { categories } = get();
    if (categories.some((c) => c.toLowerCase() === trimmed.toLowerCase())) {
      return false;
    }
    const next = [...categories, trimmed];
    persistCategories(next);
    set({ categories: next, joinCategory: trimmed, showCategoryForm: false });
    return true;
  },

  renameCategory: (oldName, newName) => {
    const trimmed = newName.trim();
    if (!trimmed || trimmed === oldName) return false;

    const { categories, favorites, joinCategory } = get();
    if (
      categories.some(
        (c) => c !== oldName && c.toLowerCase() === trimmed.toLowerCase()
      )
    ) {
      return false;
    }

    const nextCategories = categories.map((c) => (c === oldName ? trimmed : c));
    const nextFavorites = favorites.map((f) =>
      f.category === oldName ? { ...f, category: trimmed } : f
    );

    persistCategories(nextCategories);
    persistFavorites(nextFavorites);
    set({
      categories: nextCategories,
      favorites: nextFavorites,
      joinCategory: joinCategory === oldName ? trimmed : joinCategory,
    });
    return true;
  },

  removeCategory: (name) => {
    const { categories, favorites, joinCategory } = get();
    const nextCategories = categories.filter((c) => c !== name);
    const fallback = nextCategories[0] || '';

    const nextFavorites = fallback
      ? favorites.map((f) =>
          f.category === name ? { ...f, category: fallback } : f
        )
      : favorites.filter((f) => f.category !== name);

    persistCategories(nextCategories);
    persistFavorites(nextFavorites);
    set({
      categories: nextCategories,
      favorites: nextFavorites,
      joinCategory: joinCategory === name ? fallback : joinCategory,
    });
  },

  addFavorite: (channel, label, category) => {
    get().upsertFavorite(channel, label, category);
  },

  upsertFavorite: (channel, label, category) => {
    const { favorites, categories } = get();
    const trimmed = label?.trim();
    const cat = (category || categories[0] || '').trim();
    if (!cat) return;

    const existing = favorites.find((f) => f.channel === channel);

    let nextCategories = categories;
    if (!categories.some((c) => c.toLowerCase() === cat.toLowerCase())) {
      nextCategories = [...categories, cat];
      persistCategories(nextCategories);
    }

    if (existing) {
      const next = favorites.map((f) =>
        f.channel === channel
          ? {
              ...f,
              label: trimmed || f.label,
              category: cat,
            }
          : f
      );
      persistFavorites(next);
      set({ favorites: next, categories: nextCategories });
      return;
    }

    const next: FavoriteFrequency[] = [
      {
        id: `${channel}-${Date.now()}`,
        channel,
        label: trimmed || `Freq ${formatChannel(channel)}`,
        category: cat,
      },
      ...favorites,
    ];
    persistFavorites(next);
    set({ favorites: next, categories: nextCategories });
  },

  removeFavorite: (id) => {
    const next = get().favorites.filter((f) => f.id !== id);
    persistFavorites(next);
    set({ favorites: next });
  },

  addMessage: (message) => {
    const next: ChatMessage[] = [
      ...get().messages,
      {
        id: `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
        timestamp: message.timestamp ?? Date.now(),
        author: message.author,
        message: message.message,
        self: message.self,
      },
    ].slice(-80);
    persistChat(next);
    set({ messages: next });
  },

  setMessages: (messages) => {
    persistChat(messages);
    set({ messages });
  },

  getFilteredFavorites: () => {
    const { favorites, search } = get();
    const q = search.trim().toLowerCase();
    if (!q) return favorites;
    return favorites.filter(
      (f) =>
        f.label.toLowerCase().includes(q) ||
        (f.category || '').toLowerCase().includes(q) ||
        String(f.channel).includes(q) ||
        formatChannel(f.channel).includes(q)
    );
  },

  getGroupedFavorites: () => {
    const { categories, search } = get();
    const items = get().getFilteredFavorites();
    const q = search.trim().toLowerCase();
    const map = new Map<string, FavoriteFrequency[]>();

    for (const category of categories) {
      map.set(category, []);
    }

    for (const item of items) {
      const category = item.category || 'Saved';
      const list = map.get(category) || [];
      list.push(item);
      map.set(category, list);
    }

    return Array.from(map.entries())
      .filter(([category, groupItems]) => {
        if (!q) return true;
        return (
          groupItems.length > 0 || category.toLowerCase().includes(q)
        );
      })
      .map(([category, groupItems]) => ({
        category,
        items: groupItems,
      }));
  },
}));

export function formatChannel(channel: number): string {
  if (!channel) return '-';
  return Number.isInteger(channel) ? `${channel}.00` : channel.toFixed(2);
}

export default useRadioStore;
