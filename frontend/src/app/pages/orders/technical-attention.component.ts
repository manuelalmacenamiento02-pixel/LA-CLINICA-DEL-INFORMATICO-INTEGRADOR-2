import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { FormsModule, NgForm } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { ApiStore } from '../../core/api.store';
import { OrderPriority, OrderStatus, ServiceOrder, TechnicalAttention, TechnicalAttentionDraft } from '../../core/service-order.models';
import { ServiceOrderService } from '../../core/service-order.service';
import { IconComponent } from '../../shared/icon/icon.component';

@Component({
  selector: 'app-technical-attention',
  standalone: true,
  imports: [FormsModule, IconComponent, RouterLink],
  templateUrl: './technical-attention.component.html',
})
export class TechnicalAttentionComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly service = inject(ServiceOrderService);
  private readonly store = inject(ApiStore);
  protected readonly order = signal<ServiceOrder | null>(null);
  protected readonly attention = signal<TechnicalAttention | null>(null);
  protected readonly loading = signal(true);
  protected readonly busy = this.store.pending;
  protected readonly error = signal('');
  protected readonly feedback = signal('');
  protected readonly started = computed(() => this.order()?.status === 'EN_ATENCION');
  protected readonly finalized = computed(() => this.order()?.status === 'FINALIZADA');
  protected readonly returnPath = computed(() =>
    this.store.user()?.role === 'TÉCNICO' ? '/mis-ordenes' : '/ordenes');
  protected submitted = false;
  protected draft: TechnicalAttentionDraft = this.emptyDraft();

  ngOnInit(): void {
    this.route.paramMap.subscribe((params) => {
      const id = params.get('id');
      if (id) void this.load(id);
    });
  }

  protected async startAttention(): Promise<void> {
    const order = this.order();
    if (!order || this.loading() || this.finalized()) return;
    if (!window.confirm(`¿Confirma iniciar la atención de ${order.code}?`)) return;
    this.error.set('');
    this.loading.set(true);
    try {
      this.order.set(await this.service.changeStatus(order.id, 'EN_ATENCION'));
      this.feedback.set('La orden está en atención. Puedes registrar y guardar avances.');
    } catch {
      this.error.set('No se pudo iniciar la atención. Confirma que esta orden esté asignada a tu usuario.');
    } finally {
      this.loading.set(false);
    }
  }

  protected async save(form: NgForm): Promise<void> {
    this.submitted = true;
    this.error.set('');
    this.feedback.set('');
    const order = this.order();
    if (!order || !this.started() || this.finalized() || this.busy() || !form.valid) return;
    try {
      this.attention.set(await this.service.saveAttention(order.id, this.draft));
      this.feedback.set('Avance de atención guardado en PostgreSQL.');
      this.submitted = false;
    } catch {
      this.error.set('No se pudo guardar el avance de atención. Comprueba los datos e inténtalo nuevamente.');
    }
  }

  protected async finalize(): Promise<void> {
    const order = this.order();
    if (!order || !this.started() || this.finalized() || this.busy()) return;
    if (!this.draft.diagnosis.trim() || !this.draft.actionsPerformed.trim()
      || !this.draft.resultSummary.trim() || !order.technicianId) {
      this.error.set('Completa el diagnóstico, las actividades y el resultado; la orden debe tener un técnico responsable.');
      this.submitted = true;
      return;
    }
    if (!window.confirm('¿Está seguro de finalizar esta orden? Se registrará como servicio finalizado')) return;
    this.error.set('');
    this.feedback.set('');
    try {
      await this.service.saveAttention(order.id, this.draft);
      await this.service.finalizeOrder(order.id);
      this.order.set({ ...order, status: 'FINALIZADA' });
      const saved = await this.service.getAttention(order.id);
      this.attention.set(saved);
      this.feedback.set('La orden se finalizó y el historial de estados fue actualizado.');
    } catch {
      this.error.set('No se pudo finalizar la orden. Verifica que el diagnóstico, actividades, resultado y técnico estén completos.');
    }
  }

  protected cancel(): void {
    const order = this.order();
    if (order) void this.router.navigate([this.returnPath()]);
  }

  protected equipmentName(order: ServiceOrder): string {
    return `${order.equipmentType} ${order.brand} ${order.model}`.trim();
  }

  protected priorityLabel(priority: OrderPriority): string {
    return priority === 'MEDIA'
      ? 'Media'
      : priority.toLowerCase().replace(/^./, (letter) => letter.toUpperCase());
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
    try {
      const [order, attention] = await Promise.all([
        this.service.get(id),
        this.service.getAttention(id),
      ]);
      this.order.set(order);
      const savedAttention = attention?.id ? attention : null;
      this.attention.set(savedAttention);
      this.draft = savedAttention
        ? {
            attendedAt: savedAttention.attendedAt.slice(0, 10),
            diagnosis: savedAttention.diagnosis,
            actionsPerformed: savedAttention.actionsPerformed,
            performedTests: savedAttention.performedTests,
            partsUsed: savedAttention.partsUsed,
            observations: savedAttention.observations,
            resultSummary: savedAttention.resultSummary,
          }
        : this.emptyDraft();
    } catch {
      this.order.set(null);
      this.attention.set(null);
      this.error.set('No se encontró la orden o no tienes permiso para registrar su atención.');
    } finally {
      this.loading.set(false);
    }
  }

  private emptyDraft(): TechnicalAttentionDraft {
    return {
      attendedAt: localDate(),
      diagnosis: '',
      actionsPerformed: '',
      performedTests: '',
      partsUsed: '',
      observations: '',
      resultSummary: '',
    };
  }
}

function localDate(): string {
  const now = new Date();
  return new Date(now.getTime() - now.getTimezoneOffset() * 60_000).toISOString().slice(0, 10);
}
