import { inject, Injectable } from '@angular/core';
import { LoginResult, SystemUser } from './user.models';
import { ApiStore, apiErrorCode } from './api.store';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly store = inject(ApiStore);
  readonly currentUser = this.store.user.asReadonly();
  async signIn(username: string, password: string): Promise<LoginResult> {
    try {
      await this.store.write<SystemUser>('POST', '/auth/login', { username, password });
      await this.store.refresh(); return 'success';
    } catch (error) {
      this.store.clear();
      const code = apiErrorCode(error);
      return code === 'inactive-user' || code === 'invalid-credentials' ? code : 'storage-error';
    }
  }
  async signOut(): Promise<boolean> {
    try { await this.store.write('POST', '/auth/logout'); this.store.clear(); return true; }
    catch { return false; }
  }
  hasSession(): boolean { return this.currentUser() !== null; }
}

export function displayUserName(user: SystemUser): string { return `${user.firstName} ${user.lastName}`; }
