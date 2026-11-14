import { ApiStore } from '../../core/api.store';
import { Component, inject } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Client } from '../../core/client.models';
import { ClientService } from '../../core/client.service';
import { Equipment, EquipmentDraft, EQUIPMENT_TYPES, EquipmentType } from '../../core/equipment.models';
import { EquipmentSaveResult, EquipmentService } from '../../core/equipment.service';
import { IconComponent } from '../../shared/icon/icon.component';

type EquipmentModalMode = 'create' | 'edit' | 'view';

@Component({
  selector: 'app-equipment',
  standalone: true,
  imports: [FormsModule, IconComponent, RouterLink],
  templateUrl: './equipment.component.html',
})
export class EquipmentComponent {
  protected readonly busy = inject(ApiStore).pending;
  private readonly equipmentService = inject(EquipmentService);
  private readonly clientService = inject(ClientService);

  protected readonly equipment = this.equipmentService.equipment;
  protected readonly clients = this.clientService.clients;
  protected readonly equipmentTypes = EQUIPMENT_TYPES;
  protected filteredEquipment(): Equipment[] {
    const query = this.searchTerm.trim().toLocaleLowerCase();
    return this.equipment().filter((item) => {
      const owner = this.clientService.findById(item.clientId);
      return [
        item.serialNumber,
        item.type,
        item.brand,
        item.model,
        owner ? `${owner.firstName} ${owner.lastName}` : '',
      ].some((value) => value.toLocaleLowerCase().includes(query));
    });
  }

  protected searchTerm = '';
  protected clientSearch = '';
  protected isModalOpen = false;
  protected modalMode: EquipmentModalMode = 'create';
  protected selectedEquipmentId: string | null = null;
  protected submitted = false;
  protected duplicateSerial = false;
  protected formError = '';
  protected feedback = '';
  protected draft: EquipmentDraft = this.emptyDraft();
  protected get equipmentCountLabel(): string {
    const count = this.filteredEquipment().length;
    return `${count} ${count === 1 ? 'equipo' : 'equipos'}`;
  }

  protected matchingClients(): Client[] {
    const query = normalizeSearchText(this.clientSearch).split(' ').filter(Boolean);
    if (query.length === 0) return [];

    return this.clients().filter((client) => {
      const searchableText = normalizeSearchText(
        `${client.firstName} ${client.lastName} ${client.documentNumber} ${client.phone} ${client.email}`,
      );
      return query.every((term) => searchableText.includes(term));
    });
  }

  protected setClientSearch(value: string): void {
    this.clientSearch = value;
    if (
      normalizeSearchText(value) &&
      this.draft.clientId &&
      !this.matchingClients().some((client) => client.id === this.draft.clientId)
    ) {
      this.draft.clientId = '';
    }
  }

  protected selectClient(client: Client): void {
    this.draft.clientId = client.id;
  }

  protected openCreate(): void {
    this.openForm('create');
  }

  protected openEdit(equipment: Equipment): void {
    this.openForm('edit', equipment);
  }

  protected openView(equipment: Equipment): void {
    this.openForm('view', equipment);
  }

  protected closeModal(): void {
    this.isModalOpen = false;
  }

  protected async submitEquipment(form: NgForm): Promise<void> {
    if (this.busy()) return;
    this.submitted = true;
    this.duplicateSerial = false;
    this.formError = '';
    this.feedback = '';
    if (this.modalMode === 'view') {
      return;
    }

    const validFields =
      this.draft.brand.trim().length > 0 &&
      this.draft.model.trim().length > 0 &&
      this.draft.clientId.length > 0 &&
      this.clients().some((client) => client.id === this.draft.clientId) &&
      (!this.isSerialRequired || this.draft.serialNumber.trim().length > 0);
    if (!form.valid || !validFields) {
      return;
    }

    const clientIds = new Set(this.clients().map((client) => client.id));
    let result: EquipmentSaveResult;
    if (this.modalMode === 'create') {
      result = await this.equipmentService.create(this.draft, clientIds);
    } else if (this.selectedEquipmentId) {
      result = await this.equipmentService.update(this.selectedEquipmentId, this.draft, clientIds);
    } else {
      this.formError = 'No se encontró el equipo que deseas actualizar.';
      return;
    }

    if (result === 'duplicate-serial') {
      this.duplicateSerial = true;
      return;
    }
    if (result === 'storage-error') {
      this.formError = 'No se pudieron guardar los cambios en el servidor. Revisa el aviso de error.';
      return;
    }
    if (result === 'client-not-found') {
      this.formError = 'Selecciona un cliente registrado para asociar el equipo.';
      return;
    }
    if (result === 'not-found') {
      this.formError = 'No se encontró el equipo que deseas actualizar.';
      return;
    }

    this.feedback =
      this.modalMode === 'create' ? 'Equipo registrado correctamente.' : 'Cambios del equipo guardados.';
    this.closeModal();
  }

  protected async deleteEquipment(equipment: Equipment): Promise<void> {
    if (this.busy()) return;
    this.feedback = '';
    const description = `${equipment.brand} ${equipment.model}`;
    if (!window.confirm(`¿Está seguro de eliminar este equipo (${description})?`)) {
      return;
    }
    if (!(await this.equipmentService.delete(equipment.id))) {
      this.formError = 'No se pudo eliminar el equipo. Inténtalo nuevamente.';
      return;
    }

    this.formError = '';
    this.feedback = 'Equipo eliminado correctamente.';
  }

  protected ownerName(clientId: string): string {
    const client = this.clientService.findById(clientId);
    return client ? `${client.firstName} ${client.lastName}`.trim() : 'Cliente no disponible';
  }

  protected get modalTitle(): string {
    switch (this.modalMode) {
      case 'create':
        return 'Nuevo equipo';
      case 'edit':
        return 'Editar equipo';
      case 'view':
        return 'Ficha del equipo';
    }
  }

  protected get isOtherType(): boolean {
    return this.draft.type === 'Otro';
  }

  protected get isSerialRequired(): boolean {
    return this.draft.type !== 'Otro';
  }

  protected displayType(type: EquipmentType): string {
    return type;
  }

  private openForm(mode: EquipmentModalMode, equipment?: Equipment): void {
    this.modalMode = mode;
    this.selectedEquipmentId = equipment?.id ?? null;
    this.draft = equipment
      ? {
          clientId: equipment.clientId,
          type: equipment.type,
          brand: equipment.brand,
          model: equipment.model,
          serialNumber: equipment.serialNumber,
          characteristics: equipment.characteristics,
          accessories: equipment.accessories,
          observations: equipment.observations,
        }
      : this.emptyDraft();
    const selectedClient = equipment ? this.clientService.findById(equipment.clientId) : undefined;
    this.clientSearch = selectedClient
      ? `${selectedClient.firstName} ${selectedClient.lastName} — ${selectedClient.documentNumber}`.trim()
      : '';
    this.submitted = false;
    this.duplicateSerial = false;
    this.formError = '';
    this.isModalOpen = true;
  }

  private emptyDraft(): EquipmentDraft {
    return {
      clientId: '',
      type: 'Laptop',
      brand: '',
      model: '',
      serialNumber: '',
      characteristics: '',
      accessories: '',
      observations: '',
    };
  }
}

function normalizeSearchText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLocaleLowerCase()
    .trim()
    .replace(/\s+/g, ' ');
}
