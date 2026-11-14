import { DatePipe } from '@angular/common';
import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { ApiStore } from '../../core/api.store';
import { PermissionsService } from '../../core/permissions.service';
import { OrderPriority, OrderStatus, ServiceOrder } from '../../core/service-order.models';
import { ServiceOrderService } from '../../core/service-order.service';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-order-detail',
  standalone: true,
  imports: [DatePipe, IconComponent, RouterLink],
  templateUrl: './order-detail.component.html',
})
export class OrderDetailComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly service = inject(ServiceOrderService);
  private readonly store = inject(ApiStore);
  private readonly permissions = inject(PermissionsService);
  protected readonly order = signal<ServiceOrder | null>(null);
  protected readonly loading = signal(true);
  protected readonly error = signal('');
  protected readonly feedback = signal('');
  protected readonly canAttend = computed(() => {
    const user = this.store.user();
    return !!user && this.permissions.can(user.role, 'attend-orders');
  });
  protected readonly backPath = this.router.url.startsWith('/mis-ordenes') ? '/mis-ordenes' : '/ordenes';

  ngOnInit(): void {
    this.route.paramMap.subscribe((params) => {
      const id = params.get('id');
      if (id) void this.load(id);
    });
  }

  protected async startAttention(): Promise<void> {
    const current = this.order();
    if (!current || (current.status !== 'PENDIENTE' && current.status !== 'ASIGNADA') || this.loading()) return;
    await this.router.navigate(['/atencion', current.id]);
  }

  protected statusLabel(status: OrderStatus): string {
    return ({
      PENDIENTE: 'Pendiente',
      ASIGNADA: 'Asignada',
      EN_ATENCION: 'En atención',
      FINALIZADA: 'Finalizada',
      CERRADA: 'Cerrada',
      CANCELADA: 'Cancelada',
    })[status];
  }

  protected priorityLabel(priority: OrderPriority): string {
    return priority === 'MEDIA'
      ? 'Media'
      : priority.toLowerCase().replace(/^./, (letter) => letter.toUpperCase());
  }

  protected equipmentName(order: ServiceOrder): string {
    return `${order.equipmentType} ${order.brand} ${order.model}`.trim();
  }

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.error.set('');
    this.feedback.set('');
    try {
      this.order.set(await this.service.get(id));
    } catch {
      this.order.set(null);
      this.error.set('No se encontró la orden o no tienes permiso para consultarla.');
    } finally {
      this.loading.set(false);
    }
  }
}
