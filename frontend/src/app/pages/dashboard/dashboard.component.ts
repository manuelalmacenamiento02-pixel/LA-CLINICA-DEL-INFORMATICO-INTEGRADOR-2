import { computed, Component, inject, OnInit, signal } from '@angular/core';
import { IconComponent, IconName } from '../../shared/icon/icon.component';
import { ApiStore } from '../../core/api.store';
import { Permission } from '../../core/user.models';
import {
  DashboardIndicators,
  SprintSixService,
  sprintSixErrorMessage,
} from '../../core/sprint-six.service';

interface DashboardStat {
  label: string;
  value: number | '—';
  caption: string;
  icon: IconName;
  color: string;
}

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [IconComponent],
  templateUrl: './dashboard.component.html',
})
export class DashboardComponent implements OnInit {
  private readonly store = inject(ApiStore);
  private readonly sprintSixService = inject(SprintSixService);
  protected readonly orderIndicators = signal<DashboardIndicators | null>(null);
  protected readonly indicatorError = signal('');
  protected readonly canViewOrderIndicators = computed(() => {
    const user = this.store.user();
    return !!user && this.store.permissions()[user.role].includes('service-indicators');
  });
  protected readonly today = new Intl.DateTimeFormat('es', { dateStyle: 'long' }).format(new Date());
  protected readonly isTechnician = computed(() => this.store.user()?.role === 'TÉCNICO');
  protected readonly technicianOrders = this.store.technicianOrders.asReadonly();
  protected readonly priorityStats = computed(() => {
    const orders = this.technicianOrders();
    return [
      {
        label: 'Atención inmediata',
        detail: 'Atender primero',
        value: orders.filter((order) => order.priority === 'ALTA' || order.priority === 'URGENTE').length,
        color: 'critical',
      },
      {
        label: 'Atención regular',
        detail: 'Atender después',
        value: orders.filter((order) => order.priority === 'NORMAL').length,
        color: 'medium',
      },
      {
        label: 'Atención programada',
        detail: 'Hay tiempo para revisar',
        value: orders.filter((order) => order.priority === 'BAJA').length,
        color: 'low',
      },
    ];
  });
  protected readonly stats = computed<DashboardStat[]>(() => {
    const user = this.store.user();
    const permissions = user ? this.store.permissions()[user.role] : [];
    const can = (permission: Permission) => permissions.includes(permission);
    const clients = this.store.clients();
    const equipment = this.store.equipment();

    return [
      {
        label: 'Clientes registrados',
        value: can('clients') ? clients.length : '—',
        caption: can('clients') ? 'Registros en la base de datos' : 'No tienes permiso para ver este total',
        icon: 'users',
        color: '',
      },
      {
        label: 'Equipos registrados',
        value: can('equipment') ? equipment.length : '—',
        caption: can('equipment') ? 'Registros en la base de datos' : 'No tienes permiso para ver este total',
        icon: 'laptop',
        color: 'active',
      },
      {
        label: 'Usuarios activos',
        value: can('users') ? this.store.users().filter((item) => item.active).length : '—',
        caption: can('users') ? 'Cuentas habilitadas en el sistema' : 'No tienes permiso para ver este total',
        icon: 'shield',
        color: 'completed',
      },
      {
        label: 'Clientes con equipos',
        value: can('clients') && can('equipment')
          ? new Set(equipment.map((item) => item.clientId)).size
          : '—',
        caption: can('clients') && can('equipment')
          ? 'Clientes con al menos un equipo registrado'
          : 'Se requiere acceso a clientes y equipos',
        icon: 'check',
        color: 'pending',
      },
    ];
  });

  protected priorityLabel(priority: string): string {
    switch (priority) {
      case 'URGENTE':
        return 'Urgente';
      case 'ALTA':
        return 'Alta';
      case 'NORMAL':
        return 'Media';
      default:
        return 'Baja';
    }
  }

  protected priorityClass(priority: string): string {
    if (priority === 'URGENTE' || priority === 'ALTA') return 'critical';
    return priority === 'NORMAL' ? 'medium' : 'low';
  }

  protected statusLabel(status: string): string {
    switch (status) {
      case 'PENDIENTE':
        return 'Pendiente';
      case 'ASIGNADA':
        return 'Asignada';
      case 'EN_ATENCION':
        return 'En atención';
      case 'FINALIZADA':
        return 'Finalizada';
      default:
        return status;
    }
  }

  ngOnInit(): void {
    if (this.canViewOrderIndicators()) void this.loadOrderIndicators();
  }

  protected async loadOrderIndicators(): Promise<void> {
    this.indicatorError.set('');
    try {
      this.orderIndicators.set(await this.sprintSixService.dashboard());
    } catch (error) {
      this.indicatorError.set(sprintSixErrorMessage(error));
    }
  }

  protected monthWidth(value: number): number {
    const values = this.orderIndicators()?.byMonth ?? [];
    const maximum = Math.max(1, ...values.map((item) => item.total));
    return (value / maximum) * 100;
  }

  protected monthLabel(month: string): string {
    const [year, monthNumber] = month.split('-').map(Number);
    return new Intl.DateTimeFormat('es', { month: 'short', year: 'numeric' })
      .format(new Date(year, monthNumber - 1, 1));
  }

  protected orderStatusLabel(status: string): string {
    switch (status) {
      case 'PENDIENTE': return 'Pendiente';
      case 'ASIGNADA': return 'Asignada';
      case 'EN_ATENCION': return 'En atención';
      case 'FINALIZADA': return 'Finalizada';
      case 'CERRADA': return 'Cerrada';
      case 'CANCELADA': return 'Cancelada';
      default: return status;
    }
  }
}
