import { useEffect } from 'react';
import { mockMembers } from '../../data/mockRadio';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import useAppVisibilityStore from '../../stores/appVisibilityStore';
import useRadioStore from '../../stores/radioStore';
import type { ChatMessage, RadioState } from '../../types/radio';
import { debugData } from '../../utils/debugData';
import { fetchNui } from '../../utils/fetchNui';
import { isEnvBrowser } from '../../utils/misc';
import { RadioDashboard } from './RadioDashboard';
import './radio.css';

if (isEnvBrowser()) {
  debugData<boolean>([{ action: 'UPDATE_VISIBILITY', data: true }], 400);
  debugData<RadioState>(
    [
      {
        action: 'SET_RADIO_STATE',
        data: {
          onRadio: true,
          channel: 1,
          volume: 50,
          micClicks: true,
          members: mockMembers,
        },
      },
    ],
    500
  );
}

export function UI() {
  const { showApp, setVisibility } = useAppVisibilityStore();
  const setRadioState = useRadioStore((state) => state.setRadioState);
  const addMessage = useRadioStore((state) => state.addMessage);
  // Browser demo: cycle who is talking so you can see the talking state
  useEffect(() => {
    if (!isEnvBrowser()) return;

    let index = 1;
    const tick = () => {
      const next = mockMembers.map((member, i) => ({
        ...member,
        talking: i === index,
      }));
      setRadioState({ members: next });
      index += 1;
      if (index >= mockMembers.length) index = 1;
    };

    tick();
    const timer = window.setInterval(tick, 2500);
    return () => window.clearInterval(timer);
  }, [setRadioState]);

  useNuiEvent<boolean>('UPDATE_VISIBILITY', (data) => {
    setVisibility(data);
  });

  useNuiEvent<Partial<RadioState>>('SET_RADIO_STATE', (data) => {
    if (data) setRadioState(data);
  });

  useNuiEvent<Omit<ChatMessage, 'id' | 'timestamp'> & { timestamp?: number }>(
    'RADIO_CHAT_MESSAGE',
    (data) => {
      if (data?.message) addMessage(data);
    }
  );

  useNuiEvent('GET_FAVORITES', () => {
    const favorites = useRadioStore.getState().favorites;
    fetchNui('returnFavorites', favorites);
  });

  useNuiEvent<{ channel: number }>('QUICK_SAVE_FREQUENCY', (data) => {
    const channel = Number(data?.channel);
    if (!channel || Number.isNaN(channel)) return;

    const state = useRadioStore.getState();
    let category = state.categories[0];

    if (!category) {
      const names = ['General', 'Squad', 'Ops', 'Private', 'Comms', 'Channels'];
      category = names[Math.floor(Math.random() * names.length)];
      state.addCategory(category);
    }

    const existing = state.favorites.find((f) => f.channel === channel);
    if (existing) return;

    const count =
      state.favorites.filter((f) => f.category === category).length + 1;
    state.upsertFavorite(channel, `Channel ${count}`, category);
  });

  useEffect(() => {
    if (!showApp) return;

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        if (isEnvBrowser()) {
          setVisibility(false);
        } else {
          fetchNui('escape');
        }
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [showApp, setVisibility]);

  return <RadioDashboard visible={showApp} />;
}
