import { Component, inject, signal } from '@angular/core';
import { BackupRun, SprintSixService, sprintSixErrorMessage } from '../../core/sprint-six.service';

@Component({
  selector: 'app-settings',
  standalone: true,
  templateUrl: './settings.component.html',
})
export class SettingsComponent {
  private readonly service = inject(SprintSixService);
  protected readonly backups = signal<BackupRun[]>([]);
  protected readonly selectedBackupId = signal('');
  protected readonly loading = signal(false);
  protected readonly restoring = signal(false);
  protected readonly error = signal('');
  protected readonly notice = signal('');

  constructor() {
    void this.refresh();
  }

  protected async refresh(): Promise<void> {
    this.loading.set(true);
    this.error.set('');
    try {
      const history = await this.service.backupHistory();
      this.backups.set(history);
      if (!history.some(backup => backup.id === this.selectedBackupId()
        && backup.status === 'COMPLETADO')) {
        this.selectedBackupId.set(history.find(backup => backup.status === 'COMPLETADO')?.id ?? '');
      }
    } catch (error) {
      this.error.set(sprintSixErrorMessage(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected async restoreSelected(): Promise<void> {
    const backup = this.backups().find(item =>
      item.id === this.selectedBackupId() && item.status === 'COMPLETADO',
    );
    if (!backup || this.restoring()) return;

    const confirmed = window.confirm(
      `ATENCIÓN: se reemplazarán los datos actuales con el respaldo ${backup.fileName ?? backup.id}. `
      + 'Antes se creará otra copia de seguridad. Durante la restauración, el sistema estará en mantenimiento. '
      + '¿Autorizas continuar?',
    );
    if (!confirmed) return;

    this.restoring.set(true);
    this.error.set('');
    this.notice.set('');
    try {
      const result = await this.service.restoreBackup(backup.id);
      this.notice.set(result.message);
      await this.refresh();
    } catch (error) {
      this.error.set(sprintSixErrorMessage(error));
      await this.refresh();
    } finally {
      this.restoring.set(false);
    }
  }

  protected updateSelection(event: Event): void {
    if (event.target instanceof HTMLSelectElement) {
      this.selectedBackupId.set(event.target.value);
    }
  }

  protected hasCompletedBackups(): boolean {
    return this.backups().some(backup => backup.status === 'COMPLETADO');
  }

  protected formatDate(value: string): string {
    return new Intl.DateTimeFormat('es', { dateStyle: 'medium', timeStyle: 'short' })
      .format(new Date(value));
  }

  protected formatSize(value: number | null): string {
    if (value === null) return 'Tamaño no disponible';
    if (value < 1024) return `${value} B`;
    if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`;
    return `${(value / (1024 * 1024)).toFixed(1)} MB`;
  }
}
