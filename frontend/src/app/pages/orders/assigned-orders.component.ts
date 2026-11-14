import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { ApiStore } from '../../core/api.store';
import { OrderPriority, OrderStatus, ServiceOrder } from '../../core/service-order.models';
import { ServiceOrderService } from '../../core/service-order.service';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-assigned-orders',
  standalone: true,
  imports: [FormsModule, IconComponent, RouterLink],
  templateUrl: './assigned-orders.component.html',
})
export class AssignedOrdersComponent implements OnInit {
  private readonly orderService = inject(ServiceOrderService);
  private readonly router = inject(Router);
  private readonly apiStore = inject(ApiStore);
  protected readonly busy = this.apiStore.pending;
  protected readonly orders = this.orderService.assignedOrders;
  private readonly search = signal('');
  private readonly status = signal<OrderStatus | ''>('');
  protected get searchTerm(): string { return this.search(); }
  protected set searchTerm(value: string) { this.search.set(value); }
  protected get statusFilter(): OrderStatus | '' { return this.status(); }
  protected set statusFilter(value: OrderStatus | '') { this.status.set(value); }
  protected error = '';
  protected readonly filteredOrders = computed(() => {
    const query = this.searchTerm.trim().toLocaleLowerCase();
    return this.orders().filter((order) =>
      (!query || order.code.toLocaleLowerCase().includes(query))
      && (!this.statusFilter || order.status === this.statusFilter));
  });

  ngOnInit(): void {
    void this.refresh();
  }

  protected async refresh(): Promise<void> {
    this.error = '';
    try {
      await this.orderService.loadAssigned();
    } catch {
      this.error = 'No se pudieron cargar tus órdenes asignadas.';
    }
  }

  protected async attend(order: ServiceOrder): Promise<void> {
    await this.router.navigate(['/atencion', order.id]);
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

  protected equipmentName(order: { equipmentType: string; brand: string; model: string }): string {
    return `${order.equipmentType} ${order.brand} ${order.model}`.trim();
  }
}
