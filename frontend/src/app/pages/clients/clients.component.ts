import { ApiStore } from '../../core/api.store';
import { Component, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule, NgForm } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Client, ClientDraft, DOCUMENT_TYPES, DocumentType } from '../../core/client.models';
import { ClientSaveResult, ClientService } from '../../core/client.service';
import { ClientDetail } from '../../core/sprint-five.models';
import { EquipmentService } from '../../core/equipment.service';
import { IconComponent } from '../../shared/icon/icon.component';

type ClientModalMode = 'create' | 'edit' | 'view';

@Component({
  selector: 'app-clients',
  standalone: true,
  imports: [DatePipe, FormsModule, IconComponent, RouterLink],
  templateUrl: './clients.component.html',
})
export class ClientsComponent {
  protected readonly busy = inject(ApiStore).pending;
  private readonly clientService = inject(ClientService);
  private readonly equipmentService = inject(EquipmentService);

  protected readonly clients = this.clientService.clients;
  protected readonly documentTypes = DOCUMENT_TYPES;
  protected filteredClients(): Client[] {
    const query = normalizeSearchText(this.searchTerm).split(' ').filter(Boolean);
    if (query.length === 0) return this.clients();

    return this.clients().filter((client) => {
      const searchable = normalizeSearchText(
        `${client.documentType} ${client.documentNumber} ${client.firstName} ${client.lastName}`,
      );
      return query.every((term) => searchable.includes(term));
    });
  }

  protected searchTerm = '';
  protected isModalOpen = false;
  protected modalMode: ClientModalMode = 'create';
  protected selectedClientId: string | null = null;
  protected submitted = false;
  protected duplicateDocument = false;
  protected duplicateEmail = false;
  protected formError = '';
  protected feedback = '';
  protected detailLoading = false;
  protected detailError = '';
  protected clientDetail: ClientDetail | null = null;
  protected draft: ClientDraft = this.emptyDraft();
  protected get clientCountLabel(): string {
    const count = this.filteredClients().length;
    return `${count} ${count === 1 ? 'cliente' : 'clientes'}`;
  }

  protected openCreate(): void {
    this.openForm('create');
  }

  protected openEdit(client: Client): void {
    this.openForm('edit', client);
  }

  protected openView(client: Client): void {
    this.openForm('view', client);
    void this.loadClientDetail(client.id);
  }

  protected closeModal(): void {
    this.isModalOpen = false;
  }

  protected async submitClient(form: NgForm): Promise<void> {
    if (this.busy()) return;
    this.submitted = true;
    this.duplicateDocument = false;
    this.duplicateEmail = false;
    this.formError = '';

    if (this.modalMode === 'view') {
      return;
    }

    this.draft.email = this.draft.email.trim();
    const validNames =
      this.draft.firstName.trim().length > 0 &&
      (this.draft.documentType === 'RUC' || this.draft.lastName.trim().length > 0);
    const validDocument = isValidDocument(this.draft.documentType, this.draft.documentNumber);
    const validPhone = isValidPhone(this.draft.phone);
    const validEmail = isValidEmail(this.draft.email);
    this.duplicateEmail = validEmail && this.clientService.isEmailInUse(
      this.draft.email,
      this.modalMode === 'edit' ? this.selectedClientId ?? undefined : undefined,
    );

    if (!form.valid || !validNames || !validDocument || !validPhone || !validEmail || this.duplicateEmail) {
      return;
    }

    const result: ClientSaveResult =
      this.modalMode === 'create'
        ? await this.clientService.create(this.draft)
        : this.selectedClientId
          ? await this.clientService.update(this.selectedClientId, this.draft)
          : 'not-found';

    if (result === 'duplicate-document') {
      this.duplicateDocument = true;
      return;
    }
    if (result === 'duplicate-email') {
      this.duplicateEmail = true;
      return;
    }
    if (result === 'storage-error') {
      this.formError = 'No se pudieron guardar los cambios en el servidor. Revisa el aviso de error.';
      return;
    }
    if (result === 'not-found') {
      this.formError = 'No se encontró el cliente que deseas actualizar.';
      return;
    }

    this.feedback =
      this.modalMode === 'create' ? 'Cliente registrado correctamente.' : 'Cambios del cliente guardados.';
    this.closeModal();
  }

  protected async deleteClient(client: Client): Promise<void> {
    if (this.busy()) return;
    this.feedback = '';
    if (this.equipmentService.forClient(client.id).length > 0) {
      this.formError = `No se puede eliminar a ${client.firstName}: tiene equipos u órdenes relacionadas. Se conservará su historial.`;
      return;
    }

    if (!window.confirm('¿Está seguro de eliminar este cliente?')) {
      return;
    }
    if (!(await this.clientService.delete(client.id))) {
      this.formError = 'No se pudo eliminar el cliente. Inténtalo nuevamente.';
      return;
    }

    this.formError = '';
    this.feedback = 'Cliente eliminado correctamente.';
  }

  protected fullName(client: Client): string {
    return `${client.firstName} ${client.lastName}`.trim();
  }

  protected get modalTitle(): string {
    switch (this.modalMode) {
      case 'create':
        return 'Nuevo cliente';
      case 'edit':
        return 'Editar cliente';
      case 'view':
        return 'Detalle del cliente';
    }
  }

  protected get isRuc(): boolean {
    return this.draft.documentType === 'RUC';
  }

  protected isValidDocumentValue(): boolean {
    return isValidDocument(this.draft.documentType, this.draft.documentNumber);
  }

  protected isValidPhoneValue(): boolean {
    return isValidPhone(this.draft.phone);
  }

  protected isValidEmailValue(): boolean {
    return isValidEmail(this.draft.email);
  }

  protected get documentMaxLength(): number {
    switch (this.draft.documentType) {
      case 'DNI': return 8;
      case 'RUC': return 11;
      case 'CE': return 20;
      case 'Otro': return 25;
    }
  }

  protected sanitizeDocument(value: string): void {
    this.draft.documentNumber = this.draft.documentType === 'DNI' || this.draft.documentType === 'RUC'
      ? value.replace(/\D/g, '')
      : value;
  }

  protected sanitizePhone(value: string): void {
    this.draft.phone = value.replace(/\D/g, '').slice(0, 9);
  }

  protected updateEmail(value: string): void {
    this.draft.email = value;
    this.duplicateEmail = false;
  }

  protected get documentFormatError(): string {
    switch (this.draft.documentType) {
      case 'DNI':
        return 'El DNI debe contener 8 dígitos.';
      case 'RUC':
        return 'El RUC debe contener 11 dígitos.';
      case 'CE':
        return 'El CE debe contener entre 5 y 20 caracteres alfanuméricos.';
      case 'Otro':
        return 'Ingresa entre 1 y 25 caracteres.';
    }
  }

  protected displayDocumentType(type: DocumentType): string {
    return type;
  }

  private openForm(mode: ClientModalMode, client?: Client): void {
    this.modalMode = mode;
    this.selectedClientId = client?.id ?? null;
    this.draft = client
      ? {
          documentType: client.documentType,
          documentNumber: client.documentNumber,
          firstName: client.firstName,
          lastName: client.lastName,
          phone: client.phone,
          email: client.email,
          address: client.address,
          observations: client.observations,
        }
      : this.emptyDraft();
    this.submitted = false;
    this.duplicateDocument = false;
    this.duplicateEmail = false;
    this.formError = '';
    this.feedback = '';
    this.clientDetail = null;
    this.detailError = '';
    this.detailLoading = false;
    this.isModalOpen = true;
  }

  private async loadClientDetail(id: string): Promise<void> {
    this.detailLoading = true;
    this.detailError = '';
    try {
      this.clientDetail = await this.clientService.getDetail(id);
    } catch {
      this.clientDetail = null;
      this.detailError = 'No se pudo cargar desde PostgreSQL la información relacionada del cliente.';
    } finally {
      this.detailLoading = false;
    }
  }

  private emptyDraft(): ClientDraft {
    return {
      documentType: 'DNI',
      documentNumber: '',
      firstName: '',
      lastName: '',
      phone: '',
      email: '',
      address: '',
      observations: '',
    };
  }
}

function isValidDocument(type: DocumentType, documentNumber: string): boolean {
  const normalized = documentNumber.trim();
  switch (type) {
    case 'DNI':
      return /^\d{8}$/.test(normalized);
    case 'RUC':
      return /^\d{11}$/.test(normalized);
    case 'CE':
      return /^[a-zA-Z0-9-]{5,20}$/.test(normalized);
    case 'Otro':
      return normalized.length >= 1 && normalized.length <= 25;
  }
}

function isValidPhone(phone: string): boolean {
  return /^\d{9}$/.test(phone.trim());
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

function normalizeSearchText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLocaleLowerCase()
    .trim()
    .replace(/\s+/g, ' ');
}
