import { Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { ApiStore } from '../../core/api.store';
import { AuthService, displayUserName } from '../../core/auth.service';
import { displayRoleName, Permission } from '../../core/user.models';
import { PermissionsService } from '../../core/permissions.service';
import { IconComponent, IconName } from '../icon/icon.component';

interface NavigationItem {
  label: string;
  path: string;
  icon: IconName;
  permission: Permission;
}

@Component({
  selector: 'app-main-layout',
  standalone: true,
  imports: [IconComponent, RouterLink, RouterLinkActive, RouterOutlet],
  templateUrl: './main-layout.component.html',
})
export class MainLayoutComponent {
  protected readonly serverError = inject(ApiStore).error;
  protected readonly menuOpen = signal(false);
  private readonly authService = inject(AuthService);
  private readonly permissionsService = inject(PermissionsService);
  private readonly router = inject(Router);
  protected readonly currentUser = this.authService.currentUser;
  protected readonly profileName = computed(() => {
    const user = this.currentUser();
    return user ? displayUserName(user) : '';
  });
  protected readonly profileRole = computed(() => {
    const role = this.currentUser()?.role;
    return role ? displayRoleName(role) : '';
  });
  protected readonly profileInitials = computed(() => {
    const user = this.currentUser();
    return user ? `${user.firstName.charAt(0)}${user.lastName.charAt(0)}`.toLocaleUpperCase() : '';
  });

  private readonly allPrimaryNavigation: NavigationItem[] = [
    { label: 'Inicio', path: '/dashboard', icon: 'home', permission: 'dashboard' },
    { label: 'Clientes', path: '/clientes', icon: 'users', permission: 'clients' },
    { label: 'Equipos', path: '/equipos', icon: 'laptop', permission: 'equipment' },
    { label: 'Órdenes de Servicio', path: '/ordenes', icon: 'clipboard', permission: 'orders' },
    {
      label: 'Mis Órdenes Asignadas',
      path: '/mis-ordenes',
      icon: 'wrench',
      permission: 'assigned-orders',
    },
    {
      label: 'Prediagnóstico con IA',
      path: '/prediagnostico',
      icon: 'sparkles',
      permission: 'ai-prediagnosis',
    },
    {
      label: 'Seguimiento de Servicio',
      path: '/seguimiento',
      icon: 'search',
      permission: 'service-tracking',
    },
    {
      label: 'Indicadores de Servicios',
      path: '/indicadores',
      icon: 'chart',
      permission: 'service-indicators',
    },
    { label: 'Usuarios', path: '/usuarios', icon: 'users', permission: 'users' },
  ];

  protected readonly primaryNavigation = computed(() => {
    const role = this.currentUser()?.role;
    return role
      ? this.allPrimaryNavigation.filter((item) => this.permissionsService.can(role, item.permission))
      : [];
  });

  protected readonly settingsNavigation = computed(() => {
    const role = this.currentUser()?.role;
    return role && this.permissionsService.can(role, 'settings')
      ? [
          { label: 'Auditoría', path: '/auditoria', icon: 'clipboard' as const },
          { label: 'Respaldos', path: '/respaldos', icon: 'shield' as const },
          { label: 'Monitoreo', path: '/monitoreo', icon: 'chart' as const },
          { label: 'Configuración', path: '/configuracion', icon: 'settings' as const },
        ]
      : [];
  });

  protected get hasSettingsNavigation(): boolean {
    return this.settingsNavigation().length > 0;
  }

  protected async signOut(): Promise<void> {
    if (!(await this.authService.signOut())) return;
    void this.router.navigateByUrl('/login');
  }

  protected closeMenu(): void {
    this.menuOpen.set(false);
  }

}
