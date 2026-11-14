import { DatePipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ApiStore } from '../../core/api.store';
import { OrderStatus } from '../../core/service-order.models';
import { PublicTrackingResult } from '../../core/sprint-five.models';
import { ServiceOrderService } from '../../core/service-order.service';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-public-tracking',
  standalone: true,
  imports: [DatePipe, FormsModule, IconComponent, RouterLink],
  templateUrl: './public-tracking.component.html',
})
export class PublicTrackingComponent {
  protected readonly busy = inject(ApiStore).pending;
  private readonly service = inject(ServiceOrderService);
  protected code = '';
  protected phone = '';
  protected readonly result = signal<PublicTrackingResult | null>(null);
  protected readonly error = signal('');
  protected submitted = false;

  protected async consult(): Promise<void> {
    this.submitted = true;
    this.error.set('');
    this.result.set(null);
    const code = this.code.trim().toUpperCase();
    const phone = this.phone.trim();
    if (!/^OS-\d{6,}$/.test(code) || !/^[0-9+(). -]{7,30}$/.test(phone)) return;
    try {
      this.result.set(await this.service.getPublicTracking(code, phone));
    } catch {
      this.error.set('No se encontró un servicio con esos datos. Verifica el código y el teléfono asociado.');
    }
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

  protected get validCode(): boolean {
    return /^OS-\d{6,}$/i.test(this.code.trim());
  }
}
