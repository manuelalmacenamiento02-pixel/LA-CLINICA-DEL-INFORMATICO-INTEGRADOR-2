import { ApiStore } from '../../core/api.store';
import { Component, inject } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { AuthService } from '../../core/auth.service';
import {
  displayRoleName,
  PERMISSION_CATALOG,
  Permission,
  SystemUser,
  USER_ROLES,
  UserDraft,
  UserRole,
} from '../../core/user.models';
import { PermissionsService } from '../../core/permissions.service';
import { UserSaveResult, UserService } from '../../core/user.service';
import { IconComponent } from '../../shared/icon/icon.component';

type UsersTab = 'users' | 'permissions';
type UserModalMode = 'create' | 'edit' | 'view';

@Component({
  selector: 'app-users',
  standalone: true,
  imports: [FormsModule, IconComponent],
  templateUrl: './users.component.html',
})
export class UsersComponent {
  protected readonly busy = inject(ApiStore).pending;
  private readonly userService = inject(UserService);
  private readonly authService = inject(AuthService);
  private readonly permissionsService = inject(PermissionsService);

  protected readonly roles = USER_ROLES;
  protected readonly permissionCatalog = PERMISSION_CATALOG;
  protected readonly users = this.userService.users;
  protected filteredUsers(): SystemUser[] {
    const query = this.searchTerm.trim().toLocaleLowerCase();
    return this.users().filter((user) => {
      const values = [user.firstName, user.lastName, user.username, user.role];
      return !query || values.some((value) => value.toLocaleLowerCase().includes(query));
    });
  }
  protected get userCountLabel(): string {
    const count = this.filteredUsers().length;
    return `${count} ${count === 1 ? 'usuario' : 'usuarios'}`;
  }
  protected activeTab: UsersTab = 'users';
  protected searchTerm = '';
  protected isModalOpen = false;
  protected modalMode: UserModalMode = 'create';
  protected submitted = false;
  protected duplicateUsername = false;
  protected formError = '';
  protected actionError = '';
  protected permissionError = '';
  protected selectedRole: UserRole = 'ADMINISTRADOR';
  protected selectedUserId: string | null = null;
  protected passwordVisible = false;
  protected confirmPasswordVisible = false;
  protected draft: UserDraft = this.emptyDraft();
  protected confirmPassword = '';

  protected selectTab(tab: UsersTab): void {
    this.activeTab = tab;
  }

  protected openCreate(): void {
    this.openForm('create');
  }

  protected openEdit(user: SystemUser): void {
    this.openForm('edit', user);
  }

  protected openView(user: SystemUser): void {
    this.openForm('view', user);
  }

  protected closeModal(): void {
    this.isModalOpen = false;
  }

  protected async submitUser(form: NgForm): Promise<void> {
    if (this.busy()) return;
    this.submitted = true;
    this.duplicateUsername = false;
    this.formError = '';

    const validNames = this.draft.firstName.trim().length > 0 && this.draft.lastName.trim().length > 0;
    const validPassword = this.modalMode !== 'create' || this.draft.password.length > 0;
    const matchingPasswords =
      this.modalMode === 'view' ||
      (!this.draft.password && !this.confirmPassword && this.modalMode === 'edit') ||
      (this.draft.password.length > 0 && this.draft.password === this.confirmPassword);

    if (
      this.modalMode === 'view' ||
      !form.valid ||
      !validNames ||
      !validPassword ||
      !matchingPasswords
    ) {
      return;
    }

    let result: UserSaveResult;
    if (this.modalMode === 'create') {
      result = await this.userService.create(this.draft);
    } else if (this.selectedUserId) {
      result = await this.userService.update(this.selectedUserId, this.draft);
    } else {
      this.formError = 'No se pudo identificar el usuario que se desea editar.';
      return;
    }

    if (result === 'duplicate-username') {
      this.duplicateUsername = true;
      return;
    }
    if (result === 'storage-error') {
      this.formError = 'No se pudieron guardar los cambios en el servidor. Revisa el aviso de error.';
      return;
    }

    this.closeModal();
  }

  protected async toggleActive(user: SystemUser): Promise<void> {
    if (this.busy()) return;
    this.actionError = '';
    if (this.authService.currentUser()?.id === user.id) {
      this.actionError = 'No puedes desactivar tu propio usuario mientras tienes una sesión activa.';
      return;
    }

    const action = user.active ? 'desactivar' : 'activar';
    if (!window.confirm(`¿Deseas ${action} al usuario ${user.username}?`)) {
      return;
    }

    if (!(await this.userService.setActive(user.id, !user.active))) {
      this.actionError = 'No se pudo actualizar el estado del usuario. Inténtalo nuevamente.';
      return;
    }

    this.actionError = '';
  }

  protected async onPermissionChange(permission: Permission, event: Event): Promise<void> {
    if (this.busy()) return;
    const role = this.selectedRole;
    if (role === 'ADMINISTRADOR') {
      return;
    }

    const input = event.target;
    if (!(input instanceof HTMLInputElement)) {
      return;
    }

    const updated = await this.permissionsService.update(
      role,
      permission,
      input.checked,
    );
    this.permissionError = updated ? '' : 'No se pudieron guardar los permisos en el servidor.';
    if (!updated) {
      input.checked = !input.checked;
    }
  }

  protected isPermissionLocked(permission: Permission): boolean {
    return this.isAdministratorRole || ['dashboard', 'users', 'settings'].includes(permission);
  }

  protected rolePermissions(): Permission[] {
    return this.permissionsService.permissionsFor(this.selectedRole);
  }

  protected hasPermission(permission: Permission): boolean {
    return this.rolePermissions().includes(permission);
  }

  protected get isAdministratorRole(): boolean {
    return this.selectedRole === 'ADMINISTRADOR';
  }

  protected get modalTitle(): string {
    switch (this.modalMode) {
      case 'create':
        return 'Nuevo usuario';
      case 'edit':
        return 'Editar usuario';
      case 'view':
        return 'Detalle del usuario';
    }
  }

  protected fullName(user: SystemUser): string {
    return `${user.firstName} ${user.lastName}`;
  }

  protected displayRole(role: UserRole): string {
    return displayRoleName(role);
  }

  protected statusClass(active: boolean): string {
    return active ? 'user-status-active' : 'user-status-inactive';
  }

  private openForm(mode: UserModalMode, user?: SystemUser): void {
    this.modalMode = mode;
    this.selectedUserId = user?.id ?? null;
    this.draft = user
      ? {
          firstName: user.firstName,
          lastName: user.lastName,
          username: user.username,
          password: '',
          role: user.role,
          active: user.active,
        }
      : this.emptyDraft();
    this.confirmPassword = '';
    this.submitted = false;
    this.duplicateUsername = false;
    this.formError = '';
    this.passwordVisible = false;
    this.confirmPasswordVisible = false;
    this.isModalOpen = true;
  }

  private emptyDraft(): UserDraft {
    return {
      firstName: '',
      lastName: '',
      username: '',
      password: '',
      role: 'PERSONAL DE ATENCIÓN',
      active: true,
    };
  }
}
