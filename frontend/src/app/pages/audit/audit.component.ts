import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ApiStore } from '../../core/api.store';
import { AuditPage, SprintSixService, sprintSixErrorMessage } from '../../core/sprint-six.service';

@Component({
  selector: 'app-audit',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './audit.component.html',
})
export class AuditComponent {
  private readonly service = inject(SprintSixService);
  protected readonly store = inject(ApiStore);
  protected readonly page = signal<AuditPage | null>(null);
  protected readonly loading = signal(false);
  protected readonly error = signal('');
  protected search = '';
  protected user = '';
  protected module = '';
  protected from = '';
  protected to = '';
  protected result = '';
  protected currentPage = 0;

  constructor() {
    void this.refresh();
  }

  protected async refresh(page = 0): Promise<void> {
    this.currentPage = page;
    this.loading.set(true);
    this.error.set('');
    try {
      this.page.set(await this.service.audit({
        page: this.currentPage,
        search: this.search,
        user: this.user,
        module: this.module,
        from: this.from,
        to: this.to,
        result: this.result,
      }));
    } catch (error) {
      this.error.set(sprintSixErrorMessage(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected canGoBack(): boolean {
    return this.currentPage > 0;
  }

  protected canGoForward(): boolean {
    const value = this.page();
    return value !== null && (this.currentPage + 1) * value.size < value.total;
  }

  protected showPage(page: number): Promise<void> {
    return this.refresh(page);
  }

  protected formatDate(value: string): string {
    return new Intl.DateTimeFormat('es', { dateStyle: 'short', timeStyle: 'medium' })
      .format(new Date(value));
  }
}
