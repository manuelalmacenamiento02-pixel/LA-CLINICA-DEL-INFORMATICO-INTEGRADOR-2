import { Component, Input } from '@angular/core';

export type IconName =
  | 'home'
  | 'users'
  | 'laptop'
  | 'clipboard'
  | 'wrench'
  | 'sparkles'
  | 'search'
  | 'chart'
  | 'settings'
  | 'logout'
  | 'menu'
  | 'bell'
  | 'calendar'
  | 'check'
  | 'eye'
  | 'clock'
  | 'arrow-up'
  | 'printer'
  | 'eye-off'
  | 'plus'
  | 'edit'
  | 'trash'
  | 'user-plus'
  | 'shield'
  | 'save'
  | 'close';

@Component({
  selector: 'app-icon',
  standalone: true,
  template: `
    @switch (name) {
      @case ('home') {
        <svg viewBox="0 0 24 24"><path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z" /></svg>
      }
      @case ('users') {
        <svg viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="10" cy="7" r="4" /><path d="M20 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" /></svg>
      }
      @case ('laptop') {
        <svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="12" rx="2" /><path d="M2 20h20l-2-4H4z" /></svg>
      }
      @case ('clipboard') {
        <svg viewBox="0 0 24 24"><rect x="5" y="5" width="14" height="16" rx="2" /><path d="M9 5.5V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1.5M9 11h6M9 15h6" /></svg>
      }
      @case ('wrench') {
        <svg viewBox="0 0 24 24"><path d="M14.7 6.3a5 5 0 0 0-6.4 6.4L3 18l3 3 5.3-5.3a5 5 0 0 0 6.4-6.4L14 13l-3-3z" /></svg>
      }
      @case ('sparkles') {
        <svg viewBox="0 0 24 24"><path d="m12 3 1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 14l1 2.5 2.5 1-2.5 1L19 21l-1-2.5-2.5-1 2.5-1zM5 3l.7 1.8L7.5 5.5l-1.8.7L5 8l-.7-1.8-1.8-.7 1.8-.7z" /></svg>
      }
      @case ('search') {
        <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" /></svg>
      }
      @case ('chart') {
        <svg viewBox="0 0 24 24"><path d="M3 3v18h18M8 15l4-4 4 3 5-7" /><path d="M17 7h4v4" /></svg>
      }
      @case ('settings') {
        <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3" /><path d="m19.4 15 .1.1 1.4 1.1-1.4 2.4-1.7-.7a8 8 0 0 1-1.5.9l-.3 1.8h-2.8l-.3-1.8a8 8 0 0 1-1.5-.9l-1.7.7-1.4-2.4 1.4-1.1a7 7 0 0 1 0-1.8l-1.4-1.1 1.4-2.4 1.7.7a8 8 0 0 1 1.5-.9l.3-1.8h2.8l.3 1.8a8 8 0 0 1 1.5.9l1.7-.7 1.4 2.4-1.4 1.1a7 7 0 0 1-.1 1.7z" /></svg>
      }
      @case ('logout') {
        <svg viewBox="0 0 24 24"><path d="M10 17l5-5-5-5M15 12H3" /><path d="M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6" /></svg>
      }
      @case ('menu') {
        <svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16" /></svg>
      }
      @case ('bell') {
        <svg viewBox="0 0 24 24"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" /></svg>
      }
      @case ('calendar') {
        <svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="16" rx="2" /><path d="M16 3v4M8 3v4M3 10h18" /></svg>
      }
      @case ('check') {
        <svg viewBox="0 0 24 24"><path d="m5 12 4 4L19 6" /></svg>
      }
      @case ('eye') {
        <svg viewBox="0 0 24 24"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z" /><circle cx="12" cy="12" r="3" /></svg>
      }
      @case ('clock') {
        <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg>
      }
      @case ('arrow-up') {
        <svg viewBox="0 0 24 24"><path d="M7 17 17 7M7 7h10v10" /></svg>
      }
      @case ('printer') {
        <svg viewBox="0 0 24 24"><path d="M6 9V3h12v6M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" /><path d="M6 14h12v7H6zM18 12h.01" /></svg>
      }
      @case ('eye-off') {
        <svg viewBox="0 0 24 24"><path d="m3 3 18 18M10.6 10.6a2 2 0 0 0 2.8 2.8" /><path d="M9.9 5.2A10.8 10.8 0 0 1 12 5c6.5 0 10 7 10 7a16 16 0 0 1-3.2 4.1M6.2 6.2C3.5 8 2 12 2 12s3.5 7 10 7a10.7 10.7 0 0 0 4-.8" /></svg>
      }
      @case ('plus') {
        <svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" /></svg>
      }
      @case ('edit') {
        <svg viewBox="0 0 24 24"><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4z" /></svg>
      }
      @case ('trash') {
        <svg viewBox="0 0 24 24"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v5M14 11v5" /></svg>
      }
      @case ('user-plus') {
        <svg viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="10" cy="7" r="4" /><path d="M19 8v6M16 11h6" /></svg>
      }
      @case ('shield') {
        <svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11z" /><path d="m9 12 2 2 4-4" /></svg>
      }
      @case ('save') {
        <svg viewBox="0 0 24 24"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" /><path d="M17 21v-8H7v8M7 3v5h8" /></svg>
      }
      @case ('close') {
        <svg viewBox="0 0 24 24"><path d="m18 6-12 12M6 6l12 12" /></svg>
      }
    }
  `,
  styles: [
    `
      :host {
        display: inline-flex;
        width: 1em;
        height: 1em;
        flex: 0 0 auto;
      }

      svg {
        width: 100%;
        height: 100%;
        fill: none;
        stroke: currentColor;
        stroke-linecap: round;
        stroke-linejoin: round;
        stroke-width: 1.7;
      }
    `,
  ],
})
export class IconComponent {
  @Input({ required: true }) name!: IconName;
}
