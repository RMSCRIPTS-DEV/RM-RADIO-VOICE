import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import {
  AudioLines,
  ChevronDown,
  Headphones,
  FolderPlus,
  Megaphone,
  Mic,
  MicOff,
  Pencil,
  PhoneOff,
  Plus,
  Power,
  Radio,
  Search,
  Send,
  Signal,
  Trash2,
  User,
  Volume2,
  VolumeX,
  X,
} from 'lucide-react';
import useAppVisibilityStore from '../../stores/appVisibilityStore';
import useRadioStore, { formatChannel } from '../../stores/radioStore';
import type { RadioTab } from '../../types/radio';
import { fetchNui } from '../../utils/fetchNui';
import { isEnvBrowser } from '../../utils/misc';
import './radio.css';

const TRANSITION_MS = 300;

interface RadioDashboardProps {
  visible: boolean;
}

export function RadioDashboard({ visible }: RadioDashboardProps) {
  const {
    onRadio,
    channel,
    volume,
    micClicks,
    activeTab,
    search,
    chatOpen,
    showJoinForm,
    showCategoryForm,
    joinCategory,
    categories,
    profile,
    members,
    muted,
    deafened,
    showMemberList,
    shadowEligible,
    shadowEnabled,
    messages,
    setActiveTab,
    setSearch,
    setRadioState,
    setChatOpen,
    setShowJoinForm,
    setShowCategoryForm,
    setJoinCategory,
    setMuted,
    setDeafened,
    setShowMemberList,
    setProfileName,
    addCategory,
    renameCategory,
    removeCategory,
    upsertFavorite,
    removeFavorite,
    addMessage,
    getGroupedFavorites,
  } = useRadioStore();

  const groups = getGroupedFavorites();
  const [render, setRender] = useState(visible);
  const [open, setOpen] = useState(false);
  const [joinValue, setJoinValue] = useState('');
  const [joinName, setJoinName] = useState('');
  const [categoryName, setCategoryName] = useState('');
  const [renamingCategory, setRenamingCategory] = useState<string | null>(null);
  const [renameValue, setRenameValue] = useState('');
  const [categoryMenuOpen, setCategoryMenuOpen] = useState(false);
  const [membersExpanded, setMembersExpanded] = useState(true);
  const [chatDraft, setChatDraft] = useState('');
  const chatEndRef = useRef<HTMLDivElement>(null);
  const categoryMenuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (visible) {
      setRender(true);
      const frame = requestAnimationFrame(() => {
        requestAnimationFrame(() => setOpen(true));
      });
      return () => cancelAnimationFrame(frame);
    }

    setOpen(false);
    setChatOpen(false);
    const timer = window.setTimeout(() => setRender(false), TRANSITION_MS);
    return () => window.clearTimeout(timer);
  }, [visible, setChatOpen]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages.length, chatOpen]);

  useEffect(() => {
    if (!categoryMenuOpen) return;

    const onPointerDown = (event: MouseEvent) => {
      if (!categoryMenuRef.current?.contains(event.target as Node)) {
        setCategoryMenuOpen(false);
      }
    };

    window.addEventListener('mousedown', onPointerDown);
    return () => window.removeEventListener('mousedown', onPointerDown);
  }, [categoryMenuOpen]);

  useEffect(() => {
    if (!showJoinForm) setCategoryMenuOpen(false);
  }, [showJoinForm]);

  const favorites = useRadioStore((s) => s.favorites);
  const connected = onRadio && channel > 0;
  const activeFavorite = useMemo(
    () => favorites.find((f) => f.channel === channel),
    [channel, favorites]
  );
  const channelLabel = activeFavorite?.label || (connected ? formatChannel(channel) : 'No Channel');
  const channelMembers = members.filter((m) => !m.self || connected);

  const resetJoinForm = () => {
    setJoinValue('');
    setJoinName('');
    setShowJoinForm(false);
  };

  const joinChannel = async (
    value: string | number,
    options?: { label?: string; category?: string; save?: boolean }
  ) => {
    const parsed = typeof value === 'number' ? value : Number(value);
    if (!parsed || Number.isNaN(parsed)) return;

    if (options?.save) {
      const cat = options.category?.trim() || joinCategory || categories[0] || '';
      if (!cat) return;
      upsertFavorite(parsed, options.label, cat);
    }

    if (isEnvBrowser()) {
      setRadioState({ channel: parsed, onRadio: true });
      setMembersExpanded(true);
      if (options?.save) resetJoinForm();
      return;
    }

    const result = await fetchNui<{ ok: boolean; channel?: number }>('joinRadio', {
      channel: parsed,
    });
    if (result?.ok && result.channel != null) {
      setRadioState({ channel: result.channel, onRadio: true });
      setMembersExpanded(true);
    }
    if (options?.save) resetJoinForm();
  };

  const handleChannelClick = (favChannel: number) => {
    if (connected && favChannel === channel) {
      setMembersExpanded((open) => !open);
      return;
    }
    void joinChannel(favChannel);
  };

  const handleJoinSubmit = (event: FormEvent) => {
    event.preventDefault();
    void joinChannel(joinValue, {
      label: joinName,
      category: joinCategory,
      save: true,
    });
  };

  const handleCreateCategory = (event: FormEvent) => {
    event.preventDefault();
    if (addCategory(categoryName)) {
      setCategoryName('');
    }
  };

  const startRenameCategory = (name: string) => {
    setRenamingCategory(name);
    setRenameValue(name);
  };

  const commitRenameCategory = () => {
    if (!renamingCategory) return;
    renameCategory(renamingCategory, renameValue);
    setRenamingCategory(null);
    setRenameValue('');
  };

  const handleLeave = async () => {
    if (isEnvBrowser()) {
      setRadioState({ channel: 0 });
      setChatOpen(false);
      return;
    }
    await fetchNui('leaveChannel');
    setRadioState({ channel: 0 });
    setChatOpen(false);
  };

  const handlePower = async () => {
    if (isEnvBrowser()) {
      const next = !onRadio;
      setRadioState({ onRadio: next, channel: next ? channel : 0 });
      if (!next) setChatOpen(false);
      return;
    }
    const result = await fetchNui<'on' | 'off'>('powerButton');
    setRadioState({
      onRadio: result === 'on',
      channel: result === 'on' ? channel : 0,
    });
    if (result !== 'on') setChatOpen(false);
  };

  const handleVolume = async (direction: 'up' | 'down') => {
    if (isEnvBrowser()) {
      setRadioState({
        volume:
          direction === 'up'
            ? Math.min(100, volume + 5)
            : Math.max(5, volume - 5),
      });
      return;
    }

    const result = await fetchNui<{ ok: boolean; volume: number }>(
      direction === 'up' ? 'volumeUp' : 'volumeDown'
    );
    if (result?.volume != null) setRadioState({ volume: result.volume });
  };

  const handleToggleClicks = async () => {
    if (isEnvBrowser()) {
      setRadioState({ micClicks: !micClicks });
      return;
    }
    const result = await fetchNui<{ ok: boolean; micClicks: boolean }>('toggleClicks');
    if (result?.micClicks != null) setRadioState({ micClicks: result.micClicks });
  };

  const handleToggleAnonymous = async () => {
    if (!shadowEligible) return;
    const next = !shadowEnabled;
    setRadioState({ shadowEnabled: next });
    if (!isEnvBrowser()) {
      await fetchNui('setAnonymous', { enabled: next });
    }
  };

  const handleToggleMute = async () => {
    const next = !muted;
    setMuted(next);
    if (!isEnvBrowser()) {
      await fetchNui('toggleMute', { muted: next });
    }
  };

  const handleToggleDeafen = async () => {
    const next = !deafened;
    setDeafened(next);
    if (!isEnvBrowser()) {
      const result = await fetchNui<{ ok: boolean; deafened: boolean; volume?: number }>(
        'toggleDeafen',
        { deafened: next }
      );
      if (result?.volume != null) {
        setRadioState({ volume: result.volume });
      }
    }
  };

  const handleSendChat = async (event: FormEvent) => {
    event.preventDefault();
    const text = chatDraft.trim();
    if (!text || !connected) return;

    addMessage({
      author: profile.name,
      message: text,
      self: true,
    });
    setChatDraft('');

    if (!isEnvBrowser()) {
      await fetchNui('sendChatMessage', {
        channel,
        message: text,
      });
    }
  };

  const openTab = (tab: RadioTab) => {
    setActiveTab(tab);
    if (tab === 'settings') setShowJoinForm(false);
  };

  const handleCloseMenu = async () => {
    if (isEnvBrowser()) {
      useAppVisibilityStore.getState().setVisibility(false);
      return;
    }
    await fetchNui('escape');
  };

  if (!render && !connected) return null;

  const showOverlay = !visible && connected && showMemberList;

  return (
    <>
      {showOverlay ? (
        <div className="radio-hud">
          <div className="radio-hud__top">
            <span className="radio-hud__icon">
              <Megaphone size={13} strokeWidth={2.2} />
            </span>
            <p className="radio-hud__channel">{channelLabel}</p>
            <span className="radio-hud__count">
              {members.length.toString().padStart(2, '0')}
            </span>
          </div>
          <div className="radio-hud__members">
            {members.length === 0 ? (
              <p className="radio-hud__empty">Waiting for members...</p>
            ) : (
              members.map((member) => (
                <div
                  key={member.id}
                  className={`radio-hud__member${member.talking ? ' radio-hud__member--talking' : ''}`}
                >
                  <span className="radio-hud__icon radio-hud__icon--sm">
                    <User size={12} strokeWidth={2.2} />
                  </span>
                  <span className="radio-hud__member-name">{member.name}</span>
                  {member.talking ? (
                    <span className="radio-talking-icon" title="Talking" aria-label="Talking">
                      <AudioLines size={13} strokeWidth={2.4} />
                    </span>
                  ) : (
                    <span className="radio-members__dot" />
                  )}
                </div>
              ))
            )}
          </div>
        </div>
      ) : null}

      {render ? (
        <div
          className={`radio-shell${open ? ' radio-shell--open' : ''}${chatOpen ? ' radio-shell--chat' : ''}`}
        >
          {chatOpen && connected ? (
            <section className="radio-side radio-side--chat">
              <div className="radio-chat__header">
                <h3 className="radio-chat__title">
                  <span className="radio-chat__hash">#</span>
                  {channelLabel}
                </h3>
                <button
                  type="button"
                  className="radio-btn radio-btn--icon"
                  onClick={() => setChatOpen(false)}
                  aria-label="Close chat"
                >
                  <X size={15} strokeWidth={2.2} />
                </button>
              </div>

              <div className="radio-chat__messages">
                {messages.length === 0 ? (
                  <div className="radio-empty">No messages yet. Say hello on this frequency.</div>
                ) : (
                  messages.map((msg) => (
                    <div key={msg.id}>
                      <p
                        className={`radio-chat__msg-author${msg.self ? ' radio-chat__msg-author--self' : ''}`}
                      >
                        {msg.author}
                      </p>
                      <p className="radio-chat__msg-text">{msg.message}</p>
                    </div>
                  ))
                )}
                <div ref={chatEndRef} />
              </div>

              <form className="radio-chat__input-row" onSubmit={handleSendChat}>
                <input
                  className="radio-field radio-field--square"
                  type="text"
                  placeholder={`Message #${channelLabel}`}
                  value={chatDraft}
                  onChange={(e) => setChatDraft(e.target.value)}
                  maxLength={180}
                />
                <button
                  type="submit"
                  className="radio-btn radio-btn--icon radio-btn--ghost-active"
                  aria-label="Send message"
                  disabled={!chatDraft.trim()}
                >
                  <Send size={15} strokeWidth={2.2} />
                </button>
              </form>
            </section>
          ) : null}

          {chatOpen && connected ? (
            <section className="radio-side radio-side--members">
              <div className="radio-members__header">
                <h3 className="radio-members__title">Members</h3>
                <span className="radio-tag">{members.length.toString().padStart(2, '0')}</span>
              </div>
              <div className="radio-members__list">
                {members.length === 0 ? (
                  <div className="radio-empty">No members online.</div>
                ) : (
                  members.map((member) => (
                    <div
                      key={member.id}
                      className={`radio-members__item${member.talking ? ' radio-members__item--talking' : ''}`}
                    >
                      <span className="radio-user-icon">
                        <User size={14} strokeWidth={2.2} />
                      </span>
                      <p className="radio-members__name">{member.name}</p>
                      <span
                        className={`radio-members__dot${member.talking ? ' radio-members__dot--talking' : ''}`}
                      />
                    </div>
                  ))
                )}
              </div>
            </section>
          ) : null}

          <section className="radio-panel">
            <div className="radio-panel__header">
              <div className="radio-panel__logo">
                <Radio size={18} strokeWidth={2.2} />
              </div>
              <div className="radio-panel__header-text">
                <h2 className="radio-panel__title">Radio Menu</h2>
                <p className="radio-panel__subtitle">Frequencies & voice</p>
              </div>
              <div className="radio-panel__header-actions">
                <button
                  type="button"
                  className="radio-btn radio-btn--icon"
                  onClick={() => void handleCloseMenu()}
                  aria-label="Close menu"
                  title="Close menu (Esc)"
                >
                  <X size={15} strokeWidth={2.2} />
                </button>
                <button
                  type="button"
                  className={`radio-btn radio-btn--power${onRadio ? ' radio-btn--power-on' : ''}`}
                  onClick={() => void handlePower()}
                  aria-label={onRadio ? 'Turn radio off' : 'Turn radio on'}
                  title={onRadio ? 'Power off' : 'Power on'}
                >
                  <Power size={16} strokeWidth={2.3} />
                </button>
              </div>
            </div>

            <div className="radio-tabs radio-tabs--two">
              <button
                type="button"
                className={`radio-tabs__item${activeTab === 'frequencies' ? ' radio-tabs__item--active' : ''}`}
                onClick={() => {
                  openTab('frequencies');
                }}
              >
                Frequencies
              </button>
              <button
                type="button"
                className={`radio-tabs__item${activeTab === 'settings' ? ' radio-tabs__item--active' : ''}`}
                onClick={() => openTab('settings')}
              >
                Settings
              </button>
            </div>

            {activeTab === 'frequencies' ? (
              <>
                <div className="radio-toolbar">
                  <div className="radio-search-row">
                    <div className="radio-search-wrap">
                      <Search size={14} strokeWidth={2.2} />
                      <input
                        className="radio-field"
                        type="text"
                        placeholder="Search"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                      />
                    </div>
                    <button
                      type="button"
                      className={`radio-btn radio-btn--icon${showCategoryForm ? ' radio-btn--ghost-active' : ''}`}
                      onClick={() => {
                        setShowCategoryForm(!showCategoryForm);
                        setShowJoinForm(false);
                        setActiveTab('frequencies');
                      }}
                      title="New category"
                      aria-label="Create category"
                    >
                      <FolderPlus size={15} strokeWidth={2.2} />
                    </button>
                    <button
                      type="button"
                      className={`radio-btn radio-btn--icon${showJoinForm ? ' radio-btn--ghost-active' : ''}`}
                      onClick={() => {
                        setShowJoinForm(!showJoinForm);
                        setShowCategoryForm(false);
                        setActiveTab('frequencies');
                      }}
                      title="Join / create channel"
                      aria-label="Add voice channel"
                    >
                      <Plus size={15} strokeWidth={2.4} />
                    </button>
                  </div>

                  {showJoinForm ? (
                    <form className="radio-join-form" onSubmit={handleJoinSubmit}>
                      <input
                        className="radio-field radio-field--square"
                        type="text"
                        placeholder="Radio name"
                        value={joinName}
                        onChange={(e) => setJoinName(e.target.value)}
                        maxLength={32}
                        autoFocus
                      />
                      {categories.length > 0 ? (
                        <div className="radio-dropdown" ref={categoryMenuRef}>
                          <button
                            type="button"
                            className={`radio-dropdown__trigger${categoryMenuOpen ? ' radio-dropdown__trigger--open' : ''}`}
                            onClick={() => setCategoryMenuOpen((open) => !open)}
                            aria-haspopup="listbox"
                            aria-expanded={categoryMenuOpen}
                          >
                            <span className="radio-user-icon radio-user-icon--sm">
                              <FolderPlus size={12} strokeWidth={2.2} />
                            </span>
                            <span className="radio-dropdown__value">
                              {joinCategory || 'Select category'}
                            </span>
                            <ChevronDown size={14} strokeWidth={2.2} />
                          </button>
                          {categoryMenuOpen ? (
                            <div className="radio-dropdown__menu" role="listbox">
                              {categories.map((cat) => (
                                <button
                                  key={cat}
                                  type="button"
                                  role="option"
                                  aria-selected={joinCategory === cat}
                                  className={`radio-dropdown__option${joinCategory === cat ? ' radio-dropdown__option--active' : ''}`}
                                  onClick={() => {
                                    setJoinCategory(cat);
                                    setCategoryMenuOpen(false);
                                  }}
                                >
                                  <span className="radio-user-icon radio-user-icon--sm">
                                    <Signal size={11} strokeWidth={2.2} />
                                  </span>
                                  {cat}
                                </button>
                              ))}
                            </div>
                          ) : null}
                        </div>
                      ) : (
                        <p className="radio-category__empty" style={{ padding: '0 2px' }}>
                          Create a category first, then join.
                        </p>
                      )}
                      <div className="radio-join-row">
                        <input
                          className="radio-field radio-field--square"
                          type="text"
                          inputMode="decimal"
                          placeholder="Enter code"
                          value={joinValue}
                          onChange={(e) => setJoinValue(e.target.value)}
                        />
                        <button
                          type="submit"
                          className="radio-btn radio-btn--join"
                          disabled={!categories.length}
                        >
                          Join
                        </button>
                      </div>
                    </form>
                  ) : null}

                  {showCategoryForm ? (
                    <form className="radio-join-form" onSubmit={handleCreateCategory}>
                      <div className="radio-join-row">
                        <input
                          className="radio-field radio-field--square"
                          type="text"
                          placeholder="Category name"
                          value={categoryName}
                          onChange={(e) => setCategoryName(e.target.value)}
                          maxLength={24}
                          autoFocus
                        />
                        <button type="submit" className="radio-btn radio-btn--join">
                          Add
                        </button>
                      </div>
                    </form>
                  ) : null}
                </div>

                <div className="radio-list">
                  {groups.length === 0 ? (
                    <div className="radio-empty">
                      Create a category, then press + to join a channel.
                    </div>
                  ) : (
                    groups.map((group) => (
                      <div key={group.category} className="radio-category">
                        <div className="radio-category__header">
                          <span className="radio-category__icon">
                            <Signal size={12} strokeWidth={2.4} />
                          </span>
                          {renamingCategory === group.category ? (
                            <input
                              className="radio-field radio-field--square radio-category__rename"
                              type="text"
                              value={renameValue}
                              onChange={(e) => setRenameValue(e.target.value)}
                              onBlur={commitRenameCategory}
                              onKeyDown={(e) => {
                                if (e.key === 'Enter') {
                                  e.preventDefault();
                                  commitRenameCategory();
                                }
                                if (e.key === 'Escape') {
                                  setRenamingCategory(null);
                                  setRenameValue('');
                                }
                              }}
                              maxLength={24}
                              autoFocus
                            />
                          ) : (
                            <p className="radio-category__name">{group.category}</p>
                          )}
                          <button
                            type="button"
                            className="radio-btn radio-btn--icon"
                            style={{ width: 26, height: 26 }}
                            onClick={() => startRenameCategory(group.category)}
                            aria-label={`Rename ${group.category}`}
                            title="Rename category"
                          >
                            <Pencil size={12} strokeWidth={2.2} />
                          </button>
                          <button
                            type="button"
                            className="radio-btn radio-btn--icon radio-channel__remove"
                            onClick={() => removeCategory(group.category)}
                            aria-label={`Remove ${group.category}`}
                            title="Delete category"
                          >
                            <Trash2 size={12} strokeWidth={2.2} />
                          </button>
                        </div>

                        {group.items.length === 0 ? (
                          <div className="radio-category__empty">No channels yet</div>
                        ) : null}

                        {group.items.map((fav) => {
                          const isActive = connected && fav.channel === channel;
                          const showMembers = isActive && membersExpanded && channelMembers.length > 0;

                          return (
                            <div
                              key={fav.id}
                              className={`radio-channel${isActive ? ' radio-channel--active' : ''}${showMembers ? ' radio-channel--expanded' : ''}`}
                            >
                              <div className="radio-channel__row">
                                <button
                                  type="button"
                                  className="radio-channel__main"
                                  onClick={() => handleChannelClick(fav.channel)}
                                  aria-expanded={isActive ? membersExpanded : undefined}
                                  title={
                                    isActive
                                      ? membersExpanded
                                        ? 'Hide members'
                                        : 'Show members'
                                      : 'Join channel'
                                  }
                                >
                                  <span className="radio-channel__icon">
                                    <Megaphone size={14} strokeWidth={2.2} />
                                  </span>
                                  <span className="radio-channel__body">
                                    <p className="radio-channel__name">{fav.label}</p>
                                  </span>
                                  <span className="radio-channel__freq">
                                    {formatChannel(fav.channel)}
                                  </span>
                                </button>
                                <button
                                  type="button"
                                  className="radio-btn radio-btn--icon radio-channel__remove"
                                  onClick={() => removeFavorite(fav.id)}
                                  aria-label={`Remove ${fav.label}`}
                                  title="Remove"
                                >
                                  <Trash2 size={12} strokeWidth={2.2} />
                                </button>
                              </div>

                              {showMembers
                                ? channelMembers.map((member) => (
                                    <div
                                      key={member.id}
                                      className={`radio-channel__member${member.talking ? ' radio-channel__member--talking' : ''}`}
                                    >
                                      <span className="radio-user-icon radio-user-icon--sm">
                                        <User size={12} strokeWidth={2.2} />
                                      </span>
                                      <p className="radio-channel__member-name">{member.name}</p>
                                      {member.talking ? (
                                        <span className="radio-talking-icon" title="Talking" aria-label="Talking">
                                          <AudioLines size={13} strokeWidth={2.4} />
                                        </span>
                                      ) : (
                                        <span className={`radio-tag${member.self ? ' radio-tag--green' : ''}`}>
                                          {member.tag || (member.self ? 'Member' : 'Joined')}
                                        </span>
                                      )}
                                    </div>
                                  ))
                                : null}
                            </div>
                          );
                        })}
                      </div>
                    ))
                  )}
                </div>
              </>
            ) : (
              <div className="radio-settings">
                <div className="radio-setting radio-setting--column">
                  <div>
                    <p className="radio-setting__title">Display Name</p>
                    <p className="radio-setting__desc">Shown in radio & chat</p>
                  </div>
                  <input
                    className="radio-field radio-field--square"
                    type="text"
                    value={profile.name}
                    onChange={(e) => setProfileName(e.target.value)}
                    placeholder="Your name"
                    maxLength={32}
                  />
                </div>

                <div className="radio-setting">
                  <div>
                    <p className="radio-setting__title">Volume</p>
                    <p className="radio-setting__desc">Radio voice volume</p>
                  </div>
                  <div className="radio-volume">
                    <button
                      type="button"
                      className="radio-btn radio-btn--icon"
                      onClick={() => void handleVolume('down')}
                      aria-label="Volume down"
                    >
                      <VolumeX size={15} strokeWidth={2.2} />
                    </button>
                    <span className="radio-volume__value">{volume}%</span>
                    <button
                      type="button"
                      className="radio-btn radio-btn--icon"
                      onClick={() => void handleVolume('up')}
                      aria-label="Volume up"
                    >
                      <Volume2 size={15} strokeWidth={2.2} />
                    </button>
                  </div>
                </div>

                <div className="radio-setting">
                  <div>
                    <p className="radio-setting__title">Mic Clicks</p>
                    <p className="radio-setting__desc">Click sounds when talking</p>
                  </div>
                  <button
                    type="button"
                    className={`radio-toggle${micClicks ? ' radio-toggle--on' : ''}`}
                    onClick={() => void handleToggleClicks()}
                    aria-pressed={micClicks}
                    aria-label="Toggle mic clicks"
                  >
                    <span className="radio-toggle__knob" />
                  </button>
                </div>

                <div className="radio-setting">
                  <div>
                    <p className="radio-setting__title">Member List</p>
                    <p className="radio-setting__desc">
                      Show members when menu is closed
                    </p>
                  </div>
                  <button
                    type="button"
                    className={`radio-toggle${showMemberList ? ' radio-toggle--on' : ''}`}
                    onClick={() => setShowMemberList(!showMemberList)}
                    aria-pressed={showMemberList}
                    aria-label="Toggle member list overlay"
                  >
                    <span className="radio-toggle__knob" />
                  </button>
                </div>

                <div className={`radio-setting${!shadowEligible ? ' radio-setting--disabled' : ''}`}>
                  <div>
                    <p className="radio-setting__title">Anonymous</p>
                    <p className="radio-setting__desc">
                      {shadowEligible
                        ? "Hide yourself from other channel members' lists"
                        : 'Requires a shadow module in your radio storage'}
                    </p>
                  </div>
                  <button
                    type="button"
                    className={`radio-toggle${shadowEnabled ? ' radio-toggle--on' : ''}`}
                    onClick={() => void handleToggleAnonymous()}
                    disabled={!shadowEligible}
                    aria-pressed={shadowEnabled}
                    aria-label="Toggle anonymous mode"
                  >
                    <span className="radio-toggle__knob" />
                  </button>
                </div>
              </div>
            )}

            <div className={`radio-status${connected ? '' : ' radio-status--off'}`}>
              <span className="radio-status__icon">
                <Signal size={16} strokeWidth={2.2} />
              </span>
              <div className="radio-status__text">
                <p className="radio-status__title">
                  {!onRadio ? 'Radio Off' : connected ? 'Voice Connected' : 'Not Connected'}
                </p>
                <p className="radio-status__channel">
                  {connected ? channelLabel : 'Join a frequency to start'}
                </p>
              </div>
              <button
                type="button"
                className="radio-btn radio-btn--hangup"
                onClick={() => void handleLeave()}
                disabled={!connected}
                aria-label="Leave channel"
                title="Disconnect"
              >
                <PhoneOff size={15} strokeWidth={2.2} />
              </button>
            </div>

            <div className="radio-userbar">
              <div className="radio-userbar__icon">
                <User size={18} strokeWidth={2.2} />
              </div>
              <div className="radio-userbar__info">
                <p className="radio-userbar__name">{profile.name}</p>
                <p className="radio-userbar__tag">{profile.tag}</p>
              </div>
              <div className="radio-userbar__controls">
                <button
                  type="button"
                  className={`radio-btn radio-btn--icon${muted ? ' radio-btn--mic-off' : ' radio-btn--mic'}`}
                  onClick={() => void handleToggleMute()}
                  aria-label={muted ? 'Unmute mic' : 'Mute mic'}
                  title={muted ? 'Unmute (can talk)' : 'Mute (cannot talk)'}
                >
                  {muted ? <MicOff size={14} strokeWidth={2.2} /> : <Mic size={14} strokeWidth={2.2} />}
                </button>
                <button
                  type="button"
                  className={`radio-btn radio-btn--icon${deafened ? ' radio-btn--mic-off' : ''}`}
                  onClick={() => void handleToggleDeafen()}
                  aria-label={deafened ? 'Undeafen radio' : 'Deafen radio'}
                  title={deafened ? 'Undeafen (hear radio)' : 'Deafen (hear nothing)'}
                >
                  <Headphones size={14} strokeWidth={2.2} />
                </button>
              </div>
            </div>
          </section>
        </div>
      ) : null}
    </>
  );
}
