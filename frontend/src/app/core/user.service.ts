import { computed, inject, Injectable } from '@angular/core';
import { SystemUser, UserDraft } from './user.models';
import { ApiStore, apiErrorCode } from './api.store';

export type UserSaveResult = 'success' | 'duplicate-username' | 'storage-error';

@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly store = inject(ApiStore);
  readonly users = this.store.users.asReadonly();
  readonly activeUsers = computed(() => this.users().filter(user => user.active));
  findById(id: string): SystemUser | undefined { return this.users().find(user => user.id === id); }
  findByUsername(username: string): SystemUser | undefined {
    return this.users().find(user => user.username.toLowerCase() === username.trim().toLowerCase());
  }
  async create(draft: UserDraft): Promise<UserSaveResult> { return this.save('POST', '/users', draft); }
  async update(id: string, draft: UserDraft): Promise<UserSaveResult> { return this.save('PUT', '/users/' + id, draft); }
  private async save(method: string, path: string, draft: UserDraft): Promise<UserSaveResult> {
    try {
      const user = await this.store.write<SystemUser>(method, path, draft);
      this.acceptUser(user, method === 'POST'); return 'success';
    } catch (error) { return apiErrorCode(error) === 'duplicate-username' ? 'duplicate-username' : 'storage-error'; }
  }
  private acceptUser(user: SystemUser, create = false): void {
    this.store.users.update(items => create ? [...items, user] : items.map(old => old.id === user.id ? user : old));
    if (this.store.user()?.id === user.id) this.store.user.set(user);
  }
  async setActive(id: string, active: boolean): Promise<boolean> {
    try { this.acceptUser(await this.store.write<SystemUser>('PATCH', '/users/' + id + '/active', { active })); return true; }
    catch { return false; }
  }
}
