package com.clinicainformatica.api;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class BackupMaintenanceGateTest {
    @Test
    void blocksNewRequestsUntilRestorationFinishes() {
        BackupMaintenanceGate gate = new BackupMaintenanceGate();
        assertTrue(gate.tryEnterRequest());
        boolean requestHeld = true;
        CountDownLatch restorationStarted = new CountDownLatch(1);
        ExecutorService executor = Executors.newSingleThreadExecutor();

        try {
            var restoration = executor.submit(() -> {
                gate.beginRestoration();
                try {
                    restorationStarted.countDown();
                } finally {
                    gate.endRestoration();
                }
            });

            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2);
            while (!gate.isRestorationRequested() && System.nanoTime() < deadline) {
                Thread.yield();
            }
            assertTrue(gate.isRestorationRequested());
            assertFalse(gate.tryEnterRequest());
            assertFalse(restoration.isDone());

            gate.leaveRequest();
            requestHeld = false;
            assertTrue(restorationStarted.await(2, TimeUnit.SECONDS));
            restoration.get(2, TimeUnit.SECONDS);
            assertTrue(gate.tryEnterRequest());
            gate.leaveRequest();
        } catch (Exception e) {
            throw new AssertionError("La barrera de mantenimiento no terminó correctamente.", e);
        } finally {
            if (requestHeld) gate.leaveRequest();
            executor.shutdownNow();
        }
    }
}
