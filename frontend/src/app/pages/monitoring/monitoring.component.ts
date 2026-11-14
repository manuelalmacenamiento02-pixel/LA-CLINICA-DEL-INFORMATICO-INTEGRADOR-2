import { Component, inject, signal } from '@angular/core';
import { MonitorStatus, SprintSixService, sprintSixErrorMessage } from '../../core/sprint-six.service';

@Component({
  selector: 'app-monitoring',
  standalone: true,
  templateUrl: './monitoring.component.html',
})
export class MonitoringComponent {
  private readonly service = inject(SprintSixService);
  protected readonly status = signal<MonitorStatus | null>(null);
  protected readonly loading = signal(false);
  protected readonly error = signal('');

  constructor() {
    void this.refresh();
  }

  protected async refresh(): Promise<void> {
    this.loading.set(true);
    this.error.set('');
    try {
      this.status.set(await this.service.monitoring());
    } catch (error) {
      this.error.set(sprintSixErrorMessage(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected statusLabel(status: string): string {
    switch (status) {
      case 'OK': return 'Operativo';
      case 'ALERTA': return 'Advertencia';
      case 'ERROR': return 'No disponible';
      default: return 'Desconocido';
    }
  }

  protected formatDate(value: string): string {
    return new Intl.DateTimeFormat('es', { dateStyle: 'short', timeStyle: 'medium' })
      .format(new Date(value));
  }
}
