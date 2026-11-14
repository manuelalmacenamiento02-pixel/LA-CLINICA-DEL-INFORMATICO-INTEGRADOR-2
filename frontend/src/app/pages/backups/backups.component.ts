import { Component, inject, signal } from '@angular/core';
import { BackupRun, SprintSixService, sprintSixErrorMessage } from '../../core/sprint-six.service';

@Component({
  selector: 'app-backups',
  standalone: true,
  templateUrl: './backups.component.html',
})
export class BackupsComponent {
  private readonly service = inject(SprintSixService);
  protected readonly runs = signal<BackupRun[]>([]);
  protected readonly loading = signal(false);
  protected readonly creating = signal(false);
  protected readonly error = signal('');
  protected readonly notice = signal('');

  constructor() {
    void this.refresh();
  }

  protected async refresh(): Promise<void> {
    this.loading.set(true);
    this.error.set('');
    try {
      this.runs.set(await this.service.backupHistory());
    } catch (error) {
      this.error.set(sprintSixErrorMessage(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected async createBackup(): Promise<void> {
    if (!window.confirm('¿Deseas generar un respaldo completo de PostgreSQL ahora?')) return;
    this.creating.set(true);
    this.error.set('');
    this.notice.set('');
    try {
      await this.service.createBackup();
      this.notice.set('El respaldo se generó correctamente.');
      await this.refresh();
    } catch (error) {
      this.error.set(sprintSixErrorMessage(error));
      await this.refresh();
    } finally {
      this.creating.set(false);
    }
  }

  protected formatDate(value: string | null): string {
    return value
      ? new Intl.DateTimeFormat('es', { dateStyle: 'short', timeStyle: 'medium' }).format(new Date(value))
      : 'En ejecución';
  }

  protected formatSize(value: number | null): string {
    if (value === null) return 'No disponible';
    if (value < 1024) return `${value} B`;
    if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`;
    return `${(value / (1024 * 1024)).toFixed(1)} MB`;
  }

  protected statusLabel(status: BackupRun['status']): string {
    switch (status) {
      case 'EN_PROCESO': return 'En proceso';
      case 'COMPLETADO': return 'Completado';
      case 'ERROR': return 'Error';
    }
  }
}
