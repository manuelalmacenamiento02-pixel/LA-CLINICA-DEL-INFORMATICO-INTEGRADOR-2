package com.clinicainformatica.api;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import org.springframework.stereotype.Component;

@Component
public class BackupMaintenanceGate {
    private final ReentrantReadWriteLock requests = new ReentrantReadWriteLock(true);
    private final AtomicBoolean restorationRequested = new AtomicBoolean();

    public boolean tryEnterRequest() {
        if (restorationRequested.get() || !requests.readLock().tryLock()) {
            return false;
        }
        if (restorationRequested.get()) {
            requests.readLock().unlock();
            return false;
        }
        return true;
    }

    public void leaveRequest() {
        requests.readLock().unlock();
    }

    public void beginRestoration() {
        if (!restorationRequested.compareAndSet(false, true)) {
            throw new ApiException(org.springframework.http.HttpStatus.CONFLICT, "restore-in-progress",
                "Ya hay una restauración en ejecución.");
        }
        requests.writeLock().lock();
    }

    public void endRestoration() {
        requests.writeLock().unlock();
        restorationRequested.set(false);
    }

    public boolean isRestorationRequested() {
        return restorationRequested.get();
    }
}
