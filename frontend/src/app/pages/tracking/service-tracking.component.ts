import { DatePipe } from '@angular/common';
import { Component, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { OrderStatus } from '../../core/service-order.models';
import { ServiceOrderService } from '../../core/service-order.service';
import { TrackingDetail, TrackingOrder } from '../../core/sprint-five.models';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-service-tracking',
  standalone: true,
  imports: [DatePipe, FormsModule, IconComponent, RouterLink],
  templateUrl: './service-tracking.component.html',
})
export class ServiceTrackingComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly service = inject(ServiceOrderService);
  protected readonly orders = signal<TrackingOrder[]>([]);
  protected readonly detail = signal<TrackingDetail | null>(null);
  protected readonly loading = signal(true);
  protected readonly error = signal('');
  protected search = '';
  protected status = '';

  ngOnInit(): void {
    this.route.paramMap.subscribe((params) => {
      const orderId = params.get('id');
      if (orderId) void this.loadDetail(orderId);
      else void this.loadOrders();
    });
  }

  protected async searchOrders(): Promise<void> {
    await this.loadOrders();
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

  protected currentStep(status: OrderStatus): string {
    if (status === 'PENDIENTE') return 'ORDEN_REGISTRADA';
    if (status === 'ASIGNADA') return 'TECNICO_ASIGNADO';
    if (status === 'EN_ATENCION') return 'EN_ATENCION';
    return status === 'FINALIZADA' || status === 'CERRADA' ? 'FINALIZADA' : '';
  }

  private async loadOrders(): Promise<void> {
    this.loading.set(true);
    this.error.set('');
    this.detail.set(null);
    try {
      this.orders.set(await this.service.getTrackingOrders(this.search, this.status));
    } catch {
      this.orders.set([]);
      this.error.set('No se pudieron consultar las órdenes de seguimiento.');
    } finally {
      this.loading.set(false);
    }
  }

  private async loadDetail(id: string): Promise<void> {
    this.loading.set(true);
    this.error.set('');
    try {
      this.detail.set(await this.service.getTrackingDetail(id));
    } catch {
      this.detail.set(null);
      this.error.set('No se encontró el seguimiento solicitado o no tienes permiso para consultarlo.');
    } finally {
      this.loading.set(false);
    }
  }
}
