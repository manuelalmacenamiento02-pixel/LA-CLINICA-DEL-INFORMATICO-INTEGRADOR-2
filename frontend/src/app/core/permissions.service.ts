import { inject, Injectable } from '@angular/core';
import { Permission, UserRole } from './user.models';
import { ApiStore } from './api.store';

@Injectable({ providedIn: 'root' })
export class PermissionsService {
  private readonly store = inject(ApiStore);
  permissionsFor(role: UserRole): Permission[] { return [...this.store.permissions()[role]]; }
  can(role: UserRole, permission: Permission): boolean { return this.permissionsFor(role).includes(permission); }
  async update(role: Exclude<UserRole, 'ADMINISTRADOR'>, permission: Permission, allowed: boolean): Promise<boolean> {
    try {
      this.store.permissions.set(await this.store.write<Record<UserRole, Permission[]>>('PUT', '/permissions', { role, permission, allowed }));
      return true;
    } catch { return false; }
  }
}
