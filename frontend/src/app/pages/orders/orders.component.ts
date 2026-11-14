import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ApiStore } from '../../core/api.store';
import { ClientService } from '../../core/client.service';
import { EquipmentService } from '../../core/equipment.service';
import { OrderPriority, OrderStatus, ServiceOrder, ServiceOrderDraft } from '../../core/service-order.models';
import { ServiceOrderService } from '../../core/service-order.service';
import { PermissionsService } from '../../core/permissions.service';
import { IconComponent } from '../../shared/icon/icon.component';

type OrderModal = 'create' | 'edit' | 'assign' | 'status' | null;

@Component({
  selector: 'app-orders',
  standalone: true,
  imports: [FormsModule, IconComponent, RouterLink],
  templateUrl: './orders.component.html',
})
export class OrdersComponent implements OnInit {
  private readonly orderService = inject(ServiceOrderService);
  private readonly clientService = inject(ClientService);
  private readonly equipmentService = inject(EquipmentService);
  private readonly permissions = inject(PermissionsService);
  private readonly apiStore = inject(ApiStore);

  protected readonly busy = this.apiStore.pending;
  protected readonly clients = this.clientService.clients;
  protected readonly allEquipment = this.equipmentService.equipment;
  protected readonly orders = this.orderService.orders;
  protected readonly technicians = this.orderService.technicians;
  protected filteredClients() {
    const query = normalize(this.clientSearchTerm).split(/\s+/).filter(Boolean);
    return this.clients().filter((client) => {
      const searchable = normalize(
        `${client.firstName} ${client.lastName} ${client.documentNumber}`,
      );
      return query.length === 0 || query.every((term) => searchable.includes(term));
    });
  }
  protected readonly canAssign = computed(() => {
    const role = this.apiStore.user()?.role;
    return !!role && this.permissions.can(role, 'assign-technicians');
  });
  protected readonly filteredOrders = computed(() => {
    const query = normalize(this.searchTerm);
    return this.orders().filter((order) => {
      const matchesQuery = !query || normalize([
        order.code, order.clientName, order.equipmentType, order.brand, order.model, order.serialNumber,
      ].join(' ')).includes(query);
      return matchesQuery && (!this.statusFilter || order.status === this.statusFilter);
    });
  });

  private readonly search = signal('');
  private readonly status = signal<OrderStatus | ''>('');
  protected get searchTerm(): string { return this.search(); }
  protected set searchTerm(value: string) { this.search.set(value); }
  protected get statusFilter(): OrderStatus | '' { return this.status(); }
  protected set statusFilter(value: OrderStatus | '') { this.status.set(value); }
  protected modal: OrderModal = null;
  protected selectedOrder: ServiceOrder | null = null;
  protected submitted = false;
  protected error = '';
  protected feedback = '';
  protected draft = this.emptyDraft();
  protected clientSearchTerm = '';
  protected technicianId = '';
  protected assignmentNotes = '';
  protected nextStatus: OrderStatus = 'EN_ATENCION';
  protected statusReason = '';

  ngOnInit(): void {
    void this.refresh();
  }

  protected async refresh(): Promise<void> {
    this.error = '';
    try {
      await this.orderService.load();
    } catch {
      this.error = 'No se pudieron cargar las órdenes desde PostgreSQL.';
    }
  }

  protected equipmentForSelectedClient() {
    return this.allEquipment().filter((item) => item.clientId === this.draft.clientId);
  }

  protected updateClientSearch(event: Event): void {
    if (event.target instanceof HTMLInputElement) {
      this.clientSearchTerm = event.target.value;
    }
  }

  protected openCreate(): void {
    this.selectedOrder = null;
    this.draft = this.emptyDraft();
    this.clientSearchTerm = '';
    this.submitted = false;
    this.error = '';
    this.feedback = '';
    this.modal = 'create';
  }

  protected openEdit(order: ServiceOrder): void {
    this.selectedOrder = order;
    this.clientSearchTerm = '';
    this.draft = {
      clientId: order.clientId,
      equipmentId: order.equipmentId,
      receivedDate: order.receivedDate,
      reportedProblem: order.reportedProblem,
      initialObservations: order.initialObservations,
      priority: order.priority,
    };
    this.submitted = false;
    this.error = '';
    this.modal = 'edit';
  }

  protected async submitOrder(form: NgForm): Promise<void> {
    this.submitted = true;
    this.error = '';
    if (this.busy() || !form.valid || !this.validOrderReferences()) return;
    try {
      if (this.modal === 'create') {
        await this.orderService.create(this.draft);
        this.feedback = 'Orden registrada correctamente.';
      } else if (this.modal === 'edit' && this.selectedOrder) {
        await this.orderService.update(this.selectedOrder.id, this.draft);
        this.feedback = 'Cambios de la orden guardados.';
      } else {
        return;
      }
      this.closeModal();
      await this.refresh();
    } catch {
      this.error = 'No se pudo guardar la orden. Revisa los datos y la conexión con el servidor.';
    }
  }

  protected async openAssign(order: ServiceOrder): Promise<void> {
    this.selectedOrder = order;
    this.technicianId = order.technicianId ?? '';
    this.assignmentNotes = '';
    this.submitted = false;
    this.error = '';
    this.modal = 'assign';
    try {
      await this.orderService.loadTechnicians();
    } catch {
      this.error = 'No se pudieron consultar los técnicos activos.';
    }
  }

  protected async submitAssignment(): Promise<void> {
    if (this.busy() || !this.selectedOrder || !this.technicianId) {
      this.submitted = true;
      return;
    }
    this.error = '';
    try {
      await this.orderService.assign(this.selectedOrder.id, this.technicianId, this.assignmentNotes);
      this.feedback = 'Técnico asignado correctamente.';
      this.closeModal();
      await this.refresh();
    } catch {
      this.error = 'No se pudo asignar el técnico. Verifica que siga activo y tenga el rol TÉCNICO.';
    }
  }

  protected openStatus(order: ServiceOrder): void {
    this.selectedOrder = order;
    this.nextStatus = order.status === 'FINALIZADA' ? 'FINALIZADA' : 'EN_ATENCION';
    this.statusReason = '';
    this.error = '';
    this.modal = 'status';
  }

  protected async submitStatus(): Promise<void> {
    if (!this.selectedOrder || this.busy()) return;
    if (this.nextStatus === 'FINALIZADA') {
      this.error = 'Para finalizar se requiere diagnóstico y resultado técnico, disponibles en el Sprint 4.';
      return;
    }
    if (!window.confirm(`¿Confirma cambiar ${this.selectedOrder.code} a EN_ATENCION?`)) return;
    this.error = '';
    try {
      await this.orderService.changeStatus(this.selectedOrder.id, this.nextStatus, this.statusReason);
      this.feedback = 'Estado de la orden actualizado.';
      this.closeModal();
      await this.refresh();
    } catch {
      this.error = 'No se pudo actualizar el estado. La orden debe tener un técnico asignado.';
    }
  }

  protected closeModal(): void {
    this.modal = null;
    this.submitted = false;
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
    return priority === 'MEDIA' ? 'Media' : priority.toLowerCase().replace(/^./, (letter) => letter.toUpperCase());
  }

  protected equipmentName(order: ServiceOrder): string {
    return `${order.equipmentType} ${order.brand} ${order.model}`.trim();
  }

  private validOrderReferences(): boolean {
    return this.clients().some((client) => client.id === this.draft.clientId)
      && this.equipmentForSelectedClient().some((equipment) => equipment.id === this.draft.equipmentId);
  }

  private emptyDraft(): ServiceOrderDraft {
    return {
      clientId: '',
      equipmentId: '',
      receivedDate: localDate(),
      reportedProblem: '',
      initialObservations: '',
      priority: 'MEDIA',
    };
  }
}

function normalize(value: string): string {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase().trim();
}

function localDate(): string {
  const now = new Date();
  const offset = now.getTimezoneOffset() * 60_000;
  return new Date(now.getTime() - offset).toISOString().slice(0, 10);
}
