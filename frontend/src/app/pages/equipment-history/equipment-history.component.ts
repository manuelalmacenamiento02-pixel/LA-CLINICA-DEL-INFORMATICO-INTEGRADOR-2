import { DatePipe } from '@angular/common';
import { Component, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { OrderStatus } from '../../core/service-order.models';
import { EquipmentService } from '../../core/equipment.service';
import { EquipmentServiceHistory, EquipmentServiceRecord } from '../../core/sprint-five.models';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-equipment-history',
  standalone: true,
  imports: [DatePipe, FormsModule, IconComponent, RouterLink],
  templateUrl: './equipment-history.component.html',
})
export class EquipmentHistoryComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly equipmentService = inject(EquipmentService);
  protected readonly history = signal<EquipmentServiceHistory | null>(null);
  protected readonly selectedRecord = signal<EquipmentServiceRecord | null>(null);
  protected readonly loading = signal(true);
  protected readonly error = signal('');
  protected status = '';
  protected from = '';
  protected to = '';

  ngOnInit(): void {
    this.route.paramMap.subscribe((params) => {
      const id = params.get('id');
      if (id) void this.load(id);
    });
  }

  protected async applyFilters(): Promise<void> {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) await this.load(id);
  }

  protected clearFilters(): void {
    this.status = '';
    this.from = '';
    this.to = '';
    void this.applyFilters();
  }

  protected selectRecord(record: EquipmentServiceRecord): void {
    this.selectedRecord.set(record);
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

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.error.set('');
    this.selectedRecord.set(null);
    try {
      this.history.set(await this.equipmentService.getHistory(id, this.status, this.from, this.to));
    } catch {
      this.history.set(null);
      this.error.set('No se pudo consultar el historial de servicios del equipo.');
    } finally {
      this.loading.set(false);
    }
  }
}
